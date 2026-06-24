from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import joblib


FEATURE_NAMES = (
    "flex1",
    "flex2",
    "flex3",
    "flex4",
    "flex5",
    "accelX",
    "accelY",
    "accelZ",
    "gyroX",
    "gyroY",
    "gyroZ",
)


class InvalidSensorData(ValueError):
    pass


class InvalidModel(ValueError):
    pass


def _finite_number(value: Any, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InvalidSensorData(f"{field} must be a number.")
    number = float(value)
    if not math.isfinite(number):
        raise InvalidSensorData(f"{field} must be finite.")
    return number


def extract_feature_vector(raw: dict[str, Any]) -> list[float]:
    accel = raw.get("accelerometer") or raw.get("accel") or {}
    gyro = raw.get("gyroscope") or raw.get("gyro") or {}
    if not isinstance(accel, dict) or not isinstance(gyro, dict):
        raise InvalidSensorData("Accelerometer and gyroscope values must be objects.")
    aliases: dict[str, Any] = {
        "flex1": raw.get("flex1"),
        "flex2": raw.get("flex2"),
        "flex3": raw.get("flex3"),
        "flex4": raw.get("flex4"),
        "flex5": raw.get("flex5"),
        "accelX": raw.get("accelX", raw.get("accel_x", accel.get("x"))),
        "accelY": raw.get("accelY", raw.get("accel_y", accel.get("y"))),
        "accelZ": raw.get("accelZ", raw.get("accel_z", accel.get("z"))),
        "gyroX": raw.get("gyroX", raw.get("gyro_x", gyro.get("x"))),
        "gyroY": raw.get("gyroY", raw.get("gyro_y", gyro.get("y"))),
        "gyroZ": raw.get("gyroZ", raw.get("gyro_z", gyro.get("z"))),
    }
    missing = [name for name in FEATURE_NAMES if aliases[name] is None]
    if missing:
        raise InvalidSensorData("Missing required sensor fields: " + ", ".join(missing))
    return [_finite_number(aliases[name], name) for name in FEATURE_NAMES]


@dataclass
class LoadedModel:
    model: Any
    labels: dict[str, str]
    modified_ns: int


class ModelRegistry:
    def __init__(self, model_dir: str | Path | None = None) -> None:
        self.model_dir = Path(model_dir or os.getenv("MODEL_DIR", "../models")).resolve()
        self.model_dir.mkdir(parents=True, exist_ok=True)
        self._cache: dict[Path, LoadedModel] = {}

    def resolve(self, relative_path: str) -> Path:
        candidate = (self.model_dir / relative_path).resolve()
        try:
            candidate.relative_to(self.model_dir)
        except ValueError as error:
            raise InvalidModel("Model path must stay inside MODEL_DIR.") from error
        if candidate.suffix.lower() != ".joblib":
            raise InvalidModel("Only .joblib models are supported.")
        if not candidate.is_file():
            raise InvalidModel("Model file does not exist.")
        return candidate

    def load(self, relative_path: str) -> LoadedModel:
        path = self.resolve(relative_path)
        modified_ns = path.stat().st_mtime_ns
        cached = self._cache.get(path)
        if cached is not None and cached.modified_ns == modified_ns:
            return cached
        try:
            bundle = joblib.load(path)
        except Exception as error:
            raise InvalidModel("Model file could not be loaded.") from error
        labels: dict[str, str] = {}
        if isinstance(bundle, dict) and "model" in bundle:
            model = bundle["model"]
            labels.update({str(key): str(value) for key, value in bundle.get("labels", {}).items()})
        else:
            model = bundle
        if not callable(getattr(model, "predict_proba", None)) or not hasattr(model, "classes_"):
            raise InvalidModel("Model must expose predict_proba and classes_.")
        labels_path = path.with_suffix(".labels.json")
        if labels_path.is_file():
            try:
                labels.update(
                    {str(key): str(value) for key, value in json.loads(labels_path.read_text("utf-8")).items()}
                )
            except (OSError, ValueError, TypeError) as error:
                raise InvalidModel("Model labels file is invalid.") from error
        loaded = LoadedModel(model=model, labels=labels, modified_ns=modified_ns)
        self._cache[path] = loaded
        return loaded

    def validate(self, relative_path: str) -> dict[str, Any]:
        loaded = self.load(relative_path)
        return {
            "valid": True,
            "modelPath": relative_path,
            "classes": [str(value) for value in loaded.model.classes_],
            "labels": loaded.labels,
        }

    def predict(self, relative_path: str, raw: dict[str, Any]) -> dict[str, Any]:
        features = extract_feature_vector(raw)
        loaded = self.load(relative_path)
        try:
            probabilities = loaded.model.predict_proba([features])[0]
            best_index = max(range(len(probabilities)), key=lambda index: probabilities[index])
            label = str(loaded.model.classes_[best_index])
            confidence = float(probabilities[best_index])
        except Exception as error:
            raise InvalidModel("Model inference failed.") from error
        return {
            "translatedText": loaded.labels.get(label, label),
            "gestureLabel": label,
            "confidence": round(max(0.0, min(1.0, confidence)), 6),
            "modelPath": relative_path,
        }
