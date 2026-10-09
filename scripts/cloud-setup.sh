#!/usr/bin/env bash
set -euo pipefail
# Existing cloud checkouts are isolated; use this checkout rather than making a worktree.
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
state_root="${BRIGHT_LOCAL_STATE_DIR:-/workspace/.brightstudio-local}"
mkdir -p "$state_root"
chmod 700 "$state_root"
for tool in docker node npm; do command -v "$tool" >/dev/null; done
node - "$state_root" <<'NODE'
const fs = require('node:fs'), crypto = require('node:crypto'), path = require('node:path');
const root = process.argv[2];
if(!fs.existsSync(path.join(root,'db.env'))) {
  const password = crypto.randomBytes(24).toString('hex');
  fs.writeFileSync(path.join(root,'db.env'),`POSTGRES_USER=bright\nPOSTGRES_DB=bright\nPOSTGRES_PASSWORD=${password}\n`,{mode:0o600,flag:'wx'});
  fs.writeFileSync(path.join(root,'app.env'),`DATABASE_URL=postgres://bright:${password}@bright-m1-db:5432/bright\nSTUDIO_HUB_ENABLED=true\nBRIGHT_ORIGIN=http://127.0.0.1:10000\nBRIGHT_INSECURE_LOCAL_COOKIE=true\n`,{mode:0o600,flag:'wx'});
}
if(!fs.existsSync(path.join(root,'app.env'))) throw new Error('Local app configuration missing; preserve db.env and repair the local configuration.');
NODE
docker network inspect bright-m1 >/dev/null 2>&1 || docker network create bright-m1 >/dev/null
if ! docker container inspect bright-m1-db >/dev/null 2>&1; then
  docker run -d --name bright-m1-db --network bright-m1 --env-file "$state_root/db.env" \
    -v bright-m1-db-data:/var/lib/postgresql/data \
    postgres:17@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3 >/dev/null
else
  docker start bright-m1-db >/dev/null
fi
if ! docker container inspect bright-m1-dev >/dev/null 2>&1; then
  docker run -d --name bright-m1-dev --network bright-m1 --env-file "$state_root/app.env" \
    -p 127.0.0.1:10000:10000 -v "$project_root/erlang:/app" -w /app --user 1000:1000 \
    erlang:27@sha256:3bcaa1d1d910da84b59b3cfd192adc2228fcd78937adefda029f8b3a1477b3f5 sleep infinity >/dev/null
else
  docker start bright-m1-dev >/dev/null
fi
if ! docker container inspect bright-m2-worker >/dev/null 2>&1; then
  docker run -d --name bright-m2-worker --network bright-m1 --env-file "$state_root/app.env" \
    -e BRIGHT_ROLE=worker -e STUDIO_LIBRARY_ENABLED=true \
    -v "$project_root/erlang:/app" -w /app --user 1000:1000 \
    erlang:27@sha256:3bcaa1d1d910da84b59b3cfd192adc2228fcd78937adefda029f8b3a1477b3f5 sleep infinity >/dev/null
else
  docker start bright-m2-worker >/dev/null
fi
# Domain lease tests run without a competing local extraction worker.
if docker exec -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then
  docker exec -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker _build/prod/rel/bright_studio/bin/bright_studio stop
fi
for runtime in bright-m1-dev bright-m2-worker; do
  docker exec --user 0 "$runtime" sh -c 'if ! command -v pdftotext >/dev/null; then apt-get update -qq && apt-get install -y --no-install-recommends poppler-utils; fi'
done
# Use the platform's public CA bundle through rebar3's documented trust setting.
docker cp /etc/ssl/certs/ca-certificates.crt bright-m1-dev:/tmp/bright-ca.crt >/dev/null
docker exec --user 0 bright-m1-dev sh -c 'mkdir -p /.config/rebar3; printf "{ssl_cacerts_path, \"/tmp/bright-ca.crt\"}.\n" > /.config/rebar3/rebar.config'
for attempt in $(seq 1 30); do
  if docker exec bright-m1-db pg_isready -U bright >/dev/null; then break; fi
  sleep 1
done
docker exec bright-m1-db pg_isready -U bright >/dev/null
# Build locally with retained dependency cache and verified lockfile hashes.
docker exec -e REBAR_CACHE_DIR=/app/_build/cache bright-m1-dev rebar3 compile
docker exec -e REBAR_CACHE_DIR=/app/_build/cache -e BRIGHT_INTEGRATION_TESTS=true bright-m1-dev rebar3 eunit
docker exec -e REBAR_CACHE_DIR=/app/_build/cache bright-m1-dev rebar3 as prod release
# Fixed acceptance credentials are only for this isolated development database.
docker exec -e BRIGHT_ACCEPTANCE_SEED=true bright-m1-dev escript scripts/seed_acceptance.escript
cd "$project_root"
npm ci --cache /workspace/.npm-cache
