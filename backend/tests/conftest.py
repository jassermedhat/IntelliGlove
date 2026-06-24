from __future__ import annotations

import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from app.config import Settings
from app.main import create_app


TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+psycopg://intelliglove:intelliglove@localhost:5432/intelliglove",
)


@pytest.fixture()
def db():
    engine = create_engine(TEST_DATABASE_URL)
    connection = engine.connect()
    transaction = connection.begin()
    factory = sessionmaker(bind=connection, expire_on_commit=False)
    session = factory()
    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()
        engine.dispose()


class FakeFirebaseIdentity:
    def __init__(self) -> None:
        now = int(__import__("time").time())
        self.tokens = {
            "verified-user": {
                "uid": "firebase-user-1",
                "email": "user1@example.com",
                "name": "User One",
                "email_verified": True,
                "auth_time": now,
            },
            "verified-user-2": {
                "uid": "firebase-user-2",
                "email": "user2@example.com",
                "name": "User Two",
                "email_verified": True,
                "auth_time": now,
            },
            "unverified-user": {
                "uid": "firebase-unverified",
                "email": "unverified@example.com",
                "name": "Unverified",
                "email_verified": False,
                "auth_time": now,
            },
            "conflicting-user": {
                "uid": "firebase-conflict",
                "email": "user1@example.com",
                "name": "Conflict",
                "email_verified": True,
                "auth_time": now,
            },
            "stale-user": {
                "uid": "firebase-stale",
                "email": "stale@example.com",
                "name": "Stale",
                "email_verified": True,
                "auth_time": now - 600,
            },
            "admin-user": {
                "uid": "firebase-admin",
                "email": "admin@example.com",
                "name": "Admin User",
                "email_verified": True,
                "auth_time": now,
            },
        }
        self.email_updates: list[tuple[str, str]] = []

    def verify_token(self, token: str):
        if token not in self.tokens:
            raise ValueError("invalid test token")
        return dict(self.tokens[token])

    def update_email(self, uid: str, email: str) -> None:
        self.email_updates.append((uid, email))


class FakeMlClient:
    def __init__(self) -> None:
        self.calls: list[tuple[str, dict]] = []

    def predict(self, model_path: str, raw_input: dict):
        self.calls.append((model_path, raw_input))
        return {
            "translatedText": "Hello",
            "gestureLabel": "hello",
            "confidence": 0.91,
        }

    def validate(self, model_path: str):
        return {"valid": True, "modelPath": model_path, "classes": ["hello"]}


def auth_headers(token: str = "verified-user") -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def firebase_identity() -> FakeFirebaseIdentity:
    return FakeFirebaseIdentity()


@pytest.fixture()
def ml_client() -> FakeMlClient:
    return FakeMlClient()


@pytest.fixture()
def client(firebase_identity, ml_client):
    engine = create_engine(TEST_DATABASE_URL)
    tables = [
        "translation_history",
        "sessions",
        "health_monitor_data",
        "smart_house_data",
        "analytics_data",
        "practice_mode_data",
        "feedback_reports",
        "alerts",
        "admin_config",
        "admin_users",
        "audit_logs",
        "devices",
        "users",
        "models",
        "practice_signs",
        "firmware_releases",
    ]
    with engine.begin() as connection:
        connection.execute(text("TRUNCATE TABLE " + ",".join(tables) + " CASCADE"))
    engine.dispose()
    settings = Settings(
        environment="test",
        database_url=TEST_DATABASE_URL,
        require_verified_email=True,
    )
    with TestClient(
        create_app(settings, firebase_identity=firebase_identity, ml_client=ml_client)
    ) as test_client:
        # Turn the system ON by default so tests that start sessions don't need
        # to configure this explicitly.  Individual tests that need system=off
        # should override it themselves.
        from app.system_config import get_admin_config, DEFAULT_SERVICE_TOGGLES
        db = test_client.app.state.session_factory()
        try:
            config = get_admin_config(db)
            config.system_status = "on"
            config.service_toggles = dict(DEFAULT_SERVICE_TOGGLES)
            db.commit()
        finally:
            db.close()
        yield test_client
