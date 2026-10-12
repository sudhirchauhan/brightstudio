#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
for tool in docker node npm python3; do command -v "$tool" >/dev/null; done
# Switching local profiles stops owned legacy containers, preserving files/volumes.
for legacy in bright-m1-dev bright-m2-worker; do
  if docker container inspect "$legacy" >/dev/null 2>&1; then docker stop "$legacy" >/dev/null; fi
done
if ! docker container inspect bright-sqlite-dev >/dev/null 2>&1; then
  docker run -d --name bright-sqlite-dev --user 1000:1000 -w /app \
    -p 127.0.0.1:10000:10000 -v "$project_root/erlang:/app" \
    -e DATABASE_URL=sqlite:/app/_build/bright-development.sqlite \
    -e STUDIO_HUB_ENABLED=true -e STUDIO_LIBRARY_ENABLED=true -e STUDIO_EVIDENCE_ENABLED=true \
    -e STUDIO_WEB_EXTRACTION_ENABLED=true -e BRIGHT_ORIGIN=http://127.0.0.1:10000 \
    -e BRIGHT_INSECURE_LOCAL_COOKIE=true \
    erlang:27@sha256:3bcaa1d1d910da84b59b3cfd192adc2228fcd78937adefda029f8b3a1477b3f5 sleep infinity >/dev/null
else
  docker start bright-sqlite-dev >/dev/null
fi
if docker exec bright-sqlite-dev _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then
  docker exec bright-sqlite-dev _build/prod/rel/bright_studio/bin/bright_studio stop
fi
if docker container inspect bright-m2-worker >/dev/null 2>&1 && docker exec -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then
  docker exec -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker _build/prod/rel/bright_studio/bin/bright_studio stop
fi
docker exec --user 0 bright-sqlite-dev sh -c 'if ! command -v pdftotext >/dev/null; then apt-get update -qq && apt-get install -y --no-install-recommends poppler-utils; fi'
docker cp /etc/ssl/certs/ca-certificates.crt bright-sqlite-dev:/tmp/bright-ca.crt >/dev/null
docker exec --user 0 bright-sqlite-dev sh -c 'mkdir -p /.config/rebar3; printf "{ssl_cacerts_path, \"/tmp/bright-ca.crt\"}.\n" > /.config/rebar3/rebar.config'
# Preserve the cloud proxy route and TLS verification when compiling in Docker.
python3 - <<'PY'
import os,socket,subprocess,urllib.parse,time
keys=[k for k in ['HTTPS_PROXY','https_proxy','HTTP_PROXY','http_proxy','NO_PROXY','no_proxy'] if k in os.environ]
hosts={urllib.parse.urlparse(os.environ[k]).hostname for k in keys if k.lower() in ['https_proxy','http_proxy']}
for host in hosts:
    if host:
        ip=socket.gethostbyname(host)
        subprocess.run(['docker','exec','--user','0','-i','bright-sqlite-dev','sh','-c','cat >> /etc/hosts'],input=(ip+' '+host+'\n').encode(),check=True)
common=['docker','exec','-e','REBAR_CACHE_DIR=/app/_build/cache']
for key in keys:common+=['-e',key+'='+os.environ[key]]
subprocess.run(common+['bright-sqlite-dev','rebar3','compile'],check=True)
# SQL tests use a new disposable file, never the user's development database.
subprocess.run(common+['-e','BRIGHT_INTEGRATION_TESTS=true','-e','DATABASE_URL=sqlite:/app/_build/sqlite-validation-'+str(time.time_ns())+'.db','bright-sqlite-dev','rebar3','eunit'],check=True)
subprocess.run(common+['bright-sqlite-dev','rebar3','as','prod','release'],check=True)
PY
# Public fixture passwords are only for this local cloud acceptance database.
docker exec -e DATABASE_URL=sqlite:/app/_build/bright-development.sqlite -e BRIGHT_ACCEPTANCE_SEED=true bright-sqlite-dev escript scripts/seed_acceptance.escript
cd "$project_root"
npm ci --cache /workspace/.npm-cache
