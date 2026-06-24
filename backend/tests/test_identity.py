from __future__ import annotations

from tests.conftest import auth_headers


def _sync(client, token: str = "verified-user", **payload):
    return client.post("/api/v1/auth/sync", headers=auth_headers(token), json=payload)


def test_missing_and_invalid_tokens_are_rejected(client) -> None:
    assert client.get("/api/v1/me").status_code == 401
    response = client.get("/api/v1/me", headers=auth_headers("not-a-token"))
    assert response.status_code == 401
    assert response.json()["code"] == "INVALID_FIREBASE_TOKEN"


def test_sync_creates_uid_linked_user_and_me_requires_verified_email(client) -> None:
    response = _sync(client)
    assert response.status_code == 200
    profile = response.json()["data"]
    assert profile["firebaseUid"] == "firebase-user-1"
    assert profile["email"] == "user1@example.com"
    assert profile["emailVerified"] is True
    assert profile["role"] == "user"
    assert client.get("/api/v1/me", headers=auth_headers()).status_code == 200

    unverified = _sync(client, "unverified-user")
    assert unverified.status_code == 200
    blocked = client.get("/api/v1/me", headers=auth_headers("unverified-user"))
    assert blocked.status_code == 403
    assert blocked.json()["code"] == "EMAIL_VERIFICATION_REQUIRED"


def test_email_cannot_be_relinked_to_another_uid(client) -> None:
    assert _sync(client).status_code == 200
    conflict = _sync(client, "conflicting-user")
    assert conflict.status_code == 409
    assert conflict.json()["code"] == "IDENTITY_CONFLICT"


def test_profile_update_and_recent_auth_email_change(client, firebase_identity) -> None:
    assert _sync(client).status_code == 200
    response = client.patch(
        "/api/v1/me",
        headers=auth_headers(),
        json={"name": "Updated Name", "photoUrl": "https://example.com/avatar.png"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["name"] == "Updated Name"

    email = client.patch(
        "/api/v1/me",
        headers=auth_headers(),
        json={"email": "new@example.com"},
    )
    assert email.status_code == 200
    assert email.json()["data"]["verificationRequired"] is True
    assert firebase_identity.email_updates == [("firebase-user-1", "new@example.com")]
    stale_token = client.get("/api/v1/me", headers=auth_headers())
    assert stale_token.status_code == 401
    assert stale_token.json()["code"] == "TOKEN_REFRESH_REQUIRED"


def test_stale_auth_cannot_change_email(client) -> None:
    assert _sync(client, "stale-user").status_code == 200
    response = client.patch(
        "/api/v1/me",
        headers=auth_headers("stale-user"),
        json={"email": "fresh@example.com"},
    )
    assert response.status_code == 401
    assert response.json()["code"] == "RECENT_AUTH_REQUIRED"
