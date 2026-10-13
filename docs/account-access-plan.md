# Account access and membership — 2026-10-13

The user authorized continuing the original-requirement gaps after learning milestones 6–9. Implement this milestone in Erlang/OTP, preserve the approved Quiet Studio UI, SQL authorization, existing private data, main and free-only hosting.

## Visible scope

1. **Account recovery:** request a reset link with an enumeration-safe response; use a short-lived, hashed, single-use token; change the password and revoke all sessions in one transaction. Never return a reset token through the public API. Delivery requires explicit configuration. A private local development outbox exercises the complete workflow without claiming hosted email delivery.
2. **Sessions:** show owned active sessions without bearer tokens, distinguish the current session, revoke another session or sign out all sessions. Preserve server authorization and clear local offline data when the current session is revoked.
3. **Workspace membership administration:** create an owned workspace, list its members, add an existing account, change roles and remove members with owner/admin boundaries, expected versions and exact retry receipts. Protect the workspace owner from accidental removal/demotion. Group membership alone does not expose another user's private sources, documents or offline packages; sharing those resources is a separate integration contract.
4. **Verification:** both SQL backends, reset expiry/replay/concurrency, session revocation, owner/admin denial, stale edits and receipt recovery, feature gates and actual desktop/mobile UI journeys. No public account provisioning or development credential bypass.
5. **Release:** deploy the verified application to existing free staging. Record any delivery configuration still required separately from implemented and tested behavior.

## Remaining sequence

After account access: richer Reader and import/export contracts, planner AI policy, rollout cohorts and operations metrics. Durable production storage, actual production data migration and a one-writer traffic cutover need a concrete production target. Legacy-history comparison was waived; it is not a prerequisite for these Erlang features.

## Status

Implementation and local verification passed: 72 main desktop/mobile browser cases, two separate recovery UI cases, 53 SQLite and 50 PostgreSQL cases, native three-citation comparisons, account restart/default-off/independent-gate/readiness checks and ten reviewed visual baselines. The user selected a local development outbox first. The final image built successfully using the smaller pinned Debian native stage; final free-resource and hosted release checks remain in progress.
