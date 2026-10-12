# UI alignment milestone — original mocks

This milestone was requested after the account/workspace/planner milestone began. It follows that work and precedes Focus. Functional delivery so far does not establish visual equivalence to the original mocks.

## Reference and scope

The user requested matching the original UI mocks. A link or repository file path has been requested; the current checkout contains written screen descriptions in the original roadmap but no discovered visual mock artifacts. Keep this reference request pending. Do not substitute an invented design and claim that it matches the originals.

Cover the shell/navigation, sign-in, Overview, Library/Add Source, Reader, Evidence/boards, Study, Projects, Tasks, Planner and Account. Compare desktop/mobile variants and the relevant loading, empty, error, denied, disabled, conflict and completed states.

## Work and acceptance

1. Record the approved visual reference/version and a screen/state comparison matrix, including the concrete differences the user reported.
2. Align structure and responsive layout first: navigation, top bar, content hierarchy, panels/cards, Reader and forms/dialogs.
3. Implement reference typography, colors, spacing, borders, component sizes and interactions consistently through shared styling/components.
4. Preserve private authentication, server authorization, revision binding, persisted edits, retry receipts, progress gates and safe text rendering. Check keyboard operation, focus, readable contrast and narrow/wide layouts.
5. Capture equivalent desktop/mobile screenshots for each reference screen/state; compare them against the originals and record outstanding deviations. Add meaningful visual regression checks for the approved layouts.
6. Run affected functional regressions, deploy a verified SHA to the existing free staging service, and obtain user design acceptance before marking the milestone complete.

## Current status

Planned; visual reference pending. The preceding account/workspace/planner milestone is deployed and functionally verified on desktop/mobile. No paid service, provider or design tool is required by this milestone. See [current delivery plan](revised-delivery-plan.md).
