# Account access and membership

This milestone extends original slice 1. It adds account recovery through the user-selected local development outbox, owned session management and workspace membership administration. It does not imply sharing another account's personal projects/sources or configuring hosted email delivery.

## Configuration

`STUDIO_ACCESS_ENABLED` defaults off and requires Hub. Readiness requires the complete additive schema through version 41, independently of `STUDIO_WORKSPACE_ENABLED`. Cloud development and the existing staging blueprint explicitly enable Access.

For development recovery, set `BRIGHT_RECOVERY_DELIVERY=local` and an absolute `BRIGHT_RECOVERY_OUTBOX` path. The standard startup helper uses `/app/_build/recovery-outbox/development`, mounted at `erlang/_build/recovery-outbox/development`. Local recovery is permitted only at the approved loopback origins with the insecure-local-cookie opt-in. A hosted origin always reports local delivery unavailable; the UI explains that a delivery method is still required.

The operator outbox directory has mode 0700 and envelope files 0600. Each JSON file contains the recipient, reset link and expiry; it never contains a password. Tokens are secrets: inspect the envelope only in the private operator environment, never print/copy it into logs, Git or chat. Remove envelopes after use/expiry. The directory is under ignored `_build`; public APIs do not list it or expose reset tokens.

## Recovery and sessions

Request `/studio/recover/`; open the private envelope link at `/studio/reset/#token=…`; choose/confirm the new password. The browser removes the fragment from its address history once loaded and keeps it only in memory. Tokens expire after 15 minutes, are stored as SHA-256 hashes, and can be consumed only once. They are bound to the credential state, so a normal password change invalidates earlier reset links even if Access is temporarily disabled.

Known, unknown and disabled accounts receive the same accepted request message. Recovery attempts use a separate unchanged-strength ten-attempt/five-minute peer limit and at most five issued links per account/hour. Invalid input and missing delivery configuration have explicit errors. A successful reset changes the credential, consumes all outstanding links and revokes all sessions transactionally. Login first locks the user and then reads credentials in a new query, closing the PostgreSQL stale-snapshot race. The domain tests cover concurrent reset/reset and reset/login behavior.

`/studio/hub/access/` lists only the current account's active sessions, showing start/expiry and the current session. Session identifiers are hashes, never bearer tokens. Revoke one session or all sessions; revoking the current session also clears private offline copies and returns to sign-in. Failure to remove local copies produces the existing close-other-tabs warning while remote revocation still takes effect.

## Membership controls

Create up to 20 owned workspaces with up to 100 members each. Adding a member requires an existing active account and a viewer/editor/admin role. The immutable workspace owner cannot be removed/demoted, including via differently cased UUIDs. Only the owner can create/change/remove administrators; admins manage viewer/editor members; viewers/editors cannot manage membership. Non-managers do not receive the other members' email list. Removed members lose access to the workspace immediately.

Membership writes use the workspace's expected version, actor/user and workspace locks, and exact payload-bound receipts. Conflicts and uncertain responses keep input for explicit review/retry. All profile/session/CSRF checks remain active. Membership alone does not grant access to private learning resources; resource-sharing policy is a separate original-requirement integration.

## Checks and release

The main browser suite includes membership/session tests. `npm run test:recovery` is a separate desktop/mobile suite so the unchanged login-per-IP limiter is respected; run it after a normal owned-release restart if prior tests exhausted the limit. Recovery fixtures and their credentials are local/CI only. The acceptance helper creates a new disposable database and a separate private outbox, recording their paths under `_build/latest-acceptance-*`.

`tests/access-release-checks.js` requires an explicit disposable database in Docker. It proves session/membership persistence, receipt replay, disabled/default-off routes, independent feature flags, schema readiness and single-use reset/session revocation after server restart. Never run it against real user data. CI installs the real native models, tests both SQL backends and runs the separate recovery flow.

After isolated acceptance, migrate the retained development database in a separate release process if necessary, then restore `scripts/cloud-sqlite-start.sh`. Keep source, databases, model artifacts and outboxes when clearing build cache. The C++ model-tools Docker stage now uses pinned Debian rather than the Erlang build image to reduce temporary disk requirements; the application build remains pinned OTP 27.

Delivery evidence belongs in [the current milestone plan](account-access-plan.md). The existing free Render service uses the same private bootstrap credential. Free staging SQLite remains ephemeral; hosted email, durable production storage and a production cutover are separate work.
