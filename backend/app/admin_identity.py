from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import AdminUser, AuditLog, User


def ensure_admin_record(
    db: Session,
    *,
    firebase_uid: str,
    email: str,
    name: str = "IntelliGlove Admin",
) -> User:
    normalized_email = email.strip().lower()
    user = db.scalar(select(User).where(User.firebase_uid == firebase_uid))
    if user is None:
        user = db.scalar(select(User).where(User.email == normalized_email))
        if user is not None and user.firebase_uid != firebase_uid:
            raise ValueError("The admin email belongs to another Firebase UID.")
    if user is None:
        user = User(
            firebase_uid=firebase_uid,
            email=normalized_email,
            name=name.strip(),
            role="admin",
            email_verified=True,
        )
        db.add(user)
        db.flush()
    else:
        user.email = normalized_email
        user.name = name.strip() or user.name
        user.role = "admin"
        user.email_verified = True
        user.status = "active"

    now = datetime.now(timezone.utc)
    admin = db.scalar(select(AdminUser).where(AdminUser.user_id == user.id))
    if admin is None:
        admin = AdminUser(
            user_id=user.id,
            firebase_uid=firebase_uid,
            email=normalized_email,
            role="admin",
        )
        db.add(admin)
    else:
        admin.firebase_uid = firebase_uid
        admin.email = normalized_email
    db.add(
        AuditLog(
            actor_user_id=user.id,
            action="admin.seed",
            target_type="user",
            target_id=str(user.id),
            details={"email": normalized_email, "timestamp": now.isoformat()},
        )
    )
    db.commit()
    db.refresh(user)
    return user
