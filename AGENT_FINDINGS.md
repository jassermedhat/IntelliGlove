# AGENT_FINDINGS.md

Investigation notes for the three requested work items. Scope: Flutter mobile app
(`lib/`, the "frontend"), FastAPI backend (`backend/`), and React admin dashboard
(`admin_dashboard/`). Work is sequential in this folder.

## How the pieces fit together

- **Frontend** = the Flutter app in `lib/`. Routing is `go_router` (`lib/app_routes.dart`,
  router built in `lib/main.dart`). State is plain `ChangeNotifier` controllers/providers
  exposed through `InheritedNotifier` "Scope" widgets.
- **Backend** = FastAPI. The app talks to it through `lib/services/backend_api_client.dart`
  (`BackendApiClient.instance`). Response envelope: `{ "data": ... }` on success;
  `{ code, message, details, requestId }` on error (`backend/app/errors.py`).
- **Admin dashboard** seeds demo data into Postgres; the mobile app reads the same DB
  through the backend.
- **Auth**: Firebase ID token in `Authorization: Bearer`. Dev bypass (`testing` / `1234`)
  maps to backend UID `development-testing-user` (verified to match the seed's testing user).

## Key frontend files (Flutter)

| Concern | File |
|---|---|
| Entry point / DI / router | `lib/main.dart` |
| Routes | `lib/app_routes.dart` |
| HTTP client | `lib/services/backend_api_client.dart` |
| Repositories (backend impls) | `lib/repositories/backend_repositories.dart` |
| Async-state widgets | `lib/components/app_async_state.dart` (`AppLoadingState`/`AppEmptyState`/`AppErrorState`) |
| Load-status enum | `lib/models/load_status.dart` |
| Service availability | `lib/services/service_availability_controller.dart` |

### Practice Mode
- Screen: `lib/screens/practice_mode_screen.dart`
- Controller: `lib/services/practice_controller.dart`
- Repo/model: `lib/repositories/practice_repository.dart`, `lib/models/practice_*.dart`

### History
- Screen: `lib/screens/translation_history_screen.dart`
- Controller (app-lifetime singleton): `lib/services/translation_controller.dart`
- Reads `GET /translations/history`

### Home / devices
- Home screen: `lib/screens/home_screen.dart` (glove status from `GloveStateScope`)
- Devices screen: `lib/screens/devices_screen.dart`
- Smart-home screen/provider: `lib/screens/smart_home_screen.dart`, `lib/services/smart_home_provider.dart`
- Glove state + pairing: `lib/services/glove_state_provider.dart`, `lib/services/pairing_controller.dart`
  (polls `GET /devices` every 4 s while logged in)

### Analytics
- Screen: `lib/screens/analytics_screen.dart` (Day/Week/Month PageView; fresh controller per visit)
- Controller: `lib/services/analytics_controller.dart` (`loadAll()` requests day+week+month)
- Reads `GET /analytics?range=day|week|month`

## Key backend / API files

| Concern | File |
|---|---|
| App factory / lifespan | `backend/app/main.py` |
| Error envelope + handlers | `backend/app/errors.py` |
| DB engine/session | `backend/app/database.py` |
| ORM models | `backend/app/models.py` |
| Feature reads (analytics, practice, smart-house, health) | `backend/app/feature_routes.py` |
| Devices / sessions / alerts | `backend/app/core_routes.py` |
| Translations / history | `backend/app/translation_routes.py` |
| **Demo data seed + demo-glove** | `backend/app/admin_seed_routes.py` |
| Service toggles | `backend/app/system_config.py` (all default **on**) |
| Dev auth bypass | `backend/app/development_auth.py` |

## Admin panel / demo-data files
- `admin_dashboard/src/pages/SeedTool.tsx` — "Push demo data" form (default target = **Mobile
  Demo Account**, `useTestingUser: true`) + separate "Connect demo glove" toggle.
- Seed targets: `healthMonitor`, `smartHouse`, `analytics`, `practiceMode`, `translationHistory`.
  **Devices/glove are NOT a seed target** — the glove is created only by the demo-glove toggle.

---

## Suspected root causes — Demo data not showing

1. **Analytics Day & Month empty — CONFIRMED root cause (backend).**
   `backend/app/admin_seed_routes.py` `_seed_target("analytics", …)` writes rows whose
   `metrics["range"]` is always **`"week"`** (lines ~203-232). The read endpoint
   `backend/app/feature_routes.py:189` selects the row with
   `metrics.get("range") == range_name`. So `range=day` and `range=month` match nothing →
   returns `EMPTY_ANALYTICS`. Week works, Day/Month don't — exactly the reported symptom.
   *Fix:* seed one row per range (day/week/month).

2. **History & Smart-home stale after seeding — root cause (frontend cache).**
   - History uses the **app-lifetime** `TranslationController` (created once in `main.dart`).
     The screen only loads when `historyStatus == LoadStatus.initial`
     (`translation_history_screen.dart:34`). Once it has loaded empty (before seeding),
     re-opening History never refetches → stays empty until app restart.
   - Smart-home: `SmartHomeProvider.load()` runs once at login (`main.dart`); the screen
     (`smart_home_screen.dart`) has no `initState`/refetch, so seeded devices never appear
     without a restart.
   *Fix:* refetch these on screen open.

3. **Practice** — refetches on every visit (fresh `PracticeController` in `initState`), and the
   read returns seeded signs (en-US `asl-hello`, active by default) + history + stats. It works
   after navigating in fresh. The likely user-visible problem was the **layout overflow** (Phase 2)
   and/or viewing the screen while it was already mounted during the seed. No data-layer bug found;
   refetch-on-nav already correct.

4. **Home "devices"** — the Home glove status auto-updates (pairing controller polls `/devices`
   every 4 s). But seeding does **not** create a device; the admin must use **"Connect demo glove"**
   in the Seed tool. Smart-home devices are covered by fix #2. (Documentation/UX gap, not a code bug
   for the glove path.)

Ruled out: user mismatch (dev UID `development-testing-user` matches the seed's testing user),
service toggles (all default on), `PracticeSign.active` (defaults `True`).

## Suspected root causes — Backend-down / frontend crash

- `lib/services/backend_api_client.dart` has **no request timeout**. On an unreachable (not
  refused) host a request can hang → infinite loading spinner.
- `lib/main.dart` `await`s `smartHomeProvider.load()`, `alertsController.load()`,
  `firmwareController.check()` before `runApp`. They catch internally (won't crash), but awaiting
  them blocks first paint on the network. `Firebase.initializeApp` is not guarded.
- Backend `errors.py` has a catch-all `Exception → 500`. A DB outage surfaces as a generic
  `500 SERVER_ERROR` rather than a clean `503`. The process does **not** crash (good), but the
  response code isn't "service unavailable".
- Good news: most screens already use `AppLoadingState/AppErrorState/AppEmptyState`, and the
  controllers already catch and expose error state. The shell itself is resilient once startup
  is non-blocking and requests time out.

## Suspected root cause — Practice Mode overflow (Phase 2)

`lib/screens/practice_mode_screen.dart:343-360` — the "Choose a sign" grid computes
`tileHeight = textScaler.scale(28) + scale(13) + scale(10) + 44` and feeds `tileWidth/tileHeight`
as `GridView.count(childAspectRatio:)`. It sums **font sizes** as if they were **line heights**;
the real rendered content (emoji line box + name + difficulty badge + paddings/gaps) is taller than
the fixed cell, so each tile overflows vertically (a few px at scale 1.0, worse with larger text
scale). `GridView` cells are fixed-extent, so content can't expand → "BOTTOM OVERFLOWED" stripes.
*Fix:* use a content-sized layout (`Wrap` of fixed-width tiles) so tiles size to their content at
any width / text scale. Note: `t1` (mentioned in the request) is only a parametric-angle local in
the auth-screen background painters — unrelated to Practice Mode.

## Testing / commands available

- Flutter (repo root): `flutter pub get`, `flutter analyze`, `flutter test`.
- Backend (`backend/`): `ruff check app/`, `python -m compileall -q app`,
  `python -m pytest -v --basetemp=.pytest_tmp` (needs Postgres + `TEST_DATABASE_URL`).
- Admin (`admin_dashboard/`): `npm test` (Vitest), `npm run build`.
- CI: `.github/workflows/ci.yml` (backend pytest+pip-audit, dashboard vitest+audit, flutter).

---

## PHASE 1 RESULT — Demo data now shows in the app

### Root causes
1. **Analytics (Day & Month empty):** the seed wrote only `metrics["range"]="week"`; the read
   endpoint matches `metrics["range"]` to the requested range, so Day/Month found no row.
2. **History & Smart-home stale:** both are served by app-lifetime singletons loaded once at
   login; the screens didn't refetch on re-entry, so data seeded afterwards never appeared.

### Files changed
- `backend/app/admin_seed_routes.py` — `analytics` seed now inserts one row per range
  (`day`/`week`/`month`) with realistic per-range data + shared `_ANALYTICS_TOP_GESTURES`;
  distinct `source` (`mock_seed_<range>`) keeps the `(user_id, date, source)` unique constraint
  happy and still matches the `mock_seed%` wipe filter.
- `lib/screens/translation_history_screen.dart` — refetch `loadHistory()` on every screen open
  (removed the `LoadStatus.initial` gate).
- `lib/screens/smart_home_screen.dart` — added `initState` post-frame `load()` so seeded
  devices appear on open.
- `backend/tests/test_admin_api.py` — new `test_analytics_seed_populates_day_week_and_month_ranges`.

### Data flow after the fix
Admin → `POST /admin/seed {useTestingUser:true}` → rows for `development-testing-user` →
mobile app (same dev UID) reads `GET /analytics?range=…` / `/translations/history` /
`/smart-house` and now gets the seeded rows. Analytics Day/Week/Month each resolve to their
own seeded row; History and Smart-home refetch on open.

### Practice & Home devices
- **Practice** already used a fresh controller per visit and the read returns seeded signs
  (en-US `asl-hello`, active) + history + stats — it shows data once navigated to fresh. No
  data-layer change needed (the visible issue was the Phase 2 overflow).
- **Home glove**: seeding does NOT create a device. Use the Seed tool's **"Connect demo glove"**
  toggle; the app's pairing controller polls `GET /devices` every 4 s and shows it automatically.

### Manual verification
1. Admin → Demo Data → keep **Mobile Demo Account** → check Analytics + Smart House +
   Translation History + Practice Mode → **Push demo data**. Optionally click **Connect demo glove**.
2. Mobile (`testing`/`1234`): Analytics → swipe Day/Week/Month → all show charts. Services →
   Translation → History → seeded letters appear. Services → Smart Home → seeded devices appear.
   Practice → signs + recent practice appear. Home → glove shows connected (within ~4 s).

### Migration/seed steps
None. Existing `mock_seed%` analytics rows from older seeds remain valid; re-running the seed
adds the missing `day`/`month` rows (idempotent per `(user, today, source)`).

## PHASE 2 RESULT — Practice Mode responsiveness

### Root cause
The "Choose a sign" grid set `GridView.count(childAspectRatio: tileWidth/tileHeight)` where
`tileHeight` summed **font sizes** (`scale(28)+scale(13)+scale(10)+44`) as if they were line
heights. Real line boxes + paddings exceed that fixed cell, so every tile overflowed vertically
(worse at larger text scale). A secondary latent issue: section-label `Row`s
("PRACTICE"/"CHOOSE A SIGN"/"RECENT PRACTICE") didn't wrap their `Text`, so they overflowed
horizontally at very large text scale / very narrow widths.

### Files / components changed
- `lib/screens/practice_mode_screen.dart`
  - Sign grid: `GridView.count` → `Wrap` of fixed-width tiles that size to their own content
    height (overflow-proof at any width / text scale). Width keeps the 2-col (<720) / 4-col
    (≥720) behaviour with a 0.5px rounding margin.
  - Section labels wrapped in `Flexible` + `maxLines:1` + ellipsis.
  - Added a test-only `controller` injection point (`@visibleForTesting`) so the screen can be
    pumped with deterministic data.
- `test/practice_mode_responsiveness_test.dart` — new: asserts no overflow at 320/375/768/1024/1440
  and at 2× text scale on 320px.

### Manual viewport test notes
`flutter test test/practice_mode_responsiveness_test.dart` → 6/6 pass (320, 375, 768, 1024, 1440,
and 320@2×). The grid reflows 2→4 columns at 720px and tiles never clip.

### Remaining risks
At extreme text scale the difficulty badge text can visually clip inside its pill (it does not
throw — `Text` clipping isn't a layout exception). Acceptable; real-device fonts are far narrower
than the test font that surfaced it.

## PHASE 3 RESULT — Resilience when backend / DB / services are unavailable

### Files changed
- `lib/services/backend_api_client.dart` — 15 s timeout on send + body read; `TimeoutException`
  and other socket errors map to the existing `NETWORK_ERROR` `BackendApiException`. Prevents
  indefinite hangs (infinite spinners).
- `lib/main.dart` — `Firebase.initializeApp` wrapped in try/catch (never blocks launch); the
  post-login `smartHomeProvider.load()` / `alertsController.load()` / `firmwareController.check()`
  are now fire-and-forget (`unawaited`) so first paint isn't blocked on the network.
- `backend/app/errors.py` — new `OperationalError` handler → controlled `503 SERVICE_UNAVAILABLE`
  (instead of a generic 500) when the DB is down.
- `backend/app/main.py` — lifespan DB connectivity check is now non-fatal (logs and continues),
  so a DB outage at startup no longer prevents the process from coming up; `pool_pre_ping`
  reconnects when the DB returns.

### Behaviour with backend down
- App shell launches normally (splash → onboarding/login/home). Theme, onboarding, biometric
  gate, SOS (local), profile appearance, FAQ/guide all work offline.
- Backend-dependent sections each show their own inline state: `AppLoadingState` →
  `AppErrorState`/`AppEmptyState` (already wired in Analytics, Practice, History, Smart-home,
  Alerts). No raw errors, no whole-page crash, no infinite spinner (15 s timeout).

### Behaviour with DB / API-dependent services failing
- DB down → backend returns `503 SERVICE_UNAVAILABLE`; the app surfaces it as an error state.
- A disabled service toggle still returns `503 SERVICE_DISABLED` (unchanged) → friendly message.

### Not fully covered (and why)
- Live-translation WebSocket already has its own bounded backoff reconnect (8 attempts) — left
  as-is.
- The backend startup now tolerates DB-down, but Alembic/migrations are still operator-run
  (by design). The `/health` endpoint reports static info and does not probe the DB (unchanged).

### Manual test notes
Stop the backend, launch the app → shell loads; Analytics/History/Smart-home show error/empty
states with Retry; non-backend screens work. Start the backend, retry → data loads.
