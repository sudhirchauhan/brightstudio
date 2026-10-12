# Milestone 4 — Study workflow

## Scope and visible journey

Open **Study** from the Hub, choose a ready source, or choose **Study this revision** in the Reader. Read the passage, enter its missing word, get deterministic feedback, progress through the chunks, then save a reflection. Reopening a lesson restores committed progress. Completed lessons can be reviewed.

This first workflow uses prepared missing-word recall, not AI comprehension assessment. It covers up to six passages of 80 whitespace-separated words and 2,000 Unicode characters each from a source. Case folding and surrounding-space trimming determine correct answers; punctuation inside a missing word is not part of its expected answer. A correct answer completes the current chunk. Wrong answers are saved and keep that chunk active. After all chunks, a trimmed reflection of at least 20 Unicode characters completes the pass. Reflection meaning is not automatically graded. Individual tokens over 2,000 characters are excluded from practice. Sources without a usable word of at least three letters/numbers cannot start a lesson.

One pass exists per owned immutable revision; reopening it resumes or reviews it. New source revisions do not move existing passes. Updating a source produces a separately startable pass. Practice replay/reset and manually authored question banks are future work. Free Render SQLite may lose all user progress on instance replacement; bundled sample sources regenerate, user work does not.

## Persisted contracts

- Additive PostgreSQL and SQLite migrations 16–18 store passes, prepared chunks, source text hash, attempts, exact response receipts, start receipts and final reflections. Composite foreign keys preserve source/revision ownership.
- `POST /studio/api/hub/study`: source_id + revision_id, CSRF/origin and idempotency key. Ready owned text is required. Repeated starts resume the same pass; a reserved key reused for another revision conflicts.
- `GET /studio/api/hub/study?project_id=…`: project-authorized passes; `GET /studio/api/hub/study/:id`: owner-scoped pass with only the current question. Expected answer is excluded from JSON; the reference passage remains readable.
- `POST /studio/api/hub/study/:id/attempts`: expected_version, step, kind (`answer` or `summary`), answer, CSRF/origin and idempotency key. Exact replay returns its original committed response. Changed payload, stale version, future step, early reflection and completed-state writes conflict.
- An owner's writes serialize under the existing user row lock (SQLite BEGIN IMMEDIATE), with version guards. Every accepted attempt, including incorrect ones, increments the version. Updates and receipts share one transaction; exceptions roll back.
- Answer/reflection input is valid bounded Unicode (2,000 characters). Limits are 1,000 passes and 10,000 start receipts/attempts per owner, alongside the existing 256 uploaded-revision allowance.
- `STUDIO_STUDY_ENABLED` defaults off and requires Hub + Library. It gates navigation/script injection, pages, assets and APIs. Readiness requires migrations 16–18 when enabled. Disabling a feature retains progress. Signed-out pages redirect to safe login return paths; APIs remain 401.

## Validation and release

1. Run `bash scripts/cloud-sqlite-setup.sh` then `bash scripts/cloud-sqlite-start.sh`. Setup preserves development files and verifies migrations/tests; startup enables Study and embedded extraction.
2. Run `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium npm run test:e2e`. Restart the local release before repeating the full suite: the unchanged login limiter allows 10 attempts per five minutes.
3. Run `BRIGHT_TEST_DOCKER_CONTAINER=bright-sqlite-dev node tests/study-release-checks.js` against the isolated acceptance database. It verifies mid-lesson restart, exact receipt replay, feature dependencies/gates, completed reflection restart and private anonymous behavior. Existing restart checks now restore Study too.
4. CI covers PostgreSQL and SQLite and includes the Study browser/restart checks. Local PostgreSQL compatibility is tested separately; GitHub-hosted CI results must be verified independently.
5. Deploy the verified commit to the existing **free** `brightstudio-m1-staging` service on `milestone-3`, preserving all existing environment settings and bootstrap credentials. Enable only `STUDIO_STUDY_ENABLED=true`; use the existing SQLite development bootstrap and `/readyz` health check. Do not merge main or add paid resources.
6. Test the actual hosted desktop/mobile journey and record SHA/deploy ID. User design acceptance and production durability remain separate gates. Roll back by disabling Study or deploying the prior compatible release; keep additive tables and existing Library/Evidence data.

## Local evidence

36 SQLite EUnit tests and 34 PostgreSQL EUnit tests passed. The full existing-plus-Study browser suite passed 30 desktop/mobile cases, including uncertain commits/replay, stale-tab draft recovery, empty states and dependency errors. A further desktop/mobile case verifies that replaying an earlier receipt loads the latest server progress instead of rewinding the UI. Full-release Study checks passed progress/session/receipt persistence, disabled routes/scripts, Library dependency, completed-reflection persistence, and signed-out page redirect/API privacy.

Hosted release evidence is recorded after successful deployment. User design acceptance is pending.
