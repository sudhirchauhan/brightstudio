# Next milestone — Documents

Planned after Focus. No Documents implementation or release is claimed by this plan. Keep the approved Quiet Studio design, Erlang backend, SQLite development/PostgreSQL compatibility and free-only staging constraints.

## First visible feature

Create an owned project document, add/edit/reorder plain-text and quoted-evidence blocks, save a version, reopen it, and download a Markdown export with source/revision citations. Reading/exporting a saved document must retain the exact evidence provenance; concurrent edits must preserve the user's draft.

## Implementation sequence

1. Define owned documents, ordered blocks, document versions and mutation receipts. Store citations as owned evidence/source/revision references, with explicit unresolved states and no silent rebinding. Keep documents independent of Focus and Study progress.
2. Add additive SQL migrations and owner-scoped Erlang operations. Require expected versions for mutations; acknowledge after commit and preserve exact retry receipts. Bound document/block sizes and counts.
3. Build a minimal Documents list and block editor using shared styling. Include keyboard reorder/edit controls, citation selection, readable saved/conflict states and source links. Render user text safely; start with simple blocks rather than arbitrary HTML.
4. Export an exact committed document version as UTF-8 Markdown through an authenticated download. Include pinned citations, safe filenames, and clear unavailable/unresolved reference handling. No external publishing, provider or paid storage is needed.
5. Gate navigation, page, assets, APIs and exports with `STUDIO_DOCUMENTS_ENABLED`, default off. Verify ownership, stale/concurrent edits, replay, provenance, source-revision changes, safe rendering, exact export bytes, restart persistence and disabled gates on both databases and desktop/mobile.
6. Deploy a verified SHA to the existing free service and test the real create → cite → save → reopen → export journey. Record hosted evidence and obtain user product review; retain the free SQLite durability limitation.

The original roadmap remains unchanged. AI assistance, audio/OCR, offline/sync and production cutover remain later slices with their own gates.
