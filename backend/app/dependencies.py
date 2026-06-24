from __future__ import annotations

from typing import Annotated, Any

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from .errors import AppError
from .models import AdminUser, User
from .development_auth import verify_identity_token


bearer = HTTPBearer(auto_error=False)


def get_db(request: Request):
    session: Session = request.app.state.session_factory()
    try:
        yield session
    finally:
        session.close()


def get_current_claims(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(401, "UNAUTHORIZED", "Authentication is required.")
    try:
        claims = verify_identity_token(request.app, credentials.credentials)
    except Exception as error:
        raise AppError(
            401,
            "INVALID_FIREBASE_TOKEN",
            "The Firebase ID token is invalid or expired.",
        ) from error
    uid = str(claims.get("uid") or claims.get("sub") or "").strip()
    if not uid:
        raise AppError(
            401,
            "INVALID_FIREBASE_TOKEN",
            "The Firebase ID token has no user identifier.",
        )
    claims["uid"] = uid
    return claims


def get_current_user(
    request: Request,
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    user = db.scalar(select(User).where(User.firebase_uid == claims["uid"]))
    if user is None:
        raise AppError(
            409,
            "BACKEND_PROFILE_REQUIRED",
            "Synchronize the Firebase profile before using this endpoint.",
        )
    if user.status != "active":
        raise AppError(403, "ACCOUNT_DISABLED", "The account is unavailable.")
    claim_email = str(claims.get("email") or "").strip().lower()
    if claim_email and claim_email != user.email:
        raise AppError(
            401,
            "TOKEN_REFRESH_REQUIRED",
            "Refresh the Firebase ID token before continuing.",
        )
    verified = bool(claims.get("email_verified"))
    if user.email_verified != verified:
        user.email_verified = verified
        db.commit()
    if request.app.state.settings.require_verified_email and not verified:
        raise AppError(
            403,
            "EMAIL_VERIFICATION_REQUIRED",
            "Verify your email address before continuing.",
        )
    return user


def get_current_admin(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    admin = db.scalar(select(AdminUser).where(AdminUser.user_id == user.id))
    if user.role != "admin" or admin is None:
        raise AppError(403, "ADMIN_REQUIRED", "Administrator access is required.")
    return user
