from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field, HttpUrl, model_validator


class SyncRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    name: str | None = Field(default=None, min_length=1, max_length=100)
    photo_url: HttpUrl | None = Field(default=None, alias="photoUrl")


class ProfilePatch(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    name: str | None = Field(default=None, min_length=1, max_length=100)
    email: EmailStr | None = None
    photo_url: HttpUrl | None = Field(default=None, alias="photoUrl")

    @model_validator(mode="after")
    def require_value(self):
        if self.name is None and self.email is None and self.photo_url is None:
            raise ValueError("At least one profile field is required.")
        return self


def user_data(user: Any) -> dict[str, Any]:
    return {
        "id": str(user.id),
        "firebaseUid": user.firebase_uid,
        "email": user.email,
        "name": user.name,
        "role": user.role,
        "emailVerified": user.email_verified,
        "photoUrl": user.photo_url,
        "status": user.status,
        "createdAt": user.created_at,
        "updatedAt": user.updated_at,
        "lastLoginAt": user.last_login_at,
    }
