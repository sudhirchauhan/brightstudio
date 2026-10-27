# Bright Studio (Erlang/OTP)

An Erlang/OTP + Cowboy application with SQLite development and PostgreSQL support. The Learning Hub includes private uploads, formatted PDF/EPUB reading, scanned-PDF OCR, revision-pinned annotations, Study, Focus, cited Documents, Studio AI, capture/audio, offline sync and account/session/membership controls. See [current implementation status](docs/implementation-status.md) for delivered scope and remaining product requirements. Production durability and cutover remain separate.

Build and tests:

```sh
cd erlang
rebar3 compile
rebar3 eunit
rebar3 as prod release
```

Use OTP 27 and rebar3 3.27. Dependencies are pinned in `rebar.lock`. PostgreSQL 17 acceptance tests additionally require a disposable DATABASE_URL and `BRIGHT_INTEGRATION_TESTS=true`.

For SQLite development in this cloud workspace, run `bash scripts/cloud-sqlite-setup.sh` and `bash scripts/cloud-sqlite-start.sh` from repository root. The original PostgreSQL setup/start helpers remain available for PostgreSQL regression checks. They use Docker and the existing checkout. See [Milestone 3 acceptance evidence](docs/milestone-3-acceptance.md) for local fixtures, Playwright commands and full-release restart tests.

Docker: `docker build -f erlang/Dockerfile -t brightstudio:m3 erlang`. When a cloud proxy supplies a CA bundle, pass it using `--secret id=cloud_ca,src=/etc/ssl/certs/ca-certificates.crt`; TLS verification stays enabled.

`BRIGHT_ROLE=web|worker` selects role. `/healthz` reports liveness; `/readyz` reports DB readiness. Set `STUDIO_HUB_ENABLED=true` to enable protected Hub UI/API routes after migrations and secure account provisioning. Enable `STUDIO_LIBRARY_ENABLED=true` on both web and worker to accept files and process extraction. Enable `STUDIO_EVIDENCE_ENABLED=true` on web for highlights, notes and project boards; it requires Hub and Library. Enable `STUDIO_STUDY_ENABLED=true` for quote-recall lessons, saved feedback/progress and a final reflection; it requires Hub and Library. Enable `STUDIO_WORKSPACE_ENABLED=true` for owned project/task management, a daily planner and account settings/password changes. All flags default off. Poppler (`pdftotext`/`pdftoppm`), Tesseract and `prlimit` are required for PDF OCR; setup and Docker include them. Originals are stored privately in the selected SQL backend (4 MiB per file, 64 MiB and 256 revisions per owner); extracted text is limited to 2 MiB. Reader offers extracted text, PDF.js pages and safe reflowable EPUB chapters, with private original downloads. English OCR handles up to 12 scanned pages per PDF, including mixed PDFs. See [Reader contracts and limits](docs/reader-ocr-runbook.md). Set `BRIGHT_ORIGIN` to the exact HTTPS origin. Cookies are secure by default; the explicit `BRIGHT_INSECURE_LOCAL_COOKIE=true` exception supports only `http://127.0.0.1:10000` and `http://localhost:10000`.

DATABASE_URL is required for readiness. Stop web/worker writers and run migrations explicitly in a separate release process, never through the running VM or racing web startup:

```sh
bin/bright_studio console_clean -noshell -eval 'bright_migrate_cli:main().'
```

The migration runner uses a PostgreSQL advisory lock, numeric versions and transactions. Back up a real database before applying reviewed migrations. `sslmode=require` requires certificate- and hostname-verified TLS without plaintext fallback.

Render staging remains a separate deployment gate; the runbook records current access and provisioning requirements. [Milestone 3 staging and rollback runbook](docs/milestone-3-runbook.md) describes the private DB, health checks, account provisioning and expiry safeguards. Main auto-deploys the existing development service; do not merge until staging gates pass.

For free staging, use `render-milestone-3-free.yaml`. It reuses `brightstudio-m1-staging`, requests free PostgreSQL, and sets `STUDIO_WEB_EXTRACTION_ENABLED=true` so extraction runs asynchronously inside the web service without a paid worker. The setting defaults off. Free web services can sleep, delaying queued extraction until they wake; free PostgreSQL expires and is intended for disposable testing.

SQLite development and the free Render demo are documented in [SQLite development](docs/sqlite-development.md). Use `render-milestone-3-sqlite.yaml` to run the complete demo without an external database or a paid worker. Hosted demo data is disposable.

See the [original roadmap and current status](docs/implementation-status.md) and [revised delivery plan](docs/revised-delivery-plan.md) for the remaining rewrite work and next Study milestone.

Study contracts, limits, validation and release instructions are in [Milestone 4](docs/milestone-4-plan.md).

Account/workspace/planner scope and checks are in [the current milestone](docs/workspace-planner-plan.md); [UI alignment with the original mocks](docs/ui-alignment-plan.md) is the next planned milestone.
