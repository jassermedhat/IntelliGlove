from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Annotated, Any, Literal
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, select
from sqlalchemy.orm import Session
from pathlib import Path

from .dependencies import get_current_user, get_db
from .errors import AppError
from .ingestion import ingestion_manager
from .models import Alert, Device, FirmwareRelease, TranslationHistory, TranslationSession, User
from .system_config import require_service

# ── helpers ───────────────────────────────────────────────────────────────────

def _user_session_number(db: Session, session: TranslationSession) -> int:
    """Return 1-based ordinal of this session among all sessions for the user, ordered by started_at."""
    return (
        db.scalar(
            select(func.count()).select_from(TranslationSession).where(
                TranslationSession.user_id == session.user_id,
                TranslationSession.started_at <= session.started_at,
                TranslationSession.id != session.id,
            )
        ) or 0
    ) + 1

log = logging.getLogger("intelliglove.core")

router = APIRouter()


class DeviceCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    device_name: str = Field(alias="deviceName", min_length=1, max_length=100)
    hardware_id: str | None = Field(default=None, alias="hardwareId", max_length=128)
    connection_status: Literal[
        "disconnected", "scanning", "connecting", "connected", "error"
    ] = Field(default="disconnected", alias="connectionStatus")
    firmware_version: str | None = Field(default=None, alias="firmwareVersion", max_length=50)
    battery_level: int | None = Field(default=None, alias="batteryLevel", ge=0, le=100)
    signal_strength: int | None = Field(default=None, alias="signalStrength", ge=0, le=5)


class DevicePatch(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    device_name: str | None = Field(default=None, alias="deviceName", min_length=1, max_length=100)
    connection_status: Literal[
        "disconnected", "scanning", "connecting", "connected", "error"
    ] | None = Field(default=None, alias="connectionStatus")
    firmware_version: str | None = Field(default=None, alias="firmwareVersion", max_length=50)
    battery_level: int | None = Field(default=None, alias="batteryLevel", ge=0, le=100)
    signal_strength: int | None = Field(default=None, alias="signalStrength", ge=0, le=5)

    @model_validator(mode="after")
    def require_value(self):
        if not self.model_fields_set:
            raise ValueError("At least one device field is required.")
        return self


class AutoConnectRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    device_name: str = Field(alias="deviceName", min_length=1, max_length=100)


class SessionStart(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    device_id: UUID | None = Field(default=None, alias="deviceId")


class SessionStop(BaseModel):
    status: str = Field(default="closed", pattern="^(closed|failed)$")


def _owned_device(db: Session, user: User, device_id: UUID) -> Device:
    device = db.scalar(
        select(Device).where(Device.id == device_id, Device.user_id == user.id)
    )
    if device is None:
        raise AppError(404, "DEVICE_NOT_FOUND", "The device was not found.")
    return device


def _device_data(device: Device) -> dict[str, Any]:
    return {
        "id": str(device.id),
        "deviceName": device.device_name,
        "hardwareId": device.hardware_id,
        "connectionStatus": device.connection_status,
        "connectedAt": device.connected_at,
        "lastSeen": device.last_seen,
        "firmwareVersion": device.firmware_version,
        "batteryLevel": device.battery_level,
        "signalStrength": device.signal_strength,
        "createdAt": device.created_at,
        "updatedAt": device.updated_at,
        "liveStateSource": "frontend",
    }


def _session_data(session: TranslationSession, db: Session | None = None) -> dict[str, Any]:
    return {
        "id": str(session.id),
        "sessionId": session.session_id,
        "sessionNumber": _user_session_number(db, session) if db is not None else None,
        "deviceId": str(session.device_id) if session.device_id else None,
        "startedAt": session.started_at,
        "endedAt": session.ended_at,
        "status": session.status,
        "translatedLettersCount": session.translated_letters_count,
        "totalReadings": session.total_readings,
        "averageConfidence": session.average_confidence,
        "createdAt": session.created_at,
        "updatedAt": session.updated_at,
    }


@router.get("/devices", tags=["devices"])
def list_devices(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "devices")
    devices = db.scalars(
        select(Device).where(Device.user_id == user.id).order_by(Device.created_at.desc())
    ).all()
    return {"data": [_device_data(device) for device in devices]}


@router.post("/devices", status_code=201, tags=["devices"])
def create_device(
    payload: DeviceCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "devices")
    now = datetime.now(timezone.utc)
    device = Device(
        user_id=user.id,
        device_name=payload.device_name.strip(),
        hardware_id=payload.hardware_id.strip() if payload.hardware_id else None,
        connection_status=payload.connection_status,
        connected_at=now if payload.connection_status == "connected" else None,
        last_seen=now if payload.connection_status == "connected" else None,
        firmware_version=payload.firmware_version,
        battery_level=payload.battery_level,
        signal_strength=payload.signal_strength,
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return {"data": _device_data(device)}


@router.get("/devices/{device_id}", tags=["devices"])
def get_device(
    device_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "devices")
    return {"data": _device_data(_owned_device(db, user, device_id))}


@router.patch("/devices/{device_id}", tags=["devices"])
def patch_device(
    device_id: UUID,
    payload: DevicePatch,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "devices")
    device = _owned_device(db, user, device_id)
    values = payload.model_dump(exclude_unset=True)
    for key, value in values.items():
        if key == "device_name" and value is not None:
            value = value.strip()
        setattr(device, key, value)
    if payload.connection_status == "connected":
        device.connected_at = device.connected_at or datetime.now(timezone.utc)
        device.last_seen = datetime.now(timezone.utc)
    db.commit()
    db.refresh(device)
    return {"data": _device_data(device)}


@router.delete("/devices/{device_id}", tags=["devices"])
def delete_device(
    device_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "devices")
    device = _owned_device(db, user, device_id)
    db.delete(device)
    db.commit()
    return {"data": {"deleted": True, "id": str(device_id)}}


@router.post("/devices/auto-connect", tags=["devices"])
def auto_connect(
    payload: AutoConnectRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "devices")
    device = db.scalar(
        select(Device).where(
            Device.user_id == user.id,
            func.lower(Device.device_name) == payload.device_name.strip().lower(),
        )
    )
    if device is None:
        raise AppError(404, "DEVICE_NOT_FOUND", "No matching owned device was found.")
    now = datetime.now(timezone.utc)
    device.connection_status = "connected"
    device.connected_at = device.connected_at or now
    device.last_seen = now
    db.commit()
    return {"data": _device_data(device)}


@router.post("/sessions/start", status_code=201, tags=["sessions"])
async def start_session(
    payload: SessionStart,
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    config = require_service(db, "translation")
    if config.system_status != "on":
        raise AppError(503, "SYSTEM_OFF", "The system is currently off. Enable it from the admin dashboard.")
    if payload.device_id:
        _owned_device(db, user, payload.device_id)
    settings = request.app.state.settings
    active = db.scalar(
        select(TranslationSession).where(
            TranslationSession.user_id == user.id,
            TranslationSession.status == "active",
        )
    )
    if active is not None:
        if ingestion_manager.has_session(active.session_id):
            # A live watcher is still running — this is a genuine duplicate.
            raise AppError(
                409,
                "ACTIVE_SESSION_EXISTS",
                "An active session already exists.",
                {"sessionId": active.session_id},
            )
        # No watcher running → the session is stale (e.g. server restart).
        # Close it silently and let the new session proceed.
        log.info(
            "Recovering stale session %s for user %s",
            active.session_id,
            str(user.id),
        )
        active.status = "closed"
        active.ended_at = datetime.now(timezone.utc)
        db.flush()
        stale_json = settings.translation_json_dir / f"{active.session_id}.json"
        try:
            if stale_json.exists():
                stale_json.unlink()
        except OSError:
            pass

    session = TranslationSession(
        session_id=f"ses_{uuid4().hex}",
        user_id=user.id,
        device_id=payload.device_id,
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # §7.2 — backend creates the JSON output file as an empty array so the
    # watcher and any producer can rely on it always existing after session start.
    json_dir = settings.translation_json_dir
    json_dir.mkdir(parents=True, exist_ok=True)
    json_path = json_dir / f"{session.session_id}.json"
    try:
        json_path.write_text("[]", encoding="utf-8")
    except OSError as exc:
        log.error("Cannot create JSON file %s: %s", json_path, exc)
        # Do not abort the session — just log; the watcher will skip missing files.

    # §7.6 — start the per-session ingestion watcher.
    ingestion_manager.start_session(
        session_db_id=session.id,
        session_public_id=session.session_id,
        user_db_id=user.id,
        firebase_uid=user.firebase_uid,
        json_path=json_path,
        poll_interval=settings.translation_poll_interval,
        session_factory=request.app.state.session_factory,
    )

    return {"data": _session_data(session, db)}


def _owned_session(db: Session, user: User, public_id: str) -> TranslationSession:
    session = db.scalar(
        select(TranslationSession).where(
            TranslationSession.session_id == public_id,
            TranslationSession.user_id == user.id,
        )
    )
    if session is None:
        raise AppError(404, "SESSION_NOT_FOUND", "The session was not found.")
    return session


@router.post("/sessions/{session_id}/stop", tags=["sessions"])
async def stop_session(
    session_id: str,
    payload: SessionStop,
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "translation")
    session = _owned_session(db, user, session_id)
    if session.status != "active":
        raise AppError(409, "SESSION_ALREADY_STOPPED", "The session is already closed.")

    # §7.6 — tear down the watcher BEFORE we close the session in the DB so
    # no in-flight poll can resurrect it.
    ingestion_manager.stop_session(session.session_id)

    # Issue 3 — persist any entries the watcher may have missed (e.g. appended
    # between the last poll and this stop call), then commit, then delete the
    # JSON file.  The file is only deleted AFTER a successful commit so that no
    # data is lost on failure.
    settings = request.app.state.settings
    json_path: Path = settings.translation_json_dir / f"{session.session_id}.json"
    _persist_remaining_json_entries(db, session, json_path)

    rows = db.scalars(
        select(TranslationHistory).where(TranslationHistory.session_id == session.id)
    ).all()
    session.status = payload.status
    session.ended_at = datetime.now(timezone.utc)
    session.total_readings = len(rows)
    session.translated_letters_count = sum(
        len("".join(row.translated_text.split())) for row in rows
    )
    confidences = [row.confidence for row in rows if row.confidence is not None]
    session.average_confidence = (
        round(sum(confidences) / len(confidences), 6) if confidences else None
    )
    db.commit()

    # Delete the JSON file only after a successful commit (Issue 3).
    try:
        if json_path.exists():
            json_path.unlink()
    except OSError as exc:
        log.warning("Could not delete session JSON file %s: %s", json_path, exc)

    db.refresh(session)
    return {"data": _session_data(session, db)}


def _persist_remaining_json_entries(
    db: Session,
    session: TranslationSession,
    json_path: Path,
) -> None:
    """Insert any entries from the JSON file that the watcher has not yet committed."""
    if not json_path.exists():
        return
    try:
        entries: list[dict[str, Any]] = json.loads(json_path.read_text(encoding="utf-8"))
    except Exception:
        return
    if not isinstance(entries, list) or not entries:
        return

    # Count rows the watcher already committed for this session.
    already_saved = db.scalar(
        select(func.count())
        .select_from(TranslationHistory)
        .where(TranslationHistory.session_id == session.id)
    ) or 0

    remaining = entries[already_saved:]
    for entry in remaining:
        text = str(entry.get("text") or "").strip()
        ts_raw = entry.get("timestamp") or ""
        try:
            ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            ts = datetime.now(timezone.utc)
        db.add(
            TranslationHistory(
                entry_id=f"trn_{uuid4().hex}",
                session_id=session.id,
                user_id=session.user_id,
                timestamp=ts,
                raw_input={},
                translated_text=text,
                source="live",
            )
        )
    if remaining:
        db.flush()


# §3.7 — device provisioning alias.  The spec defines POST /devices/provision
# as the way the phone registers a (possibly placeholder) device.  We implement
# it as a thin wrapper around the existing POST /devices logic.
class DeviceProvision(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    device_name: str = Field(alias="deviceName", min_length=1, max_length=100)
    hardware_id: str | None = Field(default=None, alias="hardwareId", max_length=128)


@router.post("/devices/provision", status_code=201, tags=["devices"])
def provision_device(
    payload: DeviceProvision,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    """Register / provision a (placeholder) glove device for a user (§3.7)."""
    require_service(db, "devices")
    # If an identical device already exists for this user, return it idempotently.
    existing = db.scalar(
        select(Device).where(
            Device.user_id == user.id,
            func.lower(Device.device_name) == payload.device_name.strip().lower(),
        )
    )
    if existing is not None:
        return {"data": _device_data(existing)}
    device = Device(
        user_id=user.id,
        device_name=payload.device_name.strip(),
        hardware_id=payload.hardware_id.strip() if payload.hardware_id else None,
        connection_status="disconnected",
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return {"data": _device_data(device)}


@router.get("/sessions", tags=["sessions"])
def list_sessions(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(default=50, ge=1, le=100),
):
    require_service(db, "translation")
    sessions = db.scalars(
        select(TranslationSession)
        .where(TranslationSession.user_id == user.id)
        .order_by(TranslationSession.started_at.desc())
        .limit(limit)
    ).all()
    return {"data": [_session_data(session, db) for session in sessions]}


@router.get("/sessions/{session_id}", tags=["sessions"])
def get_session(
    session_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "translation")
    session = _owned_session(db, user, session_id)
    return {"data": _session_data(session, db)}


def _alert_data(alert: Alert) -> dict[str, Any]:
    return {
        "id": str(alert.id),
        "title": alert.title,
        "message": alert.message,
        "type": alert.type,
        "isRead": alert.is_read,
        "createdAt": alert.created_at,
    }


@router.get("/alerts", tags=["alerts"])
def list_alerts(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    rows = db.scalars(
        select(Alert).where(Alert.user_id == user.id).order_by(Alert.created_at.desc())
    ).all()
    return {"data": [_alert_data(row) for row in rows]}


@router.patch("/alerts/{alert_id}/read", tags=["alerts"])
def mark_alert_read(
    alert_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    alert = db.scalar(
        select(Alert).where(Alert.id == alert_id, Alert.user_id == user.id)
    )
    if alert is None:
        raise AppError(404, "ALERT_NOT_FOUND", "The alert was not found.")
    alert.is_read = True
    db.commit()
    return {"data": _alert_data(alert)}


@router.post("/alerts/read-all", tags=["alerts"])
def mark_all_read(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    rows = db.scalars(select(Alert).where(Alert.user_id == user.id)).all()
    for row in rows:
        row.is_read = True
    db.commit()
    return {"data": {"updated": len(rows)}}


@router.get("/firmware/devices/{device_id}", tags=["firmware"])
def firmware_for_device(
    device_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "firmware")
    device = _owned_device(db, user, device_id)
    release = db.scalar(
        select(FirmwareRelease)
        .where(
            FirmwareRelease.active.is_(True),
            FirmwareRelease.device_model.in_([device.device_name, "*"]),
        )
        .order_by(FirmwareRelease.created_at.desc())
    )
    return {
        "data": {
            "deviceId": str(device.id),
            "currentVersion": device.firmware_version,
            "availableVersion": release.version if release else None,
            "releaseNotes": release.release_notes if release else None,
            "packageUrl": release.package_url if release else None,
            "otaSupported": False,
            "installationOwner": "hardware_adapter",
        }
    }
