# Bright Studio (Erlang/OTP)

Initial Erlang-only application foundation. No Django runtime. This is **not** a legacy parity implementation or production cutover.

Build: `cd erlang && rebar3 compile && rebar3 eunit && rebar3 as prod release`.

Docker: `docker build -f erlang/Dockerfile erlang`.

Endpoints: `/healthz` liveness, `/readyz` database readiness, `/studio/` baseline placeholder. Hub remains unavailable until owner authorization is implemented.

`BRIGHT_ROLE=web|worker` selects service role. `DATABASE_URL` is required for readiness. All new hub functionality is disabled by default.

Next: migration runner, SQL pool, full identity and authorization, and legacy behavior inventory. Do not route production traffic here.

## Database migration (explicit, never on web boot)

Set `DATABASE_URL` in the release environment, then run `bin/bright_studio eval 'bright_migrate:run().'` as a **single migration job** before starting web/worker replicas. The migration runner uses a PostgreSQL advisory lock, records applied numeric versions, and runs each migration in a transaction. It does not provision a database or migrate legacy user data. Never run this command against production without backup and reviewed migration scripts.

The development Render web service intentionally has no database provisioned; `/readyz` responds 503 until a database is configured and reachable. `/healthz` reports only liveness.
