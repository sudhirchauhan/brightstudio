# Erlang implementation status

## Milestone 1

Implemented locally: OTP/Cowboy release; bounded supervised SQL pool; explicit locked migrations; password login and SQL-backed sessions; CSRF and owner-scoped projects; durable idempotent source metadata; responsive Hub/Library, metadata dialog and Reader placeholder; CI and staging/rollback runbook.

Validation: 24 EUnit/domain/SQL tests and 8 desktop/mobile Playwright cases passed locally. Full-release restart, feature gates, missing database and worker role were verified. Render deployment, private database connectivity, staged account/browser checks and GitHub-hosted CI execution are separate pending checks.

See [acceptance evidence](milestone-1-acceptance.md), [Milestone 1 plan](milestone-1-plan.md) and [runbook](milestone-1-runbook.md). Milestone 1 is not fully released until the Render staging gate passes.

## Later roadmap

Not implemented: legacy authentication/recovery and planner parity, source uploads/extraction, annotations/evidence, full Reader, study/focus/documents, AI, offline sync, worker queue, blob storage, legacy data import and production cutover. No existing Bright Day/Studio deployment is replaced and no production data has been migrated.
