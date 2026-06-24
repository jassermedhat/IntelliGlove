from __future__ import annotations

import math

import joblib
import pytest
from fastapi.testclient import TestClient

from main import create_app
from model_registry import InvalidSensorData, ModelRegistry, extract_feature_vector


class FixtureModel:
    classes_ = ["hello", "thanks"]

    def predict_proba(self, rows):
        assert len(rows[0]) == 11
        return [[0.1, 0.9]]


def packet():
    return {
        "flex1": 0.1,
        "flex2": 0.2,
        "flex3": 0.3,
        "flex4": 0.4,
        "flex5": 0.5,
        "accelX": 0.6,
        "accelY": 0.7,
        "accelZ": 0.8,
        "gyroX": 0.9,
        "gyroY": 1.0,
        "gyroZ": 1.1,
    }


def test_flat_and_nested_feature_packets() -> None:
    assert len(extract_feature_vector(packet())) == 11
    nested = packet()
    nested["accelerometer"] = {"x": nested.pop("accelX"), "y": nested.pop("accelY"), "z": nested.pop("accelZ")}
    nested["gyroscope"] = {"x": nested.pop("gyroX"), "y": nested.pop("gyroY"), "z": nested.pop("gyroZ")}
    assert len(extract_feature_vector(nested)) == 11


def test_prediction_uses_requested_model_and_labels(tmp_path) -> None:
    joblib.dump({"model": FixtureModel(), "labels": {"thanks": "Thank you"}}, tmp_path / "fixture.joblib")
    client = TestClient(create_app(ModelRegistry(tmp_path)))
    response = client.post(
        "/predict",
        json={"modelPath": "fixture.joblib", "rawSensorData": packet()},
    )
    assert response.status_code == 200
    assert response.json()["translatedText"] == "Thank you"
    assert response.json()["confidence"] == 0.9


def test_invalid_input_model_and_traversal_fail_closed(tmp_path) -> None:
    joblib.dump(FixtureModel(), tmp_path / "fixture.joblib")
    client = TestClient(create_app(ModelRegistry(tmp_path)))
    incomplete = client.post(
        "/predict",
        json={"modelPath": "fixture.joblib", "rawSensorData": {"flex1": 0.1}},
    )
    assert incomplete.status_code == 422
    non_finite = packet()
    non_finite["gyroZ"] = math.inf
    with pytest.raises(InvalidSensorData, match="finite"):
        extract_feature_vector(non_finite)
    assert client.post(
        "/validate", json={"modelPath": "../outside.joblib"}
    ).status_code == 422
    assert client.post(
        "/validate", json={"modelPath": "missing.joblib"}
    ).status_code == 422


def test_internal_key_is_enforced(tmp_path, monkeypatch) -> None:
    joblib.dump(FixtureModel(), tmp_path / "fixture.joblib")
    monkeypatch.setenv("ML_INTERNAL_API_KEY", "secret")
    client = TestClient(create_app(ModelRegistry(tmp_path)))
    assert client.post(
        "/validate", json={"modelPath": "fixture.joblib"}
    ).status_code == 401
    assert client.post(
        "/validate",
        headers={"X-Internal-API-Key": "secret"},
        json={"modelPath": "fixture.joblib"},
    ).status_code == 200
