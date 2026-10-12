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
| 4 | Account, workspace and planner in Erlang | Manage projects/tasks, plan a day and maintain account settings | Owner/version/retry/restart checks and usable desktop/mobile journeys; user requested direct Erlang implementation without legacy-history comparison |
| 5 | UI alignment milestone | Existing screens adopt the approved Quiet Studio concepts across desktop/mobile | Approved new JPG concepts, screen/state comparison, visual checks and final deployed UI acceptance |
| 6 | Milestone 5: Focus | Start/resume/complete a focus session linked to learning work | Durable checkpoints, valid state transitions, duplicate-completion prevention and restart tests |
| 7 | Milestone 6: Documents | Draft cited blocks, resolve edit conflicts and export | Revision/provenance checks, compare-and-swap edits and export acceptance |
| 8 | AI, audio/capture and offline/sync | Grounded assistance, private capture and reconnectable work | Provider/cost configuration within the free-only constraint, bounded jobs, replay/conflict and authorization checks |
| 9 | Full rewrite release and cutover | Existing Bright Day/Studio journeys run on Erlang | Durable storage, complete legacy parity, migration/recovery/capacity evidence and explicit one-writer cutover decision |

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

Study is implemented with deterministic revision-pinned quote-recall chunks, saved attempts, versioned gates, exact replay receipts, reflections and resume. SQLite/PostgreSQL and desktop/mobile checks pass. See [Milestone 4 contracts and validation](milestone-4-plan.md). The existing free service is live at `a9e6f1cfda3dad52269316ea5b2923e5f92688c7` (deploy `dep-db69sm7avr4c73amhqbg`) and actual hosted desktop/mobile Study journeys passed; user design acceptance and production durability remain separate. The account/workspace/planner implementation below has now shipped; UI alignment is the next item before Focus.

## Delivered milestone: Account, workspace and planner

The user requested direct Erlang implementation without legacy-history investigation. This milestone implements a usable account/workspace/planner journey; it does not certify equivalence to an unseen legacy application.

1. Create and rename owned projects, using saved versions and replay receipts. Preserve existing sources, evidence and Study passes. **Implemented; local and hosted desktop/mobile acceptance passed.**
2. Add task creation/editing, owned-project moves, priority, estimates, due/scheduled dates, and todo/doing/done transitions including reopening. **Implemented; local and hosted desktop/mobile acceptance passed.**
3. Add a daily planner that shows scheduled, due and overdue work for a selected civil date, with saved account timezone settings. **Implemented; local and hosted desktop/mobile acceptance passed.**
4. Add display-name/timezone settings and current-password-authenticated password changes that revoke all sessions. **Implemented; local and hosted desktop/mobile acceptance passed.**
5. Add responsive Projects, Tasks, Planner and Account pages, clear empty/error states, retry handling and conflict recovery that preserves drafts. Gate the complete slice with `STUDIO_WORKSPACE_ENABLED`, default off. **Implemented; local and hosted desktop/mobile acceptance passed.**
6. Verify both SQL backends, owner isolation, stale/concurrent edits, exact receipts, date validation, session revocation, restart persistence, existing journeys and hosted desktop/mobile acceptance; deploy to the existing free service. **Passed and deployed to the existing free service.**

## Current milestone: Approved Quiet Studio UI alignment

This milestone follows the current account/workspace/planner work and precedes Focus. The user approved the new Quiet Studio JPG concepts on 2026-10-12 and authorized applying them to the app. This is the visual reference for the milestone; it does not claim recovery of unseen originals.

1. Use the approved JPGs in `design/mocks/jpg` and `design/mocks/quiet-studio.html`, covering Workspace, fullscreen Reader, fullscreen Study and mobile Study.
2. Inventory Hub, sign-in, Library, Reader, Evidence, Study, Projects, Tasks, Planner and Account against those mocks. Record concrete differences and screen/state acceptance criteria in a UI comparison document.
3. Align the application shell, navigation, typography, colors, spacing, components, source/task cards, Reader/Evidence panels, lesson layout, forms and dialogs with the reference. Preserve private authentication and committed server behavior.
4. Implement the specified loading, empty, error, disabled, conflict and completed states; check narrow/wide layouts, keyboard use, focus and readable contrast. Use design references for visual decisions, not invented claims of matching unseen mocks.
5. Run representative functional regressions and visual desktop/mobile comparisons, publish a known SHA to the same free staging service, and obtain user design acceptance before calling UI alignment complete.

UI alignment is a separate milestone from adding features. The approved new reference is available; applying it and verifying the deployed app is now the active work. No paid hosting or design tool is authorized or required by this plan.

Detailed current contracts and release checks: [Account/workspace/planner](workspace-planner-plan.md). Dedicated next milestone: [UI alignment with original mocks](ui-alignment-plan.md).

Hosted workspace release: application SHA `6d071ef51fb7225f75ca39302d373ed946f56e1e`, deploy `dep-db6dc1ss728c7383irm0`, passed actual public-site desktop/mobile journeys. Current functional delivery is complete; matching the original visual mocks remains the separate UI alignment milestone.


## UI alignment release update

The approved Quiet Studio design is implemented and live at https://brightstudio-m1-staging.onrender.com/studio/hub/ . Application SHA `5f27e51aafb0d71d84f9086d2b34a45533b75878`, Render deploy `dep-db6hgvff3r2c73cahld0`, existing free staging. Local functional/visual and real hosted desktop/mobile checks passed. Reader/Study have independent distraction-free and browser fullscreen controls; notes are on demand, and all current workspace screens share the design. Final deployed UI design acceptance remains separate. Focus remains the next planned feature slice; no Focus implementation is claimed by this UI release.
