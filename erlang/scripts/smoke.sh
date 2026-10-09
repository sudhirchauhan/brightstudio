#!/bin/sh
# Smoke-check a running Bright Studio development release.
set -eu
BASE="${1:-http://127.0.0.1:10000}"
BASE="${BASE%/}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
check() {
  path="$1"; expected="$2"
  code="$(curl --silent --show-error --max-time 15 -o "$tmp/body" -w '%{http_code}' "$BASE$path")"
  if [ "$code" != "$expected" ]; then
    echo "FAIL $path: expected $expected, got $code" >&2
    cat "$tmp/body" >&2
    exit 1
  fi
  echo "PASS $path ($code)"
}
check /healthz 200
check / 200
check /studio/ 200
check /studio/hub/ 404
check /studio/api/hub/ 404
# Readiness is intentionally 503 without a configured database.
# With DATABASE_URL provisioned, require 200 explicitly using REQUIRE_DB=1.
if [ "${REQUIRE_DB:-0}" = 1 ]; then
  check /readyz 200
else
  code="$(curl --silent --show-error --max-time 15 -o "$tmp/body" -w '%{http_code}' "$BASE/readyz")"
  case "$code" in 200|503) echo "PASS /readyz ($code; database optional)" ;; *) echo "FAIL /readyz ($code)" >&2; exit 1;; esac
fi
echo "Development smoke checks passed."
