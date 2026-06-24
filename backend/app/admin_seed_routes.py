"""Admin seed data and development demo-glove endpoints (Issue 15)."""
from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Annotated, Any
from uuid import UUID, uuid4

from sqlalchemy import func

_log = logging.getLogger("intelliglove.seed")

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .admin_shared import (
    ALLOWED_SEED_TARGETS,
    DEMO_GLOVE_HARDWARE_ID,
    DEMO_GLOVE_NAME,
    _audit,
)
from .dependencies import get_current_admin, get_db
from .development_auth import DEVELOPMENT_USER_UID
from .errors import AppError
from .models import (
    AnalyticsData,
    Device,
    HealthMonitorData,
    PracticeModeData,
    PracticeSign,
    SmartHouseData,
    TranslationHistory,
    TranslationSession,
    User,
)

_router = APIRouter()


def _require_development_testing(request: Request) -> None:
    if not request.app.state.settings.development_auth_bypass:
        raise AppError(
            404,
            "DEVELOPMENT_FEATURE_DISABLED",
            "Development testing features are disabled.",
        )


def _testing_user(db: Session) -> User:
    user = db.scalar(select(User).where(User.firebase_uid == DEVELOPMENT_USER_UID))
    if user is None:
        user = User(
            firebase_uid=DEVELOPMENT_USER_UID,
            email="testing@intelliglove.local",
            name="Testing User",
            role="user",
            email_verified=True,
            status="active",
        )
        db.add(user)
        db.flush()
    return user


def _demo_glove(db: Session, user: User) -> Device | None:
    return db.scalar(
        select(Device).where(
            Device.user_id == user.id,
            Device.hardware_id == DEMO_GLOVE_HARDWARE_ID,
        )
    )


def _demo_glove_data(device: Device | None) -> dict[str, Any]:
    if device is None:
        return {"connected": False, "device": None}
    return {
        "connected": device.connection_status == "connected",
        "device": {
            "id": str(device.id),
            "deviceName": device.device_name,
            "hardwareId": device.hardware_id,
            "connectionStatus": device.connection_status,
            "firmwareVersion": device.firmware_version,
            "batteryLevel": device.battery_level,
            "signalStrength": device.signal_strength,
            "connectedAt": device.connected_at,
            "lastSeen": device.last_seen,
        },
    }


class DemoGlovePatch(BaseModel):
    connected: bool


@_router.get("/testing/demo-glove")
def read_demo_glove(
    request: Request,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    del admin
    _require_development_testing(request)
    user = db.scalar(select(User).where(User.firebase_uid == DEVELOPMENT_USER_UID))
    device = _demo_glove(db, user) if user is not None else None
    return {"data": _demo_glove_data(device)}


@_router.patch("/testing/demo-glove")
def update_demo_glove(
    payload: DemoGlovePatch,
    request: Request,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    _require_development_testing(request)
    user = _testing_user(db)
    device = _demo_glove(db, user)
    now = datetime.now(timezone.utc)
    if device is None:
        device = Device(
            user_id=user.id,
            device_name=DEMO_GLOVE_NAME,
            hardware_id=DEMO_GLOVE_HARDWARE_ID,
            firmware_version="demo-1.0.0",
            battery_level=96,
            signal_strength=5,
        )
        db.add(device)
    device.device_name = DEMO_GLOVE_NAME
    device.connection_status = "connected" if payload.connected else "disconnected"
    device.connected_at = now if payload.connected else None
    device.last_seen = now
    device.firmware_version = "demo-1.0.0"
    device.battery_level = 96
    device.signal_strength = 5
    db.flush()
    _audit(
        db,
        admin,
        f"testing.demo_glove.{'connect' if payload.connected else 'disconnect'}",
        target_type="device",
        target_id=str(device.id),
        details={"deviceName": DEMO_GLOVE_NAME, "testingUserId": str(user.id)},
    )
    db.commit()
    db.refresh(device)
    return {"data": _demo_glove_data(device)}


class SeedRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    targets: list[str] = Field(min_length=1)
    user_id: UUID | None = Field(default=None, alias="userId")
    use_testing_user: bool = Field(default=False, alias="useTestingUser")
    count: int = Field(default=10, ge=1, le=100)


# Shared "top gestures" sample for seeded analytics (percentage is a 0..1 fraction,
# matching what the mobile Top Gestures card renders as a bar width).
_ANALYTICS_TOP_GESTURES = [
    {"label": "Hello", "count": 38, "percentage": 0.88},
    {"label": "Thank you", "count": 31, "percentage": 0.72},
    {"label": "Yes", "count": 27, "percentage": 0.63},
    {"label": "No", "count": 22, "percentage": 0.51},
    {"label": "Help", "count": 18, "percentage": 0.42},
]


def _seed_target(db: Session, target: str, user: User, count: int, *, json_dir: Path | None = None) -> int:
    now = datetime.now(timezone.utc)
    if target == "healthMonitor":
        for index in range(count):
            db.add(
                HealthMonitorData(
                    user_id=user.id,
                    timestamp=now - timedelta(minutes=index),
                    metrics={
                        "isDemo": True,
                        "heartRate": 70 + index % 8,
                        "bloodPressure": "120/80",
                        "bloodOxygen": 98,
                        "respiratoryRate": 16,
                        "temperatureCelsius": 36.7,
                        "emotion": "Happy",
                        "activeEmotion": 2,
                    },
                    source="mock_seed",
                )
            )
    elif target == "smartHouse":
        templates = [
            ("Living Room Light", "light", "Peace Sign"),
            ("Smart TV", "tv", "Thumb Up"),
            ("Front Door Lock", "lock", "Fist"),
            ("Thermostat", "thermostat", "Open Palm"),
        ]
        for index in range(count):
            name, kind, gesture = templates[index % len(templates)]
            db.add(
                SmartHouseData(
                    user_id=user.id,
                    device_name=f"{name} {index + 1}" if count > len(templates) else name,
                    device_type=kind,
                    state={"isOn": index % 2 == 0, "gesture": gesture, "iconKey": kind},
                    source="mock_seed",
                )
            )
    elif target == "analytics":
        # The mobile app requests analytics by range (day / week / month) and the
        # read endpoint returns the most recent row whose metrics["range"] matches.
        # Seed ONE row per range (not many week rows) so all three views populate —
        # previously only "week" was seeded, leaving Day and Month empty.
        today = date.today()
        range_metrics = {
            "day": {
                "range": "day",
                "labels": ["8am", "9am", "10am", "11am", "12pm", "1pm", "2pm", "3pm"],
                "gestures": [12, 8, 22, 31, 18, 27, 19, 5],
                "accuracy": [94.0, 95.5, 92.0, 96.8, 95.5, 97.1, 96.4, 95.0],
                "sessionMinutes": [8, 5, 14, 22, 12, 18, 15, 4],
                "topGestures": _ANALYTICS_TOP_GESTURES,
            },
            "week": {
                "range": "week",
                "labels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                "gestures": [98, 124, 87, 142, 116, 155, 130],
                "accuracy": [94.2, 95.1, 93.8, 96.8, 95.5, 97.1, 96.4],
                "sessionMinutes": [24, 41, 18, 55, 37, 62, 48],
                "topGestures": _ANALYTICS_TOP_GESTURES,
            },
            "month": {
                "range": "month",
                "labels": ["Wk 1", "Wk 2", "Wk 3", "Wk 4"],
                "gestures": [612, 734, 890, 966],
                "accuracy": [93.0, 94.5, 95.8, 97.2],
                "sessionMinutes": [280, 340, 410, 490],
                "topGestures": _ANALYTICS_TOP_GESTURES,
            },
        }
        inserted = 0
        for range_name, metrics in range_metrics.items():
            # Distinct source per range keeps the (user_id, date, source) unique
            # constraint satisfied while still matching the wipe filter "mock_seed%".
            source = f"mock_seed_{range_name}"
            already = db.scalar(
                select(func.count()).select_from(AnalyticsData).where(
                    AnalyticsData.user_id == user.id,
                    AnalyticsData.date == today,
                    AnalyticsData.source == source,
                )
            ) or 0
            if not already:
                db.add(
                    AnalyticsData(
                        user_id=user.id,
                        date=today,
                        metrics=metrics,
                        source=source,
                    )
                )
                inserted += 1
        return inserted
    elif target == "practiceMode":
        for sign_id, text, lang, emoji in [
            ("asl-hello", "Hello", "en-US", "👋"),
            ("arsl-hello", "مرحبا", "ar-SA", "👋"),
        ]:
            sign = db.scalar(select(PracticeSign).where(PracticeSign.sign_id == sign_id))
            if sign is None:
                db.add(PracticeSign(
                    sign_id=sign_id,
                    expected_text=text,
                    language_code=lang,
                    difficulty="Easy",
                    metadata_json={"emoji": emoji},
                ))
        db.flush()
        for index in range(count):
            lang_sign = "asl-hello" if index % 2 == 0 else "arsl-hello"
            text = "Hello" if lang_sign == "asl-hello" else "مرحبا"
            db.add(
                PracticeModeData(
                    user_id=user.id,
                    sign_id=lang_sign,
                    expected_text=text,
                    detected_text=text,
                    score=90 + index % 10,
                    confidence=0.9,
                    source="mock_seed",
                )
            )
    elif target == "translationHistory":
        session = TranslationSession(
            session_id=f"seed_{uuid4().hex}",
            user_id=user.id,
            started_at=now - timedelta(minutes=5),
            ended_at=now,
            status="closed",
            source="mock_seed",
            translated_letters_count=count,
            total_readings=count,
            average_confidence=0.9,
        )
        db.add(session)
        db.flush()
        entries: list[dict[str, Any]] = []
        for index in range(count):
            ts = now - timedelta(seconds=count - index)
            text = chr(65 + index % 26)
            db.add(
                TranslationHistory(
                    entry_id=f"seed_trn_{uuid4().hex}",
                    session_id=session.id,
                    user_id=user.id,
                    timestamp=ts,
                    raw_input={"seed": True, "index": index},
                    translated_text=text,
                    language_code="en-US",
                    confidence=0.9,
                    source="mock_seed",
                )
            )
            entries.append({"text": text, "timestamp": ts.isoformat()})
        if json_dir is not None:
            try:
                json_dir.mkdir(parents=True, exist_ok=True)
                (json_dir / f"{session.session_id}.json").write_text(
                    json.dumps(entries, ensure_ascii=False), encoding="utf-8"
                )
            except OSError as exc:
                _log.warning("Seed: could not write session JSON (%s): %s", session.session_id, exc)
    return count


@_router.post("/seed")
def seed_data(
    payload: SeedRequest,
    request: Request,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    invalid = sorted(set(payload.targets) - ALLOWED_SEED_TARGETS)
    if invalid:
        raise AppError(422, "INVALID_SEED_TARGET", "One or more seed targets are invalid.", invalid)
    if payload.use_testing_user:
        _require_development_testing(request)
        target_user = _testing_user(db)
    elif payload.user_id:
        target_user = db.get(User, payload.user_id)
        if target_user is None:
            raise AppError(404, "USER_NOT_FOUND", "The seed target user was not found.")
    else:
        target_user = admin
    json_dir: Path | None = getattr(request.app.state.settings, "translation_json_dir", None)
    summary = {
        target: _seed_target(db, target, target_user, payload.count, json_dir=json_dir)
        for target in dict.fromkeys(payload.targets)
    }
    _audit(
        db,
        admin,
        "data.seed",
        target_type="user",
        target_id=str(target_user.id),
        details={"targets": summary},
    )
    db.commit()
    return {"data": {"userId": str(target_user.id), "inserted": summary}}


class WipeRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    user_id: UUID | None = Field(default=None, alias="userId")
    use_testing_user: bool = Field(default=False, alias="useTestingUser")


def _count_delete(db: Session, model, *filters) -> int:
    from sqlalchemy import delete as sa_delete
    rows = db.scalars(select(model).where(*filters)).all()
    n = len(rows)
    for row in rows:
        db.delete(row)
    return n


@_router.post("/seed/wipe")
def wipe_demo_data(
    payload: WipeRequest,
    request: Request,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    """Delete only demo data (source='mock_seed') for the target user."""
    if payload.use_testing_user:
        _require_development_testing(request)
        target_user = db.scalar(select(User).where(User.firebase_uid == DEVELOPMENT_USER_UID))
        if target_user is None:
            raise AppError(404, "USER_NOT_FOUND", "The testing user does not exist yet.")
    elif payload.user_id:
        target_user = db.get(User, payload.user_id)
        if target_user is None:
            raise AppError(404, "USER_NOT_FOUND", "The target user was not found.")
    else:
        raise AppError(422, "USER_REQUIRED", "Provide userId or useTestingUser=true.")

    uid = target_user.id

    health_n = _count_delete(
        db, HealthMonitorData,
        HealthMonitorData.user_id == uid,
        HealthMonitorData.source == "mock_seed",
    )
    smart_n = _count_delete(
        db, SmartHouseData,
        SmartHouseData.user_id == uid,
        SmartHouseData.source == "mock_seed",
    )
    practice_n = _count_delete(
        db, PracticeModeData,
        PracticeModeData.user_id == uid,
        PracticeModeData.source == "mock_seed",
    )

    # Analytics rows are identified by source prefix 'mock_seed_'.
    analytics_rows = db.scalars(
        select(AnalyticsData).where(
            AnalyticsData.user_id == uid,
            AnalyticsData.source.like("mock_seed%"),
        )
    ).all()
    analytics_n = len(analytics_rows)
    for row in analytics_rows:
        db.delete(row)

    # Translation sessions identified by source='mock_seed'; cascade deletes history.
    session_rows = db.scalars(
        select(TranslationSession).where(
            TranslationSession.user_id == uid,
            TranslationSession.source == "mock_seed",
        )
    ).all()
    history_n = sum(
        db.scalar(
            select(func.count()).select_from(TranslationHistory).where(
                TranslationHistory.session_id == s.id,
            )
        ) or 0
        for s in session_rows
    )
    sessions_n = len(session_rows)
    for s in session_rows:
        db.delete(s)  # CASCADE removes translation_history rows

    _audit(
        db,
        admin,
        "data.wipe",
        target_type="user",
        target_id=str(uid),
        details={
            "healthMonitor": health_n,
            "smartHouse": smart_n,
            "analytics": analytics_n,
            "practiceMode": practice_n,
            "translationSessions": sessions_n,
            "translationHistory": history_n,
        },
    )
    db.commit()
    return {
        "data": {
            "userId": str(uid),
            "deleted": {
                "healthMonitor": health_n,
                "smartHouse": smart_n,
                "analytics": analytics_n,
                "practiceMode": practice_n,
                "translationSessions": sessions_n,
                "translationHistory": history_n,
            },
        }
    }
