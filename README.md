# Bright Studio (Erlang/OTP)

Initial Erlang-only application foundation. No Django runtime. This is **not** a legacy parity implementation or production cutover.

Build: `cd erlang && rebar3 compile && rebar3 eunit && rebar3 as prod release`.

Docker: `docker build -f erlang/Dockerfile erlang`.

Endpoints: `/healthz` liveness, `/readyz` database readiness, `/studio/` baseline placeholder. Hub remains unavailable until owner authorization is implemented.

`BRIGHT_ROLE=web|worker` selects service role. `DATABASE_URL` is required for readiness. All new hub functionality is disabled by default.

Next: migration runner, SQL pool, full identity and authorization, and legacy behavior inventory. Do not route production traffic here.
