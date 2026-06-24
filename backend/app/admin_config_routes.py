"""Admin config and ML-model management endpoints (Issue 15)."""
from __future__ import annotations

import hashlib
import re
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .admin_shared import _audit
from .dependencies import get_current_admin, get_db
from .errors import AppError
from .ml_client import MlServiceError
from .models import AdminConfig, MlModel, User
from .system_config import DEFAULT_SERVICE_TOGGLES, get_admin_config

_router = APIRouter()


def _config_data(config: AdminConfig) -> dict[str, Any]:
    return {
        "systemStatus": config.system_status,
        "activeModelId": str(config.active_model_id) if config.active_model_id else None,
        "serviceToggles": config.service_toggles,
        "updatedAt": config.updated_at,
    }


def _model_data(model: MlModel) -> dict[str, Any]:
    return {
        "id": str(model.id),
        "modelId": model.model_id,
        "name": model.name,
        "filePath": model.file_path,
        "labelsPath": model.labels_path,
        "version": model.version,
        "status": model.status,
        "isActive": model.is_active,
        "metadata": model.metadata_json,
        "createdAt": model.created_at,
        "updatedAt": model.updated_at,
    }


@_router.get("/config")
def read_config(
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    del admin
    config = get_admin_config(db)
    db.commit()
    return {"data": _config_data(config)}


class SystemStatusPatch(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    system_status: str = Field(alias="systemStatus", pattern="^(on|off)$")


@_router.patch("/config/system-status")
def update_system_status(
    payload: SystemStatusPatch,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    config = get_admin_config(db)
    before = config.system_status
    config.system_status = payload.system_status
    config.updated_by = admin.id
    _audit(
        db,
        admin,
        "system.status.update",
        target_type="admin_config",
        target_id=str(config.id),
        details={"before": before, "after": config.system_status},
    )
    db.commit()
    db.refresh(config)
    return {"data": _config_data(config)}


class ServiceTogglesPatch(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    service_toggles: dict[str, bool] = Field(alias="serviceToggles", min_length=1)


@_router.patch("/config/service-toggles")
def update_service_toggles(
    payload: ServiceTogglesPatch,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    unknown = sorted(set(payload.service_toggles) - set(DEFAULT_SERVICE_TOGGLES))
    if unknown:
        raise AppError(422, "UNKNOWN_SERVICE", "Unknown service toggle keys.", unknown)
    config = get_admin_config(db)
    before = dict(config.service_toggles)
    config.service_toggles = {**before, **payload.service_toggles}
    config.updated_by = admin.id
    _audit(
        db,
        admin,
        "services.update",
        target_type="admin_config",
        target_id=str(config.id),
        details={"before": before, "after": config.service_toggles},
    )
    db.commit()
    db.refresh(config)
    return {"data": _config_data(config)}


@_router.get("/models")
def admin_models(
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    del admin
    rows = db.scalars(select(MlModel).order_by(MlModel.name)).all()
    return {"data": [_model_data(row) for row in rows]}


@_router.post("/models/scan")
def scan_models(
    request: Request,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    root = request.app.state.settings.model_dir.resolve()
    root.mkdir(parents=True, exist_ok=True)
    discovered = {path.relative_to(root).as_posix(): path for path in root.rglob("*.joblib")}
    existing = {row.file_path: row for row in db.scalars(select(MlModel)).all()}
    results = []
    for relative, path in sorted(discovered.items()):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        row = existing.get(relative)
        if row is None:
            stem = re.sub(r"[^a-zA-Z0-9_-]+", "-", path.stem).strip("-") or "model"
            row = MlModel(
                model_id=f"{stem}-{digest[:12]}",
                name=path.stem.replace("_", " ").strip().title(),
                file_path=relative,
                labels_path=(
                    path.with_suffix(".labels.json").relative_to(root).as_posix()
                    if path.with_suffix(".labels.json").is_file()
                    else None
                ),
                status="available",
                is_active=False,
            )
            db.add(row)
        try:
            validation = request.app.state.ml_client.validate(relative)
            row.status = "available"
            row.metadata_json = {
                "sha256": digest,
                "sizeBytes": path.stat().st_size,
                "classes": validation.get("classes", []),
            }
        except MlServiceError as error:
            row.status = "invalid"
            row.is_active = False
            row.metadata_json = {"sha256": digest, "error": str(error)}
        results.append(row)
    for relative, row in existing.items():
        if relative not in discovered:
            row.status = "invalid"
            row.is_active = False
            row.metadata_json = {**(row.metadata_json or {}), "error": "Model file is missing."}
    _audit(
        db,
        admin,
        "models.scan",
        target_type="models",
        details={"discovered": len(discovered)},
    )
    db.commit()
    for row in results:
        db.refresh(row)
    return {"data": [_model_data(row) for row in results], "meta": {"scanned": len(discovered)}}


@_router.patch("/models/{model_id}/activate")
def activate_model(
    model_id: str,
    admin: Annotated[User, Depends(get_current_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    config = get_admin_config(db)
    if config.system_status != "off":
        raise AppError(409, "SYSTEM_MUST_BE_OFF", "Turn the system off before changing models.")
    model = db.scalar(select(MlModel).where(MlModel.model_id == model_id))
    if model is None:
        raise AppError(404, "MODEL_NOT_FOUND", "The model was not found.")
    if model.status != "available":
        raise AppError(409, "MODEL_NOT_AVAILABLE", "The model is not available.")
    for row in db.scalars(select(MlModel).where(MlModel.is_active.is_(True))).all():
        row.is_active = False
    model.is_active = True
    config.active_model_id = model.id
    config.updated_by = admin.id
    _audit(
        db,
        admin,
        "model.activate",
        target_type="model",
        target_id=model.model_id,
    )
    db.commit()
    db.refresh(model)
    return {"data": _model_data(model)}
