# Milestone 1 staging and rollback runbook

## Staging prerequisites

Use a separate staging service as described by `render.yaml`; keep auto-deploy off. Main remains linked to the existing development service and must not be merged as part of a staging experiment. The Blueprint has not been applied.

Record the full commit SHA, Render deploy ID, service URL, DB identifier, applied versions and test results. Configure /healthz as the Render health-check path. Gate rollout on /readyz independently.

Set DATABASE_URL to Render's private database URL on a same-region web service. Set BRIGHT_ORIGIN to the exact HTTPS origin without a trailing slash. Do not set BRIGHT_INSECURE_LOCAL_COOKIE on staging. Leave STUDIO_HUB_ENABLED=false until migrations and accounts are prepared. Keep later feature flags disabled.

Existing plan records the Free PostgreSQL database expiration as **2026-11-08**. Verify this in Render, arrange an upgrade/retention plan before storing durable user data, and export/restore-test a backup before expiry. Do not infer current infrastructure health from the old plan record.

## Explicit migration and enablement

1. Review all migration files and take a verified database backup using the private connection from an authorized service/job. Reuse existing schema versions 1–4; new versions 5–7 add projects, credentials and sources. Existing source rows are never dropped.
2. From the new release's private execution context, run the single migration job:

   ```sh
   bin/bright_studio eval 'bright_migrate_cli:main().'
   ```

   Require exit 0. Replay once and confirm versions 1–7. The same advisory lock serializes parallel jobs. Migration is never run on web boot. Local concurrency tests are evidence for the runner, not for the staged database.
3. Provision a staging account and project through `bright_session:provision/3`. The repository's `erlang/scripts/provision.escript` demonstrates operator-only provisioning from securely injected BRIGHT_BOOTSTRAP_EMAIL, BRIGHT_BOOTSTRAP_PASSWORD (12–1024 bytes), and BRIGHT_BOOTSTRAP_PROJECT variables; run it from the source checkout's `erlang` directory with release libraries present. For a deployed release, call the same function through release eval reading those variables internally. Never put the password in CLI arguments, source, logs or chat. Remove bootstrap variables after provisioning. This is not legacy user import, public signup or password recovery.
4. Enable STUDIO_HUB_ENABLED=true, restart the web service, and require /healthz 200 and /readyz 200. Check the deployed SHA matches the reviewed commit.
5. Use separate securely provisioned staging accounts for the two-owner test. Exercise login, project selector, source create/list/open, same-key retry, conflict, cross-owner denial, logout, keyboard/mobile states and restart durability. Do not provision the public local acceptance credentials in staging. The scripted tests' fixture addresses/passwords are deliberately local-only; adapt a staging harness to securely supplied accounts.
6. Inspect redacted startup/deployment logs. Correlate any Ranch shutdown with deploy/restart timestamps rather than assuming every shutdown is a crash.

## Rollback

- Disable STUDIO_HUB_ENABLED to stop new Hub access while retaining data. Keep DB backups private.
- Redeploy the last reviewed schema-compatible Erlang image/SHA. This schema is additive; do not run down migrations or drop metadata, sessions or account tables. Verify liveness/readiness and the previously supported routes.
- Treat returning to pre-milestone builds as a disabled-Hub fallback, not a claim that Hub workflows remain available. The old epgsql version may fail under OTP 27; prefer a reviewed compatible release containing the driver correction.
- Do not restore a stale DB snapshot over acknowledged new writes. If emergency restore is needed, stop writers, preserve the current DB and reconcile post-backup writes before routing traffic.
- No legacy production cutover or routing change is included. A main merge requires its own release decision after staging gates pass.

## Troubleshooting

- 404 on every Hub route: feature is disabled.
- 401: no valid session, expired/revoked session, or disabled account.
- 403: wrong owner/project, missing CSRF, or request origin differs from BRIGHT_ORIGIN.
- 409: the same owner/idempotency key was reused with different metadata.
- 503 readiness: inspect origin configuration, DB access and migration versions. Never log DATABASE_URL. No public DB allowlist change is needed for a same-region private service.
- 429 login: wait five minutes; local per-IP rate limiter is exhausted.
- TLS error: use the authoritative CA chain and supported trust configuration. Do not disable verification or allow required TLS to fall back to plaintext.
