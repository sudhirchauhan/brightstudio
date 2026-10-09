#!/bin/sh
# Verify that the worker release does not expose an HTTP listener.
set -eu
RELEASE="${1:-./_build/prod/rel/bright_studio/bin/bright_studio}"
if [ ! -x "$RELEASE" ]; then
  echo "Release executable missing: $RELEASE" >&2
  exit 1
fi
PORT="${PORT:-19877}"
export PORT
BRIGHT_ROLE=worker "$RELEASE" foreground > /tmp/bright-worker-$$.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :; rm -f /tmp/bright-worker-$$.log' EXIT
sleep 3
if ! kill -0 "$pid" 2>/dev/null; then
  cat /tmp/bright-worker-$$.log >&2
  echo "FAIL: worker release exited" >&2
  exit 1
fi
if curl --silent --max-time 2 "http://127.0.0.1:$PORT/healthz" >/dev/null; then
  echo "FAIL: worker role exposed HTTP" >&2
  exit 1
fi
echo "PASS: worker running without HTTP listener"
