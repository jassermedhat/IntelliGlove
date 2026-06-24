"""Admin live-translation management endpoints (Issue 15)."""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .admin_shared import _audit, append_to_session_json
from .dependencies import get_current_admin, get_db
from .errors import AppError
from .models import TranslationSession, User
from .system_config import require_service

_router = APIRouter()


def _session_by_public_id(db: Session, session_id: str) -> TranslationSession:
    session = db.scalar(
        select(TranslationSession).where(TranslationSession.session_id == session_id)
    )
    if session is None:
        raise AppError(404, "SESSION_NOT_FOUND", "The session was not found.")
    return session


def _active_session_data(session: TranslationSession, user: User) -> dict:
    return {
        "sessionId": session.session_id,
        "userId": str(user.id),
        "userEmail": user.email,
        "userName": user.name,
        "startedAt": session.started_at,
        "totalReadings": session.total_readings,
    }


@_router.get("/translation/active-sessions")
def list_active_sessions(
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    del admin
    rows = db.scalars(
        select(TranslationSession)
        .where(TranslationSession.status == "active")
        .order_by(TranslationSession.started_at.desc())
    ).all()
    data = []
    for session in rows:
        user = db.get(User, session.user_id)
        if user is not None:
            data.append(_active_session_data(session, user))
    return {"data": data}


class TranslationSendRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    session_id: str = Field(alias="sessionId", min_length=1, max_length=64)
    text: str = Field(min_length=1, max_length=500)
    gesture_label: str | None = Field(default=None, alias="gestureLabel", max_length=100)
    confidence: float | None = Field(default=None, ge=0, le=1)


@_router.post("/translation/send", status_code=201)
def send_translation(
    payload: TranslationSendRequest,
    request: Request,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "translation")
    session = _session_by_public_id(db, payload.session_id)
    if session.status != "active":
        raise AppError(409, "SESSION_NOT_ACTIVE", "The session is not active.")

    text = payload.text.strip()
    ts = datetime.now(timezone.utc)

    # Append to the per-session JSON file (Issue 2).  The SessionWatcher picks
    # up the new entry, inserts it into translation_history, and pushes it over
    # WebSocket — keeping the JSON file as the single ingestion source.
    json_dir: Path = request.app.state.settings.translation_json_dir
    try:
        json_dir.mkdir(parents=True, exist_ok=True)
        append_to_session_json(json_dir / f"{payload.session_id}.json", {"text": text, "timestamp": ts.isoformat()})
    except OSError as exc:
        raise AppError(500, "FILE_WRITE_ERROR", f"Could not write to translation output: {exc}") from exc

    _audit(
        db,
        admin,
        "translation.manual_send",
        target_type="session",
        target_id=session.session_id,
        details={"text": text},
    )
    db.commit()

    return {
        "data": {
            "sessionId": payload.session_id,
            "text": text,
            "timestamp": ts.isoformat(),
            "queued": True,
        }
    }
