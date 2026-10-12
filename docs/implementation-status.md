# Bright Studio implementation status — 2026-10-12

The original roadmap is [Full UI-first Erlang/OTP Delivery Plan](bright-studio-full-ui-first-erlang-plan.md). It remains the source for the complete rewrite; the milestones delivered so far cover a smaller Learning Hub scope. The original roadmap file has not been rewritten to imply completion.

## Original roadmap and actual status

| Slice | Original scope | Current status | Remaining work |
|---|---|---|---|
| 0 | Foundation and design | OTP/Cowboy application, responsive Hub and free staged demo implemented | Broader product design acceptance and production operations |
| 1 | Account and workspace | Private sessions, project create/rename, tasks, daily planning, display names/timezones and current-password changes implemented; local and hosted desktop/mobile checks passed | User design acceptance/UI alignment, recovery delivery/membership administration and production import/cutover |
| 2 | Library and Reader | Uploads, private originals, immutable revisions, TXT/PDF/EPUB extraction and extracted-text Reader implemented; demo verified | Layout-faithful reading, remote imports and production durability are not claimed |
| 3 | Evidence and notes | Exact revision-pinned quotes, UTF-8 anchors, annotations, versioned edits/history and project boards implemented; demo verified | Product acceptance and production release gates |
| 4 | Study workflow | Revision-pinned recall lessons, attempts, feedback, reflection gate and resume implemented; local and hosted desktop/mobile checks passed | User design acceptance and production durability |
| 5 | Focus | Implemented: owned task/source sessions, pause/resume, checkpoints/evidence, server-time completion and reflections; local SQL/browser/restart and actual hosted desktop/mobile checks passed | User product review and production storage durability |
| 6 | Documents | Not implemented | Cited blocks, revisions, concurrent-edit handling and export |
| 7 | AI assistant | Not implemented | Grounded provider adapters, citation policy, budgets and cost tests |
| 8 | Audio and capture | Not implemented | Recording, transcription, OCR and bounded private jobs |
| 9 | Offline and sync | Not implemented | Offline packages, replay receipts, conflicts and authorization |
| 10 | Cutover and rollout | Not implemented | Complete legacy parity, data migration, capacity/recovery and one-writer cutover |

Milestone 1 delivered the Hub/authentication/source-metadata walking skeleton, not all of original slice 1. Milestones 2 and 3 delivered Library/Reader and Evidence/Notes. A SQLite development demo is not full legacy rewrite completion or a durable production deployment.

## Current development and deployed state

- SQLite development is implemented alongside the PostgreSQL backend. Application/domain logic remains Erlang/OTP. Versioned SQLite migrations cover versions 1–28; PostgreSQL migrations and TLS checks remain intact.
- Default cloud development uses `scripts/cloud-sqlite-setup.sh` and `scripts/cloud-sqlite-start.sh`, with the `bright-sqlite-dev` container, a retained workspace SQLite file and supervised extraction in the web VM. Existing PostgreSQL files/volumes are preserved.
- Render service: `brightstudio-m1-staging` (`srv-db5qa5bl550s73b1qu40`), Frankfurt, **free**, `milestone-3`, auto-deploy off. Live application commit: `f48e63101096b1e635d3d1a7c89d933908c11086`; deploy `dep-db6ire8473hc73dhti4g`. `/readyz` is the deployment health check.
- URL: https://brightstudio-m1-staging.onrender.com/studio/login/ . Hub, Library, Evidence, Study, Workspace, Focus and web extraction are enabled. A private getting-started source, note and board were added through the real hosted APIs.
- Development login email: `developer@brightstudio.test`. The securely generated password stays in that service's Render Environment setting `BRIGHT_BOOTSTRAP_PASSWORD`; it is not recorded in source or test logs. Normal session, cookie, CSRF and ownership checks remain active.
- Hosted SQLite is disposable: free Render instance replacement/redeploy/restart can erase saved data. The UI displays a notice. Local data survives Erlang process restarts while the workspace files remain. No production durability is asserted.
- No paid database, worker or disk was provisioned. No main merge, original development-service change, legacy import or production cutover occurred.

## Verification evidence

- 42 SQLite EUnit/domain/integration tests passed, including migration serialization/replay, transaction rollback, blob byte fidelity, injection-shaped bound input, sessions, owner isolation, immutable revisions, extraction leases and evidence conflicts/provenance.
- 39 PostgreSQL regression EUnit tests passed, preserving the original backend and TLS failure behavior.
- All 40 desktop/mobile Playwright cases passed on SQLite. Workspace project/task/date/profile/session/receipt persistence and disabled/private-route restart checks passed, alongside separate desktop/mobile password UI/session-revocation checks. Existing Library/Evidence/Study browser regressions passed.
- Release checks passed for session/source persistence across Erlang process restart, feature gates, missing-database readiness and worker-only roles.
- Docker packaging and the packaged opt-in development bootstrap passed private login, Unicode upload/extraction, evidence/note persistence, session persistence and idempotent bootstrap replay across a container restart.
- The final live Render commit passed trusted-HTTPS readiness, login, project access, TXT upload/extraction, Reader content, resolved evidence, note creation/reopen, board linking, and authenticated Hub/Library/Reader/Evidence HTML responses.
- Full hosted desktop/mobile browser acceptance and user design acceptance remain separate checks. GitHub CI now has PostgreSQL/SQLite matrix jobs; no GitHub-hosted execution result is asserted here.

See [SQLite development](sqlite-development.md), the milestone acceptance/runbook documents, and [Revised delivery plan](revised-delivery-plan.md).

## Hosted browser acceptance update

The seeded development demo now restores its bundled samples after a free SQLite instance reset. Live application SHA `707b20a7fa6d92fdc463b376805ac5acb35e11ce`, deploy `dep-db657sl9fdbs73erqff0`, passed actual public-site Chromium desktop/mobile-viewport journeys for login, all sample formats, highlights, revision history, boards, note history, fresh UI uploads/annotations/edits, private downloads, reload persistence and sign-out. 34 SQLite EUnit tests passed, including sample replay preserving user-edited notes. See [hosted demo acceptance](hosted-demo-acceptance.md). User design acceptance, other-browser/device checks and production release gates remain outstanding.

## Milestone 4 hosted release

Study is live at application SHA `a9e6f1cfda3dad52269316ea5b2923e5f92688c7`, deploy `dep-db69sm7avr4c73amhqbg`, on the existing free service. Actual Chromium desktop/mobile hosted checks passed signed-out Study → sign-in → Study, private UI upload/extraction, revision-pinned start, wrong/correct answers, reload/resume, reflection completion, completed review, responsive layout and sign-out/API privacy. `/healthz` and `/readyz` return 200. See [Milestone 4](milestone-4-plan.md). User design acceptance and production storage/cutover remain pending.

## Current workspace milestone

The user requested direct Erlang implementation without legacy-history comparison. Project/task/daily-planner/account features are live; local SQL, browser, password and restart checks and hosted desktop/mobile journeys passed. See [current milestone plan](workspace-planner-plan.md). [UI alignment with the original mocks](ui-alignment-plan.md) is now the next dedicated milestone, before Focus. Original visual-reference matching remains pending; the functional UI is not claimed to match those mocks.

Workspace live SHA `6d071ef51fb7225f75ca39302d373ed946f56e1e`, deploy `dep-db6dc1ss728c7383irm0`, passed the public Projects/Tasks/Planner/Account journey, five seeded tasks, preserved bootstrap credentials and `/healthz` + `/readyz` 200 on the free service. See [current milestone release evidence](workspace-planner-plan.md). UI alignment is now the next milestone.

The current application release adds a verified public fictional-JPG gallery at https://brightstudio-m1-staging.onrender.com/studio/mockups/ . `STUDIO_UI_MOCKS_ENABLED=true` is enabled on staging; all normal account/source APIs remain private. This fixes delivery of previews when the chat file viewer displays “No image”; the new application design still awaits review/implementation.


## Approved Quiet Studio UI implementation

The user approved the new JPG concepts on 2026-10-12 and authorized applying them. The new warm-white/teal shell, compact rail/mobile Menu, flat source/task rows, shared forms, centered serif Reader, on-demand evidence drawer and one-question Study layout are implemented. Reader and Study support independent distraction-free modes and user-triggered browser fullscreen, with discoverable exits/Escape and an unsupported-browser fallback. Revision context, draft answers, saved progress and private authorization remain intact. The Overview uses real ready sources for reading/Study actions; it does not invent reading bookmarks. See [UI alignment screen/state matrix and checks](ui-alignment-plan.md). All 46 local desktop/mobile cases passed, followed by six final UI cases and a separate ten-snapshot comparison, plus two private-asset checks. Hosted desktop/mobile acceptance passed on the deployed UI; final user design acceptance remains separate.


Latest UI application release: `5f27e51aafb0d71d84f9086d2b34a45533b75878`, deployment `dep-db6hgvff3r2c73cahld0`. Desktop/mobile live browser checks passed the complete upload → Reader → notes → Study/feedback/reflection → resumed completion journey and all workspace screens, including actual native fullscreen/Escape. The public mock gallery remains a concept reference; the signed-in application now uses the approved Quiet Studio design. Focus is the next feature milestone after deployed UI review.


## Milestone 5 — Focus delivered

Focus is implemented behind `STUDIO_FOCUS_ENABLED`, default off. Additive SQL migrations 24–28 preserve earlier data. The timer uses server anchors and persisted paused time; completion requires planned elapsed time, a saved checkpoint and reflection, with version/replay guards and one open session per owner. Study/task progress remains independent. SQLite (43) and PostgreSQL (40) domain checks, all 52 desktop/mobile browser cases, and full-release persistence/default-off/independent-gate checks passed. An authenticated feature bundle fixes the observed private-script 503 race. Hosted desktop/mobile acceptance passed; [Focus contracts](milestone-5-plan.md) record scope and limitations.

Focus live application `f48e63101096b1e635d3d1a7c89d933908c11086`, deployment `dep-db6ire8473hc73dhti4g`, remains on the same free service. Actual one-minute desktop/mobile timers passed private sign-in return, task/pinned-source entry, pause/reload/resume, native fullscreen/Escape, saved checkpoint, early-completion rejection, reflection completion and saved review. No hosted clock override was used. `/healthz` and `/readyz` returned 200; Focus readiness requires the complete migration set through 28. A saved-state refresh race found during live testing was fixed and checked on both viewports. [Documents](milestone-6-plan.md) is the next planned milestone; it has not been implemented.
