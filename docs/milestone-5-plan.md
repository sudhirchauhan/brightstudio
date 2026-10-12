# Milestone 5 — Focus

The next roadmap slice after Quiet Studio UI alignment. Keep Erlang/OTP, SQLite development, PostgreSQL compatibility and the existing free staging service. The user's request to continue authorizes implementing and releasing this milestone. Main and its original service remain unchanged.

## Scope and visible journey

Choose an owned task or ready source revision → choose 1–120 minutes (default 25) → start → pause/resume or close/reopen → save checkpoints, optionally linking existing evidence → complete with a reflection. Review completed/cancelled sessions and their checkpoints. Reader and Tasks link into Focus; Study progress and task completion remain independent.

Use the approved Quiet Studio design: a quiet timer, one active session, on-demand checkpoint/reflection forms, source/task context, optional distraction-free mode and browser fullscreen. Keep drafts on uncertain writes/conflicts and provide an explicit saved-session refresh.

## Persisted contract and guards

- Add migrations 24–28 on both SQL backends for sessions, checkpoints, receipts, a single open-session owner index and owner/project lookup. Keep each migration a single statement for the SQLite adapter.
- `STUDIO_FOCUS_ENABLED` defaults off and gates pages, navigation, client script and APIs. Focus uses existing owned work independently of the Library/Study/Workspace flags; it does not require a Study lesson.
- One active or paused session per owner. Start binds an owned task in its project, or an owned ready immutable source revision. Store the target title/revision as the starting context. Starting Focus does not update tasks or Study.
- State transitions: active → paused → active; active/paused → completed or cancelled. Terminal sessions cannot restart or mutate. Each write requires an expected version and a replay key; payload-mismatched keys conflict. Persist the exact acknowledged response only after the transaction commits. Clients read the latest saved state after a replay.
- Persist server elapsed milliseconds and the active wall-clock anchor. Pauses stop accrual. Active elapsed time includes downtime while the session remains running; a reload/restart never resets the timer. Cap elapsed time to the requested duration and clamp backward clock deltas to zero. The browser countdown is display only, and no client elapsed/completion timestamps are accepted. This measures a running timer, not verified attention or attendance.
- Checkpoints require a note of 10–2,000 characters and the expected checkpoint ordinal; retain up to 20. Optional evidence must be owned and match the pinned source revision, or belong to the task session's starting project. Quotes retain original source/revision links.
- Completion requires elapsed server time ≥ duration, at least one checkpoint and a 20–2,000 character reflection. Commit completion once with its finish timestamp and summary; race/replay cannot grant duplicate completion.
- Bound sessions to 1,000 and write receipts to 10,000 per owner. Return private/not-found, disabled, input, gate, conflict and dependency failures without exposing other owners' work.

## Verification and release plan

1. Run SQLite and PostgreSQL migration/domain checks for ownership, readiness, early/forged completion, paused time, concurrent versions, exact receipts, evidence provenance and terminal guards.
2. Run desktop/mobile browser journeys: task/source start, keyboard controls, timer display, pause/resume, fullscreen/Escape, checkpoints/evidence, drafts on uncertain saves/conflicts, completion/review and empty/error states. Use server-clock aging only in isolated test fixtures to verify completion guards without trusting browser time.
3. Restart the actual release to verify sessions, pauses, checkpoints, exact receipts and completed summaries persist. Test default-off/disabled and independent feature gates. Preserve the existing development SQLite database.
4. Run existing UI/functional regressions; review changed visual baselines for the added Focus navigation/actions. Deploy a known SHA to the same free service, enable Focus after validation, and test actual desktop/mobile hosted sessions.
5. Record exact SHA/deploy ID, flags, schema and checks. Free Render SQLite remains disposable on instance replacement; local process-restart persistence is not production storage durability.

Implementation and local validation complete; hosted release/acceptance is pending.

Local validation: 43 SQLite and 40 PostgreSQL domain/integration cases passed using new disposable databases. All 52 desktop/mobile Playwright cases passed, including all earlier journeys. Full-release checks passed paused/active/completed timer persistence, checkpoints, exact start/action receipts, default-off/disabled gates, independent flags and private return links and missing-Focus-schema readiness (liveness remains available). Completion fixtures age only their local server anchor through the trusted release console; no test clock override or elapsed-time input is shipped in the HTTP API.

A confirmed private-script loading race returned 503 when six separate feature scripts exhausted the five-connection authentication pool. The signed-in Hub now serves one authenticated, feature-gated bundle, and startup waits for deferred-script registration before emitting its session event. Individual feature asset/API gates remain protected. The added Focus navigation/actions use updated reviewed screenshots; existing visuals and functional flows remain covered. Login rate limits were preserved; full suites run after restarting the owned test release. The next feature milestone is Documents after this Focus journey is delivered and reviewed.
