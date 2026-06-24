from __future__ import annotations

import os

from firebase_admin import auth, get_app

from .admin_identity import ensure_admin_record
from .config import Settings
from .database import create_database
from .firebase_identity import create_firebase_identity


def main() -> None:
    email = os.getenv("ADMIN_EMAIL", "").strip().lower()
    password = os.getenv("ADMIN_PASSWORD", "")
    name = os.getenv("ADMIN_NAME", "IntelliGlove Admin").strip()
    if not email or len(password) < 8:
        raise RuntimeError("ADMIN_EMAIL and an ADMIN_PASSWORD of at least 8 characters are required.")

    settings = Settings.from_env()
    create_firebase_identity(settings)
    firebase_app = get_app("intelliglove-api")
    try:
        firebase_user = auth.get_user_by_email(email, app=firebase_app)
        firebase_user = auth.update_user(
            firebase_user.uid,
            password=password,
            display_name=name,
            email_verified=True,
            app=firebase_app,
        )
    except auth.UserNotFoundError:
        firebase_user = auth.create_user(
            email=email,
            password=password,
            display_name=name,
            email_verified=True,
            app=firebase_app,
        )

    engine, factory = create_database(settings.database_url)
    session = factory()
    try:
        ensure_admin_record(
            session,
            firebase_uid=firebase_user.uid,
            email=email,
            name=name,
        )
    finally:
        session.close()
        engine.dispose()
    print(f"Admin synchronized: {email}")


if __name__ == "__main__":
    main()
