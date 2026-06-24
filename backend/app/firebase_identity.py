from __future__ import annotations

from pathlib import Path
from typing import Any, Protocol

from firebase_admin import App, auth, credentials, get_app, initialize_app

from .config import Settings


class FirebaseIdentity(Protocol):
    def verify_token(self, token: str) -> dict[str, Any]: ...

    def update_email(self, uid: str, email: str) -> None: ...


class FirebaseAdminIdentity:
    def __init__(self, firebase_app: App) -> None:
        self._app = firebase_app

    def verify_token(self, token: str) -> dict[str, Any]:
        return auth.verify_id_token(token, app=self._app, check_revoked=True)

    def update_email(self, uid: str, email: str) -> None:
        auth.update_user(uid, email=email, email_verified=False, app=self._app)


def create_firebase_identity(settings: Settings) -> FirebaseIdentity:
    name = "intelliglove-api"
    try:
        firebase_app = get_app(name)
    except ValueError:
        credential = None
        if settings.firebase_credentials_path:
            path = Path(settings.firebase_credentials_path)
            if not path.is_file():
                raise RuntimeError(
                    "FIREBASE_CREDENTIALS_PATH does not point to a readable file."
                )
            credential = credentials.Certificate(str(path))
        firebase_app = initialize_app(
            credential,
            {"projectId": settings.firebase_project_id},
            name=name,
        )
    return FirebaseAdminIdentity(firebase_app)
