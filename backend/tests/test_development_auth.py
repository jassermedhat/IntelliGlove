from __future__ import annotations

from dataclasses import replace

import pytest

from app.config import Settings
from app.development_auth import (
    DEVELOPMENT_ADMIN_TOKEN,
    DEVELOPMENT_ADMIN_UID,
    DEVELOPMENT_USER_TOKEN,
    DEVELOPMENT_USER_UID,
    development_claims,
)


def test_development_tokens_map_to_separate_verified_identities() -> None:
    user = development_claims(DEVELOPMENT_USER_TOKEN, enabled=True)
    admin = development_claims(DEVELOPMENT_ADMIN_TOKEN, enabled=True)

    assert user is not None and user["uid"] == DEVELOPMENT_USER_UID
    assert user["intelliglove_development_role"] == "user"
    assert admin is not None and admin["uid"] == DEVELOPMENT_ADMIN_UID
    assert admin["intelliglove_development_role"] == "admin"
    assert user["email_verified"] is True
    assert admin["email_verified"] is True


def test_development_tokens_are_rejected_when_bypass_is_disabled() -> None:
    assert development_claims(DEVELOPMENT_USER_TOKEN, enabled=False) is None
    assert development_claims(DEVELOPMENT_ADMIN_TOKEN, enabled=False) is None
    assert development_claims("unknown", enabled=True) is None


def test_production_cannot_enable_development_auth_bypass() -> None:
    with pytest.raises(RuntimeError, match="allowed only"):
        Settings(environment="production", development_auth_bypass=True).validate()


def test_development_tokens_use_normal_user_and_admin_backend_paths(client) -> None:
    client.app.state.settings = replace(
        client.app.state.settings,
        development_auth_bypass=True,
    )

    user_headers = {"Authorization": f"Bearer {DEVELOPMENT_USER_TOKEN}"}
    admin_headers = {"Authorization": f"Bearer {DEVELOPMENT_ADMIN_TOKEN}"}

    user_sync = client.post(
        "/api/v1/auth/sync",
        headers=user_headers,
        json={"name": "Testing User"},
    )
    admin_sync = client.post(
        "/api/v1/auth/sync",
        headers=admin_headers,
        json={"name": "Testing Administrator"},
    )

    assert user_sync.status_code == 200
    assert user_sync.json()["data"]["role"] == "user"
    assert admin_sync.status_code == 200
    assert admin_sync.json()["data"]["role"] == "admin"
    assert client.get("/api/v1/me", headers=user_headers).status_code == 200
    assert client.get("/api/v1/admin/config", headers=admin_headers).status_code == 200
