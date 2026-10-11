# Milestone 3 staging and rollback

Implementation/local acceptance and Render release are separate gates. Use `render-milestone-3.yaml` for separate staging web, worker and PostgreSQL services on milestone-3, with auto-deploy off and features initially disabled. This Blueprint provisions paid resources. The user authorized deployment on 2026-10-11; use dedicated staging resources. Existing main-linked services and their databases must remain intact.

## Migration and enablement

Back up a non-disposable database before migrations. Run the reviewed release migration as one explicit job, never on web/worker startup:

```sh
bin/bright_studio eval 'bright_migrate_cli:main().'
```

Verify migration versions 1–15. Versions 10–15 are additive: revision ownership key, evidence, anchor index, note audit history, boards and links. Each migration contains one statement, as required by the existing runner. Composite ownership keys prevent mixed-owner links even below the domain API. An old image remains schema-compatible.

Provision dedicated staging accounts securely, configure the exact HTTPS BRIGHT_ORIGIN, and verify web health/readiness and worker process health on the exact reviewed SHA. Never run the public acceptance seeder against real users or a production database. Do not open an external database allowlist. Database access remains private; use reviewed service-side jobs to inspect migration state.

Enable STUDIO_HUB_ENABLED and STUDIO_LIBRARY_ENABLED on web/worker, then STUDIO_EVIDENCE_ENABLED on web. Evidence is disabled unless all three are true. The evidence worker flag is unnecessary because all evidence writes are transactional web operations; the extraction worker remains responsible for source readiness.

## Staging acceptance

Verify the complete Library journey plus Unicode highlights, exact quote rejection, annotations, note edit conflicts and history, linking to another owned project's board, and opening the pinned revision. Another owner must receive 404 for evidence, history, board details and links, and 403 for another owner's project list/write. Missing/wrong-origin CSRF must fail. Retrying create/edit keys must deduplicate; board links must be idempotent. New source revisions must leave old evidence pinned, and unresolved anchors must never be silently reassigned.

Restart web and worker, then reopen notes, history, originals and board links using the existing session. Disable evidence, verify pages/assets/APIs are 404 while Library works, and re-enable to verify records persist. Repeat mobile, keyboard and selection journeys on staging; local Playwright results do not prove Render behavior.

## Rollback and limits

Set STUDIO_EVIDENCE_ENABLED=false on web to gate evidence without deleting data; leave Library enabled if it is healthy. Roll back web/worker to the verified Milestone 2 image if needed, preserving the additive schema and all evidence/audit rows. Never use a stale database backup to erase acknowledged writes. Restore evidence only with a compatible release.

Initial limits: 1,000 evidence items and 100 boards per owner, 1,000 links per board, 2,048-character/8 KiB quotes, and 4,000-character notes. Note history APIs return the latest 1,000 versions. Overlapping anchors retain exact provenance but only non-overlapping marks are painted; all quote cards remain available. PDF/EPUB highlights refer to extracted text, not original page coordinates. Public sharing, deletion/retention UI, export, study, AI and cutover are later work.

## Current external status

On 2026-10-11, the user authorized upgrading the newly created `brightstudio-m1-staging` service instead of creating another web service. Service `srv-db5qa5bl550s73b1qu40` now tracks `milestone-3`, with auto-deploy off and HTTPS origin `https://brightstudio-m1-staging.onrender.com`. Render reports deploy `dep-db5qau8473hc73c25nng` live at commit `a2f6a4209aa729d43904363beabd3974e53ee4b0`. The existing main-linked development service was not changed.

This is a code deployment, not functional acceptance. The staging service has no DATABASE_URL configured; Hub, Library and Evidence remain disabled. No extraction worker has been created. The user has been asked to configure a dedicated PostgreSQL 17 database in Frankfurt, keep external access disabled, and save its internal connection URL in the staging service's Render environment. Do not copy database credentials into source, logs or chat, or reuse the public acceptance fixture credentials.

The existing RENDER_API_KEY works for service reads, updates and deployments. PostgreSQL and Blueprint create operations returned Cloudflare HTTP 403; database discovery and provisioning remain blocked from this machine. Public-site verification also encountered an environment egress-proxy CONNECT 403. The staging hostname was added to the saved environment network draft, preserving api.render.com; review/save and publish are required to activate that draft. No public-site health or functional checks have passed yet.

After DATABASE_URL is saved, verify that it identifies the dedicated private staging database, run the explicit migration job from the reviewed release and verify versions 1–15. Provision secure staging accounts, configure the extraction worker with the same private database, enable the feature flags, and run staging acceptance before describing the URL as ready for Library/Evidence testing.
