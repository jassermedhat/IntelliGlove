from __future__ import annotations

from typing import Any, Protocol

import httpx


class MlClientProtocol(Protocol):
    def predict(self, model_path: str, raw_input: dict[str, Any]) -> dict[str, Any]: ...

    def validate(self, model_path: str) -> dict[str, Any]: ...


class MlServiceError(RuntimeError):
    pass


class MlClient:
    def __init__(self, base_url: str, internal_api_key: str = "") -> None:
        self.base_url = base_url.rstrip("/")
        self.headers = (
            {"X-Internal-API-Key": internal_api_key} if internal_api_key else {}
        )

    def predict(self, model_path: str, raw_input: dict[str, Any]) -> dict[str, Any]:
        try:
            response = httpx.post(
                f"{self.base_url}/predict",
                headers=self.headers,
                json={"modelPath": model_path, "rawSensorData": raw_input},
                timeout=15,
            )
            response.raise_for_status()
            return response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise MlServiceError("The ML service could not complete inference.") from error

    def validate(self, model_path: str) -> dict[str, Any]:
        try:
            response = httpx.post(
                f"{self.base_url}/validate",
                headers=self.headers,
                json={"modelPath": model_path},
                timeout=15,
            )
            response.raise_for_status()
            return response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise MlServiceError("The ML service could not validate the model.") from error
