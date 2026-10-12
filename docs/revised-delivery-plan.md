# Revised Bright Studio delivery plan — 2026-10-12

This plan follows completion of SQLite development support. The [original roadmap](bright-studio-full-ui-first-erlang-plan.md) remains unchanged, and [implementation status](implementation-status.md) records what is actually delivered.

## Goal and constraints

Deliver a visible, usable UI journey at each step. Keep the application backend Erlang/OTP. Use SQLite for local development and the free Render demo; retain PostgreSQL compatibility for eventual durable deployment. Use free hosting only. Keep the current main-linked service and main unchanged until the original parity/cutover gates are explicitly satisfied.

The first UI features are available now: sign in, select the development project, add/upload a source, read extracted text, highlight a quote, save/edit a note and link evidence to a board. The free hosted database is disposable, and the UI communicates this. Production durability and complete legacy parity remain outstanding.

## Delivery sequence

| Order | Work | Visible result | Completion gate |
|---|---|---|---|
| 1 | Verify and review the current demo | Library, Reader and Evidence are usable on the existing free URL | User checks a real upload/quote/note journey; hosted desktop/mobile and keyboard checks complete |
| 2 | Resolve issues found in Milestones 1–3 | Clear empty/loading/error states, predictable navigation and reliable reading/annotation | Reproduce and fix actual issues; rerun affected checks; publish a verified commit |
| 3 | Milestone 4: Study workflow | Open a lesson from a source, answer prepared questions, see feedback and resume progress | Ownership, immutable revision binding, correct gates, idempotent attempts, restart behavior and usable desktop/mobile UI |
| 4 | Close account/workspace/planner parity gaps | Project/task management and legacy-equivalent account/planner journeys | Compare against the legacy behavior baseline and record parity evidence |
| 5 | Milestone 5: Focus | Start/resume/complete a focus session linked to learning work | Durable checkpoints, valid state transitions, duplicate-completion prevention and restart tests |
| 6 | Milestone 6: Documents | Draft cited blocks, resolve edit conflicts and export | Revision/provenance checks, compare-and-swap edits and export acceptance |
| 7 | AI, audio/capture and offline/sync | Grounded assistance, private capture and reconnectable work | Provider/cost configuration within the free-only constraint, bounded jobs, replay/conflict and authorization checks |
| 8 | Full rewrite release and cutover | Existing Bright Day/Studio journeys run on Erlang | Durable storage, complete legacy parity, migration/recovery/capacity evidence and explicit one-writer cutover decision |

Later features remain deferred until the earlier usable journey is demonstrated. The free demo does not satisfy production storage/capacity requirements. Timing depends on acceptance findings and concrete prerequisites; use verified feature releases rather than calendar promises. No paid provider, service or disk is authorized by this plan.

## Milestone 4 implementation plan

1. Define the Study screen and its loading, empty, denied, active, feedback, completed and resume states. Start from an owned source's ready immutable revision. Keep the source/revision visible throughout the lesson.
2. Define a persisted StudyPass, chunk/lesson sequence, attempts and progress transitions. Start feedback with prepared questions and deterministic answer checks, so the first Study journey has no external provider prerequisite. Document what qualifies a gate to advance.
3. Add additive PostgreSQL and SQLite migrations and owner-scoped domain operations. Persist expected versions/idempotency receipts, bind each lesson to its source revision, and reject unauthorized or out-of-order transitions.
4. Wire the complete journey: choose source → open lesson → answer → feedback → valid next step → close/reopen/resume. Include keyboard/mobile operation and explicit retry/conflict handling. UI state must follow committed server state.
5. Add `STUDIO_STUDY_ENABLED`, default off, with matching page/asset/API gates. Enable it on the development demo only after its schema and checks pass; keep existing Library/Evidence journeys working.
6. Verify correct/incorrect answers, duplicated submissions, concurrent updates, unauthorized access, immutable revision behavior, restart/resume, disabled gates and dependency errors on both database backends. Package and deploy a known SHA; run hosted functional checks and obtain UI acceptance before calling the slice delivered.

## Review and release evidence

For every release record the exact application SHA, deploy ID, URL, enabled flags, schema versions, tests and material limitations. Keep implemented code, local acceptance, hosted functional acceptance, user design acceptance and production readiness distinct. Preserve existing data when changing flags or backend configuration; switching to SQLite does not import PostgreSQL records.

Environment setup instructions are saved separately in the cloud configuration draft. Review/save and publish activate the prepared snapshot; draft saving alone is not publication. No work on the next milestone is implied by merely creating this plan.

## Milestone 4 implementation update

Study is implemented with deterministic revision-pinned quote-recall chunks, saved attempts, versioned gates, exact replay receipts, reflections and resume. SQLite/PostgreSQL and desktop/mobile checks pass. See [Milestone 4 contracts and validation](milestone-4-plan.md). Hosted release evidence will be added after deployment; user design acceptance and production durability remain separate. Account/workspace/planner parity remains the next item in this revised sequence.
