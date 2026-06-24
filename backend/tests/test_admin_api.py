from __future__ import annotations

from dataclasses import replace

from sqlalchemy import func, select

from app.admin_identity import ensure_admin_record
from app.development_auth import DEVELOPMENT_USER_UID
from app.models import (
    AuditLog,
    Device,
    HealthMonitorData,
    MlModel,
    TranslationHistory,
    User,
)
from tests.conftest import auth_headers


def test_cors_preflight_accepts_local_development_ports(client) -> None:
    headers = {
        "Origin": "http://localhost:43127",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "authorization,content-type",
    }
    response = client.options("/api/v1/auth/sync", headers=headers)
    assert response.status_code == 200, response.text
    assert response.headers["access-control-allow-origin"] == headers["Origin"]

    rejected = client.options(
        "/api/v1/auth/sync",
        headers={**headers, "Origin": "https://untrusted.example"},
    )
    assert rejected.status_code == 400
    assert "access-control-allow-origin" not in rejected.headers


def make_admin(client) -> dict:
    response = client.post(
        "/api/v1/auth/sync", headers=auth_headers("admin-user"), json={}
    )
    assert response.status_code == 200
    db = client.app.state.session_factory()
    try:
        user = ensure_admin_record(
            db,
            firebase_uid="firebase-admin",
            email="admin@example.com",
            name="Admin User",
        )
        return {"id": str(user.id)}
    finally:
        db.close()


def test_config_service_toggles_and_audits(client) -> None:
    make_admin(client)
    headers = auth_headers("admin-user")
    config = client.get("/api/v1/admin/config", headers=headers)
    assert config.status_code == 200
    assert config.json()["data"]["systemStatus"] == "on"
    toggles = client.patch(
        "/api/v1/admin/config/service-toggles",
        headers=headers,
        json={"serviceToggles": {"healthMonitor": False}},
    )
    assert toggles.status_code == 200
    assert toggles.json()["data"]["serviceToggles"]["healthMonitor"] is False
    status = client.patch(
        "/api/v1/admin/config/system-status",
        headers=headers,
        json={"systemStatus": "off"},
    )
    assert status.json()["data"]["systemStatus"] == "off"
    audit = client.get("/api/v1/admin/audit", headers=headers).json()["data"]
    assert {item["action"] for item in audit} >= {"services.update", "system.status.update"}


def test_model_scan_and_activation_requires_system_off(client, tmp_path) -> None:
    make_admin(client)
    headers = auth_headers("admin-user")
    client.patch("/api/v1/admin/config/system-status", headers=headers, json={"systemStatus": "off"})
    (tmp_path / "gesture_v1.joblib").write_bytes(b"fixture model bytes")
    client.app.state.settings = replace(client.app.state.settings, model_dir=tmp_path)
    scanned = client.post("/api/v1/admin/models/scan", headers=headers)
    assert scanned.status_code == 200, scanned.text
    model_id = scanned.json()["data"][0]["modelId"]
    activated = client.patch(
        f"/api/v1/admin/models/{model_id}/activate", headers=headers
    )
    assert activated.status_code == 200
    assert activated.json()["data"]["isActive"] is True

    # Verify GET /admin/models
    models = client.get("/api/v1/admin/models", headers=headers)
    assert models.status_code == 200
    assert isinstance(models.json()["data"], list)
    assert any(m["modelId"] == model_id for m in models.json()["data"])

    client.patch(
        "/api/v1/admin/config/system-status",
        headers=headers,
        json={"systemStatus": "on"},
    )
    blocked = client.patch(
        f"/api/v1/admin/models/{model_id}/activate", headers=headers
    )
    assert blocked.status_code == 409
    assert blocked.json()["code"] == "SYSTEM_MUST_BE_OFF"


def test_selective_seed_inserts_only_requested_targets_and_rejects_sos(client) -> None:
    admin = make_admin(client)
    headers = auth_headers("admin-user")
    seeded = client.post(
        "/api/v1/admin/seed",
        headers=headers,
        json={
            "targets": ["healthMonitor", "translationHistory"],
            "userId": admin["id"],
            "count": 3,
        },
    )
    assert seeded.status_code == 200, seeded.text
    assert seeded.json()["data"]["inserted"] == {
        "healthMonitor": 3,
        "translationHistory": 3,
    }
    db = client.app.state.session_factory()
    try:
        assert db.scalar(select(func.count()).select_from(HealthMonitorData)) == 3
        assert db.scalar(select(func.count()).select_from(TranslationHistory)) == 3
        assert db.scalar(select(AuditLog).where(AuditLog.action == "data.seed"))
    finally:
        db.close()
    rejected = client.post(
        "/api/v1/admin/seed",
        headers=headers,
        json={"targets": ["sos"], "count": 1},
    )
    assert rejected.status_code == 422
    assert rejected.json()["code"] == "INVALID_SEED_TARGET"


def test_analytics_seed_populates_day_week_and_month_ranges(client) -> None:
    # Regression: the seed previously wrote only metrics["range"]="week", so the
    # mobile app's Day and Month analytics views came back empty (the read endpoint
    # matches on range). Seeding must now populate all three ranges.
    admin = make_admin(client)
    headers = auth_headers("admin-user")
    seeded = client.post(
        "/api/v1/admin/seed",
        headers=headers,
        json={"targets": ["analytics"], "userId": admin["id"], "count": 5},
    )
    assert seeded.status_code == 200, seeded.text
    assert seeded.json()["data"]["inserted"]["analytics"] == 3

    for range_name in ("day", "week", "month"):
        resp = client.get(
            "/api/v1/analytics", headers=headers, params={"range": range_name}
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()["data"]
        assert data["range"] == range_name
        assert data["gestures"], f"{range_name} analytics should not be empty"
        assert data["labels"]
        assert data["topGestures"]


def test_non_admin_cannot_read_admin_config(client) -> None:
    assert client.post(
        "/api/v1/auth/sync", headers=auth_headers(), json={}
    ).status_code == 200
    response = client.get("/api/v1/admin/config", headers=auth_headers())
    assert response.status_code == 403


def test_admin_can_toggle_demo_glove_for_development_testing_user(client) -> None:
    make_admin(client)
    client.app.state.settings = replace(
        client.app.state.settings,
        development_auth_bypass=True,
    )
    headers = auth_headers("admin-user")

    connected = client.patch(
        "/api/v1/admin/testing/demo-glove",
        headers=headers,
        json={"connected": True},
    )
    assert connected.status_code == 200, connected.text
    assert connected.json()["data"]["connected"] is True
    assert connected.json()["data"]["device"]["deviceName"] == "INTELLIGLOVE DEMO"

    db = client.app.state.session_factory()
    try:
        user = db.scalar(select(User).where(User.firebase_uid == DEVELOPMENT_USER_UID))
        assert user is not None
        device = db.scalar(select(Device).where(Device.user_id == user.id))
        assert device is not None
        assert device.connection_status == "connected"
    finally:
        db.close()

    disconnected = client.patch(
        "/api/v1/admin/testing/demo-glove",
        headers=headers,
        json={"connected": False},
    )
    assert disconnected.status_code == 200
    assert disconnected.json()["data"]["connected"] is False


# ── Issue 1: GET /admin/users ─────────────────────────────────────────────────

def test_admin_list_users_returns_paginated_user_list(client) -> None:
    make_admin(client)
    # Sync a regular user so the table has at least 2 rows.
    client.post("/api/v1/auth/sync", headers=auth_headers("verified-user"), json={})
    headers = auth_headers("admin-user")
    response = client.get("/api/v1/admin/users", headers=headers)
    assert response.status_code == 200, response.text
    data = response.json()
    assert "data" in data
    assert "meta" in data
    assert isinstance(data["data"], list)
    assert data["meta"]["total"] >= 2
    for user in data["data"]:
        assert set(user.keys()) >= {"id", "email", "name", "role"}
        assert user["role"] in {"user", "admin"}


def test_admin_list_users_non_admin_gets_403(client) -> None:
    client.post("/api/v1/auth/sync", headers=auth_headers("verified-user"), json={})
    response = client.get("/api/v1/admin/users", headers=auth_headers("verified-user"))
    assert response.status_code == 403


def test_admin_list_users_pagination(client) -> None:
    make_admin(client)
    # Sync two extra users so there are at least 3 rows.
    client.post("/api/v1/auth/sync", headers=auth_headers("verified-user"), json={})
    client.post("/api/v1/auth/sync", headers=auth_headers("verified-user-2"), json={})
    headers = auth_headers("admin-user")
    page1 = client.get("/api/v1/admin/users?limit=2&offset=0", headers=headers).json()
    page2 = client.get("/api/v1/admin/users?limit=2&offset=2", headers=headers).json()
    assert len(page1["data"]) == 2
    assert page1["meta"]["total"] >= 3
    # Emails on second page must differ from first page.
    ids_p1 = {u["id"] for u in page1["data"]}
    ids_p2 = {u["id"] for u in page2["data"]}
    assert ids_p1.isdisjoint(ids_p2)


# ── Issue 16: POST /admin/devices/assign ─────────────────────────────────────

def test_admin_assign_device_creates_new_device(client) -> None:
    make_admin(client)
    client.post("/api/v1/auth/sync", headers=auth_headers("verified-user"), json={})
    db = client.app.state.session_factory()
    try:
        target = db.scalar(select(User).where(User.email == "user1@example.com"))
        assert target is not None
        target_id = str(target.id)
    finally:
        db.close()

    headers = auth_headers("admin-user")
    response = client.post(
        "/api/v1/admin/devices/assign",
        headers=headers,
        json={"userId": target_id, "deviceName": "Test Glove", "hardwareId": "HW-001"},
    )
    assert response.status_code == 201, response.text
    device = response.json()["data"]
    assert device["deviceName"] == "Test Glove"
    assert device["hardwareId"] == "HW-001"
    assert device["connectionStatus"] == "disconnected"
    assert device["userId"] == target_id


def test_admin_assign_device_upserts_existing_name(client) -> None:
    make_admin(client)
    client.post("/api/v1/auth/sync", headers=auth_headers("verified-user"), json={})
    db = client.app.state.session_factory()
    try:
        target = db.scalar(select(User).where(User.email == "user1@example.com"))
        target_id = str(target.id)
    finally:
        db.close()

    headers = auth_headers("admin-user")
    first = client.post(
        "/api/v1/admin/devices/assign",
        headers=headers,
        json={"userId": target_id, "deviceName": "My Glove"},
    )
    assert first.status_code == 201
    device_id = first.json()["data"]["id"]

    # Second call with same name → same device returned (upsert).
    second = client.post(
        "/api/v1/admin/devices/assign",
        headers=headers,
        json={"userId": target_id, "deviceName": "My Glove"},
    )
    assert second.status_code == 201
    assert second.json()["data"]["id"] == device_id


def test_admin_assign_device_unknown_user_returns_404(client) -> None:
    make_admin(client)
    from uuid import uuid4
    response = client.post(
        "/api/v1/admin/devices/assign",
        headers=auth_headers("admin-user"),
        json={"userId": str(uuid4()), "deviceName": "Ghost Glove"},
    )
    assert response.status_code == 404
    assert response.json()["code"] == "USER_NOT_FOUND"


# ── Translation output error handling ─────────────────────────────────────────

def test_send_translation_returns_file_write_error_on_ioerror(client, tmp_path) -> None:
    from unittest.mock import patch

    make_admin(client)
    client.post("/api/v1/auth/sync", headers=auth_headers("verified-user"), json={})
    client.app.state.settings = replace(client.app.state.settings, translation_json_dir=tmp_path)

    session_resp = client.post(
        "/api/v1/sessions/start", headers=auth_headers("verified-user"), json={}
    )
    assert session_resp.status_code == 201, session_resp.text
    session_id = session_resp.json()["data"]["sessionId"]

    with patch(
        "app.admin_translation_routes.append_to_session_json",
        side_effect=OSError("[Errno 13] Permission denied: '/translation_output/test.tmp'"),
    ):
        resp = client.post(
            "/api/v1/admin/translation/send",
            headers=auth_headers("admin-user"),
            json={"sessionId": session_id, "text": "Hello"},
        )

    assert resp.status_code == 500
    body = resp.json()
    assert body["code"] == "FILE_WRITE_ERROR"
    assert "Permission denied" in body["message"]


def test_seed_translationhistory_succeeds_when_json_dir_is_blocked(client, tmp_path) -> None:
    admin = make_admin(client)

    # A regular file where json_dir is expected makes mkdir() raise OSError —
    # the seed must still commit DB rows and return 200.
    blocker = tmp_path / "json_dir"
    blocker.write_text("blocker")
    client.app.state.settings = replace(
        client.app.state.settings, translation_json_dir=blocker
    )

    resp = client.post(
        "/api/v1/admin/seed",
        headers=auth_headers("admin-user"),
        json={"targets": ["translationHistory"], "userId": admin["id"], "count": 3},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["data"]["inserted"]["translationHistory"] == 3

    db = client.app.state.session_factory()
    try:
        assert db.scalar(select(func.count()).select_from(TranslationHistory)) == 3
    finally:
        db.close()
