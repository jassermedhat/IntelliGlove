from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError, OperationalError, ProgrammingError

log = logging.getLogger("intelliglove.errors")


class AppError(Exception):
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        details: Any | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def _payload(request: Request, code: str, message: str, details: Any = None):
    return {
        "code": code,
        "message": message,
        "details": details,
        "requestId": getattr(request.state, "request_id", None),
    }


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def app_error(request: Request, error: AppError):
        return JSONResponse(
            status_code=error.status_code,
            content=_payload(request, error.code, error.message, error.details),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, error: RequestValidationError):
        details = [
            {"field": ".".join(str(value) for value in item["loc"]), "message": item["msg"]}
            for item in error.errors()
        ]
        return JSONResponse(
            status_code=422,
            content=_payload(
                request,
                "VALIDATION_ERROR",
                "The provided data is invalid.",
                details,
            ),
        )

    @app.exception_handler(IntegrityError)
    async def integrity_error(request: Request, _: IntegrityError):
        return JSONResponse(
            status_code=409,
            content=_payload(
                request,
                "CONFLICT",
                "The requested change conflicts with existing data.",
            ),
        )

    @app.exception_handler(OperationalError)
    async def operational_error(request: Request, exc: OperationalError):
        # Raised when the database is unreachable / down. Return a controlled 503
        # (not a generic 500) and never let it crash the worker process.
        log.error("DB unavailable on %s %s: %s", request.method, request.url.path, exc.orig)
        return JSONResponse(
            status_code=503,
            content=_payload(
                request,
                "SERVICE_UNAVAILABLE",
                "The service is temporarily unavailable. Please try again later.",
            ),
        )

    @app.exception_handler(ProgrammingError)
    async def programming_error(request: Request, exc: ProgrammingError):
        log.error("DB schema error on %s %s: %s", request.method, request.url.path, exc.orig)
        return JSONResponse(
            status_code=500,
            content=_payload(
                request,
                "DB_SCHEMA_ERROR",
                "Database schema is out of date. Run: alembic upgrade head",
            ),
        )

    @app.exception_handler(Exception)
    async def unhandled_error(request: Request, exc: Exception):
        log.exception("Unhandled exception on %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content=_payload(request, "SERVER_ERROR", "An unexpected error occurred."),
        )
