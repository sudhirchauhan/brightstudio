# Milestone 1 acceptance and release evidence

Status: implementation and local acceptance complete; Render staging release gate pending access.
Baseline: `13ebd66` on main, with the existing UI plan/prototype from `53e955e`.
Working branch: `milestone-1`. Main has not been merged or deployed.

## Delivered behavior

- Erlang/OTP is the sole backend. Reuses `bright_sql_pool` and the advisory-locked explicit migration runner.
- Responsive Hub/Library, project selector and current account, searchable cards, keyboard-accessible Add Source dialog, metadata-only Reader.
- Empty, loading, malformed-input, dependency-error and disabled-feature states. Browser text is rendered with `textContent`; original links accept only HTTP(S). No fabricated extraction or study outcome.
- Password login for explicitly provisioned accounts, PBKDF2-HMAC-SHA256 (600,000 iterations), random opaque eight-hour sessions stored as SHA-256 hashes. Logout revokes the session in SQL; expiry and disabled accounts are rejected.
- Secure/HttpOnly/SameSite=Strict cookies by default. Plain HTTP cookies require an explicit switch and one of the two exact loopback origins. Login requires configured same-origin requests and has a bounded per-IP attempt limit. Cookie writes require same-origin and a session-specific CSRF token.
- Owner-scoped projects and sources, including invisible cross-owner source IDs returning 404. Creation validates metadata and returns 201 only after PostgreSQL commits. Unique owner/idempotency keys serialize concurrent retries; changed payload returns 409.
- All Hub routes and assets are disabled unless `STUDIO_HUB_ENABLED=true`. Other planned features remain unavailable.
- /healthz is liveness. /readyz requires DB connectivity; with Hub enabled it also requires configured origin and migrations 2–7.
- epgsql upgraded from 4.7.0 to 4.8.0: the older version sent malformed startup packets under OTP 27 using direct `port_command`; 4.8 uses `gen_tcp:send`.
- Connection failures are isolated from their caller, and the pool removes terminated connections without losing its capacity.
- `sslmode=require` uses required TLS, CA verification and hostname verification; a server refusing TLS cannot downgrade the connection to plaintext.

## Local evidence (2026-10-09)

| Gate | Evidence | Outcome |
| --- | --- | --- |
| OTP build | OTP 27; rebar3 3.27; lockfile with Hex checksums | Passed |
| Erlang/domain/SQL | 24 EUnit tests with `BRIGHT_INTEGRATION_TESTS=true` | Passed |
| SQL migrations | apply, replay, simultaneous runners and explicit advisory-lock blocking | Passed, local PostgreSQL 17 |
| SQL pool | bounded exhaustion, unauthorized check-in, connection pool restart and recovery after connection death | Passed |
| Sessions | valid, revoked, expired, disabled-owner and full release restart | Passed locally |
| HTTP security | anonymous 401; cross-owner read 404 and project access/write 403; missing/wrong-origin CSRF 403 | Passed |
| Data | concurrent identical keys return one source; changed metadata 409; source survives full release restart | Passed |
| Browser | 8 Playwright cases across 1280×800 desktop and 390×844 mobile; real login/create/reopen plus controlled empty/error responses | Passed using system Chromium |
| Feature gates | login, UI, assets and API all return 404 when disabled | Passed |
| Dependency failure | no DATABASE_URL: liveness 200, readiness/write 503 | Passed |
| Worker role | live release responds to ping with no HTTP listener | Passed |
| Docker | pinned OTP image, lockfile, compile/EUnit/release, non-root runtime | Passed locally; no Render deployment implied |
| Render | known new SHA, private DB connectivity, migration state, staged browser smoke | Pending credentials and staged release |

Docker build runs 23 tests without the opt-in SQL test. The 24-test local integration run includes that test. Mocked browser responses validate presentation states; real API tests and SQL tests validate persistence and authorization. No GitHub-hosted CI execution or Render deployment is claimed by local checks.

## Reproduce in this cloud checkout

Use the existing checkout; cloud tasks are already isolated and need no Git worktree.

```sh
cd /workspace/brightstudio
bash scripts/cloud-setup.sh
bash scripts/cloud-start.sh
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium npm run test:e2e
BRIGHT_TEST_DOCKER_CONTAINER=bright-m1-dev node tests/release-checks.js
```

Setup uses Docker PostgreSQL 17 and OTP 27. Cloud proxy CA trust is configured using the supplied system CA bundle, without disabling verification. Local DB passwords are generated under `/workspace/.brightstudio-local` with restricted permissions and never saved into repository files. Application processes must restart after environment restoration. Docker volume restoration in a new task has not been verified; run setup again if infrastructure is absent. Dependencies and release files are under ignored `erlang/_build`.

The isolated acceptance accounts are `owner-a@example.test` / `Milestone-test-password-A` and `owner-b@example.test` / `Milestone-test-password-B`. They are public test fixtures, not staging or production credentials. Never run the acceptance seeder against a real user database. Its explicit `BRIGHT_ACCEPTANCE_SEED=true` switch is required and reruns preserve existing accounts.

For a native installation: run compile/EUnit/release from `erlang`; set a disposable PostgreSQL DATABASE_URL for the opt-in SQL suite; seed disposable accounts, start the release, then run browser and release checks from repository root. CI encodes this workflow with a PostgreSQL service.

## Remaining scope and limits

- Render access is not injected here and no Render connector is available. `RENDER_API_KEY` has been declared in cloud environment settings for secure entry, scoped to `api.render.com`; no key value has been requested in chat or saved in source.
- Complete staging steps in [the runbook](milestone-1-runbook.md), including secure account provisioning and known-SHA health/readiness/browser checks. A main merge remains a separate release decision because it auto-deploys.
- Local PostgreSQL proves the implementation, not connectivity to Render's private database. Do not open the database's external IP allowlist.
- Library lists at most the latest 200 metadata records per selected project. Pagination, source uploads/extraction, full Reader, legacy account migration/recovery and all later roadmap slices are outside this milestone.
- Per-IP login limiting is local to a web instance and resets on restart; this milestone does not claim production account parity or production abuse resistance.
- Prior application images can roll back while retaining additive schema/data. Re-enabling old images may retain the old driver connectivity defect. Backup restoration is not a substitute for schema-compatible rollback of acknowledged writes.
