#!/bin/sh
set -eu
if [ "${BRIGHT_SQLITE_DEVELOPMENT:-false}" != "true" ]; then
  echo 'SQLite development startup requires BRIGHT_SQLITE_DEVELOPMENT=true.' >&2
  exit 1
fi
bin/bright_studio console_clean -noshell -eval 'bright_dev_bootstrap:main().'
exec bin/bright_studio foreground
