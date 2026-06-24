from __future__ import annotations

import secrets
import time
from typing import Any


DEVELOPMENT_USER_TOKEN = "intelliglove-development-user"
DEVELOPMENT_ADMIN_TOKEN = "intelliglove-development-admin"
DEVELOPMENT_USER_UID = "development-testing-user"
DEVELOPMENT_ADMIN_UID = "development-testing-admin"


def development_claims(token: str, *, enabled: bool) -> dict[str, Any] | None:
    if not enabled:
        return None

    now = int(time.time())
    if secrets.compare_digest(token, DEVELOPMENT_USER_TOKEN):
        return {
            "uid": DEVELOPMENT_USER_UID,
            "sub": DEVELOPMENT_USER_UID,
            "email": "testing@intelliglove.local",
            "name": "Testing User",
            "email_verified": True,
            "auth_time": now,
            "intelliglove_development_role": "user",
        }
    if secrets.compare_digest(token, DEVELOPMENT_ADMIN_TOKEN):
        return {
            "uid": DEVELOPMENT_ADMIN_UID,
            "sub": DEVELOPMENT_ADMIN_UID,
            "email": "testing-admin@intelliglove.local",
            "name": "Testing Administrator",
            "email_verified": True,
            "auth_time": now,
            "intelliglove_development_role": "admin",
        }
    return None


def verify_identity_token(app: Any, token: str) -> dict[str, Any]:
    claims = development_claims(
        token,
        enabled=app.state.settings.development_auth_bypass,
    )
    if claims is not None:
        return claims
    return app.state.firebase_identity.verify_token(token)
