from __future__ import annotations

from typing import Annotated, Any
from uuid import uuid4

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from .dependencies import get_current_admin, get_current_user, get_db
from .errors import AppError
from .models import AuditLog, FeedbackReport, User
from .system_config import require_service


router = APIRouter(tags=["reports"])


class ReportCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    type: str = Field(pattern="^(bug|feedback)$")
    message: str = Field(min_length=3, max_length=5000)
    app_version: str | None = Field(default=None, alias="appVersion", max_length=40)
    device_info: dict[str, Any] | None = Field(default=None, alias="deviceInfo")


class ReportPatch(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    status: str | None = Field(default=None, pattern="^(open|reviewed|resolved|dismissed)$")
    admin_notes: str | None = Field(default=None, alias="adminNotes", max_length=5000)

    @model_validator(mode="after")
    def require_value(self):
        if not self.model_fields_set:
            raise ValueError("At least one report field is required.")
        return self


def _report_data(row: FeedbackReport) -> dict[str, Any]:
    return {
        "id": str(row.id),
        "reportId": row.report_id,
        "userId": str(row.user_id),
        "type": row.type,
        "message": row.message,
        "status": row.status,
        "adminNotes": row.admin_notes,
        "appVersion": row.app_version,
        "deviceInfo": row.device_info,
        "createdAt": row.created_at,
        "updatedAt": row.updated_at,
    }


@router.post("/reports", status_code=201)
def submit_report(
    payload: ReportCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    require_service(db, "feedback")
    row = FeedbackReport(
        report_id=f"rpt_{uuid4().hex}",
        user_id=user.id,
        type=payload.type,
        message=payload.message.strip(),
        app_version=payload.app_version,
        device_info=payload.device_info,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"data": _report_data(row)}


def _admin_report_list(
    report_type: str,
    db: Session,
    *,
    status: str | None,
    limit: int,
):
    query = select(FeedbackReport).where(FeedbackReport.type == report_type)
    if status:
        query = query.where(FeedbackReport.status == status)
    rows = db.scalars(
        query.order_by(FeedbackReport.created_at.desc()).limit(limit)
    ).all()
    return {"data": [_report_data(row) for row in rows]}


@router.get("/admin/reports/bugs")
def list_bugs(
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
    status: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
):
    del admin
    return _admin_report_list("bug", db, status=status, limit=limit)


@router.get("/admin/reports/feedback")
def list_feedback(
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
    status: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
):
    del admin
    return _admin_report_list("feedback", db, status=status, limit=limit)


@router.patch("/admin/reports/{report_id}")
def update_report(
    report_id: str,
    payload: ReportPatch,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    row = db.scalar(select(FeedbackReport).where(FeedbackReport.report_id == report_id))
    if row is None:
        raise AppError(404, "REPORT_NOT_FOUND", "The report was not found.")
    if payload.status is not None:
        row.status = payload.status
    if "admin_notes" in payload.model_fields_set:
        row.admin_notes = payload.admin_notes
    db.add(
        AuditLog(
            actor_user_id=admin.id,
            action="report.update",
            target_type="report",
            target_id=row.report_id,
            details={
                "status": row.status,
                "adminNotesChanged": "admin_notes" in payload.model_fields_set,
            },
        )
    )
    db.commit()
    db.refresh(row)
    return {"data": _report_data(row)}
