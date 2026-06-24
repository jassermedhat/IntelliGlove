from __future__ import annotations

from datetime import date
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import inspect, select
from sqlalchemy.exc import IntegrityError

from app.config import Settings
from app.main import create_app
from app.models import AnalyticsData, Device, TranslationSession, User


def _user(suffix: str) -> User:
    return User(
        firebase_uid=f"firebase-{suffix}",
        email=f"{suffix}@example.com",
        name="Database Test",
    )


def test_settings_reject_non_postgresql() -> None:
    with pytest.raises(RuntimeError, match="PostgreSQL"):
        Settings(database_url="sqlite:///test.db").validate()


def test_migrated_schema_has_required_tables_and_no_sos(db) -> None:
    tables = set(inspect(db.get_bind()).get_table_names())
    assert {
        "users",
        "devices",
        "sessions",
        "translation_history",
        "health_monitor_data",
        "smart_house_data",
        "analytics_data",
        "practice_mode_data",
        "feedback_reports",
        "models",
        "admin_config",
        "admin_users",
        "audit_logs",
    } <= tables
    assert "sos_requests" not in tables
    assert "emergency_contacts" not in tables


def test_user_identity_constraints(db) -> None:
    suffix = uuid4().hex
    db.add(_user(suffix))
    db.flush()
    with pytest.raises(IntegrityError):
        with db.begin_nested():
            db.add(
                User(
                    firebase_uid=f"firebase-{suffix}",
                    email=f"other-{suffix}@example.com",
                    name="Duplicate UID",
                )
            )
            db.flush()


def test_jsonb_round_trip_and_active_session_constraint(db) -> None:
    suffix = uuid4().hex
    user = _user(suffix)
    db.add(user)
    db.flush()
    record = AnalyticsData(
        user_id=user.id,
        date=date.today(),
        metrics={"gestures": [1, 2, 3], "accuracy": 0.92},
        source="test",
    )
    db.add(record)
    first = TranslationSession(session_id=f"session-{suffix}", user_id=user.id)
    db.add(first)
    db.flush()
    assert db.scalar(select(AnalyticsData).where(AnalyticsData.id == record.id)).metrics[
        "accuracy"
    ] == 0.92

    with pytest.raises(IntegrityError):
        with db.begin_nested():
            db.add(TranslationSession(session_id=f"session-2-{suffix}", user_id=user.id))
            db.flush()


def test_device_connection_status_is_constrained(db) -> None:
    suffix = uuid4().hex
    user = _user(suffix)
    db.add(user)
    db.flush()
    with pytest.raises(IntegrityError):
        with db.begin_nested():
            db.add(
                Device(
                    user_id=user.id,
                    device_name="Invalid status glove",
                    connection_status="invented-status",
                )
            )
            db.flush()


def test_health_endpoint_connects_without_creating_schema() -> None:
    import os
    db_url = os.getenv(
        "TEST_DATABASE_URL",
        "postgresql+psycopg://intelliglove:intelliglove@localhost:5432/intelliglove",
    )
    settings = Settings(
        environment="test",
        database_url=db_url,
    )
    with TestClient(create_app(settings)) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["data"]["database"] == "postgresql"
