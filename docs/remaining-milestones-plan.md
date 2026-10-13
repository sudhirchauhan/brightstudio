# Remaining feature delivery — 2026-10-13

The user authorized continuing until finished. Keep Erlang/OTP application logic, the approved Quiet Studio UI, SQLite development and existing free Render staging. Free, paid and local AI/speech models are acceptable; the implementation uses small verified local models without requiring provider credentials. Main and its original service remain unchanged. Historical comparison was explicitly waived; do not request it again.

| Milestone | Implemented scope | Verification/release state |
|---|---|---|
| 6 Documents | Owned cited blocks, reorder/edit, immutable snapshots, explicit conflict comparison, private saved-version Markdown | SQL and desktop/mobile editor and restart checks passed; combined release pending |
| 7 Assistant | Exact evidence guides, real bounded native generation, optional verified-TLS Ollama adapter, saved questions/answers, approved citation IDs, reserved daily allowance | Domain and desktop/mobile checks passed with real native generation; hosted release pending |
| 8 Audio/capture | Private PNG/JPEG/WAV/WebM, microphone consent and recording, English OCR/transcription, fenced jobs, bounded retries, immutable derived sources | Real OCR, WAV transcription and browser-recorded WebM passed; combined release pending |
| 9 Offline/sync | Consent-based owner/project/revision packages, generic cached shell, local drafts, explicit CAS sync, exact receipts, expiry/revocation and sign-out cleanup | SQL, desktop/mobile offline/retry/conflict/logout and release restart checks passed; hosted release pending |
| 10 Operational handover | Consistent private SQLite backups, restore drill, bounded load smoke, schema/feature readiness, rollback procedure and release evidence | Backup/restore, bounded load, free-resource native workflows and restart/gates passed; durable production hosting and actual production traffic/data cutover remain separate |

Local verification: 70/70 browser cases, 50 SQLite and 47 PostgreSQL tests passed. Ten visual baselines were checked/refreshed; real generation, OCR and transcription passed under 512 MiB / 0.1 CPU. Deploy a known SHA to the existing free service. Test the actual public-site document → assistant → capture → offline journeys before recording delivery. Preserve the original development SQLite file and restore it after isolated acceptance.

The original roadmap is unchanged. The free demo is not durable production storage. No production migration, main merge or traffic switch is implied by implementation or staging validation.

Feature contracts, limits, models, backups and rollback are documented in [the learning tools runbook](learning-tools-runbook.md).
