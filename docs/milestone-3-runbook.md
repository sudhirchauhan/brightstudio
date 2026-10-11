# Milestone 3 staging and rollback

Implementation/local acceptance and Render release are separate gates. Use `render-milestone-3.yaml` for separate staging web, worker and PostgreSQL services on milestone-3, with auto-deploy off and features initially disabled. This Blueprint provisions paid resources; approval of the provisioning costs is required before applying it. Existing main-linked services and their databases must remain intact.

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

The existing RENDER_API_KEY was reused successfully for service listing/details. The PostgreSQL API returned HTTP 403 with a Cloudflare response, so database API discovery was not completed. No staging resources or deployments have been created. Use Render dashboard/Blueprint provisioning after cost approval, or resolve the API access failure before automating it. No Render credentials are saved in source. Main remains unchanged.
