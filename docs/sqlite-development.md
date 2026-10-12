# SQLite development and free UI demo

SQLite is supported for development through `DATABASE_URL=sqlite:/absolute/path/to/database.sqlite`. PostgreSQL remains the production backend; its migrations, TLS validation and database data are unchanged. The application backend is still Erlang/OTP.

## Cloud development

From `/workspace/brightstudio`, run `bash scripts/cloud-sqlite-setup.sh`, then `bash scripts/cloud-sqlite-start.sh`. Setup builds the pinned esqlite NIF with verified Hex checksums, runs integration checks against a fresh disposable SQLite file, prepares the OTP release, migrates the local development file and provisions local-only acceptance fixtures. It preserves existing SQLite and PostgreSQL data. Startup runs asynchronous extraction inside the web VM; no PostgreSQL service or separate worker is needed.

The local file is `/workspace/brightstudio/erlang/_build/bright-development.sqlite`. Preserve the file and its `-wal`/`-shm` siblings. Use SQLite's online backup API or stop all writers before copying database files; copying only the live main file can omit acknowledged writes. The database file mode is 0600, foreign keys are enabled, WAL is used, and synchronous writes use FULL. Do not commit database files or move local fixture credentials into public staging.

Validation:

```sh
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium npm run test:e2e
```

Integration EUnit runs through the setup helper. The shared integration tests cover sessions, foreign keys, migration serialization, owner isolation, extraction leases, immutable revisions, note conflicts, provenance and connection recovery. PostgreSQL and SQLite use the same domain operations through `bright_sql`; SQLite translates the application's bounded SQL dialect, binds user data, and calculates anchor SHA-256 in Erlang. SQLite migrations have independent files with versions 1–18. Backend switching does not transfer existing records between databases.

## Free Render demo

`render-milestone-3-sqlite.yaml` describes the existing free `brightstudio-m1-staging` web service with no external database, disk or paid worker. Set its Docker command to `/app/bin/start-sqlite-dev`, `DATABASE_URL=sqlite:/tmp/brightstudio/development.sqlite`, and `BRIGHT_SQLITE_DEVELOPMENT=true`. Set the HTTPS origin to the service URL, enable Hub/Library/Evidence and web extraction, and configure a private bootstrap email, a securely generated password, and project title in Render's Environment settings. Never use public local acceptance credentials.

The explicit development startup initializes/migrates SQLite and provisions the bootstrap account when absent before starting the HTTP server. Initialization failures exit nonzero without logging secrets. This is an opt-in development exception; PostgreSQL releases do not gain automatic startup migrations. Existing accounts and passwords are not overwritten on replay. Keep the private bootstrap environment settings available to recreate the account when the disposable instance is replaced.

Render free services have no persistent disk. SQLite data can disappear on restart, redeploy or instance replacement; use disposable test documents and keep copies. The UI displays this limitation. Local SQLite data survives Erlang process restarts on the retained workspace filesystem. Neither case establishes production durability. Render `/readyz` checks database connectivity and all enabled schema versions. A successful deploy with `/readyz` as its health check establishes readiness, not full hosted browser acceptance.

Sign in at `/studio/login/`; the bootstrap password can be viewed securely by the Render workspace owner in that service's Environment settings. Do not publish the password in source, logs or chat. Main and the original main-linked service remain unchanged.

## Samples after a free-instance reset

`BRIGHT_DEV_SEED_DATA=true` enables the bundled sample dataset during the opt-in SQLite development initialization. It supplies seven sources (TXT, PDF, EPUB, Unicode, two immutable revisions, an empty Reader and a deliberately damaged PDF), seven evidence items, two populated boards and note history in the private bootstrap account. A per-owner/version completion marker makes startup replay a no-op, preserving subsequent user edits. When Render replaces the disposable database, bootstrap recreates the private account and these samples before readiness succeeds. This restores sample data, not the user's own lost documents or edits. The option is restricted to SQLite development and does not run for PostgreSQL releases.

Milestone 4 adds Study (`STUDIO_STUDY_ENABLED=true`) to the default cloud helpers and the free-demo Blueprint. Migrations 16–18 persist revision-bound passes, attempts, replay receipts and start receipts. Open Study from navigation or use “Study this revision” in the Reader. Existing seeded ready sources support the lesson journey without an external provider.
