# Remaining feature delivery — 2026-10-13

## Reader/OCR update — 28 October 2026

Formatted PDF pages, safe EPUB chapters and English scanned/mixed-PDF OCR are implemented and live at `aaf3bf6ea4a992bd4a5a4d84e4c4bf9476bb4724` (`dep-dbggfjuk1f9s73e893b0`). All 78 browser cases, 55 SQLite and 52 PostgreSQL cases passed, plus six final Reader checks and six hosted desktop/mobile journeys. Real mixed OCR passed at 512 MiB / 0.1 CPU. Scanned-page annotations use the OCR text view; publisher CSS/DRM and remote imports remain outside this milestone. See [current status](implementation-status.md) and [Reader plan](reader-ocr-plan.md). Only main remains; the older entries below describe previous releases.


## Current account/access release

Account/access release verified on 2026-10-14: application `c1e8d7e8de2e5bcbdd7d92fad3e2e39a2ef8ba71`, Render deployment `dep-db785mmi0phs73c65gig` is live on the existing free staging service. All 72 main browser cases plus two recovery browser cases, 53 SQLite and 50 PostgreSQL tests passed. Hosted desktop/mobile session and membership checks passed (four groups), including owner protection, duplicate conflicts, private API denial after revocation and truthful recovery availability. Native generation, OCR and speech passed at 512 MiB / 0.1 CPU. Recovery uses the requested private local development outbox; hosted email delivery is unconfigured. Workspace membership does not share personal learning resources. Original production durability, Reader/import/export, planner AI policy and cohort/metrics work remain. GitHub-hosted CI and production cutover are not claimed.

## Earlier delivery record


The user authorized continuing until finished. Keep Erlang/OTP application logic, the approved Quiet Studio UI, SQLite development and existing free Render staging. Free, paid and local AI/speech models are acceptable; the implementation uses small verified local models without requiring provider credentials. Main and its original service remain unchanged. Historical comparison was explicitly waived; do not request it again.

| Milestone | Implemented scope | Verification/release state |
|---|---|---|
| 6 Documents | Owned cited blocks, reorder/edit, immutable snapshots, explicit conflict comparison, private saved-version Markdown | SQL, restart and local/hosted desktop/mobile journeys passed; live |
| 7 Assistant | Exact evidence guides, real bounded native generation, optional verified-TLS Ollama adapter, saved questions/answers, approved citation IDs, reserved daily allowance | SQL and local/hosted desktop/mobile real generation passed; live |
| 8 Audio/capture | Private PNG/JPEG/WAV/WebM, microphone consent and recording, English OCR/transcription, fenced jobs, bounded retries, immutable derived sources | Real OCR, WAV and browser-recorded WebM passed locally and hosted; live |
| 9 Offline/sync | Consent-based owner/project/revision packages, generic cached shell, local drafts, explicit CAS sync, exact receipts, expiry/revocation and sign-out cleanup | SQL, local/hosted offline/retry/conflict/logout and restart checks passed; live |
| 10 Operational handover | Consistent private SQLite backups, restore drill, bounded load smoke, schema/feature readiness, rollback procedure and release evidence | Backup/restore, bounded load, free-resource native workflows and restart/gates passed; durable production hosting and actual production traffic/data cutover remain separate |

Local verification: 70/70 browser cases, 50 SQLite and 47 PostgreSQL tests passed. Ten visual baselines were checked/refreshed; real generation, OCR and transcription passed under 512 MiB / 0.1 CPU. The verified SHA is deployed to the existing free service. Actual hosted desktop/mobile document → assistant → capture → offline journeys passed. The original development SQLite process was restored after isolated acceptance.

The original roadmap is unchanged. The free demo is not durable production storage. No production migration, main merge or traffic switch is implied by implementation or staging validation.

Feature contracts, limits, models, backups and rollback are documented in [the learning tools runbook](learning-tools-runbook.md).

Release `9696d739553422875aefe6979eab7fdc997a6b22` is live on the existing free service as `dep-db700ed9fdbs73eipt2g`. Trusted-HTTPS `/healthz` and `/readyz` return 200. Hosted desktop/mobile feature acceptance passed: cited document editing/export/fullscreen, real generated answers and pinned citations, OCR/private originals/Reader, WAV and browser-recorded WebM transcription, offline reload/local drafts/reconnect/sync, immutable export and sign-out cleanup/privacy. No page JavaScript errors were observed.
