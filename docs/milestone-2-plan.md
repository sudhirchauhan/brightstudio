# Milestone 2 — Library and Reader

Scope selected by the user: roadmap slice 2, uploads, private storage, extraction and reading.
Baseline: milestone-1, commit 096213c. Work branch: milestone-2. No main merge or production cutover.

## Contract

- Add source metadata with an optional TXT, PDF or EPUB original; upload new immutable revisions to an existing source.
- Store private originals in PostgreSQL bytea, alongside SHA-256 checksums and revision metadata. This bounded first storage adapter requires no public bucket and survives web/worker restarts. Cap uploads at 4 MiB, extracted text at 2 MiB and originals per owner at 64 MiB.
- Authorize uploads, revision history, extracted content and original downloads by source owner. Require existing sessions, same-origin and CSRF on writes. No remote URL fetching.
- A revision and queued job are committed together before upload success. Owner/idempotency key retries return one immutable revision; differing content conflicts. No successful extraction is reported until committed.
- Separate supervised worker role claims SQL leases using SKIP LOCKED, fencing tokens, expiry and bounded recovery. Disabled accounts and feature flags prevent processing. No in-memory-only job authority.
- TXT extraction validates UTF-8; PDF uses a bounded native pdftotext process; EPUB uses bounded in-memory ZIP and ordered spine text extraction. Reject unsafe archive/XML features. Render extracted text safely; originals remain authorized downloads. Layout-faithful PDF/EPUB rendering, OCR and remote imports are not claimed.
- Reader supports immutable revision links, revision selection, processing/failure/retry states and text reading. Library shows accurate extraction status. Preserve metadata-only sources.
- STUDIO_LIBRARY_ENABLED=false by default gates file UI, APIs and workers while retaining data. STUDIO_HUB_ENABLED continues to gate the whole Hub.

## Acceptance

Compile, EUnit and OTP release; real PostgreSQL upload/read, idempotency, owner isolation, quota and immutable revisions; expired lease recovery and stale completion rejection; TXT/PDF/EPUB extraction and corrupt/unsafe inputs; CSRF and private downloads; desktop/mobile upload, Reader and failure states; web/worker restart durability; disabled flag behavior; reproducible cloud startup and Docker packaging.

Render staging needs separately supplied Render access and same-region private DB/worker deployment. Local acceptance is not staging proof. Use the milestone 1 rollback principles: additive migrations and retained originals, never destructive down migrations.
