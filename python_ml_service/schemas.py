from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class PredictionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    model_path: str = Field(alias="modelPath", min_length=1, max_length=500)
    raw_sensor_data: dict[str, Any] = Field(alias="rawSensorData")


class PredictionResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    translated_text: str = Field(alias="translatedText")
    gesture_label: str = Field(alias="gestureLabel")
    confidence: float = Field(ge=0, le=1)
    model_path: str = Field(alias="modelPath")


class ValidateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    model_path: str = Field(alias="modelPath", min_length=1, max_length=500)
