# Formatted Reader and PDF OCR

## Reading and annotations

Open Library, upload a PDF/EPUB, wait for extraction, then open Reader. Choose **Formatted original** in the View control. PDF pages have page navigation and fit-width/125/150/200% zoom; EPUBs reflow with chapter navigation, headings, emphasis, lists/tables and bounded PNG/JPEG images. Text and annotations remains the default accessible view. Reading mode and fullscreen continue to work independently.

Select text in a digital PDF or EPUB and choose Capture selected text. The selection must match a unique passage in the immutable revision's canonical text. Whitespace is normalized for matching only; the saved quote and UTF-8 byte offsets come from exact canonical text. Repeated/unmatched selections are rejected and direct the reader to the precise text view. Saved notes remain on their original revision. Formatted highlights use the browser CSS Highlight API; text-view highlights remain available when that API is unavailable or a quote crosses unsupported layout boundaries. Show highlight uses the formatted range when available and otherwise opens its exact text anchor.

Scanned PDF pages display their original image. Their OCR text is selectable in Text and annotations view; this release does not position an OCR selection layer over the scanned image. English OCR is automatic for pages without embedded text, including mixed PDFs. Pages with any embedded text retain it; partial-image regions on such a page are not separately OCRed. Existing committed revisions are not re-extracted; upload a new revision to use the new OCR pipeline.

## Limits and safety

Existing uploads remain limited to 4 MiB. PDF extraction/viewing accepts at most 200 pages; at most 12 empty/scanned pages are OCRed in one extraction. Poppler uses 2,200-pixel rasterization; each native process has 256 MiB address space, 25 CPU seconds, at most 30 wall seconds, bounded file/output size and no core dumps. The complete extraction has a 120-second wall budget. Limit failures are explicit, never truncated success. Empty or unreadable scans return no_text. OCR is English and may contain errors; review source images before citing.

Source workers acquire the shared native slot before claiming a SQL job, avoiding lease expiry while waiting behind generation/media. The lease is 180 seconds and completion still checks its fencing token and owner. Private temporary directories are mode 0700, originals/images mode 0600, and all generated files are removed after success/failure. Native tools strip secret-bearing environment variables. OCR results use the existing immutable source revision and private evidence APIs.

The EPUB parser retains bounded ZIP/CRC/expansion checks, entity rejection and heap/time limits. Relative references resolve inside the archive; escape, absolute and remote paths are rejected. The server returns declarative nodes; the browser creates only allowlisted elements. Scripts, handlers, forms, embedded documents, SVG, publisher CSS and external URLs are excluded. Supported raster images are at most 1 MiB each. This is safe reflow, not exact reproduction of publisher CSS or DRM support.

PDF.js 4.10.38 is pinned in package-lock.json and vendored under bright_web/priv/static/pdfjs, including its Apache-2.0 license. Run `npm ci` and `node scripts/vendor-pdfjs.js` to reproduce assets. Eval is disabled; document JavaScript, forms, attachments and external links are not executed/rendered by this page/text-layer viewer. Only one page is rendered at a time. Page viewport area/dimensions and image size are bounded; PDF attachments remain part of the private downloadable original. The Reader HTML alone permits inline layout styles and self-hosted workers/fonts/raster images; inline scripts remain blocked. Other routes retain their previous CSP.

All original, chapter and PDF asset routes require authentication and Library enablement. Book reads first authorize ownership of the exact source revision. No CDN, public document URL, provider account or paid hosting is required.

## Verification and operation

- `rebar3 eunit --module=bright_extract_tests`: real scanned/mixed PDFs, embedded text, safe EPUB formatting/order and archive paths.
- Full EUnit: 55 SQLite and 52 PostgreSQL cases passed with native models enabled.
- Full desktop/mobile browser suite: 78 cases passed, including six new Reader cases and existing visual/UI/fullscreen checks.
- `BRIGHT_TEST_DOCKER_CONTAINER=bright-sqlite-dev node tests/reader-gates-checks.js`: new Library feature gates passed on a disposable acceptance database.
- Real mixed-PDF OCR and private PDF assets passed at 512 MiB / 0.1 CPU without OOM.
- Production Docker build runs its real OCR tests; its build and runtime stages both install Tesseract/Poppler. Fresh cloud setup also installs both prerequisites.

Deploy and actual hosted acceptance are recorded in reader-ocr-plan.md. Keep the existing free service and preserve the normal development SQLite database. Free hosted SQLite remains ephemeral; this milestone adds no production durability. Disabling Library hides formatted assets/API while retaining original revisions and notes.

## Hosted release

Application `aaf3bf6ea4a992bd4a5a4d84e4c4bf9476bb4724`, deployment `dep-dbggfjuk1f9s73e893b0`, is live on the existing free service. Six hosted desktop/mobile PDF/EPUB/scanned-PDF journeys passed, including annotation save/reload and sign-out privacy. Reviewed screenshots and logs are under ignored erlang/_build/setup-logs/hosted-reader. Library contains labeled Reader demo sources for testing. No paid resource, password change, new feature branch or production data/traffic cutover occurred.
