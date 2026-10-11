# Milestone 3 — Evidence and notes

Roadmap slice 3: highlight, annotate and link evidence to project boards. Baseline 651ac8e; branch milestone-3. No main merge or production cutover.

## Contract

An evidence item records immutable source/revision IDs, UTF-8 byte offsets, the exact quote and a SHA-256 hash of the extracted text. The server validates the selected quote against the authorized ready revision; malformed, empty, oversized and stale selections are rejected. No anchor is automatically moved to another revision. Older-revision evidence remains pinned and is visibly labelled; changed/missing text is unresolved.

Notes are plain text, limited to 4,000 characters. Edits use an expected version with compare-and-swap, append durable note history and preserve idempotent edit receipts. Conflicting edits return 409 with no overwrite. Creation retries deduplicate by owner/key and exact canonical request hash. Write success follows SQL commit.

Boards belong to an authorized project and owner. Evidence can be linked to boards in any project owned by that same user; its original source/revision provenance is retained. Composite foreign keys prohibit mixed-owner evidence and links. Lists and creation quotas are bounded. No public shares, remote imports, AI summaries or study progress.

STUDIO_EVIDENCE_ENABLED defaults off and requires Hub and Library enabled. Gate APIs, board pages, evidence JavaScript and UI consistently. Disabling preserves records. Existing Library and Reader journeys remain functional.

## UI and acceptance

Reader offers browser text selection and a keyboard-friendly quote search alternative, annotation form, pinned quote/note cards, jump-to-highlight, earlier revision labels, unresolved states and note conflict recovery. Project boards list pinned evidence with source/revision links; empty, loading, denied and failure states are explicit. Untrusted text uses textContent.

Verify Unicode byte boundaries and duplicate quote offsets, server provenance and wrong-quote rejection, unauthorized evidence/boards/history/links, CSRF, concurrent creation and edits, source revision isolation, note audit history, process restart durability, default-off gates and desktop/mobile keyboard flows. Render known-SHA staging remains a separate credential-dependent release gate.
