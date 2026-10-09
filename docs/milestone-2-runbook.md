# Milestone 2 staging and rollback

Local acceptance and staging release are separate gates. The staging Blueprint is `render-milestone-2.yaml`; it creates separate web and extraction-worker services on the milestone-2 branch with auto-deploy and feature flags off. It uses paid starter services; review costs before provisioning. No staging services have been created by this implementation.

Use the Milestone 1 runbook for private database setup, secure account provisioning and HTTPS cookie/origin configuration. Supply the same private DATABASE_URL to both roles, with verified TLS as required by the database. Never widen the database external allowlist. Originals reside in PostgreSQL and its backups; no public object URLs or persistent worker disk are needed.

Before enablement, back up the database and run the explicit migration job from the reviewed image:

```sh
bin/bright_studio eval 'bright_migrate_cli:main().'
```

Verify migrations 8 and 9 as well as 1–7. Run once as a reviewed job, not at each service startup. Provision staging users securely; never run the public acceptance fixture seeder against staging or real user data.

Deploy the exact reviewed SHA to both roles. Check web liveness and readiness, worker process health, and the presence of pdftotext/prlimit in the built image. Set the web BRIGHT_ORIGIN to its exact HTTPS origin. Enable STUDIO_HUB_ENABLED and STUDIO_LIBRARY_ENABLED on both roles only after these prerequisites pass. The web readiness check verifies the Library migrations when its flag is enabled. Worker has no HTTP listener.

Acceptance requires a real account uploading TXT, PDF and EPUB, observing queued/processing/ready or truthful failed states, reading text, and downloading the unchanged original. Confirm a second account cannot read or download it, wrong-origin/CSRF writes fail, and repeated upload keys create one revision. Restart both roles and verify sessions, revisions, originals and text persist. Stop the worker, upload, restart it and verify the durable job completes. SQL tests separately exercise expired lease takeover and reject stale completions. Run mobile and keyboard flows against staging; local checks do not establish Render behavior.

For an emergency gate, set STUDIO_LIBRARY_ENABLED=false on web and worker. File APIs return 404 and workers stop claiming jobs; metadata Hub remains available. A job already running cannot publish after the process observes the disabled flag. Lease tokens and expiry fence completions and allow recovery after re-enablement. Each abandoned lease gets at most three automatic attempts, then a failed state with manual retry. Do not delete revisions or restore an older backup to hide acknowledged writes.

Rollback both roles to the previously verified image while retaining additive tables and originals. A Milestone 1 image cannot read Milestone 2 files, but its metadata remains compatible. Restore Library only with an image that understands migrations 8 and 9. Keep a retention/backup policy for private originals before opening this bounded initial implementation to real users; deletion/export lifecycle, object storage and malware scanning are later work.

Render access is still required for these staged checks. Enter RENDER_API_KEY in cloud environment Settings → Secrets, targeted at api.render.com, then save/publish as the product requests. Do not put the key in Git, a tracked .env, or chat. Main merging and production cutover remain separate release decisions.
