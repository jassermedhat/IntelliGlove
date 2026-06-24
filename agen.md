# IntelliGlove Agent Backlog

Use this file for work that should be built or fixed in a later pass.

## Fix later

- [ ] Replace hard-coded PostgreSQL URLs in
  `backend/tests/test_ingestion_watcher.py` and
  `backend/tests/test_database_foundation.py` with `TEST_DATABASE_URL` or a
  shared database fixture. The full backend suite currently fails when the
  local database password is not `intelliglove`.
- [ ] Fix the `SessionWatcher._run was never awaited` warning emitted by
  translation and device-session tests. Review watcher startup when tests run
  outside an active async event loop.
- [ ] Add Ruff to the documented development toolchain or remove the Ruff
  configuration if another formatter/linter is preferred.
- [ ] Remove the stale `admin_dashboard` Docker Compose orphan after confirming
  it is no longer needed. The active service is named `admin`.

## Build later

- [ ] Add a diagnostics section to the admin dashboard showing the effective
  API URL, browser origin, backend health, and CORS connectivity.
- [ ] Add an admin action to restore all service toggles to their defaults,
  with confirmation and an audit-log entry.
- [ ] Reduce repeated mobile polling after a service returns
  `SERVICE_DISABLED`; show the disabled state and retry with backoff.

## Current fix context

- Development and test environments accept loopback browser origins on any
  port. Production remains restricted to configured origins.
- The live `devices` service was found disabled in persisted admin
  configuration and must be enabled for `/api/v1/devices` to return data.
