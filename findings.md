# Findings & Decisions

## Requirements
- Automatically present an Accessibility setup wizard the first time the app runs without Accessibility trust.
- The guide should explain `System Settings → Privacy & Security → Accessibility` and how to enable `截点`.
- Opening System Settings happens only after the user presses the guide's button.
- Let users recheck permission after returning; show a clear authorized state.
- Let users dismiss the guide and reopen it later from the app.

## Research Findings
- The supplied screenshots show the System Settings route `隐私与安全性 → 辅助功能` and the `截点` app row with its permission switch off.
- Current app is SwiftUI with AppKit integration, minimum macOS 14. Existing `AppCoordinator` polls `AXIsProcessTrusted()` every 1.5 seconds.
- `AppCoordinator` refreshes `accessibilityTrusted` directly from `AXIsProcessTrusted()` and polls every 1.5 seconds. The current `openAccessibilitySettings()` only opens the Accessibility pane after the user presses its button; it does not request the system prompt.
- Current entry points: first-run configuration in `JiedianApp`, Settings status row, capture panel's `开启选区捕获` action, and the app menu command.
- The current UI uses warm paper backgrounds, dark ink, restrained vermilion, serif display text, and square-edged rules/buttons.
- The user clarified that both original screenshots must appear in the wizard itself. Keep them as local app resources; do not upload them or change system settings based on screenshot contents.
- Official web lookup failed with HTTP 503; no web source was used.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Use a dedicated `NSPanel` hosting SwiftUI | Avoid nested `.sheet` conflicts and allow a single guide entry point from app lifecycle and all existing UI surfaces. |
| Use `UserDefaults` for the one-time dismissal marker | No server/account is needed; guide should not repeat after the user dismisses it. |
| Keep a persistent menu/settings route to reopen the guide | Dismissal must not strand users who later decide to enable permission. |
| Keep polling and expose a manual recheck action | Permission status can change while System Settings is open; explicit retry also communicates what to do next. |
| Bundle both original screenshots as SwiftPM resources | The user explicitly requested the images in the guide; keep them local and display them without altering their content. |
| When a still-denied state follows an app rebuild, explain how to replace the stale Accessibility entry | The current ad-hoc app's designated requirement is tied to the build CDHash; the system switch alone does not establish that the current binary is authorized. |

## Screenshot Attachment Discovery
- `CapturePanelView` owns the in-progress draft; `AppCoordinator.saveCapture` creates the `CaptureItem` through `ItemStore.add`, then closes the panel. The data model is Codable and the store persists a local JSON file under Application Support (or `JIEDIAN_STORAGE_PATH` for tests).
- Store image bytes in a separate per-item PNG file, with only an optional relative filename in the record JSON, so older records remain decodable and the JSON does not balloon.
- The option must be an explicit opt-in. Capture only when the checkbox is selected, and exclude the app's own capture panel from the image so the screenshot reflects the content behind it. If permission is denied or capture fails, preserve the record draft and explain recovery.
- The local macOS SDK confirms `SCScreenshotManager.captureImage(contentFilter:configuration:completionHandler:)` and `SCShareableContent` are available from macOS 14. `SCContentFilter` can exclude `SCRunningApplication` instances, allowing the capture panel itself to be left out of the screenshot. `CGPreflightScreenCaptureAccess()` checks permission without prompting; `CGRequestScreenCaptureAccess()` may prompt, so call it only after the user opts in.
- `SCStreamConfiguration.width` and `.height` are pixel dimensions; derive them from the selected `SCDisplay`'s CoreGraphics pixel size. The local SDK header search did not find an `NSScreenCaptureUsageDescription` key, so do not invent one unless compilation/runtime evidence requires it.
- A local Swift typecheck confirmed `try await SCShareableContent.current` and `SCContentFilter(display:excludingApplications:exceptingWindows:)` compile with the installed macOS SDK; this checks API spelling without requesting screen access.
- Keep the system prompt behind the checkbox. If capture permission is missing, show a Screen Recording-specific explanation and open System Settings only when the user presses its button; allow retry after returning, and let the user uncheck the option to save the record without an image.
- Preserve attachment references through record edits/completion, remove the image when a record is deleted, and render a small clickable preview on both active and completed rows. Tests should cover legacy JSON decoding, attachment persistence/reload, and deletion cleanup.
- Visual baseline from the live capture panel: a 560×430 native panel with header, source, text editor, deadline controls, and footer. Add one compact screenshot row between the deadline and footer, with a small preview/status, and allow the panel height to grow enough to avoid crowding the existing fields.

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Web tool unavailable (HTTP 503) | Consulted the installed SDK header; existing deep-link route remains the implementation basis. |

## Resources
- Project guidance: `/Users/xiongyufengmacminim4/dev/countdown/PRODUCT.md`
- macOS SDK header: `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/AXUIElement.h`

## Visual/Browser Findings
- The provided first screenshot highlights Privacy & Security in the sidebar and the Accessibility category in the pane.
- The second screenshot shows an app-permission list with `截点` turned off; it is the user's requested visual reference and should be displayed as provided.
- The existing app has an empty-state main window with a paper-colored canvas, a vermilion brand mark, a compact status in the top bar, and understated square controls.
- Use a concise, two-step, single-screen guide with both supplied screenshots; avoid a long tutorial or blocking flow.
- Live verification opened System Settings → Accessibility and showed the `截点` switch as on while the guide still reported permission as not detected. Do not alter the setting; investigate the trust-check mismatch before claiming the authorized state works.
- On resume, the live `截点` window is still the Accessibility guide and its accessibility tree reports `尚未检测到授权`; the guide text says to retry and notes that quitting and relaunching may be needed. System Settings is running, but no permission switch was changed during this check.
- The two supplied images are now visible in the guide after loading them from `Bundle.module` via `NSImage`; the earlier empty-frame issue is resolved.
- A focused live repro is now red: System Settings' Accessibility row reports `截点_Toggle = on`; clicking the guide's `重新检查` leaves its status at `尚未检测到授权`. The check was run through `cua_repl` with assertions on both app surfaces, and it changed no system setting.
- In an isolated test-bundle copy, the updated first-run guide displayed both supplied screenshots; after pressing `重新检查`, the recovery note was visible and fit in the panel. The original open guide and system permission state were left untouched.
- Source search shows both the guide state and manual recheck are driven by the same `AXIsProcessTrusted()` result; the coordinator also polls that API every 1.5 seconds. This weakens the stale-SwiftUI-state hypothesis but does not yet distinguish a process identity/TCC issue from an OS trust result.
- The running app is `dist/截点.app/Contents/MacOS/Jiedian`, bundle ID `com.xiongyufeng.jiedian`, and its current signature is ad hoc with no Team ID. This makes an outdated TCC identity or a different app copy a leading hypothesis; the installed/listed app copy and signature stability still need checking.
- Follow-up narrowed the discrepancy: Spotlight finds only the workspace app bundle, there is no valid code-signing identity on this Mac, and `codesign -dr -` reports `designated => cdhash H"2bffb833d04664b1a6d935d374adb9bcb2fe2d35"`. The current app therefore has a build-specific ad-hoc identity; the enabled System Settings entry most likely belongs to an earlier build identity and does not grant trust to the current executable. Re-adding the current app in System Settings is a user action; do not remove or change the entry during this task.
- No source-level permission-state bug was found: both the guide and recheck display the direct `AXIsProcessTrusted()` result, and the live repro stayed denied after recheck. Add a recovery hint for stale entries rather than claiming the toggle proves the current binary is trusted.
- No `CONTEXT.md` or ADR files are present; `PRODUCT.md` confirms a local-first native macOS app using AppKit/SwiftUI and Accessibility to read the selection.
