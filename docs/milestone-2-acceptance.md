# Milestone 2 acceptance evidence

Status: implementation and local acceptance complete; Render staging remains pending access. Branch: milestone-2, based on milestone-1 at 096213c. Main is unchanged.

## Delivered behavior

Private TXT, PDF and EPUB originals are committed in PostgreSQL with SHA-256 checksums, immutable revision numbers and an extraction queue. Owner-scoped sessions authorize history, content, upload, retry and downloads; writes retain same-origin/CSRF checks. Upload retries use an owner-scoped idempotency key and return the same revision; changed requests conflict. Limits are 4 MiB per original, 2 MiB extracted text, and 64 MiB/256 revisions per owner. Quota and numbering are serialized with an owner row lock.

The supervised worker claims SQL leases with SKIP LOCKED. Expired leases can be reclaimed, and a stale token cannot publish. Three abandoned automatic attempts become a truthful failure with manual retry. UTF-8 TXT is validated; PDF uses a limited pdftotext subprocess; EPUB uses bounded ZIP inflation, CRC checks, safe paths and entity-disabled XML parsing in spine order. Original bytes remain available when extraction fails.

Library shows durable extraction states. Reader safely displays extracted text, selects earlier revisions through stable URLs, uploads new revisions and downloads private originals. It supports keyboard interaction and mobile widths. Metadata-only sources remain supported. Both STUDIO_HUB_ENABLED and STUDIO_LIBRARY_ENABLED must be true; the Library flag defaults off.

## Local evidence (2026-10-09)

| Gate | Evidence | Outcome |
| --- | --- | --- |
| Compile, SQL/domain and extraction | 29 EUnit cases under OTP 27 with PostgreSQL 17; includes baseline suites | Passed |
| Private storage | exact original download, SHA-256, concurrent retry deduplication, changed-key conflict, quota and immutable history | Passed |
| Ownership and writes | second owner receives 404 for file history/content/download/upload/retry; missing/wrong-origin CSRF denied | Passed |
| Extraction | real TXT/PDF/EPUB; malformed UTF-8/PDF, entity declarations, traversal and forged ZIP size | Passed |
| SQL jobs | expired lease takeover and rejection of stale completion; failed-job retry | Passed |
| Release lifecycle | queued jobs, sessions, originals and text survive web/worker restarts; disabled worker does not claim; Library gate preserves metadata | Passed |
| Setup repeatability | reusable setup rerun, 29 tests pass, release and fixture seeding repeat | Passed |
| Docker | 27 build-time EUnit cases; non-root 164 MB image; built web/worker health, readiness and real PDF/EPUB browser extraction | Passed |
| Browser | 16 cases across desktop 1280×800 and mobile 390×844, including baseline Hub tests | Passed |

Browser tests use real authenticated sessions, uploads and the supervised worker. Only baseline loading/empty/dependency presentation cases use controlled HTTP responses. The revision selector's accessible label was corrected after the initial run; the complete final browser suite passed. The local SQL suite tests migrations and replay with no competing worker.

## Reproduce

Use the existing cloud checkout; no Git worktree is needed.

```sh
bash scripts/cloud-setup.sh
bash scripts/cloud-start.sh
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium npm run test:e2e
BRIGHT_TEST_DOCKER_CONTAINER=bright-m1-dev node tests/release-checks.js
BRIGHT_TEST_DOCKER_CONTAINER=bright-m1-dev BRIGHT_TEST_WORKER_CONTAINER=bright-m2-worker node tests/library-release-checks.js
```

Setup installs verified dependencies, stops only the local extraction worker during lease tests, applies migrations in the disposable integration suite, builds the release and seeds the public acceptance fixture accounts. Start launches separate web/worker roles, with health/readiness and worker ping checks. For repeated full browser runs, restart the local web release to reset its login-attempt limiter; do not weaken that limiter. Native CI follows the equivalent workflow and uses a distinct worker node name.

The runtime Docker image uses pinned OTP build and Debian runtime bases, includes the release and Poppler/prlimit, and runs as UID 1000. Hex checksums and TLS verification remain enabled. A cloud CA can be supplied as a build secret. Build-time EUnit excludes the two opt-in PostgreSQL integration cases; local SQL acceptance includes them.

## Limits and release gate

This Reader provides extracted text, not layout-faithful PDF pages or a complete EPUB renderer. OCR, remote imports, deletion/retention UI, object storage and later roadmap slices are outside this milestone. PostgreSQL storage is deliberately bounded for the initial implementation.

Render access is not bound in this cloud environment, and no staging deployment or GitHub-hosted CI result is claimed. Follow the [staging runbook](milestone-2-runbook.md) with the reviewed SHA and private database. Main auto-deploys the existing development service and has not been merged. Saved environment instructions prepare future tasks; publication/restoration into a new task has not been verified.
