# Milestone 1 — UI-first walking skeleton

Status: Implementation and local acceptance completed on `milestone-1`; Render staging release acceptance remains pending access. See [acceptance evidence](milestone-1-acceptance.md) and [runbook](milestone-1-runbook.md).
Baseline: GitHub `sudhirchauhan/brightstudio`, branch `main`; Render workspace My Workspace. Work branch: `feat/m1-ui-first-walking-skeleton`.
Architecture: Erlang/OTP + Cowboy + PostgreSQL 17. No Django, Python application backend, Phoenix, or secondary application backend.

## Goal and boundaries
Ship an accessible Hub shell, Library, Add Source metadata dialog, and Reader placeholder, then connect the journey authenticated user → authorized project → source metadata creation → PostgreSQL persistence → reopen source. Fixture-backed UI is allowed during prototyping but must not claim persistence. No PDF extraction, AI, offline sync, full reader, legacy cutover, or production rollout in this milestone.

## Verified infrastructure (2026-10-09)
- GitHub repository: https://github.com/sudhirchauhan/brightstudio; default branch main.
- Render service: brightstudio-erlang-dev (`srv-db4aedjncjis73ccd260`), https://brightstudio-erlang-dev.onrender.com; Docker context `erlang`, Dockerfile `erlang/Dockerfile`, Frankfurt, Free, one instance, auto-deploy on main commit, no configured health-check path or preview deployments.
- Render PostgreSQL: brightstudio-erlang-dev-db (`dpg-db4ikk6i0phs73cqgvtg-a`), PostgreSQL 17, Frankfurt, available, Free, no managed connection pool/HA/replicas; expiration 2026-11-08.
- Latest observed live deploy: `dep-db4ie36gekts73fib5og`, commit `13ebd66db31ce0523f935a2dbcae6a757a6f2555`, completed 2026-10-09 17:41:59 UTC.
- Earlier commit `88e8f31` introduced a supervised Erlang SQL pool; reuse and test it rather than duplicating it.
- `erlang/apps/bright_web/src/bright_http.erl` registers /healthz, /readyz, /, /studio/, /studio/hub/. `bright_http_handler.erl` intentionally returns 404 for Hub; /readyz pings DATABASE_URL.
- Direct external SQL inspection was blocked by empty external IP allowlist; this does not prove private connectivity fails. Do not weaken database network access merely to inspect it.
- Render logs included shutdown reason `killed` for bright_http/Ranch; correlate with lifecycle events before classifying as a crash.

## Backlog, in delivery order
| ID | Priority | Work | Estimate | Acceptance |
|---|---|---|---|---|
| M1-01 | P0 | Inventory complete repo, migrations, SQL pool and environment contract | 0.5–1d | No duplicate modules or migrations; baseline documented |
| M1-02 | P0 | Extract responsive UI shell and shared accessible states | 1–2d | Desktop/mobile and keyboard navigation |
| M1-03 | P0 | Fixture-backed Hub, Library, Add Source dialog and Reader placeholder | 1–2d | Empty, loading, error, invalid-input and gated states |
| M1-04 | P0 | Verify existing SQL pool, private DATABASE_URL connectivity, migration replay | 1–2d | /readyz 200 with DB; controlled 503 without DB; migration safe |
| M1-05 | P0 | Authenticated sessions and owner/project authorization | 2–3d | Anonymous denied, cross-owner access denied |
| M1-06 | P0 | Metadata-only source create/list/read APIs and SQL schema | 1–2d | Idempotent 201 creation, durable record, no fake extraction |
| M1-07 | P0 | EUnit, integration, HTTP and Playwright acceptance tests | 1–2d | All acceptance scenarios pass |
| M1-08 | P0 | Render staging health check, release and smoke tests | 1d | Known SHA live, /healthz and /readyz green |
| M1-09 | P1 | Rollback, free database expiry and operational runbook | 0.5–1d | Documented and reviewed |

## File-level targets (reconcile with repository tree before creating)
- Existing: `erlang/apps/bright_web/src/bright_http.erl` — extend Cowboy routes.
- Existing: `erlang/apps/bright_web/src/bright_http_handler.erl` — preserve liveness/readiness; separate UI handlers.
- Proposed: `erlang/apps/bright_web/src/bright_hub_handler.erl` and `bright_source_handler.erl`.
- Proposed: `erlang/apps/bright_web/priv/static/hub.css`, `hub.js`.
- Proposed: `erlang/apps/bright_identity/src/bright_session.erl`, `erlang/apps/bright_projects/src/bright_project_auth.erl`, `erlang/apps/bright_studio/src/bright_source.erl`.
- Proposed: `erlang/apps/bright_platform/priv/migrations/<next-version>.sql` (select only after migration inventory).
- Existing: `erlang/Dockerfile`, `README.md`.
- Proposed: `tests/e2e/hub.spec.ts`, HTTP/domain integration tests and `docs/milestone-1-acceptance.md`.
- Reuse existing supervised SQL pool and locked migration runner; do not recreate them.

## HTTP contract
- GET /healthz: liveness independent of DB.
- GET /readyz: 200 only when required dependencies available; otherwise 503.
- GET /studio/hub/: authenticated, authorized shell.
- GET /studio/hub/library/: owner-scoped Library.
- GET /studio/hub/sources/:id: authorized Reader placeholder.
- GET /studio/api/hub/sources: owner-scoped list.
- POST /studio/api/hub/sources: validated, idempotent, metadata-only creation.
- Response expectations: 201 created; 400 malformed; 401 unauthenticated; 403 unauthorized operations; 404 for invisible source IDs; 409 idempotency conflict; 503 dependency unavailable.
- Preserve server authority for sessions, project permissions and writes. Prevent CSRF on session-authenticated writes; use secure cookies and appropriate cache headers.

## Release gates
1. Build: rebar3 compile, EUnit, reproducible OTP release.
2. Database: private connectivity, migration apply/replay, concurrent migration serialization.
3. Security: anonymous denied; owner A cannot enumerate or open owner B data; feature flags gate UI and API.
4. Data: repeated idempotency key has one logical result; successful write survives restart; failures never claim success.
5. UI: responsive, accessible keyboard navigation, empty/loading/error/validation states.
6. Render: deploy known commit SHA; /healthz 200, /readyz 200 with DB; browser smoke tests pass.
7. Rollback: prior compatible release can be redeployed without data loss.
8. No legacy production cutover.

## Commit sequence
1. docs(m1): baseline and acceptance
2. feat(web): introduce hub UI shell
3. test(platform): verify postgres integration
4. feat(identity): protect hub routes
5. feat(studio): persist source metadata
6. test(e2e): cover hub user journeys
7. build(render): harden staging release
8. docs(m1): release evidence and rollback

## Deployment safeguards
Render auto-deploys main. Work on feature branch, validate before merge; merging main triggers deployment. No direct production cutover. Database is Free and expires 2026-11-08; plan retention/upgrade before durable user data or production use. Do not publish secrets or open the external database allowlist. Configure Render health check to /healthz; retain /readyz as the dependency readiness gate.

## Open verification items
Full repository tree, exact SQL pool filename, highest migration version, actual DATABASE_URL binding, applied schema versions, private DB connectivity, current service behavior and shutdown-log explanation. Record evidence before closing gates.
