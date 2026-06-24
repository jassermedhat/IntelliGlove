from __future__ import annotations

from sqlalchemy import select

from app.admin_identity import ensure_admin_record
from app.models import AdminUser, AuditLog


def test_admin_record_is_seeded_without_a_password(db) -> None:
    user = ensure_admin_record(
        db,
        firebase_uid="firebase-admin",
        email="ADMIN@example.com",
        name="System Admin",
    )
    assert user.role == "admin"
    assert user.email == "admin@example.com"
    assert not hasattr(user, "password_hash")
    assert db.scalar(select(AdminUser).where(AdminUser.user_id == user.id)) is not None
    assert db.scalar(select(AuditLog).where(AuditLog.action == "admin.seed")) is not None
