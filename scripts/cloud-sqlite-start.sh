#!/usr/bin/env bash
set -euo pipefail
# Existing local SQLite files are preserved; no PostgreSQL service is required.
docker start bright-sqlite-dev >/dev/null
if ! docker exec bright-sqlite-dev _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then
  docker exec -d -e DATABASE_URL=sqlite:/app/_build/bright-development.sqlite \
    -e STUDIO_HUB_ENABLED=true -e STUDIO_LIBRARY_ENABLED=true -e STUDIO_EVIDENCE_ENABLED=true \
    -e STUDIO_STUDY_ENABLED=true -e STUDIO_WEB_EXTRACTION_ENABLED=true -e BRIGHT_ORIGIN=http://127.0.0.1:10000 \
    -e BRIGHT_INSECURE_LOCAL_COOKIE=true bright-sqlite-dev \
    sh -c '_build/prod/rel/bright_studio/bin/bright_studio foreground > /tmp/bright-release.log 2>&1'
fi
for attempt in $(seq 1 40); do
  if curl --fail --silent --max-time 2 http://127.0.0.1:10000/readyz >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent --max-time 5 http://127.0.0.1:10000/healthz
curl --fail --silent --max-time 5 http://127.0.0.1:10000/readyz
docker exec bright-sqlite-dev _build/prod/rel/bright_studio/bin/bright_studio rpc erlang whereis '[bright_source_worker]'
