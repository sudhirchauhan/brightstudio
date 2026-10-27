# OCR and formatted Reader — 28 October 2026

Use Erlang/OTP, immutable revision text, the approved Quiet Studio UI, main only, and existing free staging.

1. Extract embedded PDF text; OCR empty scanned pages with bounded Poppler and English Tesseract. Preserve private temporary files, cleanup, output/time/page limits and SQL lease fencing. Existing committed revisions are immutable; re-upload to opt into new extraction.
2. Render original PDFs with pinned, locally served PDF.js: selectable text, page controls, zoom and accessible text fallback. Scanned pages retain the original image; OCR text is selectable in text view.
3. Render safe reflowable EPUB chapters in spine order: headings, emphasis, lists, tables and bounded PNG/JPEG illustrations. Strip executable content, publisher CSS and external references. Never inject publisher HTML.
4. Map formatted selections to exact canonical revision text, using existing evidence/notes APIs. Reject ambiguous or unmatched selections. Restore saved highlights and preserve revision switching, reading mode and fullscreen.
5. Verify scanned/mixed OCR, archive safety, private endpoints, actual rendered pages/chapters and annotation save/reopen on desktop/mobile. Deploy verified main to existing free staging and record evidence and limits.

Remote imports, Anki exports, sharing and production storage remain separate.

## Verification status

Implemented. All 78 desktop/mobile browser cases, 55 SQLite and 52 PostgreSQL cases passed, including actual OCR and formatted annotation save/reopen. Library feature gates passed. The production image built successfully with real OCR tests enabled. The free-resource check and hosted deployment acceptance are in progress. See [contracts and limits](reader-ocr-runbook.md).
