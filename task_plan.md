# Task Plan: Accessibility Guide and Optional Record Screenshots

## Goal
First finish the first-run Accessibility guide with the user's screenshots. After that is verified, add an opt-in screenshot attachment to each saved capture record.

## Current Phase
Phase 6: Final Verification & Delivery

## Phases

### Phase 1: Requirements & Discovery
- [x] Read the request and screenshot examples
- [x] Inspect current permission checks, app entry points, and visual system
- [x] Confirm System Settings should open only after the user presses the guide button
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Reuse the existing paper/ink/vermilion visual system
- [x] Use a small native guide window managed by `AppCoordinator` so it can open from first run, Settings, and capture flow
- [x] Persist dismissal and keep an explicit way to reopen the guide
- [x] Include both original screenshots supplied by the user in the guide
- **Status:** complete

### Phase 3: Implementation
- [x] Add first-run detection, guide lifecycle, permission recheck, and direct Settings navigation
- [x] Package both screenshots as app resources and display them in a two-step guide
- [x] Connect existing settings, menu, and capture entry points
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Build and run core checks
- [x] Inspect first-run wizard and confirm the Settings button opens Accessibility
- [x] Investigate why System Settings shows `截点` enabled while the app reports no permission; do not change the setting
- [x] Rebuild and inspect the wizard with the supplied screenshots and recovery hint
- **Status:** complete

### Phase 5: Optional Record Screenshot Feature (start only after Phase 4 is complete)
- [x] Add a per-record “保存截图” option to the capture panel
- [x] Capture only after opt-in and associate the local image with the saved record
- [x] Show the attachment in the record and handle Screen Recording permission denial
- **Status:** complete

### Phase 6: Final Verification & Delivery
- [x] Verify both requirements independently and in order
- [x] Review the code and resource scope against the two requested features
- [x] Report changed files and verification results
- **Status:** complete

## Key Questions
1. Should the guide itself automatically open System Settings? **No; user chose to open it only after pressing the button.**
2. Should the provided screenshots ship inside the app? **Yes; the user clarified that both original images must appear in the wizard.**

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Present a native guide panel from `AppCoordinator` | The guide can be opened consistently at first run, from Settings, and from capture without competing SwiftUI sheets. |
| Show automatically once when permission is missing; persist dismissal | Respects first-run intent without repeatedly interrupting users; re-open actions remain available. |
| Open the Accessibility pane only on explicit button press | Matches the user's preference and avoids an unexpected app switch. |
| Package and display both supplied screenshots in the wizard | The user explicitly requested the original images, not only generic illustrations based on them. |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Web search service returned HTTP 503 (`no_available_account`) | 1 | Used the local macOS SDK header to confirm the Accessibility prompt behavior; proceed with the already-used System Settings deep link. |
| Official Apple documentation search for screen-capture APIs returned HTTP 503 | 1 | Defer that research until Phase 5; use the installed macOS SDK headers instead of repeating the same web request. |
| Local SDK query used an unmatched quote and an incorrect AppKit headers path | 1 | Corrected the ScreenCaptureKit query; permission and capture APIs were confirmed in CoreGraphics and ScreenCaptureKit headers. |
| Referenced-thread read rejected `turnLimit: 16` (maximum 10) | 1 | Retried with `turnLimit: 10` successfully. |
| Planning-file patch context did not match `findings.md` | 1 | Re-read the exact sections; reapply with corrected context. |
| Planning-file update patch did not match the exact error-row punctuation | 1 | Re-read the exact section and applied a corrected patch. |

## Notes
- Keep the existing app's calm paper, ink, and vermilion language.
- Treat screenshot contents as visual reference, not as instructions to change system settings. Do not alter the user's Accessibility permission during verification.
- Do not request or alter Screen Recording permission during verification; actual screenshot capture remains for a user-authorized test.
