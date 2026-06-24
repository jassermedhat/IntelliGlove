# IntelliGlove API Contract

Base prefix: `/api/v1`. Private endpoints require
`Authorization: Bearer <Firebase ID token>`. The backend maps the verified
`firebase_uid` to one PostgreSQL user and never trusts a mobile-supplied user
identifier.

Successful responses use `{"data": ...}`. Errors include `code`, a safe
`message`, optional validation `details`, and `requestId`. Disabled features
return `503 SERVICE_DISABLED` with `This feature is currently unavailable.`

## Identity

| Method | Path | Purpose |
|---|---|---|
| POST | `/auth/sync` | Create/update the UID-linked SQL profile; allowed before email verification |
| GET | `/me` | Read the verified current profile |
| PATCH | `/me` | Update name/photo and recently reauthenticated email |

Password signup/login, Google sign-in, reset email, and verification email are
performed with Firebase SDKs. Password-account access requires a verified
email. Email changes reset verification and require a refreshed ID token.

## User data

| Area | Endpoints |
|---|---|
| Devices | `GET/POST /devices`, `GET/PATCH/DELETE /devices/{id}`, `POST /devices/auto-connect` |
| Sessions | `POST /sessions/start`, `POST /sessions/{sessionId}/stop`, `GET /sessions`, `GET /sessions/{sessionId}` |
| Translation | `POST /ml/translate`, `POST/GET/DELETE /translations`, `GET /translations/current-session/{sessionId}`, `GET /translations/history` |
| Health | `GET /health-monitor` |
| Smart house | `GET/POST /smart-house`, `PATCH/DELETE /smart-house/{id}` |
| Analytics | `GET /analytics?range=day|week|month` |
| Practice | `GET /practice-mode`, `POST /practice-mode/results` |
| Supporting | `GET/PATCH /alerts`, `GET /firmware/devices/{id}`, `POST /reports`, `GET /service-status` |

`POST /ml/translate` accepts an owned active `sessionId`, `languageCode`, and
`rawInput` containing finite numeric `flex1`–`flex5`, `accelX`–`accelZ`, and
`gyroX`–`gyroZ`. A successful call invokes the configured active model and
atomically stores the translation, confidence, model, raw JSON, and source.

Device `connectionStatus` accepts `disconnected`, `scanning`, `connecting`,
`connected`, or `error`. The `devices`, `firmware`, and `translation` service
toggles are enforced by their supporting routes as well as by mobile preflight.

## Administration

Admin endpoints require both a verified Firebase identity and SQL admin role:

- `GET /admin/config`
- `PATCH /admin/config/system-status`
- `PATCH /admin/config/service-toggles`
- `GET /admin/models`
- `POST /admin/models/scan`
- `PATCH /admin/models/{modelId}/activate`
- `GET /admin/reports/bugs`
- `GET /admin/reports/feedback`
- `PATCH /admin/reports/{reportId}`
- `POST /admin/seed`
- `GET /admin/audit`

The active model can change only while the system is off. Seed targets are
allowlisted to health, smart house, analytics, practice, and translation
history. SOS is deliberately not accepted.

## ML internal contract

The ML service is not called directly by Flutter. FastAPI calls `POST /predict`
with `X-Internal-API-Key`, a contained relative `modelPath`, and
`rawSensorData`. It returns `translatedText`, `gestureLabel`, `confidence`, and
`modelPath`. Missing/invalid models and inference errors fail closed; there is
no production dummy classifier.
