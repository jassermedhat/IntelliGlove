# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository structure

| Directory | Language | Role |
|---|---|---|
| `lib/` (repo root) | Dart/Flutter | Mobile app (iOS/Android/Web) |
| `backend/` | Python 3.12 / FastAPI | REST + WebSocket API |
| `python_ml_service/` | Python 3.12 / FastAPI | Gesture inference service |
| `admin_dashboard/` | TypeScript/React/Vite | Admin SPA |
| `models/` | — | `.joblib` model artifacts (not committed) |
| `alembic/` (inside `backend/`) | — | DB migrations |

There is no git repository initialized at the root. All source control must be done per-subdirectory or initialized first.

## Commands

### Backend (run from `backend/`)

```powershell
# Install
python -m venv .venv && .\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt

# Run (Alembic does not load .env — export DATABASE_URL first)
$env:DATABASE_URL='postgresql+psycopg://intelliglove:<PASSWORD>@localhost:5432/intelliglove'
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --env-file .env

# Test (use a separate DB — the suite truncates all tables)
$env:TEST_DATABASE_URL='postgresql+psycopg://intelliglove:<PASSWORD>@localhost:5432/intelliglove_test'
$env:DATABASE_URL=$env:TEST_DATABASE_URL
alembic upgrade head
python -m pytest -v --basetemp=.pytest_tmp   # --basetemp required on Windows

# Single test
python -m pytest -v --basetemp=.pytest_tmp tests/test_admin_api.py::test_admin_list_users_returns_paginated_user_list

# Lint
ruff check app/
python -m compileall -q app alembic
```

### Python ML service (run from `python_ml_service/`)

```powershell
pip install -r requirements-dev.txt
uvicorn main:app --host 0.0.0.0 --port 8080 --env-file .env
python -m pytest -q
```

### Admin dashboard (run from `admin_dashboard/`)

```powershell
npm install
npm run dev        # Vite dev server at http://localhost:5173
npm test           # Vitest
npm run build      # production build check
```

### Flutter (run from repo root)

```powershell
flutter pub get
flutter test
flutter analyze
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

### Docker

```powershell
# Postgres + ML only (recommended; run backend locally for Firebase creds)
docker compose up --build -d postgres ml

# Full stack smoke
docker compose up --build -d postgres ml backend
Invoke-RestMethod http://127.0.0.1:8000/health
Invoke-RestMethod http://127.0.0.1:8080/health
```

### Seed the admin user (backend venv, all env vars exported)

```powershell
python -m app.seed_admin
```

## Architecture

### Request lifecycle

1. Flutter or admin dashboard sends a Firebase ID token as `Authorization: Bearer <token>`.
2. `backend/app/dependencies.py` — `get_current_claims()` verifies the token via `FirebaseIdentity` (real or dev bypass), `get_current_user()` maps `firebase_uid` → `users` row, `get_current_admin()` additionally checks `admin_users`.
3. All route errors go through `AppError(status, code, message)` → `install_error_handlers` in `errors.py`. Response envelope: `{"data": ...}` on success, `{"code":..., "message":..., "details":..., "requestId":...}` on error.
4. `AdminConfig` (singleton row, `system_config.py`) holds `system_status` (`on`/`off`) and `service_toggles` JSONB. `require_service(db, key)` raises `503 SERVICE_DISABLED` if a toggle is off. System must be **off** to activate a model.

### Translation live path

1. `POST /api/v1/sessions/start` creates a `TranslationSession` row and an empty `{session_id}.json` file in `TRANSLATION_JSON_DIR`. Both `start_session` and `stop_session` are declared `async def` — this is load-bearing: `async def` routes run in the asyncio event loop thread, so `asyncio.create_task()` in `SessionWatcher.start()` finds a running loop and `_stop_event.set()` / `_task.cancel()` in `stop()` are event-loop-safe. Do not convert these routes back to sync `def`.
2. Admin `POST /api/v1/admin/translation/send` calls `append_to_session_json()` in `admin_shared.py`, which does a thread-safe atomic write (tmp-rename) to the JSON file.
3. `SessionWatcher._poll()` reads the JSON file, inserts new `TranslationHistory` rows, and pushes the latest over `WebSocketHub` (singleton `ws_hub` in `ingestion.py`).
4. `POST /api/v1/sessions/{id}/stop` calls `_persist_remaining_json_entries()` (flushes any entries the watcher missed), commits, then deletes the JSON file. File is only deleted **after** a successful commit.
5. Flutter connects to `ws/{session_id}` at session start; receives `{"type":"translation", ...}` messages in real time.

### Backend module map

| Module | Purpose |
|---|---|
| `main.py` | `create_app()` factory — lifespan, middleware, router registration |
| `models.py` | SQLAlchemy ORM (all tables) |
| `dependencies.py` | `get_db`, `get_current_user`, `get_current_admin` FastAPI deps |
| `errors.py` | `AppError`, `install_error_handlers` |
| `system_config.py` | `get_admin_config()`, `require_service()`, `DEFAULT_SERVICE_TOGGLES` |
| `ingestion.py` | `WebSocketHub`, `SessionWatcher`, `IngestionManager` (singletons `ws_hub`, `ingestion_manager`) |
| `admin_routes.py` | Hub: includes the four sub-routers under `/admin` |
| `admin_shared.py` | `_audit()`, `append_to_session_json()`, seed constants |
| `admin_config_routes.py` | Config/model admin endpoints |
| `admin_seed_routes.py` | Seed and demo-glove endpoints |
| `admin_translation_routes.py` | Active sessions + send-translation admin endpoints |
| `admin_user_routes.py` | User list, device assign, audit log |
| `development_auth.py` | Dev bypass tokens (`DEVELOPMENT_AUTH_BYPASS`) |
| `config.py` | `Settings` dataclass; `Settings.from_env()` |

### Admin route hub pattern

`admin_routes.py` creates `router = APIRouter(prefix="/admin")` and calls `router.include_router()` for each sub-module's `_router` (no prefix, no tags on `_router` itself). Add new admin concern as a new `_router` file; never add routes directly to `admin_routes.py`.

### Flutter architecture

- `lib/services/backend_api_client.dart` — singleton `BackendApiClient.instance`; handles Firebase token injection + one 401-then-refresh retry; compile-time `API_BASE_URL` via `--dart-define`.
- `lib/repositories/backend_repositories.dart` — `BackendTranslationRepository`; owns WebSocket lifecycle with exponential backoff (500 ms base, ×2, cap 60 s, 8 attempts). `stopSession()` sets `_sessionId = null` first to prevent reconnect during teardown.
- Repositories are consumed by controllers in `lib/services/`; screens read controllers via Flutter providers.
- Dev bypass: email `testing` / password `1234` skips Firebase; the token `developmentTestingUserToken` is accepted by the backend when `DEVELOPMENT_AUTH_BYPASS=true`.

### Admin dashboard

- `src/api.ts` — `api<T>(path, init)` returns `body.data as T` directly (already unwrapped). On 401, refreshes the Firebase token once and retries. Do not call `.data` on the return value.
- `src/App.tsx` — page routing via `Page` union type and `NAV` array; `renderPage()` switch. Add new pages here.
- Pages call `api<Type>('/admin/...')` directly; no intermediate service layer.

### Database

- PostgreSQL 16, driver `psycopg` (not `psycopg2`). Connection string format: `postgresql+psycopg://...`.
- All schema changes via Alembic migrations in `backend/alembic/versions/`. The app never calls `create_all()`.
- Single migration: `563c5de3b860_initial_postgresql_schema.py`.
- `AdminConfig` is a singleton (`singleton_key='default'`); `get_admin_config()` creates it on first access.
- One active `TranslationSession` per user enforced by partial unique index on `status='active'`.

### CI

`.github/workflows/ci.yml` runs three jobs: `backend` (pytest + pip-audit, with Postgres 16 service), `dashboard` (vitest + npm audit), `flutter` (flutter-action@v2, version 3.32.8). Backend CI uses `TEST_DATABASE_URL` (not just `DATABASE_URL`).

## Key constraints

- `backend_base/` has been removed. Do not reference it.
- `GET /translations/current-session/{sessionId}` is deprecated — WebSocket is the canonical live delivery path.
- ML service is internal-only; Flutter never calls it directly. Backend calls `POST /predict` with `X-Internal-API-Key`.
- Model activation requires `system_status='off'`. `PATCH /admin/models/{id}/activate` enforces this.
- SOS/emergency contacts are local to the device (SharedPreferences) and have no backend counterpart.
- The `backend/` Docker image runs as non-root `appuser`; the `/translation_output` volume is chowned in the Dockerfile `RUN` layer before `USER appuser`.
- `TEST_DATABASE_URL` must point at a separate database — the test suite runs `TRUNCATE ... CASCADE` on all tables at startup.
- On Windows, run pytest with `--basetemp=.pytest_tmp` to avoid `PermissionError` on `AppData\Local\Temp\pytest-of-<user>`.
