# Bright Studio implementation status — 28 October 2026

The original specification remains [the full UI-first Erlang plan](bright-studio-full-ui-first-erlang-plan.md). The core Learning Hub is implemented; the complete production product specification is not finished. Legacy-history comparison was explicitly waived.

## Reader and OCR release

Application `aaf3bf6ea4a992bd4a5a4d84e4c4bf9476bb4724` is live on the existing free service as deployment `dep-dbggfjuk1f9s73e893b0`. All six actual hosted desktop/mobile PDF, EPUB and scanned-PDF journeys passed: private upload, extraction/OCR, formatted rendering, annotation save, revision reload and sign-out/privacy. Screenshots were reviewed; no page JavaScript errors were observed.

Test URL: https://brightstudio-m1-staging.onrender.com/studio/hub/library/ . Open a **Reader demo** source or upload a PDF/EPUB, then choose **Formatted original**. Text and annotations remains the default accessible view.

- PDF: original-page rendering, page selection, zoom and selectable embedded text.
- EPUB: safe reflowable chapters with headings, emphasis, lists/tables and supported images; publisher CSS/scripts and external resources are excluded.
- OCR: English extraction for empty/scanned PDF pages, including mixed PDFs. At most 12 scanned pages/200 total pages; 4 MiB upload limit. Existing committed revisions stay immutable; upload a new revision to use OCR.
- Notes: formatted digital selections map to exact revision text; ambiguous/unmatched selections are rejected. Scanned-page OCR is selectable in text view, not an OCR overlay on the page image.
- Reading mode and fullscreen remain independent. Private originals, revision history, byte-pinned quotes, note history and project boards remain intact.

See [milestone plan](reader-ocr-plan.md) and [contracts/limits](reader-ocr-runbook.md).

## Product scope

| Area | Delivered | Remaining |
|---|---|---|
| Account/workspace | Login/logout, profiles/timezones/password changes, recovery through local outbox, owned session controls and workspace membership roles | Hosted recovery email, resource-sharing integration and remaining account/integration contracts |
| Projects/planner | Projects, tasks, selected-day planning, completion/reopen and version conflicts | Separate planner AI workflows/policies and remaining specified planner contracts |
| Library/Reader | Private TXT/PDF/EPUB uploads, immutable revisions, extraction/OCR, formatted PDF/EPUB reading and text fallback | Remote imports; scanned-image selection overlay and publisher-specific layout features are not implemented |
| Evidence | Exact revision-pinned quotes, annotations, note history and boards | Shared-resource policy and final product acceptance |
| Study | Missing-word recall, attempts, feedback, reflection gates, progress and resume | Broader StudyPass/chunk/summary and Anki/export contracts |
| Focus | Server-timed sessions, pause/resume, checkpoints, reflection and saved review | Final product acceptance |
| Documents | Revisioned cited blocks, conflicts, saved snapshots and private Markdown exports | Remaining export contracts |
| Studio AI | Evidence guides, real bounded generation, authorized citations and daily budget | Planner-specific policy; generated claims still require review |
| Capture/audio | Private image/audio capture, browser recording, English OCR/transcription and bounded jobs | Final product acceptance; language/size limits remain |
| Offline | Consented pinned packages, local drafts, exact sync receipts, conflicts and cleanup | Final product acceptance |
| Rollout/operations | Supervision, readiness, additive migrations, backup/restore drill, bounded load and rollback runbooks | Owner/cohort rollout allowlists, broader metrics, production capacity/recovery, durable storage and actual data/traffic cutover |

## Verification and environment

All 78 desktop/mobile Chromium cases, 55 SQLite and 52 PostgreSQL tests passed with real native models. The six final Reader cases also passed after the mobile toolbar refinement. Library-disabled gates passed. The production image built with real OCR tests; mixed-PDF OCR/private assets passed at 512 MiB / 0.1 CPU without OOM. GitHub-hosted CI, other browsers/physical devices and full production acceptance are separate checks.

Only `main` remains locally and remotely. Staging is the existing free Frankfurt service `srv-db5qa5bl550s73b1qu40`, tracking main with auto-deploy off. No paid infrastructure or production traffic cutover was added. The original main-linked service configuration was preserved.

SQLite development is retained at `erlang/_build/bright-development.sqlite`; PostgreSQL compatibility and migrations 1–41 remain intact. The primary development server was restored after isolated acceptance and private backup. Free hosted SQLite may reset on instance replacement/redeploy: it is not durable production storage. Development recovery uses the requested private local outbox; hosted email is unconfigured. Bootstrap credentials remain in Render settings and are not recorded in source/logs.

[Earlier release evidence](implementation-status-history.md) is historical. [Remaining delivery records](remaining-milestones-plan.md), [account contracts](account-access-runbook.md) and [learning-tool operations](learning-tools-runbook.md) provide supporting detail.
