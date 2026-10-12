# Hosted SQLite demo acceptance — 2026-10-12

Target: https://brightstudio-m1-staging.onrender.com . Render service `srv-db5qa5bl550s73b1qu40`, free plan, application SHA `707b20a7fa6d92fdc463b376805ac5acb35e11ce`, live deploy `dep-db657sl9fdbs73erqff0`. Main and the original main-linked service remain unchanged.

The initial live browser check found an empty Library despite successful login: manually seeded data was no longer present in the disposable SQLite instance. The opt-in development bootstrap now restores versioned bundled samples when the database is recreated. Its completion marker preserves user edits on replay. It restores samples, not lost user documents; the UI continues to display the free-hosting reset notice.

## Checks actually executed

A real headless Chromium 151 browser opened the public HTTPS site, signed in with the private bootstrap account, and exercised the following at desktop 1280×800 and mobile viewport 390×844:

| Journey | Result |
|---|---|
| Private sign-in and seeded Library | Passed |
| All seven sample sources and development reset notice visible | Passed in both viewports |
| TXT, Unicode, PDF and EPUB text displayed with seeded highlights | Passed in both viewports |
| Revision selector and earlier-revision evidence | Passed in both viewports |
| Empty Reader and upload action | Passed in both viewports |
| Deliberately damaged PDF, truthful failure and retry | Passed in both viewports |
| Populated board, note versions and pinned Reader link | Passed in both viewports |
| New source/file upload through the UI | Passed in both viewports |
| Keyboard quote capture, note creation and edit | Passed in both viewports |
| Board linking, exact private download bytes and reload persistence | Passed in both viewports |
| No horizontal overflow on checked pages | Passed in both viewports |
| Sign-out and no uncaught page JavaScript errors | Passed |

Two additional browser-test sources/notes were created in the development account. Existing seed notes were not overwritten. Library screenshots were captured locally during the run. Browser HTTPS verification stayed enabled; the existing cloud proxy CA was imported into Chromium's active NSS trust store to resolve the initial environment certificate-trust failure. No credential or session values were written into the report or screenshots.

34 SQLite EUnit/domain/integration tests passed, including the new sample bootstrap check: seven sources, six ready and one intentionally failed revision, seven resolved evidence items, two boards, note history, repeatability and preservation of a user-edited note. The packaged clean-VM bootstrap also initialized the sample dataset successfully before HTTP startup.

## Limits

This is Chromium desktop/mobile-viewport acceptance, not a claim of Safari, native mobile devices, production durability or complete legacy parity. Free Render instance replacement can still erase user-created data. The PostgreSQL backend and the main deployment were not changed by the sample-loader fix. No paid services were provisioned.

## Signed-out page entry fix

Application SHA `359aeae03a20039c6bf5374c63a23d3fd040eafd`, live deploy `dep-db65elflk1mc73c02fo0`, fixes browser page requests that previously displayed `{"error":"unauthenticated"}`. Signed-out GET requests for Hub, Library, Reader and Evidence now redirect to sign-in with an encoded return path. Successful sign-in returns to an allowlisted page on the same origin, preserving its query/pinned revision. API and protected asset requests retain HTTP 401 JSON; feature-disabled routes still return 404.

34 SQLite EUnit tests and ten desktop/mobile Hub cases passed locally. The focused sign-in/return-path cases passed again on both viewports after adding checks rejecting external URLs and asset paths as login destinations. Live Chromium checks at desktop and mobile viewports passed direct anonymous/invalid-session Library navigation, the sign-in form, unchanged API 401, successful login returning to Library, visible samples, sign-out, and signed-out Evidence navigation. The live browser checks preserved HTTPS verification.

## Milestone 4: Study — 2026-10-12

Application SHA `a9e6f1cfda3dad52269316ea5b2923e5f92688c7`, deploy `dep-db69sm7avr4c73amhqbg`, passed actual public-site Chromium desktop/mobile Study acceptance: sign-in return, fresh UI source/upload/extraction, pinned lessons, wrong/correct answers, keyboard submit, reload/resume, final reflection, completed review, no horizontal overflow/page errors, and logout privacy. Live `/healthz` and `/readyz` returned 200; Render remains free. [Milestone 4 evidence and contracts](milestone-4-plan.md) records the full scope and its limits. User design acceptance and production readiness remain outstanding.
