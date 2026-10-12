# UI alignment milestone — approved Quiet Studio design

This milestone was requested after the account/workspace/planner milestone began. It follows that work and precedes Focus. Functional delivery so far does not establish visual equivalence to the original mocks.

## Reference and scope

The user requested matching the original UI mocks. The user subsequently requested new minimal, slick, distraction-free mocks based on the original written document, including exclusive fullscreen and Study modes. The new concept below is the working visual reference for review; it is not presented as a recovered original design.

Cover the shell/navigation, sign-in, Overview, Library/Add Source, Reader, Evidence/boards, Study, Projects, Tasks, Planner and Account. Compare desktop/mobile variants and the relevant loading, empty, error, denied, disabled, conflict and completed states.

## Work and acceptance

1. Record the approved visual reference/version and a screen/state comparison matrix, including the concrete differences the user reported.
2. Align structure and responsive layout first: navigation, top bar, content hierarchy, panels/cards, Reader and forms/dialogs.
3. Implement reference typography, colors, spacing, borders, component sizes and interactions consistently through shared styling/components.
4. Preserve private authentication, server authorization, revision binding, persisted edits, retry receipts, progress gates and safe text rendering. Check keyboard operation, focus, readable contrast and narrow/wide layouts.
5. Capture equivalent desktop/mobile screenshots for each reference screen/state; compare them against the approved concepts and record outstanding deviations. Add meaningful visual regression checks for the approved layouts.
6. Run affected functional regressions, deploy a verified SHA to the existing free staging service, and obtain user design acceptance before marking the milestone complete.

## Current status

The user approved the new JPG concepts with “look good, go ahead” on 2026-10-12. Application implementation, local validation and hosted desktop/mobile acceptance are complete; final acceptance of the deployed UI remains separate. The preceding account/workspace/planner milestone is deployed and functionally verified on desktop/mobile. No paid service, provider or design tool is required by this milestone. See [current delivery plan](revised-delivery-plan.md).

## New visual reference — 2026-10-12

`design/mocks/jpg/bright-studio-design-board.jpg` presents the new four-screen concept. Individual JPGs cover Workspace, exclusive fullscreen Reader, exclusive fullscreen Study and mobile Study. `design/mocks/bright-studio-jpg-mocks.zip` contains all five JPGs. The user explicitly requested JPG output.

The design uses warm-white surfaces, restrained teal accents, thin dividers, a compact navigation rail, generous spacing and readable serif source text. Study presents one question and one main action. Workspace navigation/account/project chrome disappears in distraction-free reading and Study modes. Browser fullscreen is independent of the activity: enter through an explicit control, leave through a discoverable exit or Escape, and keep source/revision context visible. Evidence notes open only when requested.

`design/mocks/quiet-studio.html` is a standalone interactive concept using fictional sources and local sample interactions, with no account/database changes or saved progress. Native browser fullscreen, chrome hiding, Reader/Study switching, sample feedback and mobile width were verified during JPG export. The image-generated presentation board uses a future reflective question layout; the interactive sample uses deterministic missing-word recall compatible with the current Study domain. Final question/feedback layouts should be agreed during design review. The concepts are the approved application design reference. The implementation preserves deterministic missing-word recall rather than inventing the reflective questions illustrated in the presentation board.

## Browser gallery fallback

The chat/workspace image viewer displayed “No image” despite valid JPG files. Mock files were made readable and a separate `/studio/mockups/` gallery was added for ordinary-browser viewing. The gallery and its fixed JPG/CSS assets are enabled only with `STUDIO_UI_MOCKS_ENABLED=true`; the default is off. They contain fictional design content and require no account/session. Public preview assets can be embedded; existing private application pages/APIs retain their original authentication and security headers. No upload, filesystem binding, private source image or account data is exposed by the gallery.

The browser gallery is live at https://brightstudio-m1-staging.onrender.com/studio/mockups/ . Application SHA `249d288256b69fc0cc4676fc1a6dc706262ab387`, Render deploy `dep-db6h1laj9qps73c9vlj0`, passed real Chromium desktop/mobile checks: all five JPGs decode, MIME types are `image/jpeg`, remote byte hashes match the exported files, the page fits narrow/wide viewports, no page errors occur, no session is created, and account APIs remain 401. The disabled gallery/CSS/JPG gate returns 404 and unsupported methods 405. This browser link is the reliable fallback for the chat image viewer's “No image” failure. This gallery release preceded the application redesign below. The existing service remains free.


## Application implementation — 2026-10-12

Approved reference: the five JPGs above and their interactive Quiet Studio prototype. This approval authorizes implementing that direction; it does not establish equivalence to an unseen original mock set.

| Screen | Application change | Reference/acceptance |
|---|---|---|
| Sign-in | Compact warm-white form, serif wordmark, shared buttons/inputs | Extended shared design; private return links and validation retained |
| Overview | Ready-source reading action, recent source rows, revision-pinned Study action | Workspace concept; actions use real owned sources rather than fictional data |
| Library/Add Source | Flat source rows, quiet search, compact upload dialog | Workspace components extended to loading, empty, failure and disabled states |
| Reader | Centered serif text, independent reading/fullscreen controls, pinned context bar, source options | Fullscreen Reader concept; no fabricated reading-position bar or bookmark persistence |
| Evidence | On-demand note drawer, keyboard quote finding, selection capture, existing edit/history/link actions | Reader concept; exact UTF-8 anchors, revisions and conflicts retained |
| Boards | Shared shell, restrained cards/forms and revision links | Extended shared design; loading/empty/errors retained |
| Study | One current question, source context/progress, recall/reflection/completed layouts, independent mode/fullscreen controls | Study/mobile concept adapted to the existing deterministic domain |
| Projects | Quiet project cards and create/rename forms | Shared design extension; saved versions and receipts retained |
| Tasks/Planner | Divided task rows, quiet actions, date/filter controls and dialogs | Shared design extension; civil-date and timezone behavior retained |
| Account | Shared profile/password forms and readable errors | Shared design extension; all-session revocation and password checks retained |

Fullscreen is requested only through a user click. An exit control, Escape and browser-driven exits restore the prior reading/study mode. Unsupported or denied fullscreen preserves a usable distraction-free view with a visible message. Study focus starts when an actual lesson opens; back to lessons restores navigation. Changing modes does not rewrite source revision, answer draft, committed progress or notes. Failed lesson refreshes retain the active lesson/draft and its exit controls.

Mobile navigation uses an explicit Menu/Close control, trapped keyboard focus, an inert background and Escape focus return. Notes open only on request or after an evidence save and return focus on close. Existing feature flags and private page/API boundaries remain active; the public fictional mock gallery remains separate from the signed-in app.

Visual baselines cover sign-in, Overview, Library, focused Reader and Study on desktop/mobile. They are reviewed Linux Chromium 151 snapshots, with only variable account/project/status fields masked. Run pixel comparisons with `BRIGHT_VISUAL_BASELINES=true PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium npm run test:e2e`. Other browser runners execute the same interaction/layout checks and capture screenshots without asserting cross-version pixel equality. Baselines are regression references for this approved implementation; they are not pixel-equivalence claims for the generated presentation board. Final deployed design acceptance remains for the user.


## Local validation

The Erlang production release assembled successfully. All 46 desktop/mobile Playwright cases passed in a new isolated SQLite database, including real uploads/extraction/downloads, quote/Unicode provenance, note/board conflicts, immutable Study receipts/resume, tasks/planner/profile and private authentication. Existing development data was preserved; earlier repeated fixture runs had exhausted its account revision quota. After the final Overview action was added, all six UI cases were rerun, the two Overview baselines were reviewed/updated, and a separate comparison run checked the ten unchanged/final desktop/mobile baselines. No quota or security limit was weakened. PostgreSQL domain logic/migrations were not changed by this UI milestone; earlier SQL evidence remains historical rather than a new SQL test claim.


## Hosted UI release

Live application SHA `5f27e51aafb0d71d84f9086d2b34a45533b75878`, Render deploy `dep-db6hgvff3r2c73cahld0`, existing `brightstudio-m1-staging` service, free plan, `milestone-3`, auto-deploy off. Test URL: https://brightstudio-m1-staging.onrender.com/studio/hub/ . Normal pages require the existing test login; the fictional mock gallery remains public.

Actual trusted-HTTPS Chromium desktop/mobile acceptance passed private sign-in return, keyboard upload and extraction, reading/fullscreen/Escape, on-demand evidence saving and reopen, pinned Study source/revision, wrong-answer feedback, reflection/completed resume, real Overview actions, Projects/Tasks/Planner/Account/Boards navigation, narrow layouts, no page errors and sign-out privacy. All account settings and bootstrap credentials were preserved. Readiness passed. Final visual acceptance of the deployed UI remains with the user. The normal development SQLite database was restored after isolated local acceptance; existing files remain intact. No new service, paid resource, schema, dependency, main merge or original-service change was introduced.
