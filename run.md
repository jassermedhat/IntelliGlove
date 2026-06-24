# IntelliGlove Full System Run Guide

This guide documents the repository exactly as it currently exists. Commands
are written for PowerShell from the repository root unless a section says
otherwise. Replace every `<PLACEHOLDER>` before running a command; never commit
real passwords, Firebase Admin credentials, or admin auto-login credentials.

## 1. System Overview

IntelliGlove consists of six runtime components:

| Component | Repository path | Responsibility | Local address |
|---|---|---|---|
| Flutter app | repository root, `lib/` | User authentication, screens, API calls, session polling, local preferences/biometrics/SOS | Device-dependent |
| Backend API | `backend/` | Firebase token verification, PostgreSQL data, ownership, sessions, model registry, reports, admin APIs | `http://127.0.0.1:8000` |
| PostgreSQL | Docker Compose `postgres` service | Sole authoritative application-data store | `localhost:5432` |
| Python ML service | `python_ml_service/` | Validates model files and eleven sensor values, then performs joblib inference | `http://127.0.0.1:8080` |
| Admin dashboard | `admin_dashboard/` | Firebase-authenticated system/model/service/report/seed controls | `http://localhost:5173` |
| Firebase Authentication | external Firebase project | Email/password and Google identities plus Firebase ID tokens | External service |

Runtime data flow:

1. Flutter or the admin dashboard signs in through Firebase Authentication.
2. The client sends its Firebase ID token to FastAPI as a bearer token.
3. FastAPI verifies the token with Firebase Admin, maps its Firebase UID to a
   PostgreSQL user, and enforces ownership or the SQL admin role.
4. Translation requests go to FastAPI, which calls the separate ML service
   with `X-Internal-API-Key`.
5. The admin `POST /admin/send-translation` endpoint appends the translated text
   entry to the per-session JSON file on disk. The backend's session watcher
   detects the new entry, persists it to PostgreSQL, and pushes it over the
   open WebSocket connection.
6. Flutter receives the WebSocket message and displays the latest translated
   text in real time. On session stop, any un-committed JSON entries are
   flushed to PostgreSQL and the JSON file is deleted.

Firestore, Realtime Database, Firebase Storage, Cloud Functions, and FCM are
not application-data dependencies. SOS contacts and prepared SOS records stay
on the device in SharedPreferences and are not dispatched by the backend.

The repository also contains:

- Alembic migration `backend/alembic/versions/563c5de3b860_initial_postgresql_schema.py`.
- Firebase/SQL admin synchronization command `python -m app.seed_admin`.
- Admin mock-data seeding through `POST /api/v1/admin/seed` and the dashboard.
- `backend_base/` has been removed from the active codebase. Do not reference
  it in new code or documentation.

## 2. Prerequisites

### Required for the recommended local setup

- **Python 3.12.** Both Python Dockerfiles use `python:3.12-slim`, and backend
  tooling targets Python 3.12.
- **Flutter 3.32.8 stable.** This version is recorded in
  `.flutter-plugins-dependencies`; `.metadata` records the stable channel.
- **Dart 3.8.1-compatible SDK.** `pubspec.yaml` requires `sdk: ^3.8.1`.
- **Docker Desktop or another Docker Engine with Docker Compose.** Version
  cannot be determined from repository files.
- **PostgreSQL 16** when using the provided Compose service
  (`postgres:16-alpine`). A separate local PostgreSQL installation is not
  needed for the recommended path.
- **Node.js and npm** for local admin-dashboard development. Version cannot be
  determined from repository files for local execution. The dashboard Docker
  build uses Node 24 Alpine.
- **Firebase project access** for project configuration, Authentication
  providers, authorized domains, Android SHA fingerprints, and a Firebase
  Admin service-account credential or other Application Default Credentials.
- **A real compatible `.joblib` model** for live inference.

### Platform tooling

- **Android:** Android Studio/Android SDK. The app compiles with SDK 36, has
  minimum SDK 24, and targets Java 11 bytecode. Android Studio/JDK version
  cannot be determined from repository files.
- **iOS:** Xcode and CocoaPods on macOS. Version cannot be determined from
  repository files.
- **Web:** A Flutter-supported browser.

The Firebase CLI is not used by a repository script and is not required by the
documented startup path.

## 3. Required Environment Variables

### Root `.env` for Docker Compose

Copy `.env.example` to the untracked root `.env`:

```powershell
Copy-Item .env.example .env
```

| Variable | Required | Purpose | Example placeholder | Location |
|---|---|---|---|---|
| `POSTGRES_PASSWORD` | Yes for every Compose command | Initializes the PostgreSQL user and is inserted into the backend container URL | `replace-with-strong-local-password` | Root `.env` |
| `ML_INTERNAL_API_KEY` | Yes for every Compose command | Shared secret between backend and ML containers | `replace-with-random-internal-key` | Root `.env` |
| `VITE_API_BASE_URL` | Required for the functional Compose admin image | Browser-visible FastAPI prefix embedded at build time | `http://127.0.0.1:8000/api/v1` | Root `.env` |
| `VITE_FIREBASE_API_KEY` | Required for Compose admin login | Firebase web client API key embedded at build time | `<FIREBASE_WEB_API_KEY>` | Root `.env` |
| `VITE_FIREBASE_AUTH_DOMAIN` | Required for Compose admin login | Firebase web auth domain | `<PROJECT_ID>.firebaseapp.com` | Root `.env` |
| `VITE_FIREBASE_PROJECT_ID` | Required for Compose admin login | Firebase project ID | `<PROJECT_ID>` | Root `.env` |
| `VITE_FIREBASE_APP_ID` | Required for Compose admin login | Firebase web app ID | `<FIREBASE_WEB_APP_ID>` | Root `.env` |
| `VITE_FIREBASE_MESSAGING_SENDER_ID` | Present in the Compose build contract | Firebase sender/project number | `<SENDER_ID>` | Root `.env` |

If the PostgreSQL password contains URL-special characters, URL-encode it when
placing the same value in a standalone backend `DATABASE_URL`.

### Backend API

`backend/.env.example` is the configuration reference. `Settings.from_env()`
reads the process environment. Alembic and `python -m app.seed_admin` do **not**
automatically load `backend/.env`; export the relevant values in their shell.
Uvicorn can load it when started with `--env-file .env`.

| Variable | Required | Purpose | Example placeholder |
|---|---|---|---|
| `APP_ENV` | Optional; defaults to `development` | Environment name; `production` enables the production ML-key requirement | `development` |
| `DATABASE_URL` | Operationally required | PostgreSQL SQLAlchemy/Psycopg URL | `postgresql+psycopg://intelliglove:<URL_ENCODED_PASSWORD>@localhost:5432/intelliglove` |
| `FIREBASE_PROJECT_ID` | Required; code has an approved-project default | Firebase project used by Firebase Admin | `your-firebase-project-id` |
| `FIREBASE_CREDENTIALS_PATH` | Required when Application Default Credentials are unavailable | Readable Firebase Admin service-account JSON path | `C:/secure/intelliglove-admin.json` |
| `REQUIRE_VERIFIED_EMAIL` | Optional; defaults to `true` | Rejects unverified users from protected endpoints | `true` |
| `DEVELOPMENT_AUTH_BYPASS` | Development only; defaults to `true` when `APP_ENV=development` | Accepts the local testing user/admin bearer tokens; rejected in production | `true` |
| `CORS_ORIGINS` | Optional | Comma-separated browser origins | `http://localhost:5173,http://127.0.0.1:7358` |
| `ML_SERVICE_URL` | Optional; defaults to `http://localhost:8080` | ML service base URL | `http://localhost:8080` |
| `ML_INTERNAL_API_KEY` | Required in production; recommended locally | Key sent to `/validate` and `/predict`; must match ML | `<SAME_RANDOM_KEY>` |
| `MODEL_DIR` | Optional; defaults to `../models` | Backend model-scan root | `../models` |
| `RATE_LIMIT_ENABLED` | Optional; defaults to `false` | Enables the in-memory IP rate limiter | `false` |
| `RATE_LIMIT_REQUESTS` | Optional; defaults to `120` | Requests allowed per window | `120` |
| `RATE_LIMIT_WINDOW_SECONDS` | Optional; defaults to `60` | Rate-limit window length | `60` |
| `ADMIN_EMAIL` | Required only for `app.seed_admin` | Firebase/SQL admin email | `admin@example.test` |
| `ADMIN_PASSWORD` | Required only for `app.seed_admin`; minimum 8 characters | Firebase admin password | `<ADMIN_PASSWORD>` |
| `ADMIN_NAME` | Optional seed display name | Firebase/SQL admin display name | `IntelliGlove Admin` |
| `TEST_DATABASE_URL` | Optional outside tests; strongly recommended for tests | Separate PostgreSQL test URL because the suite truncates its target | `postgresql+psycopg://intelliglove:<PASSWORD>@localhost:5432/intelliglove_test` |

### Python ML service

Source: `python_ml_service/.env.example`.

| Variable | Required | Purpose | Example placeholder |
|---|---|---|---|
| `ML_INTERNAL_API_KEY` | Compose requires it; code permits an empty value | Protects `/validate` and `/predict` | `<SAME_RANDOM_KEY>` |
| `MODEL_DIR` | Optional; defaults to `../models` | Directory containing relative `.joblib` paths | `../models` |

The service reads process variables. Use Uvicorn's `--env-file .env` option for
a local `python_ml_service/.env` file.

### Admin dashboard

Copy `admin_dashboard/.env.example` to `admin_dashboard/.env.local`. Vite loads
this file for local development and embeds `VITE_*` values at build time.

| Variable | Required | Purpose | Example placeholder |
|---|---|---|---|
| `VITE_API_BASE_URL` | Optional fallback exists; set it explicitly | FastAPI prefix | `http://127.0.0.1:8000/api/v1` |
| `VITE_DEVELOPMENT_AUTH_BYPASS` | Optional; local testing only | Enables the `testing` / `1234` admin login that still uses the real backend | `true` |
| `VITE_FIREBASE_API_KEY` | Required for functional Firebase Auth | Firebase web API key | `<FIREBASE_WEB_API_KEY>` |
| `VITE_FIREBASE_AUTH_DOMAIN` | Required | Firebase Auth domain | `<PROJECT_ID>.firebaseapp.com` |
| `VITE_FIREBASE_PROJECT_ID` | Required | Firebase project ID | `<PROJECT_ID>` |
| `VITE_FIREBASE_APP_ID` | Required | Firebase web application ID | `<FIREBASE_WEB_APP_ID>` |
| `VITE_FIREBASE_MESSAGING_SENDER_ID` | Present in example configuration | Firebase sender/project number | `<SENDER_ID>` |
| `VITE_ADMIN_AUTO_LOGIN` | Optional; defaults to disabled behavior | Enables development-only automatic login when exactly `true` | `false` |
| `VITE_ADMIN_EMAIL` | Optional; only used with development auto-login | Development admin email | `admin@example.test` |
| `VITE_ADMIN_PASSWORD` | Optional; only used with development auto-login | Development admin password | `<ADMIN_PASSWORD>` |

The testing login is available in Vite development mode or when
`VITE_DEVELOPMENT_AUTH_BYPASS=true`. The backend must also have
`DEVELOPMENT_AUTH_BYPASS=true`; production mode rejects that backend setting.

### Flutter

| Variable | Required | Purpose | Example placeholder | Placement |
|---|---|---|---|---|
| `API_BASE_URL` | Compile-time optional; required when the default is unreachable | Backend `/api/v1` base URL | `http://10.0.2.2:8000/api/v1` | `flutter run --dart-define=API_BASE_URL=...` |

The default is Android-emulator networking (`10.0.2.2`). Firebase client
options are compiled into `lib/firebase_options.dart`; there is no Flutter
runtime `.env` loader.

In Flutter debug builds, use email `testing` and password `1234`. This skips
Firebase login only: the app synchronizes `Testing User` with PostgreSQL and
uses the normal protected REST and WebSocket backend paths.

## Missing or Required Manual Setup

The following items are required for a fully functional system but are not
provided as ready-to-run artifacts:

1. **Firebase console configuration:** enable Email/Password and Google sign-in,
   add authorized web domains, and register the required Android SHA-1/SHA-256
   fingerprints. The required console-only values cannot be determined from
   repository files.
2. **Firebase Admin credentials:** no service-account JSON is committed, which
   is correct. Supply `FIREBASE_CREDENTIALS_PATH` or externally configured
   Application Default Credentials.
3. **Backend Docker credential mount:** `docker-compose.yml` does not mount a
   Firebase credential or pass `FIREBASE_CREDENTIALS_PATH`. The backend
   container can serve `/health`, but authenticated requests need an external
   Compose extension/credential mechanism that is not present. Run the backend
   locally for the repository-supported explicit credential-path flow.
4. **Trained model:** `models/` contains documentation only. Supply a compatible
   `.joblib` artifact and optional sibling `.labels.json`.
5. **Physical glove protocol:** BLE UUIDs, packet framing, and a sensor-ingest
   adapter are not implemented. Flutter device discovery lists backend-registered
   devices, and Flutter does not currently post sensor readings to
   `/api/v1/ml/translate`.
6. **Test database provisioning:** backend tests support `TEST_DATABASE_URL`,
   but no separate test-database creation script is provided. Exact manual
   creation commands cannot be determined from repository files.

## 4. Firebase Setup

Firebase is used only for authentication and Firebase ID tokens. The checked-in
client/backend defaults target project `intelligent-glove-asl-33-da1aa`.

1. Obtain access to the Firebase project represented by the checked-in client
   configuration, or replace all platform configuration consistently with your
   own project.
2. In Firebase Authentication, enable:
   - Email/Password.
   - Google sign-in if the Google buttons will be used.
3. Configure authorized domains for the dashboard and Flutter web origins.
   `localhost` is needed for the documented local web flows.
4. Register Android SHA fingerprints for package
   `com.intelligentglove.asl`, then update `android/app/google-services.json`
   if Firebase generates a changed file.
5. The repository already contains:
   - Android `android/app/google-services.json`.
   - Android Google Services Gradle plugin wiring.
   - Android/iOS/web `FirebaseOptions` in `lib/firebase_options.dart`.
   - iOS Google client ID and reversed-client URL scheme in
     `ios/Runner/Info.plist`.
6. No `GoogleService-Info.plist` is present. iOS initialization uses the
   explicit options in `firebase_options.dart`; if the Firebase console values
   change, regenerate/update all iOS options and URL schemes consistently.
7. Create a Firebase Admin service account outside this repository and point
   `FIREBASE_CREDENTIALS_PATH` to its readable JSON file. Do not place it in a
   tracked project directory.
8. Keep `FIREBASE_PROJECT_ID` aligned between backend, Flutter, and dashboard.

Password signup sends a verification email, synchronizes the unverified SQL
profile, signs out, and requires verification before login. Google login also
requires a verified email claim. Password-reset email is sent by Firebase.

## 5. Database Setup

### Start PostgreSQL with Docker

From the repository root, create/edit the root `.env`, then run:

```powershell
docker compose up -d postgres
docker compose ps
```

The supplied service uses:

- PostgreSQL image: `postgres:16-alpine`
- Database: `intelliglove`
- User: `intelliglove`
- Password: root `POSTGRES_PASSWORD`
- Host port: `5432`
- Persistent named volume: Compose-managed `intelliglove_postgres`

### Apply migrations

For a local backend shell:

```powershell
Set-Location backend
$env:DATABASE_URL='postgresql+psycopg://intelliglove:<URL_ENCODED_PASSWORD>@localhost:5432/intelliglove'
alembic upgrade head
alembic current
alembic check
Set-Location ..
```

Alternatively, migration-only execution inside the backend image does not need
Firebase credentials:

```powershell
docker compose build backend
docker compose run --rm backend alembic upgrade head
```

`alembic current` should report revision `563c5de3b860`; `alembic check` should
report no new upgrade operations.

### Reset the local Docker database

This permanently deletes all local PostgreSQL data and every Compose volume:

```powershell
docker compose down -v
docker compose up -d postgres
Set-Location backend
$env:DATABASE_URL='postgresql+psycopg://intelliglove:<URL_ENCODED_PASSWORD>@localhost:5432/intelliglove'
alembic upgrade head
Set-Location ..
```

Changing `POSTGRES_PASSWORD` after the volume was initialized does not change
the existing database user's password. Reset the volume or update PostgreSQL
manually.

The repository supports Docker PostgreSQL. If Docker is not used, manually
create a PostgreSQL database/user and provide a matching `DATABASE_URL`; no
manual provisioning script is included.

## 6. Backend API Setup and Run

### Local setup (recommended for functional Firebase Auth)

```powershell
Set-Location backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
Copy-Item .env.example .env
```

Edit `backend/.env`. At minimum, make its database password match the root
Compose password, set a readable Firebase Admin credential path, and use the
same ML key as the root `.env`.

Export the database URL before Alembic because Alembic does not load `.env`:

```powershell
$env:DATABASE_URL='postgresql+psycopg://intelliglove:<URL_ENCODED_PASSWORD>@localhost:5432/intelliglove'
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --env-file .env
```

Expected endpoints:

- Health: `http://127.0.0.1:8000/health`
- Swagger UI: `http://127.0.0.1:8000/docs`
- OpenAPI JSON: `http://127.0.0.1:8000/openapi.json`
- API prefix: `http://127.0.0.1:8000/api/v1`

The backend performs a database-connectivity check at startup. It never creates
tables automatically; migrations must already be applied.

### Docker backend smoke path

```powershell
docker compose up --build -d postgres ml backend
Invoke-RestMethod http://127.0.0.1:8000/health
```

This validates container startup. Authenticated calls still require the missing
Firebase credential injection described under manual setup.

## 7. Python ML Service Setup and Run

### Model format

Place model artifacts under root `models/`:

```text
models/
  my_model.joblib
  my_model.labels.json   # optional
```

The joblib file must either be the estimator or a dictionary containing
`model` and optional `labels`. The estimator must expose `predict_proba` and
`classes_`. It must consume this ordered eleven-value vector:

`flex1`, `flex2`, `flex3`, `flex4`, `flex5`, `accelX`, `accelY`, `accelZ`,
`gyroX`, `gyroY`, `gyroZ`.

The optional labels JSON maps class values to display text. Model paths sent to
the service are relative to `MODEL_DIR`; traversal and non-`.joblib` files are
rejected.

### Run with Docker (recommended)

```powershell
docker compose up --build -d ml
Invoke-RestMethod http://127.0.0.1:8080/health
```

Compose mounts root `models/` read-only at `/models`, sets `MODEL_DIR=/models`,
and publishes port `8080`.

### Run locally

```powershell
Set-Location python_ml_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn main:app --host 0.0.0.0 --port 8080 --env-file .env
```

Health and documentation:

- `GET http://127.0.0.1:8080/health`
- `http://127.0.0.1:8080/docs`
- Protected internal endpoints: `POST /validate`, `POST /predict`

The backend calls `POST /predict` and `POST /validate` with the configured
`X-Internal-API-Key`. A sample request appears in Section 14.

## 8. Admin Dashboard Setup and Run

Use the local Vite path for functional Firebase configuration:

```powershell
Set-Location admin_dashboard
Copy-Item .env.example .env.local
npm install
npm run dev
```

Edit `.env.local` before starting. Vite normally serves the configured project
at `http://localhost:5173`. If it selects another port, add that origin to the
backend `CORS_ORIGINS` and restart the backend.

For quick local testing, sign in with email `testing` and password `1234`.
This creates/synchronizes a development administrator and all dashboard pages
continue to read and write the real backend database.

Create the admin identity before logging in. In a backend virtual-environment
shell, export all backend settings plus:

```powershell
$env:ADMIN_EMAIL='admin@example.test'
$env:ADMIN_PASSWORD='<ADMIN_PASSWORD_AT_LEAST_8_CHARACTERS>'
$env:ADMIN_NAME='IntelliGlove Admin'
python -m app.seed_admin
```

This command creates or updates the Firebase user, marks its email verified,
sets the SQL user role, creates the `admin_users` record, and writes an audit
entry. It is idempotent for the same Firebase identity/email.

Dashboard pages and actions:

- **Overview:** master status, enabled-service count, active-model status.
- **System & models:** turn the master system on/off, scan `MODEL_DIR`, and
  activate an available model. The system must be **off** before activation.
- **Bug reports / Feedback:** review submissions, change status, and save admin notes.
- **Demo Data:** connect or disconnect `INTELLIGLOVE DEMO` for the mobile
  `testing` account. The debug mobile app synchronizes this backend state about
  every four seconds and exposes normal glove-dependent features while connected.
- **Services:** toggle translation, health monitor, smart house, analytics,
  practice, feedback, devices, and firmware availability.
- **Demo data:** seed selected PostgreSQL data targets for the admin or an
  explicit SQL user UUID.

Production build checks:

```powershell
npm test
npm run build
```

The Compose/Nginx build accepts the public dashboard `VITE_*` values from the
root `.env` as Docker build arguments. Rebuild the image after changing them.
Development auto-login credentials are never passed to the production image.

## 9. Flutter App Setup and Run

From the repository root:

```powershell
flutter pub get
flutter doctor
```

The checked-in client configuration targets package/bundle identifier
`com.intelligentglove.asl`. Confirm that the Firebase project permits the
platform and provider being tested.

### Android emulator

The default API URL already uses Android emulator host forwarding:

```powershell
flutter run -d <ANDROID_EMULATOR_ID> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

List device IDs with `flutter devices`.

### Physical Android device

Use a reachable HTTPS backend address:

```powershell
flutter run -d <ANDROID_DEVICE_ID> --dart-define=API_BASE_URL=https://<REACHABLE_API_HOST>/api/v1
```

The main Android manifest does not explicitly opt into arbitrary cleartext
HTTP. HTTPS is the documented safe physical-device path.

### Flutter web

Port `7358` is included in the backend example CORS list:

```powershell
flutter run -d chrome --web-port 7358 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Ensure the corresponding local domain is authorized in Firebase Auth.

### iOS

Run from macOS with a reachable backend URL:

```powershell
flutter run -d <IOS_DEVICE_OR_SIMULATOR_ID> --dart-define=API_BASE_URL=https://<REACHABLE_API_HOST>/api/v1
```

No local HTTP App Transport Security exception is present, so use HTTPS unless
you intentionally add platform-specific development configuration.

### User flow

1. Sign up with email/password.
2. Open the Firebase verification email and verify the account.
3. Return to the app and log in, or use an enabled Google provider.
4. Flutter calls `/api/v1/auth/sync` and uses refreshed Firebase bearer tokens
   for subsequent calls.
5. Register a backend device through the protected device API if the account
   has none. The current Flutter discovery UI lists already registered backend
   devices; it does not perform real BLE discovery.
6. Connect the registered device in the Devices UI and open Translation.
7. Start a session. Flutter receives translations in real time over a WebSocket
   connection opened at session start.
8. Until a BLE/sensor adapter exists, send translation text from the admin
   dashboard's "Live Translation" page or via `POST /api/v1/admin/translation/send`.
   The backend appends entries to the session JSON file; the watcher streams
   them over WebSocket to the app.

Flutter screen layouts remain mostly unchanged. The implementation focused on
repositories, services, controllers, authentication actions, unavailable/error
states, report submission, and the required translation status values.

## 10. Recommended Startup Order

The most functional current local topology is PostgreSQL and ML in Docker,
with the credential-aware backend and Vite dashboard running locally.

1. Configure root `.env`, `backend/.env`, and
   `admin_dashboard/.env.local`.
2. Place a compatible model in root `models/`.
3. Start PostgreSQL and ML:

   ```powershell
   docker compose up --build -d postgres ml
   ```

4. Apply the migration from `backend/` with `DATABASE_URL` exported:

   ```powershell
   Set-Location backend
   .\.venv\Scripts\Activate.ps1
   $env:DATABASE_URL='postgresql+psycopg://intelliglove:<URL_ENCODED_PASSWORD>@localhost:5432/intelliglove'
   alembic upgrade head
   ```

5. Start the backend in that terminal:

   ```powershell
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --env-file .env
   ```

6. In a second configured backend shell, seed the admin once:

   ```powershell
   Set-Location backend
   .\.venv\Scripts\Activate.ps1
   # Export DATABASE_URL, FIREBASE_PROJECT_ID, FIREBASE_CREDENTIALS_PATH,
   # ADMIN_EMAIL, ADMIN_PASSWORD, and optional ADMIN_NAME in this shell.
   python -m app.seed_admin
   ```

7. Start the admin dashboard:

   ```powershell
   Set-Location admin_dashboard
   npm run dev
   ```

8. Log in as the admin, scan/activate the model while the system is off,
   enable required services, then turn the system on.
9. Start Flutter with the platform-appropriate `API_BASE_URL`.

## 11. First-Time Setup Flow

1. Copy and edit all applicable examples:

   ```powershell
   Copy-Item .env.example .env
   Copy-Item backend\.env.example backend\.env
   Copy-Item python_ml_service\.env.example python_ml_service\.env
   Copy-Item admin_dashboard\.env.example admin_dashboard\.env.local
   ```

2. Use the same PostgreSQL password between root `.env` and backend
   `DATABASE_URL`, and the same ML key in root/backend/ML configuration.
3. Configure Firebase providers, domains, SHA fingerprints, and Admin
   credentials.
4. Put the real model in `models/`.
5. Start PostgreSQL and ML; apply the migration.
6. Run `python -m app.seed_admin` with the documented process variables.
7. Start the backend and dashboard, then log in as the seeded admin.
8. In **System & models**:
   - Keep or turn the master system **off**.
   - Select **Scan model folder**.
   - Confirm the model is `available`.
   - Activate it.
   - Turn the master system **on**.
9. In **Services**, ensure `translation` and any other desired features are
   enabled. New configuration defaults all documented service toggles to true,
   while the master system defaults to off.
10. Run Flutter, sign up, verify email, and log in.
11. If needed, create a registered device with the protected API, connect it in
    Flutter, and start a translation session.
12. Submit a sensor packet manually until the physical BLE adapter exists.

## 12. Mock Data / Seed Data

The dashboard **Demo data** page calls `POST /api/v1/admin/seed`.

Supported targets:

- `healthMonitor`
- `smartHouse`
- `analytics`
- `practiceMode`
- `translationHistory`

`count` may be 1–100. Omitting `userId` seeds the current admin; supplying a
SQL user UUID seeds that existing user. SOS is intentionally excluded.

Equivalent API payload:

```json
{
  "targets": ["healthMonitor", "smartHouse", "analytics"],
  "count": 10,
  "userId": "<OPTIONAL_EXISTING_SQL_USER_UUID>"
}
```

Verify seeded data through the corresponding Flutter screens/API endpoints or
the dashboard's inserted-record count. Seed operations also write an audit
record available at `GET /api/v1/admin/audit`.

## 13. Testing the System

### Backend

Backend tests truncate all application tables at suite startup. Use a separate
migrated PostgreSQL database through `TEST_DATABASE_URL`; otherwise the default
points to the development `intelliglove` database and destroys its data.

```powershell
Set-Location backend
.\.venv\Scripts\Activate.ps1
$env:TEST_DATABASE_URL='postgresql+psycopg://<TEST_USER>:<TEST_PASSWORD>@localhost:5432/<TEST_DATABASE>'
$env:DATABASE_URL=$env:TEST_DATABASE_URL
alembic upgrade head
python -m pytest -q
python -m compileall -q app alembic
```

### ML service

```powershell
Set-Location python_ml_service
python -m pip install -r requirements-dev.txt
python -m pytest -q
python -m compileall -q .
```

`requirements-dev.txt` pins the service runtime plus pytest/httpx test dependencies.

### Admin dashboard

```powershell
Set-Location admin_dashboard
npm install
npm test
npm run build
```

### Flutter

```powershell
Set-Location <REPOSITORY_ROOT>
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

### Current known test state

According to `tasks.md` and `progress_log.md`:

- Backend: 27/27 passed.
- ML: 4/4 passed.
- Admin: 2/2 passed; production build passed.
- Flutter: 71/71 passed; analyzer clean; Android debug APK built.
- Alembic downgrade/upgrade/drift checks passed.
- Docker images and startup health smokes passed.

There is no single committed live end-to-end runner. Backend translation tests
use injected Firebase and ML doubles. A live end-to-end test needs external
Firebase credentials, a valid model, and manual sensor submission.

## 14. API Smoke Tests

### Public health checks

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
Invoke-RestMethod http://127.0.0.1:8080/health
```

### Protected user checks

The repository does not provide a CLI token-minting helper. Obtain a current ID
token from a legitimately signed-in Firebase client; do not invent a token.

```powershell
$token = '<FIREBASE_ID_TOKEN>'
$userHeaders = @{ Authorization = "Bearer $token" }

Invoke-RestMethod `
  -Headers $userHeaders `
  http://127.0.0.1:8000/api/v1/me

Invoke-RestMethod `
  -Headers $userHeaders `
  http://127.0.0.1:8000/api/v1/service-status
```

If this is a new identity, synchronize it first:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Headers ($userHeaders + @{ 'Content-Type' = 'application/json' }) `
  -Body '{"name":"Local User"}' `
  http://127.0.0.1:8000/api/v1/auth/sync
```

### Register a local test device

```powershell
$deviceBody = @{
  deviceName = 'Local IntelliGlove'
  hardwareId = 'manual-local-device'
  connectionStatus = 'connected'
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Headers ($userHeaders + @{ 'Content-Type' = 'application/json' }) `
  -Body $deviceBody `
  http://127.0.0.1:8000/api/v1/devices
```

### Direct ML validation and prediction

These calls require a real relative model path:

```powershell
$mlHeaders = @{
  'X-Internal-API-Key' = '<ML_INTERNAL_API_KEY>'
  'Content-Type' = 'application/json'
}

Invoke-RestMethod `
  -Method Post `
  -Headers $mlHeaders `
  -Body '{"modelPath":"<MODEL_FILE>.joblib"}' `
  http://127.0.0.1:8080/validate

$prediction = @{
  modelPath = '<MODEL_FILE>.joblib'
  rawSensorData = @{
    flex1 = 0.1; flex2 = 0.2; flex3 = 0.3; flex4 = 0.4; flex5 = 0.5
    accelX = 0.6; accelY = 0.7; accelZ = 0.8
    gyroX = 0.9; gyroY = 1.0; gyroZ = 1.1
  }
} | ConvertTo-Json -Depth 4

Invoke-RestMethod `
  -Method Post `
  -Headers $mlHeaders `
  -Body $prediction `
  http://127.0.0.1:8080/predict
```

### Backend translation

The system must be on, translation enabled, a valid model active, and the
session owned/active:

```powershell
$translation = @{
  sessionId = '<ACTIVE_SESSION_ID>'
  languageCode = 'en-US'
  rawInput = @{
    flex1 = 0.1; flex2 = 0.2; flex3 = 0.3; flex4 = 0.4; flex5 = 0.5
    accelX = 0.6; accelY = 0.7; accelZ = 0.8
    gyroX = 0.9; gyroY = 1.0; gyroZ = 1.1
  }
} | ConvertTo-Json -Depth 4

Invoke-RestMethod `
  -Method Post `
  -Headers ($userHeaders + @{ 'Content-Type' = 'application/json' }) `
  -Body $translation `
  http://127.0.0.1:8000/api/v1/ml/translate
```

### Admin check

Use a Firebase ID token belonging to the seeded SQL/Firebase admin:

```powershell
$adminToken = '<ADMIN_FIREBASE_ID_TOKEN>'
Invoke-RestMethod `
  -Headers @{ Authorization = "Bearer $adminToken" } `
  http://127.0.0.1:8000/api/v1/admin/config
```

## 15. Troubleshooting

### Compose says a required variable is missing

Create the root `.env` and set both required values. Every Compose command,
including `docker compose ps`, parses those required variables.

### PostgreSQL is unavailable

```powershell
docker compose up -d postgres
docker compose ps
docker compose logs postgres
```

Confirm port 5432 is free and the root/backend passwords agree. Docker Desktop
was intermittently unavailable during final validation; restart it if its Linux
engine/named pipe disappears.

### Migrations fail authentication

- Export `DATABASE_URL` in the Alembic shell; Alembic does not load `.env`.
- URL-encode special password characters.
- Remember that changing root `.env` does not update an existing volume's
  database password.

### Backend fails during startup

- Confirm PostgreSQL is healthy and migrations are applied.
- Confirm `FIREBASE_CREDENTIALS_PATH` exists and is readable when supplied.
- Confirm `DATABASE_URL` begins with `postgresql://` or
  `postgresql+psycopg://`; SQLite is rejected.

### Firebase token is invalid or expired

Sign in again or force a Firebase token refresh. The Flutter API client retries
once with a refreshed token after HTTP 401. Confirm all clients and backend use
the same Firebase project.

### Email verification is required

Open the Firebase verification email, verify, then sign in again. The backend
defaults `REQUIRE_VERIFIED_EMAIL=true`.

### Admin receives `ADMIN_REQUIRED`

Run `python -m app.seed_admin` with the same Firebase project and email used to
log in. A Firebase account alone is insufficient; the SQL role and
`admin_users` record must also exist.

### Model scan marks the model invalid

- Confirm the same root model directory is visible to both backend and ML.
- Confirm the extension is `.joblib`.
- Confirm the estimator exposes `predict_proba` and `classes_`.
- Confirm backend and ML internal keys match.
- Review backend and ML logs.

### Model activation returns `SYSTEM_MUST_BE_OFF`

Turn the master system off, activate the model, then turn it on again.

### Backend cannot reach ML

- Local-to-local: `ML_SERVICE_URL=http://localhost:8080`.
- Docker backend-to-Docker ML: `ML_SERVICE_URL=http://ml:8080` is already in
  Compose.
- Confirm port 8080 is free and keys match.

### Flutter cannot reach FastAPI

- Android emulator: use `10.0.2.2`, not `localhost`.
- Flutter web/local admin: use `127.0.0.1` or `localhost` and match CORS.
- Physical device: use a reachable HTTPS hostname/IP, not the development
  machine's loopback address.

### Browser reports CORS errors

Add the exact browser origin to backend `CORS_ORIGINS` and restart FastAPI.
The examples include ports 5173 and 7358 only.

### Ports are already in use

The expected host ports are PostgreSQL 5432, backend 8000, ML 8080, admin 5173,
and the documented Flutter web port 7358. Stop the conflicting process or
change all dependent URLs and CORS entries consistently.

### Docker reports orphan containers

Final validation observed two pre-existing orphan containers. Inspect them
before removal; this repository does not require deleting user-owned containers
to run the current services.

## 16. Production Notes

- Store all secrets in a managed secret system; do not commit `.env`, Firebase
  Admin JSON, admin passwords, or model artifacts without explicit approval.
- Set `APP_ENV=production`; the backend then requires `ML_INTERNAL_API_KEY`.
- Use managed PostgreSQL with backups, point-in-time recovery, TLS, and tested
  migration/rollback procedures.
- Run FastAPI and ML behind TLS/private networking. The ML endpoint is an
  internal service and should not be publicly exposed.
- Build the admin dashboard with production `VITE_*` values. Development
  auto-login is disabled outside Vite development and must remain disabled.
- Replace the current Android release debug-signing configuration with a real
  production signing setup.
- Configure production CORS origins explicitly.
- Supply reviewed, versioned real model files and retain model/hash/audit
  records.
- Firebase client identifiers may be distributed to clients, but Firebase
  Admin credentials are private server secrets.
- Plan database backups before migrations or seed operations.
- SOS remains local-only; do not market or deploy it as emergency dispatch.

## 17. Current Known Limitations

- No trained production model is included.
- Physical BLE UUIDs and packet framing are unavailable; discovery currently
  lists registered backend devices rather than nearby hardware.
- Flutter has no live sensor-posting adapter. Translation sessions and polling
  work, but sensor packets must currently be posted manually.
- Firmware metadata checking exists; OTA installation is explicitly unsupported.
- Live Firebase provider acceptance depends on external console credentials,
  authorized domains, and Android SHA configuration.
- The current backend Compose service lacks Firebase credential injection.
- No single live end-to-end automation script is committed.
- Backend tests default to truncating the development database unless
  `TEST_DATABASE_URL` is overridden.
- iOS has no local HTTP ATS exception; use HTTPS or add deliberate development
  configuration.
- Android production signing is not configured.
- `npm install` reported one low-severity transitive advisory during final
  validation.
- Docker Desktop was intermittent during validation, although image builds,
  migration startup, and service HTTP smokes ultimately passed.
- SOS and emergency contacts remain local and do not contact responders.

## 18. Quick Start

This sequence assumes all environment files, Firebase console settings,
Firebase Admin credentials, Python/Node dependencies, and the model are already
configured.

### Terminal 1: PostgreSQL and ML

```powershell
Set-Location <REPOSITORY_ROOT>
docker compose up --build -d postgres ml
```

### Terminal 2: migrate and run backend

```powershell
Set-Location <REPOSITORY_ROOT>\backend
.\.venv\Scripts\Activate.ps1
$env:DATABASE_URL='postgresql+psycopg://intelliglove:<URL_ENCODED_PASSWORD>@localhost:5432/intelliglove'
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --env-file .env
```

### Terminal 3: admin dashboard

```powershell
Set-Location <REPOSITORY_ROOT>\admin_dashboard
npm run dev
```

### Terminal 4: Flutter Android emulator

```powershell
Set-Location <REPOSITORY_ROOT>
flutter pub get
flutter run -d <ANDROID_EMULATOR_ID> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Verify:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
Invoke-RestMethod http://127.0.0.1:8080/health
```

Then log in to `http://localhost:5173`, configure the model/system, and use the
Flutter first-time flow documented above.
