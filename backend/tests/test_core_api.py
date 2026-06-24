from __future__ import annotations

from app.models import Alert, FirmwareRelease
from app.system_config import get_admin_config
from tests.conftest import auth_headers


def _sync(client, token: str = "verified-user") -> None:
    response = client.post("/api/v1/auth/sync", headers=auth_headers(token), json={})
    assert response.status_code == 200, response.text


def _device(client, token: str = "verified-user", name: str = "IntelliGlove Pro") -> dict:
    response = client.post(
        "/api/v1/devices",
        headers=auth_headers(token),
        json={
            "deviceName": name,
            "hardwareId": f"hardware-{token}",
            "firmwareVersion": "2.3.1",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


def test_device_crud_auto_connect_and_ownership(client) -> None:
    _sync(client)
    _sync(client, "verified-user-2")
    device = _device(client)
    listed = client.get("/api/v1/devices", headers=auth_headers()).json()["data"]
    assert [item["id"] for item in listed] == [device["id"]]

    connected = client.post(
        "/api/v1/devices/auto-connect",
        headers=auth_headers(),
        json={"deviceName": "intelliglove pro"},
    )
    assert connected.status_code == 200
    assert connected.json()["data"]["connectionStatus"] == "connected"

    foreign = client.get(
        f"/api/v1/devices/{device['id']}", headers=auth_headers("verified-user-2")
    )
    assert foreign.status_code == 404

    updated = client.patch(
        f"/api/v1/devices/{device['id']}",
        headers=auth_headers(),
        json={"batteryLevel": 87, "signalStrength": 4},
    )
    assert updated.status_code == 200
    assert updated.json()["data"]["batteryLevel"] == 87
    assert client.delete(
        f"/api/v1/devices/{device['id']}", headers=auth_headers()
    ).status_code == 200


def test_device_status_validation_and_core_service_toggles(client) -> None:
    _sync(client)
    device = _device(client)
    invalid = client.patch(
        f"/api/v1/devices/{device['id']}",
        headers=auth_headers(),
        json={"connectionStatus": "invented-status"},
    )
    assert invalid.status_code == 422

    db = client.app.state.session_factory()
    try:
        config = get_admin_config(db)
        config.service_toggles = {
            **config.service_toggles,
            "devices": False,
            "translation": False,
            "firmware": False,
        }
        db.commit()
    finally:
        db.close()

    responses = (
        client.get("/api/v1/devices", headers=auth_headers()),
        client.post("/api/v1/sessions/start", headers=auth_headers(), json={}),
        client.get(
            f"/api/v1/firmware/devices/{device['id']}", headers=auth_headers()
        ),
    )
    for response in responses:
        assert response.status_code == 503
        assert response.json()["code"] == "SERVICE_DISABLED"


def test_sessions_enforce_one_active_and_ownership(client) -> None:
    _sync(client)
    _sync(client, "verified-user-2")
    device = _device(client)
    start = client.post(
        "/api/v1/sessions/start",
        headers=auth_headers(),
        json={"deviceId": device["id"]},
    )
    assert start.status_code == 201
    session_id = start.json()["data"]["sessionId"]
    duplicate = client.post(
        "/api/v1/sessions/start", headers=auth_headers(), json={}
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "ACTIVE_SESSION_EXISTS"
    assert client.get(
        f"/api/v1/sessions/{session_id}", headers=auth_headers("verified-user-2")
    ).status_code == 404

    stopped = client.post(
        f"/api/v1/sessions/{session_id}/stop",
        headers=auth_headers(),
        json={"status": "closed"},
    )
    assert stopped.status_code == 200
    assert stopped.json()["data"]["totalReadings"] == 0
    assert stopped.json()["data"]["averageConfidence"] is None


def test_stale_session_is_auto_recovered(client) -> None:
    """A session with status='active' but whose watcher is gone (e.g. after a
    server restart) must be auto-closed so the user can start a new session."""
    from app.ingestion import ingestion_manager
    from app.models import TranslationSession
    from sqlalchemy import select

    _sync(client)

    # Start a real session — this registers the watcher in ingestion_manager.
    start1 = client.post("/api/v1/sessions/start", headers=auth_headers(), json={})
    assert start1.status_code == 201, start1.json()
    stale_id = start1.json()["data"]["sessionId"]

    # Simulate a server restart: drop the watcher without touching the DB.
    ingestion_manager._watchers.pop(stale_id, None)

    # A second start should auto-close the stale session and succeed.
    start2 = client.post("/api/v1/sessions/start", headers=auth_headers(), json={})
    assert start2.status_code == 201, start2.json()
    new_id = start2.json()["data"]["sessionId"]
    assert new_id != stale_id

    # Verify the stale session was closed in the database.
    db = client.app.state.session_factory()
    try:
        stale = db.scalar(
            select(TranslationSession).where(TranslationSession.session_id == stale_id)
        )
        assert stale is not None
        assert stale.status == "closed"
    finally:
        db.close()


def test_stop_session_persists_json_entries_and_deletes_file(client, tmp_path) -> None:
    """Issue 3: JSON entries not yet committed by watcher are flushed on stop,
    and the file is deleted from disk after a successful commit."""
    from dataclasses import replace
    import json

    _sync(client)
    device = _device(client)

    # Point the app at a temp JSON dir so we can pre-seed a file.
    client.app.state.settings = replace(
        client.app.state.settings,
        translation_json_dir=tmp_path,
    )

    start = client.post(
        "/api/v1/sessions/start",
        headers=auth_headers(),
        json={"deviceId": device["id"]},
    )
    assert start.status_code == 201
    session_id = start.json()["data"]["sessionId"]

    # Write two entries directly to the JSON file (simulating ML output that
    # the watcher has NOT yet processed).
    json_path = tmp_path / f"{session_id}.json"
    json_path.write_text(
        json.dumps([
            {"text": "Hello", "timestamp": "2025-01-01T00:00:00Z"},
            {"text": "World", "timestamp": "2025-01-01T00:00:01Z"},
        ]),
        encoding="utf-8",
    )

    stopped = client.post(
        f"/api/v1/sessions/{session_id}/stop",
        headers=auth_headers(),
        json={"status": "closed"},
    )
    assert stopped.status_code == 200, stopped.text
    assert stopped.json()["data"]["status"] == "closed"

    # File must be gone after successful stop.
    assert not json_path.exists(), "JSON file should be deleted after commit"

    # Both entries should be in translation_history.
    from app.models import TranslationHistory
    from sqlalchemy import func, select
    db = client.app.state.session_factory()
    try:
        count = db.scalar(select(func.count()).select_from(TranslationHistory))
        assert count == 2
    finally:
        db.close()


def test_stop_session_preserves_json_when_commit_fails(client, tmp_path) -> None:
    """Issue 3 failure path: JSON file must NOT be deleted if db.commit() raises."""
    from dataclasses import replace
    from unittest.mock import patch
    import json
    import sqlalchemy.orm

    _sync(client)
    device = _device(client)
    client.app.state.settings = replace(client.app.state.settings, translation_json_dir=tmp_path)

    start = client.post(
        "/api/v1/sessions/start",
        headers=auth_headers(),
        json={"deviceId": device["id"]},
    )
    assert start.status_code == 201
    session_id = start.json()["data"]["sessionId"]

    json_path = tmp_path / f"{session_id}.json"
    json_path.write_text(
        json.dumps([{"text": "A", "timestamp": "2025-01-01T00:00:00Z"}]),
        encoding="utf-8",
    )

    original_commit = sqlalchemy.orm.Session.commit
    call_count = [0]

    def failing_commit(self):
        call_count[0] += 1
        if call_count[0] == 1:
            raise Exception("Simulated DB failure")
        return original_commit(self)

    # Starlette's TestClient re-raises unhandled server exceptions instead of
    # converting them to 500.  Catch either outcome; the critical assertion is
    # that the file survives regardless.
    with patch.object(sqlalchemy.orm.Session, "commit", failing_commit):
        try:
            response = client.post(
                f"/api/v1/sessions/{session_id}/stop",
                headers=auth_headers(),
                json={"status": "closed"},
            )
            assert response.status_code >= 500
        except Exception:
            pass  # re-raised by TestClient — still counts as a server error

    assert json_path.exists(), "JSON file must be preserved when commit fails"


def test_alerts_and_firmware_are_database_backed(client) -> None:
    _sync(client)
    device = _device(client)
    session = client.app.state.session_factory()
    try:
        from app.models import User
        from sqlalchemy import select

        user = session.scalar(select(User).where(User.firebase_uid == "firebase-user-1"))
        alert = Alert(
            user_id=user.id,
            title="Calibration complete",
            message="All sensors calibrated.",
            type="success",
        )
        release = FirmwareRelease(
            device_model="IntelliGlove Pro",
            version="2.5.0",
            release_notes="Recognition improvements.",
        )
        session.add_all([alert, release])
        session.commit()
    finally:
        session.close()

    alerts = client.get("/api/v1/alerts", headers=auth_headers())
    assert alerts.status_code == 200
    alert_id = alerts.json()["data"][0]["id"]
    marked = client.patch(
        f"/api/v1/alerts/{alert_id}/read", headers=auth_headers()
    )
    assert marked.json()["data"]["isRead"] is True

    firmware = client.get(
        f"/api/v1/firmware/devices/{device['id']}", headers=auth_headers()
    )
    assert firmware.status_code == 200
    assert firmware.json()["data"]["availableVersion"] == "2.5.0"
    assert firmware.json()["data"]["otaSupported"] is False
