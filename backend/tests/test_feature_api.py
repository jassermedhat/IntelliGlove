from __future__ import annotations

from datetime import date

from sqlalchemy import select

from app.models import (
    AdminConfig,
    AnalyticsData,
    HealthMonitorData,
    PracticeSign,
    SmartHouseData,
    User,
)
from tests.conftest import auth_headers


def setup_features(client):
    assert client.post(
        "/api/v1/auth/sync", headers=auth_headers(), json={}
    ).status_code == 200
    db = client.app.state.session_factory()
    try:
        user = db.scalar(select(User).where(User.firebase_uid == "firebase-user-1"))
        health = HealthMonitorData(
            user_id=user.id,
            metrics={"heartRate": 72, "bloodOxygen": 98, "isDemo": False},
            source="device",
        )
        smart = SmartHouseData(
            user_id=user.id,
            device_name="Living Room Light",
            device_type="light",
            state={"isOn": True, "gesture": "Peace Sign", "iconKey": "light"},
            source="mock_seed",
        )
        analytics = AnalyticsData(
            user_id=user.id,
            date=date.today(),
            metrics={
                "range": "week",
                "gestures": [3],
                "labels": ["Mon"],
                "accuracy": [91.0],
                "sessionMinutes": [5],
                "topGestures": [],
            },
            source="mock_seed",
        )
        sign = PracticeSign(
            sign_id="asl-hello",
            expected_text="Hello",
            language_code="en-US",
            difficulty="Easy",
            metadata_json={"emoji": "👋"},
        )
        db.add_all([health, smart, analytics, sign])
        db.commit()
        return str(smart.id)
    finally:
        db.close()


def test_health_smart_house_and_analytics_are_database_backed(client) -> None:
    smart_id = setup_features(client)
    health = client.get("/api/v1/health-monitor", headers=auth_headers())
    assert health.json()["data"]["metrics"]["heartRate"] == 72
    smart = client.get("/api/v1/smart-house", headers=auth_headers())
    assert smart.json()["data"][0]["deviceName"] == "Living Room Light"
    toggled = client.patch(
        f"/api/v1/smart-house/{smart_id}",
        headers=auth_headers(),
        json={"state": {"isOn": False}},
    )
    assert toggled.json()["data"]["state"]["isOn"] is False
    analytics = client.get(
        "/api/v1/analytics", headers=auth_headers(), params={"range": "week"}
    )
    assert analytics.json()["data"]["gestures"] == [3]


def test_practice_catalog_results_and_stats(client) -> None:
    setup_features(client)
    initial = client.get(
        "/api/v1/practice-mode",
        headers=auth_headers(),
        params={"languageCode": "en-US"},
    )
    assert initial.json()["data"]["signs"][0]["id"] == "asl-hello"
    created = client.post(
        "/api/v1/practice-mode/results",
        headers=auth_headers(),
        json={"signId": "asl-hello", "detectedText": "Hello", "score": 92, "confidence": 0.94},
    )
    assert created.status_code == 201
    loaded = client.get(
        "/api/v1/practice-mode",
        headers=auth_headers(),
        params={"languageCode": "en-US"},
    ).json()["data"]
    assert loaded["stats"]["totalPracticed"] == 1
    assert loaded["stats"]["averageAccuracy"] == 92


def test_disabled_feature_returns_standard_error(client) -> None:
    setup_features(client)
    db = client.app.state.session_factory()
    try:
        config = db.scalar(select(AdminConfig).where(AdminConfig.singleton_key == "default"))
        if config is None:
            from app.system_config import get_admin_config

            config = get_admin_config(db)
        config.service_toggles = {**config.service_toggles, "healthMonitor": False}
        db.commit()
    finally:
        db.close()
    response = client.get("/api/v1/health-monitor", headers=auth_headers())
    assert response.status_code == 503
    assert response.json()["code"] == "SERVICE_DISABLED"
    assert response.json()["message"] == "This feature is currently unavailable."
