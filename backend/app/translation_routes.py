from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Annotated, Any
from uuid import uuid4

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from .core_routes import _owned_session
from .dependencies import get_current_user, get_db
from .errors import AppError
from .ml_client import MlServiceError
from .models import MlModel, TranslationHistory, TranslationSession, User
from .system_config import require_service


router = APIRouter(tags=["translations"])

SENSOR_FIELDS = (
    "flex1",
    "flex2",
    "flex3",
    "flex4",
    "flex5",
    "accelX",
    "accelY",
    "accelZ",
    "gyroX",
    "gyroY",
    "gyroZ",
)


def _validate_raw(raw: dict[str, Any]) -> dict[str, Any]:
    missing = [field for field in SENSOR_FIELDS if field not in raw]
    if missing:
        raise ValueError("Missing sensor fields: " + ", ".join(missing))
    for field in SENSOR_FIELDS:
        value = raw[field]
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError(f"{field} must be a number")
        if not math.isfinite(float(value)):
            raise ValueError(f"{field} must be finite")
    return raw


class TranslateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    session_id: str = Field(alias="sessionId", min_length=1, max_length=64)
    raw_input: dict[str, Any] = Field(alias="rawInput")
    language_code: str = Field(default="en-US", alias="languageCode", max_length=20)

    @field_validator("raw_input")
    @classmethod
    def validate_sensor_input(cls, value):
        return _validate_raw(value)


class ManualTranslationRequest(TranslateRequest):
    translated_text: str = Field(alias="translatedText", min_length=1, max_length=500)
    gesture_label: str | None = Field(default=None, alias="gestureLabel", max_length=100)
    confidence: float | None = Field(default=None, ge=0, le=1)


def _translation_data(row: TranslationHistory) -> dict[str, Any]:
    return {
        "id": str(row.id),
        "entryId": row.entry_id,
        "sessionId": row.session.session_id if row.session else None,
        "deviceId": str(row.device_id) if row.device_id else None,
        "timestamp": row.timestamp,
        "rawInput": row.raw_input,
        "translatedText": row.translated_text,
        "gestureLabel": row.gesture_label,
        "languageCode": row.language_code,
        "confidence": row.confidence,
        "modelId": str(row.model_id) if row.model_id else None,
        "source": row.source,
        "createdAt": row.created_at,
    }


def _save_translation(
    db: Session,
    *,
    session: TranslationSession,
    raw_input: dict[str, Any],
    translated_text: str,
    gesture_label: str | None,
    language_code: str,
    confidence: float | None,
    model_id,
    source: str,
) -> TranslationHistory:
    row = TranslationHistory(
        entry_id=f"trn_{uuid4().hex}",
        session_id=session.id,
        user_id=session.user_id,
        device_id=session.device_id,
        timestamp=datetime.now(timezone.utc),
        raw_input=raw_input,
        translated_text=translated_text,
        gesture_label=gesture_label,
        language_code=language_code,
        confidence=confidence,
        model_id=model_id,
        source=source,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.post("/ml/translate")
def translate(
    payload: TranslateRequest,
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    config = require_service(db, "translation")
    if config.system_status != "on":
        raise AppError(503, "SYSTEM_OFF", "The translation system is currently off.")
    session = _owned_session(db, user, payload.session_id)
    if session.status != "active":
        raise AppError(409, "SESSION_NOT_ACTIVE", "The translation session is not active.")
    model = db.get(MlModel, config.active_model_id) if config.active_model_id else None
    if model is None or model.status != "available" or not model.is_active:
        raise AppError(503, "NO_ACTIVE_MODEL", "No valid active model is configured.")
    try:
        result = request.app.state.ml_client.predict(model.file_path, payload.raw_input)
    except MlServiceError as error:
        raise AppError(502, "ML_INFERENCE_FAILED", str(error)) from error
    row = _save_translation(
        db,
        session=session,
        raw_input=payload.raw_input,
        translated_text=str(result["translatedText"]),
        gesture_label=result.get("gestureLabel"),
        language_code=payload.language_code,
        confidence=float(result["confidence"]),
        model_id=model.id,
        source="live",
    )
    return {"data": _translation_data(row)}


@router.post("/translations", status_code=201)
def save_manual_translation(
    payload: ManualTranslationRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "translation")
    session = _owned_session(db, user, payload.session_id)
    if session.status != "active":
        raise AppError(409, "SESSION_NOT_ACTIVE", "The translation session is not active.")
    row = _save_translation(
        db,
        session=session,
        raw_input=payload.raw_input,
        translated_text=payload.translated_text,
        gesture_label=payload.gesture_label,
        language_code=payload.language_code,
        confidence=payload.confidence,
        model_id=None,
        source="manual_test",
    )
    return {"data": _translation_data(row)}


def _translation_query(user: User, session: TranslationSession | None = None):
    query = select(TranslationHistory).where(TranslationHistory.user_id == user.id)
    if session is not None:
        query = query.where(TranslationHistory.session_id == session.id)
    return query


@router.get("/translations")
def list_translations(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    session_id: str | None = Query(default=None, alias="sessionId"),
    limit: int = Query(default=100, ge=1, le=200),
):
    require_service(db, "translation")
    session = _owned_session(db, user, session_id) if session_id else None
    rows = db.scalars(
        _translation_query(user, session)
        .order_by(TranslationHistory.timestamp.desc())
        .limit(limit)
    ).all()
    return {"data": [_translation_data(row) for row in rows]}


@router.get(
    "/translations/current-session/{session_id}",
    deprecated=True,
    # Issue 12: live translation is now delivered over WebSocket (/ws/translation/{uid}).
    # This polling endpoint is kept for backwards compatibility only; new clients
    # should not use it.
)
def current_session_translations(
    session_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    cursor: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
):
    require_service(db, "translation")
    session = _owned_session(db, user, session_id)
    query = _translation_query(user, session)
    if cursor:
        cursor_row = db.scalar(
            select(TranslationHistory).where(
                TranslationHistory.entry_id == cursor,
                TranslationHistory.user_id == user.id,
                TranslationHistory.session_id == session.id,
            )
        )
        if cursor_row is None:
            raise AppError(422, "INVALID_CURSOR", "The translation cursor is invalid.")
        query = query.where(TranslationHistory.timestamp > cursor_row.timestamp)
    rows = db.scalars(query.order_by(TranslationHistory.timestamp.asc()).limit(limit)).all()
    return {
        "data": [_translation_data(row) for row in rows],
        "meta": {"nextCursor": rows[-1].entry_id if rows else cursor},
    }


@router.get("/translations/history")
def translation_history(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(default=100, ge=1, le=200),
):
    require_service(db, "translation")
    rows = db.scalars(
        _translation_query(user)
        .join(TranslationSession, TranslationHistory.session_id == TranslationSession.id)
        .where(TranslationSession.status != "active")
        .order_by(TranslationHistory.timestamp.desc())
        .limit(limit)
    ).all()
    return {"data": [_translation_data(row) for row in rows]}


@router.delete("/translations/{entry_id}")
def delete_translation(
    entry_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "translation")
    row = db.scalar(
        select(TranslationHistory).where(
            TranslationHistory.entry_id == entry_id,
            TranslationHistory.user_id == user.id,
        )
    )
    if row is None:
        raise AppError(404, "TRANSLATION_NOT_FOUND", "The translation was not found.")
    db.delete(row)
    db.commit()
    return {"data": {"deleted": True, "entryId": entry_id}}


@router.delete("/translations")
def clear_translations(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "translation")
    rows = db.scalars(
        select(TranslationHistory).where(TranslationHistory.user_id == user.id)
    ).all()
    for row in rows:
        db.delete(row)
    db.commit()
    return {"data": {"deleted": len(rows)}}


@router.get("/ml/models")
def list_models(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    del user
    require_service(db, "translation")
    models = db.scalars(
        select(MlModel).where(MlModel.status == "available").order_by(MlModel.name)
    ).all()
    return {
        "data": [
            {
                "modelId": model.model_id,
                "name": model.name,
                "version": model.version,
                "isActive": model.is_active,
            }
            for model in models
        ]
    }
