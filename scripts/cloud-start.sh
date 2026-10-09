#!/usr/bin/env bash
set -euo pipefail
# Use the existing isolated checkout. No additional Git worktree is needed.
docker start bright-m1-db bright-m1-dev bright-m2-worker >/dev/null
if ! docker exec bright-m1-dev _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then
  docker exec -d -e STUDIO_LIBRARY_ENABLED="${STUDIO_LIBRARY_ENABLED:-true}" bright-m1-dev sh -c '_build/prod/rel/bright_studio/bin/bright_studio foreground > /tmp/bright-release.log 2>&1'
fi
for attempt in $(seq 1 40); do
  if curl --fail --silent --max-time 2 http://127.0.0.1:10000/readyz >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent --max-time 5 http://127.0.0.1:10000/healthz
curl --fail --silent --max-time 5 http://127.0.0.1:10000/readyz

if ! docker exec -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then
  docker exec -d -e STUDIO_LIBRARY_ENABLED="${STUDIO_LIBRARY_ENABLED:-true}" -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker sh -c '_build/prod/rel/bright_studio/bin/bright_studio foreground > /tmp/bright-worker.log 2>&1'
fi
for attempt in $(seq 1 20); do
  if docker exec -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker _build/prod/rel/bright_studio/bin/bright_studio ping >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec -e VMARGS_PATH=/app/config/worker.vm.args bright-m2-worker _build/prod/rel/bright_studio/bin/bright_studio ping
