# Bright Studio (Erlang/OTP)

An Erlang/OTP + Cowboy + PostgreSQL development application. Milestone 1 implements an authenticated Learning Hub, owner-scoped Library, metadata-only Add Source dialog and Reader placeholder. No Django runtime, extraction, legacy cutover or production parity is claimed.

Build and tests:

```sh
cd erlang
rebar3 compile
rebar3 eunit
rebar3 as prod release
```

Use OTP 27 and rebar3 3.27. Dependencies are pinned in `rebar.lock`. PostgreSQL 17 acceptance tests additionally require a disposable DATABASE_URL and `BRIGHT_INTEGRATION_TESTS=true`.

For this cloud workspace, run `bash scripts/cloud-setup.sh` and `bash scripts/cloud-start.sh` from repository root. They use Docker and the existing checkout. See [acceptance evidence](docs/milestone-1-acceptance.md) for local fixtures, Playwright commands and full-release restart tests.

Docker: `docker build -f erlang/Dockerfile -t brightstudio:m1 erlang`. When a cloud proxy supplies a CA bundle, pass it using `--secret id=cloud_ca,src=/etc/ssl/certs/ca-certificates.crt`; TLS verification stays enabled.

`BRIGHT_ROLE=web|worker` selects role. `/healthz` reports liveness; `/readyz` reports DB readiness. Set `STUDIO_HUB_ENABLED=true` to enable protected Hub UI/API routes after migrations and secure account provisioning. Set `BRIGHT_ORIGIN` to the exact HTTPS origin. Cookies are secure by default; the explicit `BRIGHT_INSECURE_LOCAL_COOKIE=true` exception supports only `http://127.0.0.1:10000` and `http://localhost:10000`.

DATABASE_URL is required for readiness. Migrations run explicitly as a single reviewed job, never on web startup:

```sh
bin/bright_studio eval 'bright_migrate_cli:main().'
```

The migration runner uses a PostgreSQL advisory lock, numeric versions and transactions. Back up a real database before applying reviewed migrations. `sslmode=require` requires certificate- and hostname-verified TLS without plaintext fallback.

Render staging release remains pending access. [Staging and rollback runbook](docs/milestone-1-runbook.md) describes the private DB, health checks, account provisioning and expiry safeguards. Main auto-deploys the existing development service; do not merge until staging gates pass.
