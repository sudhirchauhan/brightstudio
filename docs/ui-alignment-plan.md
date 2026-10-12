# UI alignment milestone — original mocks

This milestone was requested after the account/workspace/planner milestone began. It follows that work and precedes Focus. Functional delivery so far does not establish visual equivalence to the original mocks.

## Reference and scope

The user requested matching the original UI mocks. The user subsequently requested new minimal, slick, distraction-free mocks based on the original written document, including exclusive fullscreen and Study modes. The new concept below is the working visual reference for review; it is not presented as a recovered original design.

Cover the shell/navigation, sign-in, Overview, Library/Add Source, Reader, Evidence/boards, Study, Projects, Tasks, Planner and Account. Compare desktop/mobile variants and the relevant loading, empty, error, denied, disabled, conflict and completed states.

## Work and acceptance

1. Record the approved visual reference/version and a screen/state comparison matrix, including the concrete differences the user reported.
2. Align structure and responsive layout first: navigation, top bar, content hierarchy, panels/cards, Reader and forms/dialogs.
3. Implement reference typography, colors, spacing, borders, component sizes and interactions consistently through shared styling/components.
4. Preserve private authentication, server authorization, revision binding, persisted edits, retry receipts, progress gates and safe text rendering. Check keyboard operation, focus, readable contrast and narrow/wide layouts.
5. Capture equivalent desktop/mobile screenshots for each reference screen/state; compare them against the originals and record outstanding deviations. Add meaningful visual regression checks for the approved layouts.
6. Run affected functional regressions, deploy a verified SHA to the existing free staging service, and obtain user design acceptance before marking the milestone complete.

## Current status

New concept mocks created; visual design acceptance pending. The preceding account/workspace/planner milestone is deployed and functionally verified on desktop/mobile. No paid service, provider or design tool is required by this milestone. See [current delivery plan](revised-delivery-plan.md).

## New visual reference — 2026-10-12

`design/mocks/jpg/bright-studio-design-board.jpg` presents the new four-screen concept. Individual JPGs cover Workspace, exclusive fullscreen Reader, exclusive fullscreen Study and mobile Study. `design/mocks/bright-studio-jpg-mocks.zip` contains all five JPGs. The user explicitly requested JPG output.

The design uses warm-white surfaces, restrained teal accents, thin dividers, a compact navigation rail, generous spacing and readable serif source text. Study presents one question and one main action. Workspace navigation/account/project chrome disappears in distraction-free reading and Study modes. Browser fullscreen is independent of the activity: enter through an explicit control, leave through a discoverable exit or Escape, and keep source/revision context visible. Evidence notes open only when requested.

`design/mocks/quiet-studio.html` is a standalone interactive concept using fictional sources and local sample interactions, with no account/database changes or saved progress. Native browser fullscreen, chrome hiding, Reader/Study switching, sample feedback and mobile width were verified during JPG export. The image-generated presentation board uses a future reflective question layout; the interactive sample uses deterministic missing-word recall compatible with the current Study domain. Final question/feedback layouts should be agreed during design review. These mocks have not been deployed to the application.

## Browser gallery fallback

The chat/workspace image viewer displayed “No image” despite valid JPG files. Mock files were made readable and a separate `/studio/mockups/` gallery was added for ordinary-browser viewing. The gallery and its fixed JPG/CSS assets are enabled only with `STUDIO_UI_MOCKS_ENABLED=true`; the default is off. They contain fictional design content and require no account/session. Public preview assets can be embedded; existing private application pages/APIs retain their original authentication and security headers. No upload, filesystem binding, private source image or account data is exposed by the gallery.

The browser gallery is live at https://brightstudio-m1-staging.onrender.com/studio/mockups/ . Application SHA `249d288256b69fc0cc4676fc1a6dc706262ab387`, Render deploy `dep-db6h1laj9qps73c9vlj0`, passed real Chromium desktop/mobile checks: all five JPGs decode, MIME types are `image/jpeg`, remote byte hashes match the exported files, the page fits narrow/wide viewports, no page errors occur, no session is created, and account APIs remain 401. The disabled gallery/CSS/JPG gate returns 404 and unsupported methods 405. This browser link is the reliable fallback for the chat image viewer's “No image” failure. The existing service remains free and the application UI itself has not yet adopted the proposed design.
