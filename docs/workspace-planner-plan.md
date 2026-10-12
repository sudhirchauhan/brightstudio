# Current milestone — Account, workspace and planner in Erlang

The user requested this step from the revised delivery plan, then specified direct Erlang implementation without legacy-history comparison. This scope delivers functional project/task/planner/account management; it does not certify equivalence to an unseen legacy application. The next milestone is [UI alignment with the original mocks](ui-alignment-plan.md), before Focus.

## Feature contracts

1. **Projects:** create and rename private projects. Renaming preserves IDs and all existing Library, Evidence and Study references. Changes require the expected version; exact retry receipts prevent duplicate creation/edits. No delete/archive or sharing/invitations are included.
2. **Tasks:** create/edit tasks, move between owned projects, set priority (high/normal/low), estimate (5–480 minutes), note (2,000 characters), due/scheduled dates, and todo/doing/done state. Complete/reopen actions use the same server version checks. Completion timestamps are server-owned and preserved on edits to completed tasks; reopening clears the timestamp.
3. **Daily planner:** select a civil date and see scheduled, due or overdue open work in the current project; scheduled/due completed work remains visible on its matching day. Filter/search and open-task estimates are derived from committed records. Dates remain literal ISO calendar dates, validated for real days from 1900 through 2100; no UTC conversion changes their day. The saved timezone determines the default Today date. Selected planner day survives refresh through the URL; active project is remembered only as a navigation preference and remains server-authorized.
4. **Account:** save display name and an IANA timezone from the bundled canonical zone-name list. Display names are used in the account header. Profile edits use expected versions, retry receipts and draft-preserving conflict recovery. Email/signup, invitations, recovery delivery and legacy imports are outside this scope; provisioning/recovery remain operator concerns.
5. **Passwords:** require the current password and an active session, accept a different new password of 12–1,024 UTF-8 bytes, replace the salted PBKDF2 hash and revoke every existing session atomically. The user signs in again after success. Wrong-password attempts are limited per account, independently of the unchanged login-per-IP limit. Passwords are not stored in mutation receipts or logs. A lost response can mean the change committed; the UI directs the user to sign in with the new password if the session has ended.

## Storage and API

Additive PostgreSQL/SQLite migrations 19–23 add project versions, account timezone/profile versions, owner-scoped tasks and workspace mutation receipts. Mutation writes and receipts share an owner-serialized transaction; exceptions and error results roll back. Task-project foreign keys include the owner. Limits are 100 projects, 1,000 tasks and 10,000 workspace receipts per owner; title limits are 200 characters and display names 100.

`/studio/api/workspace/projects` and `/:id` support private reads, creation and versioned renaming. `/studio/api/workspace/tasks?project_id=…&day=…` lists tasks; `/tasks/:id` reads/edits an owned task. `/account` reads/edits only the authenticated profile. `/password` changes only that authenticated user's password. Cookie writes require origin and CSRF; project/task/profile mutations also require idempotency keys. Same keys with changed requests conflict. APIs and client assets remain private; signed-out HTML pages redirect to safe login return paths.

`STUDIO_WORKSPACE_ENABLED` defaults off and requires Hub. It consistently gates Projects, Tasks, Planner, Account, their script and APIs, with enabled-schema readiness checks for versions 19–23. Library/Evidence/Study stay independently gated. Turning Workspace off retains every record and the existing Hub project selector.

## Private demo samples

The opt-in SQLite demo bootstrap adds five labeled sample tasks: planned, in progress, tomorrow, completed and unscheduled. A separate per-owner/version marker prevents replay from overwriting user-edited tasks. The seed date is saved before creation so interrupted bootstrap retries use identical request bodies. Samples regenerate after a disposable instance reset; user-created data does not. PostgreSQL and normal deployments do not gain automatic fixture seeding.

## Verification and release plan

Run the reusable SQLite setup/start helpers, SQL/domain tests on both databases, the complete desktop/mobile browser suite, `tests/workspace-release-checks.js` and the separate `tests/account-password-ui.js`. Restart the acceptance web release before each complete browser/password/restart run to reset the unchanged login limiter, rather than weakening it. The password UI harness uses separate local fixture accounts and restores their initial passwords; it never changes the hosted bootstrap password.

Verify owner isolation, invalid/leap/DST-boundary civil dates, project moves, concurrent/stale versions, exact/changed-request retries, transaction rollback, profile conflicts, password correctness/all-session revocation, sample replay, disabled gates, dependency errors, restart persistence, private redirects and existing feature regressions. Deploy a verified SHA to the existing free staging service, enable Workspace after schema initialization, and test the actual hosted Projects/Tasks/Planner/Account journey on desktop/mobile. Preserve the existing bootstrap credentials, main branch/service and free-only constraint.

Local checks passed: 42 SQLite EUnit tests, 39 PostgreSQL EUnit tests, all 40 desktop/mobile Playwright cases, workspace restart/gate/privacy checks, and separate desktop/mobile password-change/session-revocation UI checks. The final cloud setup/start helpers were rerun successfully. Hosted release evidence is recorded after deployment. The original roadmap stays unchanged. Production durability, email recovery, multi-user workspace administration, legacy import/cutover, GitHub-hosted CI and user design acceptance remain separate work.
