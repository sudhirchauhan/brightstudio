# Milestone 3 acceptance evidence

Status: implementation and local acceptance complete; Render staging is a separate pending release gate. Branch milestone-3, based on Milestone 2 commit 651ac8e. Main has not been merged or deployed.

## Delivered

Reader captures browser selections or a unique exact quote through keyboard controls. The server validates ready revision ownership, UTF-8 byte boundaries and quote equality; immutable source/revision IDs, offsets, quote and extracted-text SHA-256 are stored. New source revisions do not relocate evidence. A hash or quote mismatch is explicitly unresolved. Highlights and note cards use safe text rendering.

Notes use SQL compare-and-swap versions, append audit history, and retain idempotent receipts. Concurrent edits cannot silently overwrite. The conflict UI preserves a draft, shows the latest server note and requires an explicit save against the refreshed version. Creation retries return the same evidence item; changed payloads conflict. Project boards can link evidence from another project owned by the same user while retaining original source/revision provenance. Composite SQL ownership keys block mixed-owner references.

STUDIO_EVIDENCE_ENABLED defaults off and requires Hub and Library. It gates the board page, evidence asset and APIs. Library remains available when only evidence is disabled. Capture controls are disabled until reading text is loaded. Lists, quotes, notes, boards and creation quotas are bounded; all acknowledgements follow commit.

## Local evidence — 2026-10-11

| Gate | Evidence | Outcome |
| --- | --- | --- |
| Build/domain/SQL | 31 EUnit tests, OTP 27 and PostgreSQL 17; includes all previous milestone suites | Passed |
| Anchors | Unicode byte boundaries, repeated quote positions, false quote rejection, pending revision rejection, immutable revision isolation, damaged derived-text detection | Passed |
| Ownership | evidence read/edit/history/creation, project boards, links; SQL mixed-owner foreign-key rejection | Passed |
| Notes/concurrency | concurrent HTTP creation deduplicates; concurrent note edits yield one success/one conflict; retries retain one audit version | Passed |
| Cross-project boards | same-owner project links retain original source/revision; different-owner board link denied | Passed |
| Browser | 22 desktop/mobile cases, including all 16 previous cases; keyboard notes/boards, real selection, revision labels, conflict recovery | Passed |
| Release lifecycle | all previous restart checks plus pinned quote, note history and board links persist; evidence disable/re-enable gates and retains records | Passed |
| Docker | 28 build-time EUnit cases; non-root 164 MB image; all 3 new desktop cases pass against built web/worker images | Passed |

The first browser run exposed initially enabled capture controls before Reader content loaded; that was corrected and the full final suite passed. A baseline worker restart check used a fixed delay; it now waits for a successful ping and the complete release checks passed. SQL tests establish actual unresolved provenance behavior; one browser test supplies an unresolved response to verify its presentation. Baseline loading/empty/dependency UI cases use controlled responses; authorization, concurrency and persistence checks use the real PostgreSQL-backed API and worker.

## Reproduce

Use the existing checkout; no extra Git worktree is needed.

```sh
bash scripts/cloud-setup.sh
bash scripts/cloud-start.sh
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium npm run test:e2e
BRIGHT_TEST_DOCKER_CONTAINER=bright-m1-dev node tests/release-checks.js
BRIGHT_TEST_DOCKER_CONTAINER=bright-m1-dev BRIGHT_TEST_WORKER_CONTAINER=bright-m2-worker node tests/library-release-checks.js
BRIGHT_TEST_DOCKER_CONTAINER=bright-m1-dev node tests/evidence-release-checks.js
```

Setup stops the isolated extraction worker during domain lease tests, applies/replays migrations in SQL tests, builds the release and seeds only the disposable acceptance database. Startup enables Hub, Library and Evidence locally and starts the separate worker. Repeat full browser runs after restarting the web release to reset its per-IP login limit; do not weaken that limit. CI uses the equivalent native workflow with a distinct worker node name.

## Release boundary

The Render key is now usable for read-only service inspection. Database API reads returned Cloudflare HTTP 403; staging is unverified and no new resources were provisioned. The [staging Blueprint](../render-milestone-3.yaml) and [runbook](milestone-3-runbook.md) are ready for a reviewed deployment with separate paid resources. No hosted CI result, live test URL, production parity or main merge is implied by these local checks.
