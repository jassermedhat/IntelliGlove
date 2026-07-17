# ML Implementation Reference

How to implement, package, deploy, and wire the gesture-recognition model into
IntelliGlove **when the trained model is ready**.

This document is the single reference for that hand-off. It describes the exact
artifact format the system expects, the inference contract, the admin
activation workflow, and — most importantly — the **gap that still has to be
closed** between "a model exists on disk" and "translations appear live on the
user's phone".

> Audience: whoever trains the model and whoever wires it into the running
> system. Read §1–§4 to ship a model; read §6 to make live translation actually
> flow from the glove.

---

## 1. The big picture

There are three processes plus the glove:

```
  ┌─────────┐   sensor frames    ┌───────────────┐   POST /predict    ┌──────────────────┐
  │  Glove  │ ─────────────────► │   Backend     │ ─────────────────► │  ML service      │
  │ (BLE)   │   (11 features)    │  (FastAPI)    │  X-Internal-API-Key│ python_ml_service│
  └─────────┘                    │  port 8000    │ ◄───────────────── │  port 8080       │
       │                         └───────┬───────┘   {translatedText, │  loads .joblib   │
       │  Flutter app                    │            gestureLabel,    └──────────────────┘
       │  (phone)                        │            confidence}            │
       │                                 │                                   │ reads (ro)
       ▼                                 ▼                                   ▼
  ┌─────────────┐   WebSocket      ┌───────────┐                       ┌──────────┐
  │ translate   │ ◄─────────────── │ Postgres  │                       │ models/  │
  │ screen      │  live entries    │ history   │                       │ *.joblib │
  └─────────────┘                  └───────────┘                       └──────────┘
```

| Process | Dir | Role re: ML |
|---|---|---|
| **ML service** | `python_ml_service/` | Loads `.joblib`, runs inference. Internal-only. The *only* process that imports scikit-learn / joblib. |
| **Backend** | `backend/` | Calls the ML service over HTTP. Owns the model registry table, activation, and session lifecycle. Never loads the model itself. |
| **Flutter app** | `lib/` | Displays translations. Today it only *listens* on a WebSocket. |
| **Glove** | hardware | Produces the 11 raw sensor values. Not yet streaming into the backend. |

Key constraint (from `CLAUDE.md`): **the ML service is internal-only; Flutter
never calls it directly.** The backend is the only caller, and it authenticates
with `X-Internal-API-Key`.

---

## 2. The model artifact

### 2.1 Format

A model is a **`.joblib` file** placed under the repo-root `models/` directory.
Two shapes are accepted by the loader (`python_ml_service/model_registry.py`,
`ModelRegistry.load`):

1. **Bundle dict (recommended):**
   ```python
   {"model": <fitted estimator>, "labels": {"<class>": "<display text>", ...}}
   ```
2. **Bare estimator:** just the fitted classifier (no labels).

The estimator **must** expose:
- `predict_proba(X)` — returns per-class probabilities for a 2-D input.
- `classes_` — the array of class labels (the gesture labels).

If either is missing, validation fails with `Model must expose predict_proba
and classes_.` Any scikit-learn classifier that supports probability output
works (`RandomForestClassifier`, `LogisticRegression`, calibrated SVM, an
sklearn `Pipeline` ending in such a classifier, etc.).

### 2.2 Labels (gesture → human text)

`classes_` holds **gesture labels** (e.g. `"hello"`, `"A"`, `"thanks"`). The
optional `labels` map turns a gesture label into the **translated text** shown
to the user. Inference returns `translatedText = labels.get(label, label)` — so
if there is no entry for a class, the raw class string is shown verbatim.

Labels can be supplied **two ways** (both are merged; the sidecar file wins on
key conflicts):
- Inside the bundle dict under `"labels"`.
- A **sidecar JSON file** next to the model: `<name>.labels.json`, e.g.
  `asl_alphabet.joblib` → `asl_alphabet.labels.json`, containing
  `{"A": "A", "hello": "Hello", ...}`.

The backend records the sidecar path in `models.labels_path` during a scan if
the file exists.

### 2.3 The feature vector — 11 values, fixed order

Every prediction consumes exactly **11 floats in this order** (`FEATURE_NAMES`
in `python_ml_service/model_registry.py`):

```
flex1, flex2, flex3, flex4, flex5, accelX, accelY, accelZ, gyroX, gyroY, gyroZ
```

**Train your model on columns in exactly this order.** The service builds the
row in this order and calls `predict_proba([row])`; there is no feature-name
negotiation at inference time — position is the contract.

The raw sensor payload may be **flat or nested** — `extract_feature_vector`
accepts these aliases:

| Feature | Accepted keys |
|---|---|
| `flex1`..`flex5` | `flex1` … `flex5` |
| `accelX/Y/Z` | `accelX` / `accel_x` / `accelerometer.x` (also `accel.x`) |
| `gyroX/Y/Z` | `gyroX` / `gyro_x` / `gyroscope.x` (also `gyro.x`) |

All 11 must be present and **finite** (no `NaN`/`Inf`), else `422`.

> **Single-frame contract.** The current pipeline classifies **one instantaneous
> 11-value reading** per prediction — there is no built-in windowing or temporal
> sequence. If your model needs a time window (e.g. an LSTM over N frames or
> hand-engineered window statistics), you must either (a) flatten/aggregate the
> window into an 11-value vector before sending, or (b) extend the contract
> (feature list + `extract_feature_vector` + the backend validator). See §6.4.

---

## 3. Producing a compatible model

Minimal training/export example that yields a drop-in artifact:

```python
# train_export.py  — run anywhere with scikit-learn 1.7.x + joblib 1.5.x
import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier

FEATURE_ORDER = [
    "flex1", "flex2", "flex3", "flex4", "flex5",
    "accelX", "accelY", "accelZ", "gyroX", "gyroY", "gyroZ",
]

# X must be shape (n_samples, 11) with columns in FEATURE_ORDER.
# y is the gesture-label per sample (these become classes_).
X = np.load("X.npy")          # your features, columns in FEATURE_ORDER
y = np.load("y.npy")          # e.g. ["hello", "thanks", "A", ...]

clf = RandomForestClassifier(n_estimators=200, random_state=0)
clf.fit(X, y)

# Bundle the model with a gesture->text map.
labels = {"hello": "Hello", "thanks": "Thank you", "A": "A"}
joblib.dump({"model": clf, "labels": labels}, "asl_v1.joblib")
```

Then (optionally) write `asl_v1.labels.json` if you prefer the sidecar form.

### Pin the versions

The ML service runs **scikit-learn 1.7.0** and **joblib 1.5.1**
(`python_ml_service/requirements.txt`). Pickled sklearn estimators are **not
guaranteed to load across versions** — train/export with the same minor
versions, or you risk an `InvalidModel("Model file could not be loaded.")` at
scan time. If you upgrade sklearn, re-export the model and bump both files
together.

### Pre-flight check (loads exactly like the service does)

```python
import joblib
b = joblib.load("asl_v1.joblib")
m = b["model"] if isinstance(b, dict) else b
assert callable(getattr(m, "predict_proba", None)) and hasattr(m, "classes_")
probs = m.predict_proba([[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1]])[0]
print("classes:", list(m.classes_))
print("argmax  :", m.classes_[max(range(len(probs)), key=probs.__getitem__)])
```

---

## 4. Deploying the artifact

### 4.1 Where the file goes

- Repo-root **`models/`** directory (see `models/README.md`). **Not committed**
  — model files are deployment artifacts.
- The path stored in Postgres (`models.file_path`) is **relative to the model
  dir, POSIX-style** (e.g. `asl_v1.joblib`, or `sub/dir/asl_v1.joblib`).
- Loader safety rails (`ModelRegistry.resolve`): must stay **inside** the model
  dir (no `../` traversal), must end in **`.joblib`**, must exist.

### 4.2 Model directory config (must match across processes)

| Process | Env var | Default | Notes |
|---|---|---|---|
| ML service | `MODEL_DIR` | `../models` | In Docker compose it's `/models`. |
| Backend | `MODEL_DIR` | `../models` | Used by `POST /admin/models/scan` to discover files. |

In `docker-compose.yml` the host `./models` is mounted **read-only** into the
ML service at `/models` (`- ./models:/models:ro`) and `MODEL_DIR=/models`. The
backend uses its own `MODEL_DIR` to scan/list. Both must point at the **same set
of files** (same mount / same path) or a scan will register a model the ML
service can't load.

### 4.3 Internal API key

Set `ML_INTERNAL_API_KEY` to the **same value** on both the ML service and the
backend in any non-local deployment. When set on the ML service, every
`/validate` and `/predict` requires the `X-Internal-API-Key` header (the backend
adds it automatically from its own `ML_INTERNAL_API_KEY`). Locally it can be
blank (auth disabled). Note: `Settings.validate()` does **not** enforce this in
prod — it's informational — so don't forget it.

### 4.4 Caching behavior

The ML service caches each loaded model keyed by path + file mtime
(`st_mtime_ns`). **Overwriting** a `.joblib` in place is picked up automatically
on the next request (mtime changes). There is no need to restart the service to
roll a model — but a brand-new filename still needs an admin **scan** to enter
the registry (§5).

---

## 5. Registering & activating the model (admin workflow)

The backend keeps a `models` table (`MlModel` in `backend/app/models.py`) and an
`admin_config` singleton whose `active_model_id` points at the live model. The
end-to-end activation flow:

1. **Drop the file** into `models/` (+ optional `.labels.json`).
2. **Turn the system OFF.** Activation is refused unless
   `admin_config.system_status == 'off'`
   (`PATCH /admin/models/{id}/activate` → `409 SYSTEM_MUST_BE_OFF`).
3. **Scan:** `POST /api/v1/admin/models/scan` (admin auth). This:
   - walks `MODEL_DIR/**/*.joblib`,
   - inserts new rows (auto `model_id` = `<slug>-<sha256[:12]>`),
   - calls the ML service `/validate` for each → on success sets
     `status='available'` and stores `metadata.classes`, `sha256`, `sizeBytes`;
     on failure sets `status='invalid'` with the error,
   - marks rows whose files vanished as `invalid`.
4. **Activate:** `PATCH /api/v1/admin/models/{model_id}/activate`. Deactivates
   any other active model, sets `is_active=true`, and sets
   `admin_config.active_model_id`. Requires `status='available'`. A partial
   unique index (`uq_models_one_active`) guarantees at most one active model.
5. **Turn the system ON** (`PATCH /api/v1/admin/config/system-status`,
   `{"systemStatus":"on"}`) and make sure the `translation` service toggle is on
   (`PATCH /api/v1/admin/config/service-toggles`).

After this, `GET /api/v1/admin/config` reports the `activeModelId`, and the
inference endpoint (§6) can resolve a live model.

> All of these endpoints are also surfaced in the **admin dashboard**
> (`admin_dashboard/`) — adding a UI button is just a call to `api<T>('/admin/...')`.

---

## 6. Wiring live inference — the gap to close

This is the part that is **not finished**. The model can already be validated
and predicted against, but the live translation a user sees on the phone does
**not** yet come from the model. Read this section carefully before declaring
the model "live".

### 6.1 What already works

`POST /api/v1/ml/translate` (`backend/app/translation_routes.py`) is a complete,
correct inference endpoint. Given `{sessionId, rawInput, languageCode}` it:

1. checks the `translation` toggle and `system_status == 'on'`,
2. confirms the caller owns an **active** session,
3. resolves the **active model** (`503 NO_ACTIVE_MODEL` if none),
4. calls `ml_client.predict(model.file_path, rawInput)` (→ ML service `/predict`),
5. persists a `TranslationHistory` row (`source='live'`, with `confidence`,
   `gestureLabel`, `model_id`) and returns it.

So: backend → ML service → DB is wired and tested. Steps 1–4 are reused as-is by
the chosen design; **step 5 changes** — instead of saving the row directly, the
endpoint will append the result to the session JSON and let the watcher save it
(§6.3c).

### 6.2 Why translations still don't appear live

The **live display path** and the **inference path** are currently two
different pipelines that don't meet:

| | Live display (what the phone sees) | Inference (`/ml/translate`) |
|---|---|---|
| Source of text | per-session JSON file `TRANSLATION_JSON_DIR/{id}.json` | the model |
| Who writes it | admin "manual send" / seed (`admin_translation_routes.py`) | the model |
| Delivery | `SessionWatcher` → DB → **WebSocket** push (`ingestion.py`) | HTTP response only |
| Flutter | **listens** on `ws/translation/{uid}` | **never calls `/ml/translate`** |

Consequences to be aware of:

- The Flutter `BackendTranslationRepository`
  (`lib/repositories/backend_repositories.dart`) starts a session and opens the
  WebSocket, then waits. It has **no code path that sends sensor data**. That's
  the "manual TTS mode" shipped in the last commit — text is injected by the
  admin, not produced by a glove.
- `/ml/translate` saves to the DB and returns the result but does **not** push
  over `ws_hub`, so even if something called it, the live screen (which only
  reads the WebSocket) wouldn't update from it.
- The `SessionWatcher` writes `raw_input={}` and leaves `confidence=null` /
  `gesture_label=null` / `model_id=null` for entries it ingests from the JSON
  file (`ingestion.py`, the `TranslationHistory(...)` construction). Those
  fields are model metadata it doesn't have.

### 6.3 The wiring: model output goes into the session JSON

**Design decision: the model's output is written into the per-session JSON file,
exactly like the admin manual-send does today.** The JSON file stays the single
ingestion source; the `SessionWatcher` remains the *only* writer to the DB and
the *only* thing that pushes the WebSocket. This means the model never talks to
the DB or the WebSocket directly — it just appends an entry to
`TRANSLATION_JSON_DIR/{session_id}.json` and the existing watcher does the rest.

```
 raw frame ─► ML service /predict ─► append_to_session_json() ─► {id}.json
                                                                     │
                                            SessionWatcher._poll() ◄─┘
                                                     │
                                       DB insert ───┴───► ws_hub.send() ─► phone
```

This keeps a single code path for *every* source of live text (admin send, seed,
and now the model) and reuses the thread-safe atomic writer
(`append_to_session_json` in `admin_shared.py`) and the watcher's dedup
(`_processed` cursor) that already exist.

Three changes are needed.

#### (a) Enrich the JSON entry schema

Today an entry is `{"text": ..., "timestamp": ...}`. The model carries more, so
write the richer entry (extra keys are optional — older producers still work):

```json
{
  "text": "Hello",
  "timestamp": "2026-06-26T12:00:00+00:00",
  "gestureLabel": "hello",
  "confidence": 0.94,
  "modelId": "asl_v1-ab12cd34ef56",
  "rawInput": { "flex1": 0.1, "flex2": 0.2, "...": "...", "gyroZ": 1.1 }
}
```

#### (b) Teach the watcher to read those fields

In `SessionWatcher._poll()` (`backend/app/ingestion.py`), the per-entry
`TranslationHistory(...)` construction currently hard-codes `raw_input={}` and
leaves `confidence`/`gesture_label`/`model_id` unset. Read them from the entry
instead (all optional, so admin/seed entries that omit them keep working):

```python
row = TranslationHistory(
    entry_id=f"trn_{uuid4().hex}",
    session_id=self._session_db_id,
    user_id=self._user_db_id,
    timestamp=ts,
    raw_input=entry.get("rawInput") or {},
    translated_text=text,
    gesture_label=entry.get("gestureLabel"),
    confidence=entry.get("confidence"),
    model_id=_resolve_model_uuid(entry.get("modelId")),   # see note
    source="live",
)
```

Then add `gestureLabel` / `confidence` to the WebSocket payload the watcher
already sends (it sends `confidence` today — add `gestureLabel` if the live
screen should show it). The Flutter client needs **no** change for `confidence`;
it already reads `entry['confidence']`.

> **`modelId` note:** the JSON carries the *public* `models.model_id` string, but
> the `translation_history.model_id` column is the `models.id` **UUID**
> (FK → `models.id`). The watcher must map one to the other (a tiny lookup,
> cacheable for the session) or you can leave `model_id` null and rely on
> `gesture_label`/`confidence` for provenance. Don't put the public string into
> the UUID column.

#### (c) Add the producer that runs inference and appends

Something has to take a sensor frame, call the ML service, and append the result
to the JSON. Reuse the existing `/ml/translate` endpoint
(`backend/app/translation_routes.py`) but **change it to append to the JSON
instead of saving the row directly** — otherwise the row is inserted twice (once
by the endpoint, once by the watcher). After `ml_client.predict(...)` succeeds:

```python
from .admin_shared import append_to_session_json

entry = {
    "text": str(result["translatedText"]),
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "gestureLabel": result.get("gestureLabel"),
    "confidence": float(result["confidence"]),
    "modelId": model.model_id,        # public id; watcher maps to UUID
    "rawInput": payload.raw_input,
}
json_path = request.app.state.settings.translation_json_dir / f"{session.session_id}.json"
append_to_session_json(json_path, entry)
return {"data": {"sessionId": session.session_id, "queued": True}}
```

This mirrors the admin `POST /admin/translation/send` flow
(`admin_translation_routes.py`) exactly, but with **model** output instead of
typed text. Drop the direct `_save_translation(...)` call from `translate()` so
the watcher is the sole DB writer. (If a synchronous, immediately-returned
prediction is ever needed for a non-live use case, keep that on a *separate*
endpoint that does **not** touch the session JSON.)

**Who calls it:** the Flutter app (or a device gateway) posts each gesture frame:

```dart
// lib/repositories/backend_repositories.dart
Future<void> sendReading(Map<String, num> sensors) =>
    _api.post('/ml/translate', body: {
      'sessionId': _sessionId,
      'rawInput': sensors,            // flex1..gyroZ
      'languageCode': 'en-US',
    });
```

Drive it from the BLE sensor stream (`lib/services/glove_state_provider.dart`,
`lib/repositories/glove_repository.dart`). The live screen keeps consuming
`translationStream()` (the WebSocket) unchanged — it never sees the HTTP
response. **Don't** fire one call per raw BLE packet; debounce to gesture
boundaries or a fixed cadence on the device.

#### Alternative: an external device-gateway as the producer

If sensor frames arrive at a gateway process rather than the phone, the gateway
can be the producer instead — it calls the ML service `/predict` (it needs the
`X-Internal-API-Key`) and appends the same enriched entry to the session JSON.
Same JSON schema, same watcher, no backend endpoint involved. Only worth it if
the glove streams somewhere other than the phone.

### 6.4 If the model needs a time window

The contract is single-frame (§2.3). If your real model is temporal:

- **Cheapest:** aggregate the window on the **device/client** into 11 values
  (e.g. mean/peak per channel) and keep the contract unchanged.
- **Contract change:** if the model genuinely needs N×11 (or more features),
  you must update, in lockstep: `FEATURE_NAMES` + `extract_feature_vector`
  (ML service), and `SENSOR_FIELDS` + `_validate_raw` (backend
  `translation_routes.py`). Bump the ML service version and re-test.

---

## 7. The inference contract (reference)

### ML service `POST /predict`

Request (header `X-Internal-API-Key: <key>` when configured):
```json
{
  "modelPath": "asl_v1.joblib",
  "rawSensorData": {
    "flex1": 0.1, "flex2": 0.2, "flex3": 0.3, "flex4": 0.4, "flex5": 0.5,
    "accelX": 0.6, "accelY": 0.7, "accelZ": 0.8,
    "gyroX": 0.9, "gyroY": 1.0, "gyroZ": 1.1
  }
}
```
Response:
```json
{
  "translatedText": "Hello",
  "gestureLabel": "hello",
  "confidence": 0.94,
  "modelPath": "asl_v1.joblib"
}
```
- `gestureLabel` = `classes_[argmax(predict_proba)]`.
- `translatedText` = `labels.get(gestureLabel, gestureLabel)`.
- `confidence` = max probability, clamped to `[0,1]`, rounded to 6 dp.

### ML service `POST /validate`

Request: `{"modelPath": "asl_v1.joblib"}` → Response:
```json
{"valid": true, "modelPath": "asl_v1.joblib", "classes": ["A","hello","thanks"], "labels": {"hello":"Hello"}}
```

### Error codes

| Where | Status | Meaning |
|---|---|---|
| ML service | `401` | bad/missing `X-Internal-API-Key` (when key configured) |
| ML service | `422` | invalid sensor data, bad/missing/traversal model path, inference failure |
| Backend `/ml/translate` | `503 SYSTEM_OFF` | system is off |
| Backend `/ml/translate` | `503 NO_ACTIVE_MODEL` | no valid active model |
| Backend `/ml/translate` | `502 ML_INFERENCE_FAILED` | ML service unreachable/errored |
| Backend activate | `409 SYSTEM_MUST_BE_OFF` | tried to activate while system on |

---

## 8. Validation & smoke-test checklist

Run these in order once the artifact is in `models/`:

1. **Artifact loads** — the pre-flight snippet in §3.
2. **ML service health** — `Invoke-RestMethod http://127.0.0.1:8080/health`
   (reports `modelDir`).
3. **Validate via ML service** directly:
   ```powershell
   Invoke-RestMethod -Method Post http://127.0.0.1:8080/validate `
     -Headers @{ 'X-Internal-API-Key'='<key-or-omit>' } `
     -ContentType 'application/json' `
     -Body '{"modelPath":"asl_v1.joblib"}'
   ```
4. **Predict via ML service** — POST `/predict` with a real 11-value frame;
   confirm `gestureLabel` / `translatedText` look right.
5. **Admin scan** — `POST /api/v1/admin/models/scan`; confirm the model shows
   `status:"available"` and `metadata.classes`.
6. **Activate** (system off) → **system on**.
7. **JSON append** — with §6.3 wiring in place, `POST /api/v1/ml/translate` for a
   session you own; confirm the enriched entry (`text`, `gestureLabel`,
   `confidence`, `modelId`, `rawInput`) is appended to
   `TRANSLATION_JSON_DIR/{session_id}.json`.
8. **Watcher → DB** — confirm the `SessionWatcher` ingests that entry into
   `translation_history` with non-null `confidence`/`gesture_label` (and
   `raw_input` populated, not `{}`).
9. **Live screen** — start a session in the app, feed a frame, and confirm the
   translation appears on the phone via WebSocket — driven by the model, not an
   admin send.

Existing automated coverage to mirror/extend:
`python_ml_service/tests/test_service.py` (loader, feature extraction, key
enforcement, traversal), `backend/tests/test_translation_pipeline.py`,
`backend/tests/test_ingestion_watcher.py`.

---

## 9. Gotchas

- **Feature order is positional** — a mis-ordered training matrix produces a
  model that "works" but predicts garbage. Lock the order to §2.3.
- **sklearn/joblib version skew** — re-export when the service's versions change.
- **`MODEL_DIR` mismatch** between backend (scan) and ML service (load) →
  model registers but inference 502s. Same files, same relative paths.
- **`.joblib` only**, no `../` in paths — the loader rejects both.
- **Activation needs system OFF**; live inference needs system ON and the
  `translation` toggle ON.
- **The model output must go into the session JSON**, not straight to the DB —
  the `SessionWatcher` is the single DB writer + WebSocket pusher. If
  `/ml/translate` *also* saves the row directly, the entry is inserted twice
  (once by the endpoint, once by the watcher). Drop the direct save (§6.3c).
- **`modelId` in the JSON is the public string; the DB column is a UUID** — map
  `models.model_id` → `models.id` in the watcher, or leave `model_id` null. Never
  write the public string into the FK column.
- **`SessionWatcher` currently writes `raw_input={}` / null confidence** — until
  §6.3b lands, JSON-file ingestion drops all model metadata even if it's present
  in the entry.
- **Flutter doesn't send sensor data yet** — `BackendTranslationRepository` only
  listens on the WebSocket; add `sendReading` (§6.3c) and drive it from the BLE
  stream, or the screen stays in admin-driven manual mode.
- Don't commit model files unless explicitly approved (`models/README.md`).

---

## 10. File map (where to make changes)

| Concern | File |
|---|---|
| Feature list, loader, inference | `python_ml_service/model_registry.py` |
| ML service HTTP API | `python_ml_service/main.py`, `python_ml_service/schemas.py` |
| Backend → ML HTTP client | `backend/app/ml_client.py` |
| Inference endpoint (`/ml/translate`) | `backend/app/translation_routes.py` |
| Model registry table | `backend/app/models.py` (`MlModel`) |
| Scan / activate | `backend/app/admin_config_routes.py` |
| Live WS push + file watcher | `backend/app/ingestion.py` |
| Manual/admin send (current live source) | `backend/app/admin_translation_routes.py` |
| Config / env (`MODEL_DIR`, `ML_*`) | `backend/app/config.py` |
| Deployment (volumes, env) | `docker-compose.yml`, `python_ml_service/Dockerfile` |
| Flutter live translation | `lib/repositories/backend_repositories.dart` |
| Flutter glove/sensor stream | `lib/services/glove_state_provider.dart`, `lib/repositories/glove_repository.dart` |
| Model drop directory | `models/` (`models/README.md`) |
