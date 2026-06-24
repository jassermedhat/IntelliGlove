from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path


LOCAL_CORS_ORIGIN_REGEX = (
    r"^https?://(?:localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$"
)


def _as_bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    app_name: str = "IntelliGlove API"
    environment: str = "development"
    api_prefix: str = "/api/v1"
    database_url: str = (
        "postgresql+psycopg://intelliglove:intelliglove@localhost:5432/intelliglove"
    )
    firebase_project_id: str = "intelligent-glove-asl-33-da1aa"
    firebase_credentials_path: str = ""
    require_verified_email: bool = True
    development_auth_bypass: bool = False
    cors_origins: tuple[str, ...] = (
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:7358",
        "http://127.0.0.1:7358",
    )
    cors_origin_regex: str | None = None
    ml_service_url: str = "http://localhost:8080"
    ml_internal_api_key: str = ""
    model_dir: Path = Path("../models")
    # §7.1 — directory where per-session JSON translation output files live.
    # Must be writable by the backend process.  The admin mock-data tool and
    # any future real ML pipeline write files here; the ingestion watcher reads them.
    translation_json_dir: Path = Path("./translation_output")
    # §7.5 — how often (seconds) the per-session watcher polls each JSON file.
    translation_poll_interval: float = 1.0
    rate_limit_enabled: bool = False
    rate_limit_requests: int = 120
    rate_limit_window_seconds: int = 60

    @classmethod
    def from_env(cls) -> "Settings":
        environment = os.getenv("APP_ENV", "development").strip().lower()
        origins = tuple(
            value.strip()
            for value in os.getenv("CORS_ORIGINS", ",".join(cls.cors_origins)).split(",")
            if value.strip()
        )
        # Rate limiting: enabled by default outside development/test (Issue 8).
        # Explicitly set RATE_LIMIT_ENABLED=false to opt out in non-dev environments.
        rate_limit_default = environment not in {"development", "test"}
        settings = cls(
            environment=environment,
            database_url=os.getenv("DATABASE_URL", cls.database_url).strip(),
            firebase_project_id=os.getenv(
                "FIREBASE_PROJECT_ID", cls.firebase_project_id
            ).strip(),
            firebase_credentials_path=os.getenv("FIREBASE_CREDENTIALS_PATH", "").strip(),
            require_verified_email=_as_bool("REQUIRE_VERIFIED_EMAIL", True),
            development_auth_bypass=_as_bool(
                "DEVELOPMENT_AUTH_BYPASS", environment == "development"
            ),
            cors_origins=origins,
            cors_origin_regex=os.getenv("CORS_ORIGIN_REGEX") or None,
            ml_service_url=os.getenv("ML_SERVICE_URL", "http://localhost:8080").rstrip("/"),
            ml_internal_api_key=os.getenv("ML_INTERNAL_API_KEY", ""),
            model_dir=Path(os.getenv("MODEL_DIR", "../models")),
            translation_json_dir=Path(
                os.getenv("TRANSLATION_JSON_DIR", "./translation_output")
            ),
            translation_poll_interval=float(
                os.getenv("TRANSLATION_POLL_INTERVAL", "1.0")
            ),
            rate_limit_enabled=_as_bool("RATE_LIMIT_ENABLED", rate_limit_default),
            rate_limit_requests=int(os.getenv("RATE_LIMIT_REQUESTS", "120")),
            rate_limit_window_seconds=int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60")),
        )
        settings.validate()
        return settings

    def validate(self) -> None:
        if not self.database_url.startswith(("postgresql://", "postgresql+psycopg://")):
            raise RuntimeError("DATABASE_URL must use PostgreSQL.")
        if not self.firebase_project_id:
            raise RuntimeError("FIREBASE_PROJECT_ID is required.")
        if self.development_auth_bypass and self.environment not in {
            "development",
            "test",
        }:
            raise RuntimeError(
                "DEVELOPMENT_AUTH_BYPASS is allowed only in development or test."
            )
        if self.cors_origin_regex:
            try:
                re.compile(self.cors_origin_regex)
            except re.error as error:
                raise RuntimeError(
                    "CORS_ORIGIN_REGEX must be a valid regular expression."
                ) from error
        # ML service is explicitly out of scope this phase (§0, §4.3) so we do
        # NOT enforce ML_INTERNAL_API_KEY in production — it stays informational.
        if self.translation_poll_interval <= 0:
            raise RuntimeError("TRANSLATION_POLL_INTERVAL must be positive.")
        if self.rate_limit_requests <= 0 or self.rate_limit_window_seconds <= 0:
            raise RuntimeError("Rate-limit values must be positive.")

    @property
    def effective_cors_origin_regex(self) -> str | None:
        if self.cors_origin_regex:
            return self.cors_origin_regex
        if self.environment in {"development", "test"}:
            return LOCAL_CORS_ORIGIN_REGEX
        return None
