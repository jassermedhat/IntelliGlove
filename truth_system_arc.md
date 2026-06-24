# Glove-Based Sign Language Translation App — System Specification (Phase 2: Local-Only / No-Cloud)

**Status:** Active source of truth. Supersedes `glove_translation_app_full_specification.md` (Phase 1, cloud-based) for the current implementation phase.

**Scope of this phase:**
- No cloud hosting for our own infrastructure — the backend and database run **locally on a laptop/PC**.
- The ML model itself is **out of scope**. The only contract this system depends on is: *a JSON file containing the model's translated-text output gets produced, and the backend consumes it.*
- **Firebase Authentication is the one explicit exception** — it remains in use as the identity provider, since replacing it wasn't part of this phase's goal.

Phase 1 is preserved in **Appendix A** for historical reference. Every decision made in this phase is logged in **Appendix B**, in the same traceable format Phase 1 established — clearly marked as either your explicit decision or a proposed default still open for your confirmation.

---

## Table of Contents
0. [System Overview & Phase Scope](#0-system-overview--phase-scope)
1. [High-Level Architecture & Data Flow](#1-high-level-architecture--data-flow)
2. [Authentication Flow](#2-authentication-flow)
3. [App Pages & Features](#3-app-pages--features)
4. [Backend Services](#4-backend-services)
5. [Admin Dashboard](#5-admin-dashboard)
6. [Database Schema (PostgreSQL)](#6-database-schema-postgresql)
7. [JSON Output File Contract](#7-json-output-file-contract)
8. [Key API Surface](#8-key-api-surface-summary)
9. [Security Considerations](#9-security-considerations)
10. [Local Network Requirements](#10-local-network-requirements)
- [Appendix A — Phase 1 Decisions Log (historical)](#appendix-a--phase-1-decisions-log-historical)
- [Appendix B — Phase 2 Decisions Log (current)](#appendix-b--phase-2-decisions-log-current)

---

## 0. System Overview & Phase Scope

| Layer | Phase 1 (cloud, historical) | Phase 2 (current — local only) |
|---|---|---|
| Identity / Auth | Firebase Authentication | **Unchanged** — Firebase Authentication, kept as the sole cloud dependency |
| Application backend hosting | Cloud-hosted | **Local** — runs on a laptop/PC |
| Central application database | PostgreSQL (cloud-hosted) | PostgreSQL, **running locally** on the same laptop/PC |
| Custom backend stack | Python — FastAPI | Unchanged |
| ML model internals | Detailed two-half edge/cloud ML service | **Out of scope.** Only the JSON output file matters (§7) |
| Sensor → model → output pipeline | Local hardware gateway + edge inference | **Out of scope.** Whatever produces the JSON file is not this system's concern |
| Gateway ↔ backend connectivity | Direct HTTPS; gateway is its own authenticated client | **Replaced for now** by the backend reading per-session JSON files from local disk (§7). Devices table & pairing flow kept as a logical placeholder (§3.7) |
| Live delivery of translated text to app | WebSocket | Unchanged — WebSocket, now over the **local network** instead of the internet |
| Frontend (mobile) | Flutter app (phone), over the internet | Flutter app (phone), connects to the backend over the **local network (same WiFi)** |
| Admin dashboard | Web app, calling the cloud backend | Web app, calling the same **local** backend |
| Admin dashboard login | Manual login | Unchanged |
| Translation page live display | Full accumulated text builds up on screen | **Only the latest appended entry is shown live**; full accumulated text is available separately via History (§3.4) |

---

## 1. High-Level Architecture & Data Flow

```
┌──────────────────────────────┐
│  Translation Output Producer   │   Out of scope for this system.
│  ──────────────────────────    │   Phase 2 (now): the Admin Mock-Data
│  Phase 2: Admin Mock-Data tool │   tool (§5.6), or a manually-run
│  Phase 3+ (future): real glove │   test script writing in the same
│  + gateway + ML model           │   format.
└───────────────┬─────────────────┘
                │ appends entries to
                ▼
┌─────────────────────────────────────────┐
│  Local filesystem, same laptop/PC         │
│  as the backend:                          │
│  TRANSLATION_JSON_DIR/{session_id}.json   │
│  (one JSON file per session, an array;    │
│   each new translated entry is appended)  │
└───────────────┬───────────────────────────┘
                │ watched / polled
                ▼
┌───────────────────────────────────────────────┐
│                FastAPI Backend                   │  ◄── runs on the laptop/PC
│  - Verifies Firebase identity (ID token)          │
│  - Session management                             │
│  - Per-session JSON file ingestion watcher (§7)    │
│  - WebSocket hub (live relay, local network)       │
│  - Admin-only endpoints                            │
│  - Mock-data generation (writes JSON + ingests)     │
└───────┬────────────────────────┬────────────────────┘
        │ SQL (psycopg/SQLAlchemy) │  WebSocket + REST
        ▼                          │  (local network / same WiFi)
┌──────────────────┐               ▼
│   PostgreSQL        │   ┌──────────────────────┐
│   (same laptop/PC)   │   │   Flutter App (phone)  │
└──────────────────┘   └──────────────────────┘

┌────────────────────────┐
│     Firebase Auth         │  ◄── the one cloud dependency: reached
│     (cloud, internet)     │      over the internet, only for identity
└────────────────────────┘      (sign up / login / password reset /
                                  ID-token verification)

┌────────────────────────────────────┐
│       Admin Dashboard (Web)           │  Manual login → admin-scoped
│  Browser, same local network as the    │  session → REST calls to the
│  backend (could be the same laptop,    │  same local FastAPI backend
│  or another device on the same WiFi)   │
└────────────────────────────────────┘
```

**Why this shape:**
- The backend is the single source of truth and runs entirely on the local laptop/PC for this phase — no internet hosting for our own services.
- Translation data ingestion no longer relies on an authenticated HTTP push from a separate gateway device. Instead, the backend treats a **per-session JSON file on local disk** as the entire input contract — see §7. This is a direct consequence of your instruction that the model's internals aren't this system's concern: all this system needs to know is "a JSON file with translated text shows up, and gets used."
- WebSocket is still used between backend ↔ app, because the Translation page needs live updates the moment a new entry appears — now carried over the local network instead of the internet.
- Firebase Authentication is retained as a deliberate, explicit exception to "no cloud" — it's the identity provider, and replacing it wasn't part of this phase's goal.
- The Admin Dashboard and the Flutter app are both just local-network clients of the same backend, exactly as they were cloud clients of it in Phase 1 — only the network they sit on has changed.

---

## 2. Authentication Flow

Unchanged from Phase 1 — Firebase Authentication is still the identity source for both the app and the backend. The only difference is *where* the backend itself lives: the Firebase SDK calls below still go straight from the phone to Firebase's cloud servers over the internet (this is normal Firebase behavior, independent of our own hosting), while the token-exchange call to *our* backend (`POST /auth/session`) now resolves against the **local** backend over the local network instead of a cloud-hosted one.

| Screen | Backend Behavior |
|---|---|
| **Splash/Onboarding** | Static UI only, no backend. |
| **Sign Up** | `POST /auth/signup` → creates Firebase Auth account → Firebase UID becomes the `users.firebase_uid` primary key in Postgres → backend inserts a `users` row (name, email, created_at) → "Confirm Password" validated client-side before submission → Firebase sends verification email automatically on account creation. |
| **Login** | App calls Firebase Auth `signInWithEmailAndPassword` directly (Firebase already validates "email exists AND password correct" atomically — no separate existence check is exposed by Firebase's API, and exposing one would be a user-enumeration risk). On success, app exchanges the Firebase ID token with the **local** backend (`POST /auth/session`) to retrieve the matching Postgres `users` row. |
| **Sign in with Google** | (1) Google OAuth credential is properly exchanged for a Firebase credential via `signInWithCredential`, (2) the resulting Firebase UID matches/creates the same `users` row as email signup (no duplicate accounts per email), (3) login only completes after Firebase's own email-verification state is checked — Google accounts are inherently pre-verified by Google, so this passes through as "verified" automatically. |
| **Biometric Login** | **Still unresolved — see Appendix B.** Phase 1's recommendation (device-local biometric gating a securely stored refresh token) was never explicitly confirmed, and this round of clarification didn't revisit it either. Carried forward as open. |
| **Forgot Password** | `POST /auth/forgot-password` → backend (or app directly) calls Firebase's `sendPasswordResetEmail` — Firebase internally no-ops silently if the email doesn't exist (to avoid enumeration) — the new password fully replaces the old one in Firebase once confirmed. |
| **Admin Login** | *(See §5.1 — explicitly manual, not auto-login.)* |

---

## 3. App Pages & Features

Unless otherwise noted, every endpoint referenced below is now served by the **local** FastAPI backend on the laptop/PC, reached over the local network rather than the internet.

### 3.1 Home Page
- `GET /users/me` returns `name` → rendered as "Welcome back, **{name}**".
- `GET /devices?uid=...` returns the user's paired device(s) from the `devices` table (see schema, §6) — name, last-seen, connection status. For this phase, these are placeholder entries (§3.7) rather than real hardware.
- Sessions are pulled from `GET /sessions?uid=...`, each with `start_time`/`end_time`.
- The frontend remains the real-time source of truth for "is my device currently connected"; every successful pairing/heartbeat is also persisted via `PATCH /devices/{device_id}` (updates `last_seen`).

### 3.2 Services Page
- Health Monitor, Smart House, Analytics, and Practice Mode each have a dedicated read endpoint (e.g. `GET /health-monitor?uid=...`) backed by their own Postgres table.
- A seeding mechanism (shared with §5.6) populates these tables with mock rows for demo/testing — exposed both as a standalone script (`python scripts/seed_mock_data.py --target=health_monitor`) and as the admin dashboard's "Mock Data Push" button, which calls the same underlying seeding function via `POST /admin/mock-data/seed`.

### 3.3 SoS
- Stored exclusively in local Shared Preferences on-device. No backend endpoint exists for this feature at all — by design, for privacy. Unchanged.

### 3.4 Translation Page (Core Feature)

This is the centerpiece of the system. Full session lifecycle for this phase:

1. **Start tapped** → `POST /sessions/start {uid, device_id}` → backend inserts a `sessions` row (`status='active'`, `start_time=now()`), **creates that session's JSON output file** on local disk at `TRANSLATION_JSON_DIR/{session_id}.json` (initialized as an empty array `[]`), and returns `session_id`. The app also opens a WebSocket connection to the local backend: `ws://<backend-host>:<port>/ws/translation/{uid}`.
2. **Status cards update immediately:**
   - *Session* card → shows the returned `session_id`.
   - *History* card → starts at `0` (increments by 1 with each new appended entry).
   - *Confidence* card → repurposed to show **Active**.
3. **Whatever produces translations** — for now, the Admin Mock-Data tool (§5.6); later, a real ML model — **appends new entries to that exact JSON file** as they're recognized. Each entry is a small object: `{"text": "...", "timestamp": "..."}` (full contract in §7). The producer of this file is intentionally out of scope: this system's responsibility starts the moment a new entry appears in the file.
4. **Backend's ingestion watcher**, running per active session, detects newly appended entries in that session's JSON file (§7.5), and for each new entry: inserts a row into `translation_history` (tied to that `session_id`), then immediately pushes that entry over the open WebSocket for the matching `uid`.
5. **App on WebSocket message:** **replaces** the on-screen translated text with the newly received entry's text — it does **not** concatenate/build up a growing string on this screen — and increments the *History* card count by 1.
6. **Speak button** → on-device text-to-speech reads the currently displayed (latest) translated text. No backend call needed.
7. **Repeat button** → replays the last spoken text from the app's in-memory/cached state. No backend call needed.
8. **Stop tapped** → `POST /sessions/{session_id}/stop` → backend sets `end_time=now()`, `status='closed'` → the per-session ingestion watcher for that session is torn down → any entries in the JSON file that the watcher had not yet committed are persisted to `translation_history` in the same transaction → **the JSON file is deleted from disk** after the commit succeeds (the database rows are now the authoritative durable record) → WebSocket subscription for that session ends → *Active* card flips off.
9. **History view** → `GET /translation/history?uid=...` returns the full `translation_history`, joined with `sessions`, across **all** sessions (current + past). For each session, the frontend reconstructs the full accumulated text by concatenating that session's entries in timestamp order — this is the only place the *complete* sentence/text for a session is shown; the live Translation page itself only ever shows the single latest entry (step 5).
10. **Mock data support** → the admin dashboard's Mock-Data tool (§5.6) can generate one or more synthetic sessions, pre-populate their JSON files with fake entries, and run them through this exact same ingestion path — so mock sessions show up in History identically to real ones, and can even be pushed live into an active session for demoing the live page.

**Important interaction with the System On/Off master toggle (§5.2):** when the admin switches the system **off**, the backend's `/sessions/start` endpoint rejects new session creation, and the per-session ingestion watcher **stops processing** newly appended JSON entries (it pauses — nothing is lost from the file itself, it simply isn't read into the database while the system is off). The app disables the Start button client-side too. Users **can still** open the Translation page and browse past history via `/translation/history` — they just cannot begin a new live session.

### 3.5 Edit Profile
- `PATCH /users/me {name?, email?}` — backend updates **both** the Firebase Auth record (via Firebase Admin SDK) **and** the Postgres `users` row in a single transaction-like flow: update Firebase first, then Postgres; if Postgres fails, roll back the Firebase change to avoid the two stores diverging. Unchanged — the Firebase Admin SDK call works the same way from a local backend as a cloud one, provided the laptop has internet access.

### 3.6 Help & Feedback
- `POST /feedback {uid, type, message}` → inserts into `feedback_reports`, `type` constrained to `bug` or `feedback`, always linked to the submitting `uid`. Unchanged.

### 3.7 Device / Gateway Pairing (placeholder for this phase)
- The phone app, during initial setup, still sends `POST /devices/provision {device_name, uid}` to the backend, exactly as designed in Phase 1.
- The backend creates a `devices` row linking that `device_name`/`device_id` to the `uid` — this is required because `sessions.device_id` is a foreign key, so a session can't be started without at least one paired device existing.
- In Phase 1, this also returned a device-scoped credential for the gateway to authenticate its own `POST /translation/ingest` calls. **That part doesn't apply this phase**, since translation data now arrives via local JSON file ingestion (§7), not an authenticated HTTP push from a gateway. The provisioning step is kept purely to satisfy the schema/FK and to be ready for real hardware later — at that point, the original credential-issuing behavior can be reinstated with no other changes needed to the schema or API shape.

---

## 4. Backend Services

### 4.1 Database — PostgreSQL
Runs **locally** on the same laptop/PC as the FastAPI backend (e.g. a local Postgres install or container) rather than a managed cloud database. Connection points to `localhost`. Schema is unchanged from Phase 1 (§6) — chosen so that sessions, translation history, and user data can be modeled with proper foreign keys and relational integrity.

### 4.2 Bug/Feedback Intake Service
Thin FastAPI router (`/feedback`) backed by `feedback_reports`. Powers both §3.6 (user submission) and §5.3/§5.4 (admin viewing). Unchanged.

### 4.3 Translation Ingestion Service (formerly "ML Model Service")
Phase 1 described this as a service with two physical halves (edge inference + cloud registry). For this phase, model internals are explicitly out of scope, and the service collapses to **one half**, running entirely inside the FastAPI backend on the laptop/PC:

- **Per-session file watcher:** for every currently `active` session, periodically re-reads `TRANSLATION_JSON_DIR/{session_id}.json`, compares against the last-processed entry count for that session, and processes any new entries found — full mechanism in §7.5.
- **On each new entry:** inserts a `translation_history` row, then pushes it over the open WebSocket for that session's `uid`.
- **What this service explicitly does NOT do, this phase:** read sensor data, run any model, or care about model format/architecture. Whatever produces the JSON file (the admin mock tool now, a real model later) is entirely outside this service's responsibility.
- **Model registry** (`models` table, `GET /models`, active-model selection): retained structurally exactly as in Phase 1 (§5.5) for when a real model is wired in. Model files would be scanned from a **local** directory on the same laptop/PC rather than cloud storage; the mechanism itself (path + name, format-agnostic) is unchanged.

### 4.4 Additional Services
New services are added as additional FastAPI routers, each independently toggleable via the `service_toggles` table (§6). Unchanged from Phase 1.

---

## 5. Admin Dashboard

**Design direction:** modern, sleek UI (web app, separate from the Flutter mobile app, calling the same FastAPI backend with admin-scoped credentials) — now reached over the local network instead of the internet.

### 5.1 Admin Authentication — manual login
Unchanged from Phase 1: admin enters email + password → validated against Firebase Auth → backend checks the resulting Firebase UID against the `admin_users` table → only Firebase accounts present there are granted an admin-scoped session/JWT. The dashboard is opened in a browser on the same local network as the backend (e.g. directly on the laptop hosting the backend, or another device on the same WiFi pointed at the laptop's local IP).

### 5.2 System Control
- Master toggle, `admin_config.system_status` (`on`/`off`).
- **On:** the per-session ingestion watcher processes new JSON entries normally; `/sessions/start` is accepted.
- **Off:** `/sessions/start` is rejected; the ingestion watcher **pauses** (new JSON entries are not read into the database until the system is back on); the active model becomes changeable (§5.5).

### 5.3 Bug Reports Section
`GET /admin/feedback?type=bug` — lists all rows from `feedback_reports` where `type='bug'`. Unchanged.

### 5.4 Feedback / Reports Section
`GET /admin/feedback?type=feedback` — same table, filtered the other way. Unchanged.

### 5.5 Model Selection
- `GET /models` populates the dropdown (registry scan results, now from a local directory).
- `PATCH /admin_config {active_model_id}` — guarded server-side to only succeed while `system_status = 'off'`. Unchanged in mechanism.

### 5.6 Mock Data Push Tool
- Admin selects one or more targets via checkboxes (Health Monitor, Smart House, Translation, etc.), same as Phase 1.
- For the **Translation** target specifically: `POST /admin/mock-data/seed {targets: ["translation"], ...}` creates one or more synthetic `sessions` rows (tied to a designated placeholder/mock `device_id`), writes a fully pre-populated JSON file for each at `TRANSLATION_JSON_DIR/{session_id}.json` (with however many fake entries were requested), and runs that file through the **exact same ingestion path** described in §4.3/§7 — so the resulting `translation_history` rows are created identically to how real entries would be.
  - By default, mock sessions are created with `status='closed'`, so they appear immediately in `GET /translation/history` for demoing the History view.
  - If the admin instead targets an existing **active** session, appended mock entries are picked up live by that session's running watcher and pushed over WebSocket — i.e. the same mechanism doubles as a way to demo the live Translation page.
  - *(Flagged in Appendix B — confirm this two-mode behavior matches your intent.)*

### 5.7 Service Management
- `GET /admin/services` lists every toggleable feature (one row per `service_toggles` entry) with its current state.
- `PATCH /admin/services/{service_key} {is_enabled}` flips it.
- The Flutter app fetches this config on app start and on each navigation attempt to a toggleable page; if disabled, the app shows a toast ("This feature is currently unavailable") instead of opening the page. Unchanged.

---

## 6. Database Schema (PostgreSQL)

Unchanged structurally from Phase 1. Two inline notes added below to reflect current-phase semantics; everything else is identical.

```sql
-- Identity
users (
  firebase_uid   VARCHAR PRIMARY KEY,
  name           VARCHAR NOT NULL,
  email          VARCHAR UNIQUE NOT NULL,
  created_at     TIMESTAMPTZ DEFAULT now()
);

-- Gateway devices, one user can have multiple over time
-- Phase 2 note: real gateway hardware is not yet connected. At least one
-- placeholder/manually-provisioned row is expected per user so that
-- sessions.device_id has something to reference (see §3.7).
devices (
  device_id      UUID PRIMARY KEY,
  user_id        VARCHAR REFERENCES users(firebase_uid),
  device_name    VARCHAR NOT NULL,
  connected_at   TIMESTAMPTZ,
  last_seen      TIMESTAMPTZ
);

-- Translation sessions
sessions (
  session_id     UUID PRIMARY KEY,
  user_id        VARCHAR REFERENCES users(firebase_uid),
  device_id      UUID REFERENCES devices(device_id),
  start_time     TIMESTAMPTZ NOT NULL,
  end_time       TIMESTAMPTZ,
  status         VARCHAR CHECK (status IN ('active','closed'))
);

-- Per-entry translation events within a session
-- Phase 2 note: rows here are inserted by the backend's per-session JSON
-- file ingestion watcher (§7), not by an HTTP ingest call from a gateway.
translation_history (
  entry_id         BIGSERIAL PRIMARY KEY,
  session_id       UUID REFERENCES sessions(session_id),
  user_id          VARCHAR REFERENCES users(firebase_uid),
  timestamp        TIMESTAMPTZ NOT NULL,
  raw_input        JSONB,            -- optional snapshot of the sensor reading; unused/null this phase
  translated_text  VARCHAR NOT NULL
);

-- Secondary feature data (one table per feature; flexible JSONB payload
-- since exact metrics per feature aren't finalized yet)
health_monitor_data (
  id          BIGSERIAL PRIMARY KEY,
  user_id     VARCHAR REFERENCES users(firebase_uid),
  timestamp   TIMESTAMPTZ NOT NULL,
  payload     JSONB
);
-- smart_house_data, analytics_data, practice_mode_data: identical shape

feedback_reports (
  report_id   UUID PRIMARY KEY,
  user_id     VARCHAR REFERENCES users(firebase_uid),
  type        VARCHAR CHECK (type IN ('bug','feedback')),
  message     TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- ML model registry
models (
  model_id    UUID PRIMARY KEY,
  name        VARCHAR NOT NULL,
  file_path   VARCHAR NOT NULL,
  format      VARCHAR,              -- e.g. 'onnx', 'pt', 'pkl' — informational
  added_at    TIMESTAMPTZ DEFAULT now()
);

-- Single-row table holding global system state
admin_config (
  id               INT PRIMARY KEY DEFAULT 1,
  system_status    VARCHAR CHECK (system_status IN ('on','off')),
  active_model_id  UUID REFERENCES models(model_id),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  CHECK (id = 1)   -- enforce singleton
);

-- Per-feature on/off flags (replaces the embedded serviceToggles object)
service_toggles (
  service_key  VARCHAR PRIMARY KEY,   -- 'health_monitor', 'smart_house', 'translation', ...
  is_enabled   BOOLEAN DEFAULT true,
  updated_at   TIMESTAMPTZ DEFAULT now()
);

-- Admin accounts: maps a Firebase admin account to "is an admin"
admin_users (
  admin_id      UUID PRIMARY KEY,
  email         VARCHAR UNIQUE NOT NULL,
  firebase_uid  VARCHAR UNIQUE NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT now()
);
```

*(SoS data is intentionally absent — it never reaches the backend, per §3.3.)*

---

## 7. JSON Output File Contract

This is the one contract the entire translation pipeline depends on for this phase. Everything upstream of "a new entry appears in this file" — sensor hardware, the ML model itself, how confidence is computed — is explicitly out of scope, per your instruction.

### 7.1 File location & naming
- One JSON file **per session**.
- Path convention (proposed, configurable): `TRANSLATION_JSON_DIR/{session_id}.json` on the local filesystem of the machine running the backend.
- The directory path should be a backend config value (e.g. a `TRANSLATION_JSON_DIR` environment variable), not hardcoded, so it can be pointed at wherever the model (or the mock tool) is told to write.
- *(Flagged in Appendix B — exact path/convention is a proposed default.)*

### 7.2 File creation
- The **backend itself** creates the file (as an empty array `[]`) at the moment `POST /sessions/start` succeeds. This guarantees the file always exists before anything tries to append to it, avoiding race conditions between session creation and the first translation entry.

### 7.3 File structure
```json
[
  { "text": "H", "timestamp": "2026-06-21T10:15:03.120Z" },
  { "text": "HE", "timestamp": "2026-06-21T10:15:04.900Z" },
  { "text": "HEL", "timestamp": "2026-06-21T10:15:06.310Z" }
]
```
- `text` (string, required) — the recognized translated text for that entry. Whether each entry represents a single letter, a word, or a running partial string is determined entirely by whatever writes the file; this system treats each array entry as one discrete "translation event" and stores/displays it as-is, without interpreting it.
- `timestamp` (ISO 8601 string, required) — when that entry was recognized.
- `session_id` and `uid` are **not** required inside each entry — they're implied by which file it is (the filename) and that session's row in the `sessions` table.
- *(Flagged in Appendix B — this schema is a proposed default.)*

### 7.4 How new entries are written
- The producer (the admin mock tool, now; a real model, later) **appends** new objects to the end of the array. The file is never reset or cleared mid-session — it only grows.

### 7.5 How the backend detects new entries
- For every currently `active` session, the backend's ingestion watcher polls that session's JSON file on a short interval (proposed default: ~1 second, configurable) and tracks how many entries it has already processed for that session.
- On each poll, if the array's length has grown, every entry past the last-processed index is treated as new: each is inserted into `translation_history`, and the **most recent of the newly-found entries** is pushed over the WebSocket (so the live display always reflects the latest state even if several entries land between polls).
- *(Flagged in Appendix B — polling vs. filesystem-watch, e.g. via Python's `watchdog`, is an implementation choice. Polling is proposed here for simplicity on a single local machine.)*

### 7.6 Lifecycle
- Watching starts when a session becomes `active` (`POST /sessions/start`) and stops when it becomes `closed` (`POST /sessions/{id}/stop`), or pauses while the system is switched off (§5.2).
- At session stop, the backend persists any entries that the watcher had not yet committed (i.e. entries appended to the JSON file between the last watcher poll and the stop call) into `translation_history` before returning the closed-session response. The JSON file is then **deleted** from disk after the database transaction commits successfully — the authoritative record is the database rows, not the file. If the commit fails the file is preserved so the entries are not lost.

---

## 8. Key API Surface (summary)

| Method & Path | Purpose |
|---|---|
| `POST /auth/signup` | Create Firebase account + Postgres user row |
| `POST /auth/session` | Exchange Firebase ID token for a backend session (now issued by the local backend) |
| `POST /auth/forgot-password` | Trigger Firebase reset email |
| `GET /users/me` | Fetch profile |
| `PATCH /users/me` | Update name/email in Firebase + Postgres |
| `GET /devices?uid=` | List paired devices (placeholder, for now) |
| `POST /devices/provision` | Pair/register a device (real or placeholder) to a user |
| `PATCH /devices/{id}` | Heartbeat / last-seen update |
| `POST /sessions/start` | Begin a translation session — also creates that session's JSON output file (§7.2) |
| `POST /sessions/{id}/stop` | End a session — also tears down its ingestion watcher |
| `POST /translation/ingest` *(not used this phase)* | Reserved for a future phase with real hardware pushing over HTTPS. Translation data currently arrives via the per-session JSON file + ingestion watcher (§7) instead. |
| `GET /translation/history?uid=` | Full history, all sessions |
| `WS /ws/translation/{uid}` | Live relay of new translations to the app, over the local network |
| `GET /health-monitor`, `/smart-house`, `/analytics`, `/practice-mode` | Per-feature data |
| `POST /feedback` | Submit bug/feedback |
| `POST /admin/login` | Admin manual login |
| `GET/PATCH /admin_config` | System on/off, active model |
| `GET /models` | Model registry scan results (now scanning a local directory) |
| `GET /admin/feedback?type=` | Bug or feedback list |
| `POST /admin/mock-data/seed` | Seed mock data for selected targets — for `translation`, also writes a real per-session JSON file and runs it through the normal ingestion path (§5.6) |
| `GET/PATCH /admin/services` | Service toggle management |

---

## 9. Security Considerations

- **Translation data trust model:** no HTTP-authenticated gateway client exists yet in this phase — translation data arrives via local file ingestion (§7), which trusts anything writing to the configured local directory on the same machine. Once real hardware is introduced, this should be revisited (e.g. reinstating a device-scoped credential per §3.7).
- **Admin separation:** `admin_users` is a strict allow-list — being a valid Firebase user is necessary but not sufficient for admin access. Unchanged.
- **System-off guard:** enforced server-side on `/sessions/start`, and on the per-session ingestion watcher (which pauses while the system is off), and on `PATCH /admin_config.active_model_id` (only while off).
- **Profile updates:** Firebase updated before Postgres, with rollback on partial failure, to keep the two stores from silently diverging (§3.5). Unchanged.
- **SoS data:** never has a network path to the backend at all — enforced by simply never building one. Unchanged.
- **Biometric login:** still unresolved — see §2 and Appendix B.
- **Local network exposure (new this phase):** the backend binds to a local network interface (not just `127.0.0.1`) so the phone can reach it over WiFi. This means anyone on the same WiFi network can reach the backend's API surface during this phase. Since there's no cloud/internet exposure, this is a smaller attack surface than Phase 1 — but trusted-WiFi-only should be assumed (no port-forwarding the backend to the public internet) until a network-hardening pass happens for a future hosted phase.
- **Firebase remains internet-dependent:** sign up, login, password reset, and ID-token verification all still need outbound connectivity to Firebase's servers even though the rest of the system is fully local.

---

## 10. Local Network Requirements

- Phone and laptop/PC must be on the **same local network** (e.g. same WiFi) for the app to reach the backend.
- Backend should run on a fixed, known local IP/port (e.g. `192.168.x.x:8000`) that the app is configured to point at — there's no DNS/domain resolution like a cloud deployment would have.
- WebSocket URL changes from `wss://` (TLS) in Phase 1 to plain `ws://<local-ip>:<port>/ws/translation/{uid}` for this phase; TLS isn't required for local-network-only testing but could be added later.
- The Admin Dashboard is reached the same way — pointing a browser at that same local IP/port.

---

## Appendix A — Phase 1 Decisions Log (historical)

*Preserved unchanged from the original Phase 1 specification, for historical reference. This no longer reflects the current implementation plan — see Appendix B for what changed in Phase 2.*

| Topic | Original Spec | Resolution | Source |
|---|---|---|---|
| Central database | "Firebase + custom services," unspecified | PostgreSQL | Your decision |
| Custom backend stack | Unspecified | Python / FastAPI | Your decision |
| Sensor data → model | "JSON file" mentioned, transport unspecified | A local hardware gateway writes the JSON file directly; model reads it continuously | Your decision |
| Where the ML model runs | Unspecified | Locally, on the gateway device (edge inference) | Your decision |
| Gateway → cloud connectivity | Not addressed | Direct connection (gateway is its own authenticated client) | My recommendation, since you deferred — rationale in §1 |
| Translated text → app delivery | Not addressed | WebSocket | My recommendation, since you deferred — rationale in §1 |
| Admin dashboard login | Spec called for automatic/instant login, no manual step | Manual login required | Your decision — explicit override of the original spec |
| System OFF → user's Translation page | Not addressed | Can still view history; cannot start a new session | Your decision |
| Biometric login approach | Spec asked for a researched recommendation | Device-local biometric + securely stored token | My recommendation — flagged for your confirmation, not yet explicitly approved by you |
| Model file format | "A folder/storage location," format unspecified | Left format-agnostic; registry stores path + name only | Reasonable default, not blocking — revisit if you want a single standardized format |

---

## Appendix B — Phase 2 Decisions Log (current)

| Topic | Phase 1 (original) | Phase 2 Resolution | Source |
|---|---|---|---|
| Cloud usage | All infra cloud-hosted | Backend (FastAPI) + Database (PostgreSQL) run locally on a laptop/PC; no cloud hosting for our own services | Your decision |
| Authentication provider | Firebase Authentication | Unchanged — kept as the one explicit exception to "no cloud" | Your decision |
| ML model architecture/internals | Detailed two-half edge/cloud ML service | Out of scope entirely. System only consumes a JSON file containing the model's translated-text output | Your decision |
| Translation data ingestion mechanism | Gateway pushes via `POST /translation/ingest` (HTTPS) | Replaced by backend reading per-session JSON files from local disk (§7); HTTP ingest endpoint not used this phase | Derived directly from your decision — flagged for confirmation |
| JSON output structure | Not previously defined this way | One JSON file per session; new entries appended over time as a growing array | Your decision |
| JSON file location/naming, creation responsibility, entry schema, polling interval | Not specified | Proposed defaults — see §7.1–7.5 | My proposal — flagged for your confirmation |
| Live Translation page display | Full accumulated text builds up on screen | Only the single latest appended entry is shown live; full text only available via History | Your decision |
| Device/gateway concept | Full hardware pairing + devices table | Kept exactly as designed, treated as a logical placeholder until real hardware exists | Your decision |
| Admin Mock-Data tool for Translation | Generic "seed sample rows," no mechanism detail | Mock data is written as a real per-session JSON file and run through the same ingestion path as real output, landing in `sessions` + `translation_history` identically to genuine entries; supports both historical (closed-session) demo data and live injection into an active session | My proposal, following from your instruction — flagged for your confirmation |
| System-off guard | Blocked `/sessions/start` and `/translation/ingest` | Blocks `/sessions/start` and pauses the per-session ingestion watcher (since the ingest endpoint isn't used this phase) | Derived directly from your decision — flagged for confirmation |
| Local network requirements (fixed IP/port, same WiFi, plain `ws://` instead of `wss://`) | Not applicable (cloud, domain-based) | New requirement for this phase — see §10 | My proposal — flagged for your confirmation |
| Biometric login approach | Flagged for confirmation, never explicitly approved | **Still unresolved** — carried forward unchanged, not addressed in this round of clarification | Carried over from Phase 1 — still open |
| Model file format/storage | Format-agnostic registry, path unspecified | Unchanged in mechanism; files now scanned from a local directory instead of cloud storage | Your decision (cloud→local) + Phase 1 default (format-agnostic) carried forward |

If anything in this log doesn't match what you intended — including any item marked "flagged for your confirmation" above — flag it and I'll revise the relevant section.
