from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from .errors import AppError
from .models import AdminConfig


DEFAULT_SERVICE_TOGGLES: dict[str, bool] = {
    "translation": True,
    "healthMonitor": True,
    "smartHouse": True,
    "analytics": True,
    "practiceMode": True,
    "feedback": True,
    "devices": True,
    "firmware": True,
}


def get_admin_config(db: Session) -> AdminConfig:
    config = db.scalar(select(AdminConfig).where(AdminConfig.singleton_key == "default"))
    if config is None:
        config = AdminConfig(
            singleton_key="default",
            system_status="off",
            service_toggles=dict(DEFAULT_SERVICE_TOGGLES),
        )
        db.add(config)
        db.flush()
    else:
        merged = dict(DEFAULT_SERVICE_TOGGLES)
        merged.update(config.service_toggles or {})
        config.service_toggles = merged
    return config


def require_service(db: Session, key: str) -> AdminConfig:
    config = get_admin_config(db)
    if not config.service_toggles.get(key, False):
        raise AppError(503, "SERVICE_DISABLED", "This feature is currently unavailable.")
    return config
