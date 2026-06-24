"""Admin user, device, and audit-log endpoints (Issue 15)."""
from __future__ import annotations

from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .admin_shared import _audit
from .dependencies import get_current_admin, get_db
from .errors import AppError
from .models import AuditLog, Device, User

_router = APIRouter()


@_router.get("/users")
def list_users(
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    """Return a paginated list of users for admin targeting (Issue 1)."""
    del admin
    rows = db.scalars(select(User).order_by(User.email).limit(limit).offset(offset)).all()
    total = db.scalar(select(func.count()).select_from(User))
    return {
        "data": [
            {"id": str(user.id), "email": user.email, "name": user.name, "role": user.role}
            for user in rows
        ],
        "meta": {"total": total or 0, "limit": limit, "offset": offset},
    }


class DeviceAssignRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    user_id: UUID = Field(alias="userId")
    device_name: str = Field(alias="deviceName", min_length=1, max_length=100)
    hardware_id: str | None = Field(default=None, alias="hardwareId", max_length=128)


def _device_assign_data(device: Device) -> dict[str, Any]:
    return {
        "id": str(device.id),
        "userId": str(device.user_id),
        "deviceName": device.device_name,
        "hardwareId": device.hardware_id,
        "connectionStatus": device.connection_status,
        "createdAt": device.created_at,
    }


@_router.post("/devices/assign", status_code=201)
def assign_device(
    payload: DeviceAssignRequest,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    """Assign (or upsert) a device to any user as an admin action (Issue 16)."""
    target_user = db.get(User, payload.user_id)
    if target_user is None:
        raise AppError(404, "USER_NOT_FOUND", "The target user was not found.")
    existing = db.scalar(
        select(Device).where(
            Device.user_id == target_user.id,
            func.lower(Device.device_name) == payload.device_name.strip().lower(),
        )
    )
    if existing is not None:
        _audit(
            db,
            admin,
            "admin.device.assign",
            target_type="device",
            target_id=str(existing.id),
            details={"userId": str(target_user.id), "deviceName": existing.device_name, "action": "existing"},
        )
        db.commit()
        db.refresh(existing)
        return {"data": _device_assign_data(existing)}
    device = Device(
        user_id=target_user.id,
        device_name=payload.device_name.strip(),
        hardware_id=payload.hardware_id.strip() if payload.hardware_id else None,
        connection_status="disconnected",
    )
    db.add(device)
    db.flush()
    _audit(
        db,
        admin,
        "admin.device.assign",
        target_type="device",
        target_id=str(device.id),
        details={"userId": str(target_user.id), "deviceName": device.device_name, "action": "created"},
    )
    db.commit()
    db.refresh(device)
    return {"data": _device_assign_data(device)}


@_router.get("/audit")
def audit_log(
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(default=100, ge=1, le=200),
):
    del admin
    rows = db.scalars(select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit)).all()
    return {
        "data": [
            {
                "id": str(row.id),
                "actorUserId": str(row.actor_user_id) if row.actor_user_id else None,
                "action": row.action,
                "targetType": row.target_type,
                "targetId": row.target_id,
                "details": row.details,
                "createdAt": row.created_at,
            }
            for row in rows
        ]
    }
