from __future__ import annotations

from app.models import MlModel
from app.system_config import get_admin_config
from tests.conftest import auth_headers


def packet():
    return {
        "flex1": 0.1,
        "flex2": 0.2,
        "flex3": 0.3,
        "flex4": 0.4,
        "flex5": 0.5,
        "accelX": 0.6,
        "accelY": 0.7,
        "accelZ": 0.8,
        "gyroX": 0.9,
        "gyroY": 1.0,
        "gyroZ": 1.1,
    }


def setup_user_session(client) -> str:
    assert client.post(
        "/api/v1/auth/sync", headers=auth_headers(), json={}
    ).status_code == 200
    response = client.post(
        "/api/v1/sessions/start", headers=auth_headers(), json={}
    )
    assert response.status_code == 201
    return response.json()["data"]["sessionId"]


def configure_model(client, *, system_status: str = "on", active: bool = True):
    db = client.app.state.session_factory()
    try:
        model = MlModel(
            model_id="fixture-v1",
            name="Fixture",
            file_path="fixture.joblib",
            status="available",
            is_active=active,
        )
        db.add(model)
        db.flush()
        config = get_admin_config(db)
        config.system_status = system_status
        config.active_model_id = model.id if active else None
        config.service_toggles = {**config.service_toggles, "translation": True}
        db.commit()
    finally:
        db.close()


def test_inference_is_saved_and_session_aggregates_are_computed(client, ml_client) -> None:
    session_id = setup_user_session(client)
    configure_model(client)
    response = client.post(
        "/api/v1/ml/translate",
        headers=auth_headers(),
        json={"sessionId": session_id, "rawInput": packet(), "languageCode": "en-US"},
    )
    assert response.status_code == 200, response.text
    translated = response.json()["data"]
    assert translated["translatedText"] == "Hello"
    assert translated["confidence"] == 0.91
    assert translated["source"] == "live"
    assert ml_client.calls[0][0] == "fixture.joblib"

    current = client.get(
        f"/api/v1/translations/current-session/{session_id}", headers=auth_headers()
    )
    assert current.status_code == 200
    assert [item["entryId"] for item in current.json()["data"]] == [translated["entryId"]]
    empty_increment = client.get(
        f"/api/v1/translations/current-session/{session_id}",
        headers=auth_headers(),
        params={"cursor": translated["entryId"]},
    )
    assert empty_increment.json()["data"] == []

    stopped = client.post(
        f"/api/v1/sessions/{session_id}/stop",
        headers=auth_headers(),
        json={"status": "closed"},
    )
    aggregate = stopped.json()["data"]
    assert aggregate["totalReadings"] == 1
    assert aggregate["translatedLettersCount"] == 5
    assert aggregate["averageConfidence"] == 0.91
    history = client.get("/api/v1/translations/history", headers=auth_headers())
    assert len(history.json()["data"]) == 1


def test_pipeline_fails_closed_when_system_or_model_is_unavailable(client) -> None:
    session_id = setup_user_session(client)
    configure_model(client, system_status="off")
    response = client.post(
        "/api/v1/ml/translate",
        headers=auth_headers(),
        json={"sessionId": session_id, "rawInput": packet()},
    )
    assert response.status_code == 503
    assert response.json()["code"] == "SYSTEM_OFF"


def test_manual_translation_and_invalid_sensor_payload(client) -> None:
    session_id = setup_user_session(client)
    configure_model(client)
    invalid = client.post(
        "/api/v1/ml/translate",
        headers=auth_headers(),
        json={"sessionId": session_id, "rawInput": {"flex1": 1}},
    )
    assert invalid.status_code == 422
    manual = client.post(
        "/api/v1/translations",
        headers=auth_headers(),
        json={
            "sessionId": session_id,
            "rawInput": packet(),
            "translatedText": "Manual",
            "gestureLabel": "manual",
            "confidence": 0.5,
        },
    )
    assert manual.status_code == 201
    assert manual.json()["data"]["source"] == "manual_test"


def test_disabled_translation_blocks_supporting_mutations_and_model_list(client) -> None:
    setup_user_session(client)
    db = client.app.state.session_factory()
    try:
        config = get_admin_config(db)
        config.service_toggles = {**config.service_toggles, "translation": False}
        db.commit()
    finally:
        db.close()

    for method, path in (
        ("delete", "/api/v1/translations"),
        ("get", "/api/v1/ml/models"),
    ):
        response = getattr(client, method)(path, headers=auth_headers())
        assert response.status_code == 503
        assert response.json()["code"] == "SERVICE_DISABLED"
