# Bright Studio implementation status — 2026-10-12

The original roadmap is [Full UI-first Erlang/OTP Delivery Plan](bright-studio-full-ui-first-erlang-plan.md). It remains the source for the complete rewrite; the milestones delivered so far cover a smaller Learning Hub scope. The original roadmap file has not been rewritten to imply completion.

## Original roadmap and actual status

| Slice | Original scope | Current status | Remaining work |
|---|---|---|---|
| 0 | Foundation and design | OTP/Cowboy application, responsive Hub and free staged demo implemented | Broader product design acceptance and production operations |
| 1 | Account and workspace parity | Private password login, sessions, project selection and owner authorization implemented | Legacy login/recovery/import, project/task management and planner parity |
| 2 | Library and Reader | Uploads, private originals, immutable revisions, TXT/PDF/EPUB extraction and extracted-text Reader implemented; demo verified | Layout-faithful reading, remote imports and production durability are not claimed |
| 3 | Evidence and notes | Exact revision-pinned quotes, UTF-8 anchors, annotations, versioned edits/history and project boards implemented; demo verified | Product acceptance and production release gates |
| 4 | Study workflow | Revision-pinned recall lessons, attempts, feedback, reflection gate and resume implemented; local and hosted desktop/mobile checks passed | User design acceptance and production durability |
| 5 | Focus | Not implemented | Sessions, checkpoint guards and restart-safe transitions |
| 6 | Documents | Not implemented | Cited blocks, revisions, concurrent-edit handling and export |
| 7 | AI assistant | Not implemented | Grounded provider adapters, citation policy, budgets and cost tests |
| 8 | Audio and capture | Not implemented | Recording, transcription, OCR and bounded private jobs |
| 9 | Offline and sync | Not implemented | Offline packages, replay receipts, conflicts and authorization |
| 10 | Cutover and rollout | Not implemented | Complete legacy parity, data migration, capacity/recovery and one-writer cutover |

Milestone 1 delivered the Hub/authentication/source-metadata walking skeleton, not all of original slice 1. Milestones 2 and 3 delivered Library/Reader and Evidence/Notes. A SQLite development demo is not full legacy rewrite completion or a durable production deployment.

## Current development and deployed state

- SQLite development is implemented alongside the PostgreSQL backend. Application/domain logic remains Erlang/OTP. Versioned SQLite migrations cover versions 1–18; PostgreSQL migrations and TLS checks remain intact.
- Default cloud development uses `scripts/cloud-sqlite-setup.sh` and `scripts/cloud-sqlite-start.sh`, with the `bright-sqlite-dev` container, a retained workspace SQLite file and supervised extraction in the web VM. Existing PostgreSQL files/volumes are preserved.
- Render service: `brightstudio-m1-staging` (`srv-db5qa5bl550s73b1qu40`), Frankfurt, **free**, `milestone-3`, auto-deploy off. Live application commit: `a9e6f1cfda3dad52269316ea5b2923e5f92688c7`; deploy `dep-db69sm7avr4c73amhqbg`. `/readyz` is the deployment health check.
- URL: https://brightstudio-m1-staging.onrender.com/studio/login/ . Hub, Library, Evidence, Study and web extraction are enabled. A private getting-started source, note and board were added through the real hosted APIs.
- Development login email: `developer@brightstudio.test`. The securely generated password stays in that service's Render Environment setting `BRIGHT_BOOTSTRAP_PASSWORD`; it is not recorded in source or test logs. Normal session, cookie, CSRF and ownership checks remain active.
- Hosted SQLite is disposable: free Render instance replacement/redeploy/restart can erase saved data. The UI displays a notice. Local data survives Erlang process restarts while the workspace files remain. No production durability is asserted.
- No paid database, worker or disk was provisioned. No main merge, original development-service change, legacy import or production cutover occurred.

## Verification evidence

- 36 SQLite EUnit/domain/integration tests passed, including migration serialization/replay, transaction rollback, blob byte fidelity, injection-shaped bound input, sessions, owner isolation, immutable revisions, extraction leases and evidence conflicts/provenance.
- 34 PostgreSQL regression EUnit tests passed, preserving the original backend and TLS failure behavior.
- 30 desktop/mobile Playwright UI cases passed on SQLite, followed by all eight focused Study cases after the latest-progress retry improvement. Library, Evidence and Study full-release restart checks passed.
- Release checks passed for session/source persistence across Erlang process restart, feature gates, missing-database readiness and worker-only roles.
- Docker packaging and the packaged opt-in development bootstrap passed private login, Unicode upload/extraction, evidence/note persistence, session persistence and idempotent bootstrap replay across a container restart.
- The final live Render commit passed trusted-HTTPS readiness, login, project access, TXT upload/extraction, Reader content, resolved evidence, note creation/reopen, board linking, and authenticated Hub/Library/Reader/Evidence HTML responses.
- Full hosted desktop/mobile browser acceptance and user design acceptance remain separate checks. GitHub CI now has PostgreSQL/SQLite matrix jobs; no GitHub-hosted execution result is asserted here.

See [SQLite development](sqlite-development.md), the milestone acceptance/runbook documents, and [Revised delivery plan](revised-delivery-plan.md).

## Hosted browser acceptance update

The seeded development demo now restores its bundled samples after a free SQLite instance reset. Live application SHA `707b20a7fa6d92fdc463b376805ac5acb35e11ce`, deploy `dep-db657sl9fdbs73erqff0`, passed actual public-site Chromium desktop/mobile-viewport journeys for login, all sample formats, highlights, revision history, boards, note history, fresh UI uploads/annotations/edits, private downloads, reload persistence and sign-out. 34 SQLite EUnit tests passed, including sample replay preserving user-edited notes. See [hosted demo acceptance](hosted-demo-acceptance.md). User design acceptance, other-browser/device checks and production release gates remain outstanding.

## Milestone 4 hosted release

Study is live at application SHA `a9e6f1cfda3dad52269316ea5b2923e5f92688c7`, deploy `dep-db69sm7avr4c73amhqbg`, on the existing free service. Actual Chromium desktop/mobile hosted checks passed signed-out Study → sign-in → Study, private UI upload/extraction, revision-pinned start, wrong/correct answers, reload/resume, reflection completion, completed review, responsive layout and sign-out/API privacy. `/healthz` and `/readyz` return 200. See [Milestone 4](milestone-4-plan.md). User design acceptance and production storage/cutover remain pending.
