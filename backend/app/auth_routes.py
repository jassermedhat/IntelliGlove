from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from .dependencies import get_current_claims, get_current_user, get_db
from .errors import AppError
from .models import AuditLog, User
from .admin_identity import ensure_admin_record
from .development_auth import DEVELOPMENT_ADMIN_UID
from .schemas import ProfilePatch, SyncRequest, user_data


router = APIRouter(tags=["identity"])


def _claim_email(claims: dict[str, Any]) -> str:
    email = str(claims.get("email") or "").strip().lower()
    if not email or "@" not in email:
        raise AppError(422, "FIREBASE_EMAIL_REQUIRED", "The Firebase account has no email.")
    return email


@router.post("/auth/sync")
def sync_profile(
    payload: SyncRequest,
    request: Request,
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    db: Annotated[Session, Depends(get_db)],
):
    uid = claims["uid"]
    email = _claim_email(claims)
    if (
        request.app.state.settings.development_auth_bypass
        and uid == DEVELOPMENT_ADMIN_UID
        and claims.get("intelliglove_development_role") == "admin"
    ):
        user = ensure_admin_record(
            db,
            firebase_uid=uid,
            email=email,
            name=(payload.name or str(claims.get("name") or "")).strip()
            or "Testing Administrator",
        )
        user.last_login_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(user)
        return {"data": user_data(user)}

    user = db.scalar(select(User).where(User.firebase_uid == uid))
    email_owner = db.scalar(select(User).where(User.email == email))
    if email_owner is not None and (user is None or email_owner.id != user.id):
        raise AppError(
            409,
            "IDENTITY_CONFLICT",
            "This email is linked to a different authentication identity.",
        )
    now = datetime.now(timezone.utc)
    if user is None:
        claim_name = str(claims.get("name") or "").strip()
        name = (payload.name or claim_name or email.split("@", 1)[0]).strip()
        user = User(
            firebase_uid=uid,
            email=email,
            name=name,
            email_verified=bool(claims.get("email_verified")),
            photo_url=str(payload.photo_url) if payload.photo_url else claims.get("picture"),
            last_login_at=now,
        )
        db.add(user)
    else:
        user.email = email
        user.email_verified = bool(claims.get("email_verified"))
        user.last_login_at = now
        if payload.name:
            user.name = payload.name.strip()
        if payload.photo_url:
            user.photo_url = str(payload.photo_url)
    if user.role == "admin":
        db.add(
            AuditLog(
                actor_user_id=user.id,
                action="admin.login_sync",
                target_type="user",
                target_id=str(user.id),
                details={"email": email},
            )
        )
    db.commit()
    db.refresh(user)
    return {"data": user_data(user)}


@router.get("/me")
def get_me(user: Annotated[User, Depends(get_current_user)]):
    return {"data": user_data(user)}


@router.patch("/me")
def update_me(
    payload: ProfilePatch,
    request: Request,
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    if payload.name is not None:
        user.name = payload.name.strip()
    if payload.photo_url is not None:
        user.photo_url = str(payload.photo_url)
    if payload.email is not None:
        email = str(payload.email).strip().lower()
        auth_time = claims.get("auth_time")
        now = datetime.now(timezone.utc).timestamp()
        if not isinstance(auth_time, (int, float)) or now - float(auth_time) > 300:
            raise AppError(
                401,
                "RECENT_AUTH_REQUIRED",
                "Reauthenticate before changing the email address.",
            )
        owner = db.scalar(select(User).where(User.email == email))
        if owner is not None and owner.id != user.id:
            raise AppError(409, "EMAIL_ALREADY_EXISTS", "The email is unavailable.")
        try:
            request.app.state.firebase_identity.update_email(user.firebase_uid, email)
        except Exception as error:
            raise AppError(
                409,
                "FIREBASE_EMAIL_UPDATE_FAILED",
                "Firebase could not update the email address.",
            ) from error
        user.email = email
        user.email_verified = False
    db.commit()
    db.refresh(user)
    return {
        "data": {
            **user_data(user),
            "verificationRequired": payload.email is not None,
        }
    }
