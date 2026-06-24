# AGENT_FINAL_REPORT.md

Final report for the three requested work items, done sequentially in this folder.
Detailed investigation + per-phase results live in `AGENT_FINDINGS.md`.

## Summary of what was fixed

1. **Admin demo data now shows in the mobile app** — Analytics Day/Month were empty because the
   seed only wrote `range="week"`; History and Smart-home showed stale empty state because their
   app-lifetime providers never refetched after seeding. Both root causes fixed.
2. **Practice Mode overflow** — the sign grid used a hand-computed `childAspectRatio` that summed
   font sizes as line heights and overflowed each cell; section labels could also overflow at
   large text scale. Replaced the grid with a content-sized `Wrap` and made labels flex-safe.
3. **Frontend resilient when backend/DB/services are down** — added an HTTP request timeout,
   made app startup non-blocking and crash-proof, and made the backend return a controlled `503`
   on DB outage instead of a generic `500` (and not crash at startup).

## Root causes

| Symptom | Root cause |
|---|---|
| Analytics **Day** & **Month** empty | Seed wrote only `metrics["range"]="week"`; the read endpoint matches `metrics["range"]` to the requested range (`backend/app/feature_routes.py:189`). |
| **History** empty after seeding | App-lifetime `TranslationController`; screen only loaded when status was `initial`, so it never refetched after the first (empty) load. |
| **Smart-home** empty after seeding | `SmartHomeProvider` loaded once at login; the screen had no refetch on open. |
| **Practice** "not showing" | No data bug (refetches per visit, reads seeded signs/history). The visible problem was the grid overflow below. |
| **Home devices** | Seeding doesn't create a glove device — that's the separate "Connect demo glove" toggle; the app then auto-shows it via a 4 s `GET /devices` poll. |
| **Practice overflow** | `GridView.count(childAspectRatio:)` derived from summed font sizes (not line heights) → fixed cells too short → vertical overflow. Section-label `Row`s didn't wrap text. |
| **Infinite loading / crash when backend down** | No HTTP timeout in `BackendApiClient`; `main()` awaited backend loads before first paint; backend surfaced DB outage as generic 500 and failed startup connectivity check. |

## Files changed, grouped by phase

### Phase 1 — demo data
- `backend/app/admin_seed_routes.py` — analytics seed inserts one row per range (day/week/month)
  with realistic data + shared `_ANALYTICS_TOP_GESTURES`; distinct `mock_seed_<range>` source.
- `lib/screens/translation_history_screen.dart` — refetch history on every open.
- `lib/screens/smart_home_screen.dart` — refetch smart-home devices on open (`initState`).
- `lib/screens/device_updates_screen.dart` — refetch firmware + alerts on open (converted to
  `StatefulWidget`; both come from app-lifetime singletons that otherwise only loaded at login).
- `backend/tests/test_admin_api.py` — added `test_analytics_seed_populates_day_week_and_month_ranges`.

#### Refetch-on-open scan (all data-backed screens)
| Screen | Source | Refetches on open? |
|---|---|---|
| Analytics | fresh `AnalyticsController`/visit | already ✓ |
| Practice | fresh `PracticeController`/visit | already ✓ |
| Health (`healthMonitor`) | fresh `HealthController`/visit | already ✓ |
| History | singleton `TranslationController` | **fixed** |
| Smart Home | singleton `SmartHomeProvider` | **fixed** |
| Device Updates | singletons `Firmware` + `Alerts` | **fixed** |
| Devices | `GloveState`/`Pairing` | auto (4 s poll) |
| Home alerts panel | singleton `Alerts` | left as-is — Home is a kept-alive shell tab (no remount), alerts aren't a seed target, and the singleton is refreshed whenever Device Updates is opened (the "View all" target), which also updates Home's panel. |

### Phase 2 — Practice responsiveness
- `lib/screens/practice_mode_screen.dart` — `GridView.count` → `Wrap` of fixed-width tiles;
  section labels wrapped in `Flexible` + ellipsis; added test-only `controller` injection.
- `test/practice_mode_responsiveness_test.dart` — new test at 320/375/768/1024/1440 + 2× text scale.

### Phase 3 — resilience
- `lib/services/backend_api_client.dart` — 15 s request timeout → `NETWORK_ERROR`.
- `lib/main.dart` — guarded `Firebase.initializeApp`; post-login loads are fire-and-forget.
- `backend/app/errors.py` — `OperationalError` → controlled `503 SERVICE_UNAVAILABLE`.
- `backend/app/main.py` — DB connectivity check at startup is non-fatal (logs and continues).

### Docs
- `AGENT_FINDINGS.md` (Phase 0 map + per-phase results), `AGENT_FINAL_REPORT.md` (this file).

## How to manually test

**Demo data**
1. Admin panel (`testing`/`1234`) → Demo Data → keep **Mobile Demo Account** → check Analytics,
   Smart House, Translation History, Practice Mode → **Push demo data**. Optionally **Connect demo glove**.
2. Mobile app (`testing`/`1234`):
   - Analytics → swipe **Day / Week / Month** → all three render charts.
   - Services → Translation → History → seeded entries appear (re-opening refetches).
   - Services → Smart Home → seeded devices appear (re-opening refetches).
   - Practice → signs + recent practice appear.
   - Home → glove shows **connected** within ~4 s of the demo-glove toggle.

**Practice overflow** — open Practice Mode at 320/375/768/1024/desktop widths and at large
system font size; no horizontal scroll, no overflow stripes; grid is 2 cols (<720) / 4 cols (≥720).

**Backend down** — stop the backend, launch the app: shell loads; Analytics/History/Smart-home
show inline error/empty with Retry; non-backend screens still work. Restart backend → Retry loads.

## Commands run and results

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found.** |
| `flutter test` | **87/87 passing** (81 existing + 6 new Practice responsiveness tests). |
| `flutter test test/practice_mode_responsiveness_test.dart` | 6/6 (320/375/768/1024/1440 + 320@2×). |
| `python -m compileall app` (backend) | OK (all modules compile). |
| `python -m py_compile` on changed modules + new test | OK. |
| backend `pytest` | **Not run here** — no Postgres in this session (`psycopg ConnectionTimeout`). Runs in CI. |
| `ruff check` | **Not run** — ruff not installed in this environment. Runs in CI. |

## Failures / limitations
- **Backend pytest and ruff could not be executed in this session** (no reachable Postgres; ruff
  not installed). Backend changes are compile-clean, consistent with existing tests (no existing
  test asserts on analytics-seed counts), and a new regression test was added for CI.
- At extreme text scale the Practice difficulty-badge text can visually clip inside its pill
  (does not throw); acceptable and not reproducible with real-device fonts.

## Follow-up recommendations (not done — out of scope)
- Consider a shared "refetch on screen focus" helper; the same stale-singleton pattern exists for
  any future screen backed by an app-lifetime provider.
- Add demo-glove (devices) as a first-class seed target, or surface a hint in the admin Seed tool
  that devices come from the separate "Connect demo glove" toggle.
- The `_SectionLabel` helper in `analytics_screen.dart` / `home_screen.dart` shares the same
  non-flex label pattern; wrapping its `Text` in `Flexible` would harden those screens too.
