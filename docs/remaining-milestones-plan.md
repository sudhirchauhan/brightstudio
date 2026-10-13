# Remaining feature delivery — 2026-10-13

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
