from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .dependencies import get_current_user, get_db
from .errors import AppError
from .models import (
    AnalyticsData,
    HealthMonitorData,
    PracticeModeData,
    PracticeSign,
    SmartHouseData,
    User,
)
from .system_config import get_admin_config, require_service


router = APIRouter(tags=["features"])


@router.get("/service-status")
def service_status(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    del user
    config = get_admin_config(db)
    db.commit()
    return {
        "data": {
            "systemStatus": config.system_status,
            "services": config.service_toggles,
            "updatedAt": config.updated_at,
        }
    }


@router.get("/health-monitor")
def health_monitor(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "healthMonitor")
    row = db.scalar(
        select(HealthMonitorData)
        .where(HealthMonitorData.user_id == user.id)
        .order_by(HealthMonitorData.timestamp.desc())
        .limit(1)
    )
    if row is None:
        return {"data": None}
    return {
        "data": {
            "id": str(row.id),
            "deviceId": str(row.device_id) if row.device_id else None,
            "timestamp": row.timestamp,
            "metrics": row.metrics,
            "source": row.source,
        }
    }


def _smart_data(row: SmartHouseData) -> dict[str, Any]:
    return {
        "id": str(row.id),
        "deviceName": row.device_name,
        "deviceType": row.device_type,
        "state": row.state,
        "source": row.source,
        "createdAt": row.created_at,
        "updatedAt": row.updated_at,
    }


@router.get("/smart-house")
def smart_house(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "smartHouse")
    rows = db.scalars(
        select(SmartHouseData)
        .where(SmartHouseData.user_id == user.id)
        .order_by(SmartHouseData.created_at)
    ).all()
    return {"data": [_smart_data(row) for row in rows]}


class SmartStatePatch(BaseModel):
    state: dict[str, Any] = Field(min_length=1)


class SmartDeviceCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    device_name: str = Field(alias="deviceName", min_length=1, max_length=100)
    device_type: str = Field(alias="deviceType", min_length=1, max_length=60)
    state: dict[str, Any] = Field(min_length=1)


@router.patch("/smart-house/{device_id}")
def patch_smart_house(
    device_id: UUID,
    payload: SmartStatePatch,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "smartHouse")
    row = db.scalar(
        select(SmartHouseData).where(
            SmartHouseData.id == device_id, SmartHouseData.user_id == user.id
        )
    )
    if row is None:
        raise AppError(404, "SMART_DEVICE_NOT_FOUND", "The smart device was not found.")
    row.state = {**row.state, **payload.state}
    row.source = "user"
    db.commit()
    db.refresh(row)
    return {"data": _smart_data(row)}


@router.post("/smart-house", status_code=201)
def create_smart_house_device(
    payload: SmartDeviceCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "smartHouse")
    row = SmartHouseData(
        user_id=user.id,
        device_name=payload.device_name.strip(),
        device_type=payload.device_type,
        state=payload.state,
        source="user",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"data": _smart_data(row)}


@router.delete("/smart-house/{device_id}")
def delete_smart_house_device(
    device_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "smartHouse")
    row = db.scalar(
        select(SmartHouseData).where(
            SmartHouseData.id == device_id, SmartHouseData.user_id == user.id
        )
    )
    if row is None:
        raise AppError(404, "SMART_DEVICE_NOT_FOUND", "The smart device was not found.")
    db.delete(row)
    db.commit()
    return {"data": {"deleted": True, "id": str(device_id)}}


EMPTY_ANALYTICS = {
    "gestures": [],
    "labels": [],
    "accuracy": [],
    "sessionMinutes": [],
    "topGestures": [],
}


@router.get("/analytics")
def analytics(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    range_name: str = Query(default="week", alias="range", pattern="^(day|week|month)$"),
):
    require_service(db, "analytics")
    rows = db.scalars(
        select(AnalyticsData)
        .where(AnalyticsData.user_id == user.id)
        .order_by(AnalyticsData.date.desc(), AnalyticsData.created_at.desc())
    ).all()
    row = next((item for item in rows if item.metrics.get("range") == range_name), None)
    metrics = dict(EMPTY_ANALYTICS)
    if row is not None:
        metrics.update(row.metrics)
    metrics["range"] = range_name
    return {"data": metrics}


def _practice_result(row: PracticeModeData) -> dict[str, Any]:
    return {
        "id": str(row.id),
        "signId": row.sign_id,
        "expectedText": row.expected_text,
        "detectedText": row.detected_text,
        "score": row.score,
        "confidence": row.confidence,
        "correct": row.score is not None and row.score >= 85,
        "source": row.source,
        "createdAt": row.created_at,
    }


@router.get("/practice-mode")
def practice_mode(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    language_code: str = Query(default="en-US", alias="languageCode"),
):
    require_service(db, "practiceMode")
    signs = db.scalars(
        select(PracticeSign)
        .where(PracticeSign.active.is_(True), PracticeSign.language_code == language_code)
        .order_by(PracticeSign.expected_text)
    ).all()
    results = db.scalars(
        select(PracticeModeData)
        .where(PracticeModeData.user_id == user.id)
        .order_by(PracticeModeData.created_at.desc())
        .limit(100)
    ).all()
    scores = [row.score for row in results if row.score is not None]
    return {
        "data": {
            "signs": [
                {
                    "id": sign.sign_id,
                    "name": sign.expected_text,
                    "emoji": sign.metadata_json.get("emoji", "✋"),
                    "difficulty": sign.difficulty,
                    "languageCode": sign.language_code,
                }
                for sign in signs
            ],
            "history": [_practice_result(row) for row in results],
            "stats": {
                "totalPracticed": len(results),
                "averageAccuracy": round(sum(scores) / len(scores)) if scores else 0,
                "streak": 0,
            },
        }
    }


class PracticeResultCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    sign_id: str = Field(alias="signId", min_length=1, max_length=100)
    detected_text: str | None = Field(default=None, alias="detectedText", max_length=200)
    score: float | None = Field(default=None, ge=0, le=100)
    confidence: float | None = Field(default=None, ge=0, le=1)


@router.post("/practice-mode/results", status_code=201)
def create_practice_result(
    payload: PracticeResultCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "practiceMode")
    sign = db.scalar(select(PracticeSign).where(PracticeSign.sign_id == payload.sign_id))
    if sign is None or not sign.active:
        raise AppError(404, "PRACTICE_SIGN_NOT_FOUND", "The practice sign was not found.")
    row = PracticeModeData(
        user_id=user.id,
        sign_id=sign.sign_id,
        expected_text=sign.expected_text,
        detected_text=payload.detected_text,
        score=payload.score,
        confidence=payload.confidence,
        source="live",
        created_at=datetime.now(timezone.utc),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"data": _practice_result(row)}
