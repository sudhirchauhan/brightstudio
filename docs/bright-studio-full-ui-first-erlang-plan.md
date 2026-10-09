# Bright Studio — Full UI-first Erlang/OTP Delivery Plan

**Status:** Delivery plan, not implementation completion. **Updated:** 2026-10-09.
**Companion:** [Milestone 1 actionable backlog](milestone-1-plan.md).
**Source baseline:** Bright Studio Complete Erlang/OTP Rewrite Plan (365-line source document). This roadmap reorganizes delivery into vertical slices while retaining its architecture, invariants and parity/cutover obligations.

## Mission and non-negotiable architecture

Replace the complete Bright Day/Studio application backend with **Erlang/OTP only**. Deliver the Learning Hub in usable UI-first vertical slices while preserving existing authentication, projects, tasks, planner, Studio reading/study/export, integrations and administration. A Hub staging demo is **not** completion of the legacy rewrite.

- One rebar3 OTP release with `bright_platform`, `bright_identity`, `bright_projects`, `bright_planner`, `bright_studio`, `bright_ai`, `bright_web`.
- Cowboy for same-origin HTML and APIs; PostgreSQL is transactional authority; private blob storage for originals and derived assets; supervised Erlang workers for jobs.
- Browser HTML/Datastar and small JavaScript islands; PDF.js, EPUB.js, offline storage and recording can run in the browser. Bounded native OCR/media tools are allowed but contain no application-domain logic.
- **No Django, Python application server, Python worker, Phoenix/Elixir backend, gateway, second backend authority, or mandatory Redis/Mnesia.**
- Preserve established URLs, IDs, fragment anchors, export contracts and behavior where feasible; migrate only with verified parity.
- Separate `BRIGHT_ROLE=web|worker` deployment roles, not separate business authorities.

## Delivery rule: UI first, behavior immediately behind it

For every slice:
1. **Prototype:** design clickable browser states (empty, loading, success, invalid input, conflict, offline, denied) and keyboard/mobile behavior.
2. **Contract:** define routes, domain ownership, permissions, data invariants, feature flags and durable acknowledgements.
3. **Implement:** build Erlang domain functions, explicit SQL migrations, adapters and supervised jobs as required.
4. **Integrate:** connect the real UI to authorized Erlang endpoints; label fixture behavior until replaced.
5. **Verify:** EUnit, SQL integration, browser E2E, owner isolation, failure/restart and accessibility.
6. **Release:** known commit SHA on Render staging, smoke tests, telemetry, rollback and user feedback.

No slice is done because the mock looks right. A real write must survive process restart. UI must never become authoritative for authorization, revisions, progress or budget.

## Product mock screens

### A. Hub Home
- Left navigation: Overview, Library, Study, Focus, Documents, Audio, Projects.
- Top bar: active project selector, current account, clear feature availability.
- Main: continue reading card, recent sources, next study activity, project-linked evidence.
- Empty state: invite to add a source; no fabricated metrics.
- Error/disabled state: explain access or readiness without leaking another owner's data.

### B. Library and Reader
- Library: searchable/filterable source cards, status badges, Add Source action, empty/loading/error states.
- Add Source: metadata-only first; later upload/import with processing status and truthful extraction outcomes.
- Reader: source title, revision, text/EPUB/PDF viewer, anchored highlights, evidence note panel.
- Missing or stale anchors: visible unresolved state, never silently attach evidence to wrong text.

### C. Study lesson
- Source-linked lesson, prompt, answer field, submit action, feedback and completion state.
- Store attempts and progress durably; block unauthorized or incomplete gates; avoid client-only completion.

### D. Focus
- Minimal session timer, checkpoints, pause/resume and evidence summary.
- Timer is display only; server-side state and durable transitions determine credit and completion.

### E. Documents
- Block editor with cited evidence, provenance, revision conflicts and export status.
- Save acknowledgements only after commit; conflict resolution never silently overwrites newer edits.

## Vertical slice roadmap

| Slice | Name | Target | Usable journey | Erlang/SQL requirements | Release proof |
|---|---|---|---|---|---|
| 0 | Foundation and design | 1–2 weeks | Open shell, navigate prototype | OTP/Cowboy, CI, Render staging, design tokens | Build, /healthz, staged UI |
| 1 | Account and workspace parity | 2–4 weeks | Login, select project, view/manage tasks | Sessions, owner isolation, projects, planner parity | Auth and planner parity tests |
| 2 | Library and reader | 2–3 weeks | Add, browse and open source | Private blobs, source metadata, extraction jobs | Owner-scoped source and restart tests |
| 3 | Evidence and notes | 2–3 weeks | Highlight, annotate, link project | Immutable revisions, anchors, boards | Anchor provenance and cross-owner tests |
| 4 | Study workflow | 2–3 weeks | Start lesson, answer, receive feedback | StudyPass/chunk/summary, durable gates | Correct gate and progress behavior |
| 5 | Focus | 1–2 weeks | Run and complete session | Durable focus state, checkpoint guards | Restart and transition tests |
| 6 | Documents | 2–3 weeks | Draft cited blocks, save, export | Block revisions, CAS, provenance, exports | Concurrent-edit and export tests |
| 7 | AI assistant | 2–3 weeks | Explain/compare/feedback on evidence | Provider adapters, citations, budgets | Grounding, policy and cost tests |
| 8 | Audio and capture | 2–3 weeks | Record, transcribe, capture paper | Bounded jobs, private blobs, OCR | Retry, permission, provenance tests |
| 9 | Offline and sync | 2–3 weeks | Work offline and reconcile | Packages, idempotent receipts, conflicts | Replay and owner isolation tests |
| 10 | Cutover and rollout | 2–4 weeks | Existing user journeys run in Erlang | Migration, parity, recovery, capacity | Signed parity and one-writer cutover |

Estimates are directional, not commitments. Each slice requires design acceptance, real backend behavior, persistence, tests and staging verification. Earlier parity obligations may run in parallel, but **production Erlang cutover is blocked** until the complete legacy baseline is equivalent.

## Full cross-cutting requirements

### Identity and authorization
- Secure login/logout, session revocation, recovery and account integrations as verified from existing app.
- Owner/project checks at request and domain layers; deny-by-default Hub APIs, jobs and client assets.
- CSRF protection for cookie-authenticated writes; secure cookies, content security policy, safe rendering, no owner enumeration.
- Import credential hashes only if verified compatible; otherwise use explicit reset flow. Invalidate legacy sessions at cutover.

### Planner and Studio parity
- Inventory and test all legacy routes, task/planner rules, timezones, study gates, exports, callbacks and admin commands.
- Preserve legacy reader, annotation, StudyPass, Anki/export and task/project integration contracts before cutover.
- Maintain parity matrix and `docs/studio_decisions.md` until each decision is implemented and verified.

### Evidence and source revisions
- Immutable source revisions and stable anchor provenance; no silent rebinding.
- Revision-specific citations, explicit stale/unresolved states, source ownership, project links and audit.
- Private original/derived blobs with signed access or authorized proxy; no public object-store URLs.

### Durable jobs and media
- SQL-backed leases, fencing tokens, idempotency, bounded concurrency, backoff and dead-letter/recovery procedures.
- No acknowledged write or job completion before SQL commit. Jobs re-check owner authorization.
- Native extraction/OCR/media programs only as bounded tools under Erlang supervision.

### Documents, study and focus
- Revisioned blocks, compare-and-swap edits, provenance and safe export.
- Study/focus progress and completion gates stored server-side, not browser-local.
- Keep lesson and focus independent where required; distinguish feature-disabled from unauthorized and state-conflict responses.

### AI and budget
- Distinct planner and Studio AI policies, provider limits, timeouts and budgets.
- Ground Studio outputs in authorized source revisions with citations; fail safely when grounding is absent.
- Audit attempts and usage without leaking credentials or cross-owner data.

### Offline
- Versioned offline packages scoped to owner/project/source revision.
- Idempotent sync receipts, conflict handling, revocation and explicit stale package behavior.
- Service worker scoped under `/studio/hub/`; browser storage is never sole authority.

### Observability and operations
- Structured logs without secrets, bounded resource usage, health vs readiness separation, job/revision metrics.
- Graceful restarts, process supervision, migrations as a locked explicit release job (never racing during replica startup).
- Capacity/load tests, backup/restore drills, runbooks and rollback compatibility.

## Feature flags

False by default, with owner/cohort allowlists:
`STUDIO_HUB_ENABLED`, `STUDIO_DOCUMENTS_ENABLED`, `STUDIO_FOCUS_ENABLED`, `STUDIO_LESSONS_ENABLED`, `STUDIO_AUDIO_ENABLED`, `STUDIO_OFFLINE_ENABLED`, `STUDIO_AI_ENABLED`.

Gate UI, routes, APIs, jobs, navigation and client assets consistently. Disabling a feature must retain durable data and preserve recovery/export pathways.

## Migration and production cutover

1. Inventory all routes, relational tables, credential formats, blobs, callbacks, jobs, retention rules and existing permissions.
2. Capture approved snapshots, frozen behavior fixtures, ID mappings and checksums.
3. Rehearse offline SQL/Erlang import against consistent DB/blob snapshots; verify counts, ownership, references, revisions and exports.
4. Schedule maintenance; stop legacy writers/workers; drain or record queues; create final consistent snapshot.
5. Import and verify; route traffic only after checks pass. Erlang becomes sole writer.
6. Keep secured read-only legacy snapshot for reconciliation; remove legacy runtime after acceptance.
7. Roll back to schema-compatible Erlang release when possible. Any pre-cutover restore requires isolating writes and reconciling every acknowledged post-cutover operation; never silently restore stale data.

## Current verified implementation baseline — 2026-10-09

- GitHub: `sudhirchauhan/brightstudio`; feature branch `feat/m1-ui-first-walking-skeleton`.
- Render: `brightstudio-erlang-dev` (`srv-db4aedjncjis73ccd260`), Docker context `erlang`, `erlang/Dockerfile`, Frankfurt, Free, one instance; auto-deploy from `main`; no health-check path or preview deployments.
- Render Postgres: `brightstudio-erlang-dev-db` (`dpg-db4ikk6i0phs73cqgvtg-a`), PostgreSQL 17, available, Free, expires 2026-11-08; no managed pool, HA or replicas.
- Latest observed live deploy: `13ebd66db31ce0523f935a2dbcae6a757a6f2555`; prior `88e8f31` introduced supervised `bright_sql_pool.erl`.
- Existing `bright_http.erl` routes `/healthz`, `/readyz`, `/`, `/studio/`, `/studio/hub/`; Hub deliberately 404 until authorized.
- Direct external SQL inspection blocked by empty IP allowlist. Do not open DB publicly to inspect it.
- Current UI prototype committed on feature branch in `erlang/apps/bright_web/src/bright_hub_view.erl` (`0b7d2c0`), but not yet routed or tested.
- No production cutover or `main` merge authorized by this plan.

## Milestone 1 acceptance

Implement the walking skeleton: Hub shell, Library empty/list, Add Source metadata-only dialog, Reader placeholder, authorized project selector, PostgreSQL-backed metadata creation/listing, and accessible error/empty/loading states. Preserve /healthz and DB-aware /readyz.

**Release gates:** compile/EUnit/release; SQL migration apply/replay/concurrency; owner and CSRF tests; idempotent writes and restart durability; keyboard/mobile browser tests; Render staging known-SHA deploy with health/readiness and smoke checks; schema-compatible rollback.

**Commit order:** docs baseline → UI shell → SQL pool/database verification → identity and owner checks → metadata persistence → E2E tests → Render hardening → acceptance/rollback documentation. Merge only when gates pass, since `main` auto-deploys.

## Definition of done for every slice

- Usable UI with accessible states, real Erlang behavior and server authorization.
- PostgreSQL durable acknowledgements and versioned migration; safe concurrency/replay.
- EUnit + integration + browser tests including denial, failure and restart cases.
- Render staging smoke test on a known commit, flags and rollback documented.
- User-facing acceptance demonstration and feedback recorded.
- No parallel backend, no Django, no hidden legacy dependencies.

## Risks and open checks

Verify full repo inventory, exact migration versions, environment binding, applied SQL schema, private DB connectivity, legacy parity fixtures and worker deployment needs before changing production. Free Render PostgreSQL expiry must be addressed before relying on durable user data. Investigate observed Ranch/HTTP shutdown logs with deployment lifecycle context before calling them crashes.
