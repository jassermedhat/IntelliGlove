from __future__ import annotations

import os

from fastapi import FastAPI, Header, HTTPException

from model_registry import InvalidModel, InvalidSensorData, ModelRegistry
from schemas import PredictionRequest, PredictionResponse, ValidateRequest


def create_app(registry: ModelRegistry | None = None) -> FastAPI:
    app = FastAPI(title="IntelliGlove ML Service", version="2.0.0")
    app.state.registry = registry or ModelRegistry()

    def authorize(x_internal_api_key: str | None) -> None:
        configured = os.getenv("ML_INTERNAL_API_KEY", "")
        if configured and x_internal_api_key != configured:
            raise HTTPException(status_code=401, detail="Invalid internal API key.")

    @app.get("/health")
    def health():
        return {"status": "ok", "modelDir": str(app.state.registry.model_dir)}

    @app.post("/validate")
    def validate(
        payload: ValidateRequest,
        x_internal_api_key: str | None = Header(default=None),
    ):
        authorize(x_internal_api_key)
        try:
            return app.state.registry.validate(payload.model_path)
        except InvalidModel as error:
            raise HTTPException(status_code=422, detail=str(error)) from error

    @app.post("/predict", response_model=PredictionResponse, response_model_by_alias=True)
    def predict(
        payload: PredictionRequest,
        x_internal_api_key: str | None = Header(default=None),
    ):
        authorize(x_internal_api_key)
        try:
            return app.state.registry.predict(payload.model_path, payload.raw_sensor_data)
        except (InvalidSensorData, InvalidModel) as error:
            raise HTTPException(status_code=422, detail=str(error)) from error

    return app


app = create_app()
