#!/usr/bin/env bash
set -euo pipefail
# Use the existing isolated checkout. No additional Git worktree is needed.
docker start bright-m1-db bright-m1-dev >/dev/null
if ! docker exec bright-m1-dev _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then
  docker exec -d bright-m1-dev sh -c '_build/prod/rel/bright_studio/bin/bright_studio foreground > /tmp/bright-release.log 2>&1'
fi
for attempt in $(seq 1 40); do
  if curl --fail --silent --max-time 2 http://127.0.0.1:10000/readyz >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent --max-time 5 http://127.0.0.1:10000/healthz
curl --fail --silent --max-time 5 http://127.0.0.1:10000/readyz
