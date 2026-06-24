"""
Tests for the per-session JSON file ingestion pipeline (§7).

These tests verify that:
  - POST /sessions/start creates the JSON file and starts the watcher.
  - Entries written to the JSON file are ingested into translation_history.
  - POST /sessions/{id}/stop stops the watcher and computes session aggregates.
  - System-off guard: when system_status is 'off' the watcher pauses ingestion.
"""

from __future__ import annotations

import asyncio
import json
import time
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.config import Settings
from app.main import create_app
from app.models import TranslationHistory, TranslationSession
from app.system_config import get_admin_config
from tests.conftest import FakeFirebaseIdentity, FakeMlClient, auth_headers


@pytest.fixture()
def tmp_json_dir(tmp_path):
    return tmp_path / "translation_output"


@pytest.fixture()
def ingestion_client(tmp_json_dir):
    """A test client configured with a temporary JSON directory."""
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import sessionmaker

    import os
    TEST_DB = os.getenv(
        "TEST_DATABASE_URL",
        "postgresql+psycopg://intelliglove:intelliglove@localhost:5432/intelliglove",
    )
    engine = create_engine(TEST_DB)
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
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE TABLE " + ",".join(tables) + " CASCADE"))
    engine.dispose()

    firebase_identity = FakeFirebaseIdentity()
    ml_client = FakeMlClient()
    settings = Settings(
        environment="test",
        database_url=TEST_DB,
        require_verified_email=True,
        translation_json_dir=tmp_json_dir,
        translation_poll_interval=0.1,  # fast polling for tests
    )
    # System must be "on" for sessions to start.
    # We turn it on after creating the client (seed DB).
    with TestClient(
        create_app(settings, firebase_identity=firebase_identity, ml_client=ml_client)
    ) as test_client:
        # Sync user and enable system.
        test_client.post("/api/v1/auth/sync", headers=auth_headers(), json={})
        db_factory = test_client.app.state.session_factory
        db = db_factory()
        try:
            config = get_admin_config(db)
            config.system_status = "on"
            config.service_toggles = {**config.service_toggles, "translation": True}
            db.commit()
        finally:
            db.close()
        yield test_client


def _write_entries(json_path: Path, entries: list[dict]) -> None:
    """Write a JSON array to the given path (appending to any existing entries)."""
    existing: list = []
    if json_path.exists():
        try:
            existing = json.loads(json_path.read_text(encoding="utf-8"))
        except Exception:
            existing = []
    json_path.write_text(json.dumps(existing + entries, ensure_ascii=False), encoding="utf-8")


def test_session_start_creates_json_file(ingestion_client, tmp_json_dir):
    """POST /sessions/start should create an empty JSON array file."""
    response = ingestion_client.post(
        "/api/v1/sessions/start", headers=auth_headers(), json={}
    )
    assert response.status_code == 201, response.text
    session_id = response.json()["data"]["sessionId"]
    json_path = tmp_json_dir / f"{session_id}.json"
    assert json_path.exists(), f"Expected JSON file at {json_path}"
    content = json.loads(json_path.read_text(encoding="utf-8"))
    assert content == [], "Expected empty JSON array in new session file"


def test_watcher_ingests_json_entries(ingestion_client, tmp_json_dir):
    """Entries written to the JSON file should appear in translation_history."""
    response = ingestion_client.post(
        "/api/v1/sessions/start", headers=auth_headers(), json={}
    )
    assert response.status_code == 201
    session_id = response.json()["data"]["sessionId"]
    json_path = tmp_json_dir / f"{session_id}.json"

    # Write two entries to the JSON file.
    from datetime import datetime, timezone
    _write_entries(json_path, [
        {"text": "Hello", "timestamp": datetime.now(timezone.utc).isoformat()},
        {"text": "World", "timestamp": datetime.now(timezone.utc).isoformat()},
    ])

    # Wait for the watcher to ingest (poll_interval=0.1 s → give 2 s headroom).
    deadline = time.monotonic() + 2.0
    db_factory = ingestion_client.app.state.session_factory
    found = []
    while time.monotonic() < deadline:
        db = db_factory()
        try:
            session_row = db.scalar(
                select(TranslationSession).where(
                    TranslationSession.session_id == session_id
                )
            )
            if session_row is not None:
                rows = db.scalars(
                    select(TranslationHistory).where(
                        TranslationHistory.session_id == session_row.id
                    )
                ).all()
                if len(rows) >= 2:
                    found = [r.translated_text for r in rows]
                    break
        finally:
            db.close()
        time.sleep(0.1)

    assert "Hello" in found, f"Expected 'Hello' in ingested rows, got: {found}"
    assert "World" in found, f"Expected 'World' in ingested rows, got: {found}"


def test_stop_session_stops_watcher_and_computes_aggregates(ingestion_client, tmp_json_dir):
    """POST /sessions/{id}/stop should stop the watcher and compute aggregates."""
    start_response = ingestion_client.post(
        "/api/v1/sessions/start", headers=auth_headers(), json={}
    )
    assert start_response.status_code == 201
    session_id = start_response.json()["data"]["sessionId"]
    json_path = tmp_json_dir / f"{session_id}.json"

    from datetime import datetime, timezone
    _write_entries(json_path, [
        {"text": "Hi", "timestamp": datetime.now(timezone.utc).isoformat()},
    ])
    # Allow the watcher to ingest.
    time.sleep(0.5)

    stop_response = ingestion_client.post(
        f"/api/v1/sessions/{session_id}/stop",
        headers=auth_headers(),
        json={"status": "closed"},
    )
    assert stop_response.status_code == 200, stop_response.text
    data = stop_response.json()["data"]
    assert data["status"] == "closed"
    assert data["totalReadings"] >= 1, "Expected at least 1 reading after ingestion"


def test_system_off_pauses_ingestion(ingestion_client, tmp_json_dir):
    """With system_status='off', the watcher must not ingest new JSON entries."""
    start_response = ingestion_client.post(
        "/api/v1/sessions/start", headers=auth_headers(), json={}
    )
    assert start_response.status_code == 201
    session_id = start_response.json()["data"]["sessionId"]
    json_path = tmp_json_dir / f"{session_id}.json"

    # Turn system off.
    db_factory = ingestion_client.app.state.session_factory
    db = db_factory()
    try:
        config = get_admin_config(db)
        config.system_status = "off"
        db.commit()
    finally:
        db.close()

    from datetime import datetime, timezone
    _write_entries(json_path, [
        {"text": "ShouldNotAppear", "timestamp": datetime.now(timezone.utc).isoformat()},
    ])
    # Wait longer than the poll interval.
    time.sleep(0.5)

    db = db_factory()
    try:
        session_row = db.scalar(
            select(TranslationSession).where(
                TranslationSession.session_id == session_id
            )
        )
        if session_row is not None:
            rows = db.scalars(
                select(TranslationHistory).where(
                    TranslationHistory.session_id == session_row.id
                )
            ).all()
            texts = [r.translated_text for r in rows]
            assert "ShouldNotAppear" not in texts, (
                "Watcher should not ingest entries while system is off"
            )
    finally:
        db.close()
