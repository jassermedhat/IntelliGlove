from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import OperationalError

from .config import Settings
from .database import create_database
from .errors import install_error_handlers
from .firebase_identity import FirebaseIdentity, create_firebase_identity
from .ml_client import MlClient, MlClientProtocol
from .auth_routes import router as auth_router
from .core_routes import router as core_router
from .feature_routes import router as feature_router
from .report_routes import router as report_router
from .admin_routes import router as admin_router
from .translation_routes import router as translation_router
from .ws_routes import router as ws_router
from .ingestion import ingestion_manager
from .rate_limit import InMemoryRateLimiter


def create_app(
    settings: Settings | None = None,
    firebase_identity: FirebaseIdentity | None = None,
    ml_client: MlClientProtocol | None = None,
) -> FastAPI:
    settings = settings or Settings.from_env()
    engine, session_factory = create_database(settings.database_url)
    firebase_identity = firebase_identity or create_firebase_identity(settings)
    ml_client = ml_client or MlClient(settings.ml_service_url, settings.ml_internal_api_key)

    # Ensure the translation JSON output directory exists at startup (§7.1).
    try:
        settings.translation_json_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logging.getLogger("intelliglove.startup").warning(
            "Could not create TRANSLATION_JSON_DIR=%s — check permissions.",
            settings.translation_json_dir,
        )

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        # Schema creation is migration-owned. This only proves connectivity.
        # A DB outage at startup must NOT crash the process — log and continue so
        # the API can come up and return controlled 503s (see the OperationalError
        # handler) until the database recovers. pool_pre_ping reconnects later.
        try:
            with engine.connect():
                pass
        except OperationalError as exc:
            logging.getLogger("intelliglove.startup").error(
                "Database unavailable at startup: %s. Serving 503 until it recovers.",
                exc,
            )
        yield
        # Gracefully stop all running ingestion watchers on shutdown.
        ingestion_manager.stop_all()
        engine.dispose()

    app = FastAPI(title=settings.app_name, version="2.0.0", lifespan=lifespan)
    app.state.settings = settings
    app.state.engine = engine
    app.state.session_factory = session_factory
    app.state.firebase_identity = firebase_identity
    app.state.ml_client = ml_client
    app.state.rate_limiter = InMemoryRateLimiter(
        settings.rate_limit_requests,
        settings.rate_limit_window_seconds,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_origins),
        allow_origin_regex=settings.effective_cors_origin_regex,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID", "Access-Control-Request-Private-Network"],
        expose_headers=["X-Request-ID", "Access-Control-Allow-Private-Network"],
    )

    @app.middleware("http")
    async def private_network_access(request: Request, call_next):
        response = await call_next(request)
        if request.headers.get("Access-Control-Request-Private-Network"):
            response.headers["Access-Control-Allow-Private-Network"] = "true"
        return response

    install_error_handlers(app)

    @app.middleware("http")
    async def rate_limit(request: Request, call_next):
        if settings.rate_limit_enabled and request.url.path != "/health":
            client_key = request.client.host if request.client else "unknown"
            if not app.state.rate_limiter.allow(client_key):
                return JSONResponse(
                    status_code=429,
                    content={
                        "code": "RATE_LIMITED",
                        "message": "Too many requests. Please try again later.",
                        "details": None,
                        "requestId": request.headers.get("X-Request-ID"),
                    },
                )
        return await call_next(request)

    @app.middleware("http")
    async def request_context(request: Request, call_next):
        request.state.request_id = request.headers.get("X-Request-ID", str(uuid4()))
        started = time.perf_counter()
        response = await call_next(request)
        response.headers["X-Request-ID"] = request.state.request_id
        logging.getLogger("intelliglove.request").info(
            "%s %s %s %.2fms request_id=%s",
            request.method,
            request.url.path,
            response.status_code,
            (time.perf_counter() - started) * 1000,
            request.state.request_id,
        )
        return response

    @app.get("/health", tags=["system"])
    def health() -> dict[str, object]:
        return {
            "data": {
                "status": "ok",
                "service": settings.app_name,
                "version": "2.0.0",
                "database": "postgresql",
            }
        }

    app.include_router(auth_router, prefix=settings.api_prefix)
    app.include_router(core_router, prefix=settings.api_prefix)
    app.include_router(feature_router, prefix=settings.api_prefix)
    app.include_router(report_router, prefix=settings.api_prefix)
    app.include_router(admin_router, prefix=settings.api_prefix)
    app.include_router(translation_router, prefix=settings.api_prefix)
    # WebSocket route — no api_prefix because WS URLs are path-matched directly.
    app.include_router(ws_router)

    return app


app = create_app()
