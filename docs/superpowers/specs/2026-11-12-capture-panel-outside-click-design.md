# Capture Panel Outside-Click Dismissal

## Intent

After `⌘1` opens the “截下一件事” capture panel, clicking anywhere outside the panel should dismiss it so the user can continue working. The outside click should still reach the window underneath.

## Goals

- Dismiss on clicks outside the capture panel, both within this app and in other apps.
- Reuse the existing `AppCoordinator.dismissCapture()` behavior, including clearing the unsaved capture draft.
- Keep the existing close button and Escape behavior.

## Non-goals

- Change the `⌘1` shortcut, the panel layout, or screenshot capture behavior.
- Preserve an unsaved draft after dismissal.

## Constraints

- `CapturePanel` is an `NSPanel` subclass; the SwiftUI view does not own the window lifecycle.
- `AppCoordinator.dismissCapture()` already closes the panel and clears the capture session.
- The accessibility guide intentionally orders the capture panel out and can restore it. Outside-click monitoring must stop while the capture panel is ordered out and resume when it is shown again.
- The Codex learning-update automation now lives in the separate `codex-skills-auto-update` project and stays out of this countdown repository.

## Approaches

1. **Local and global mouse monitors (chosen):** observe clicks in this app and other apps while the panel is visible, dismiss through the existing coordinator callback, and allow the original click to continue. This covers the requested outside-click behavior.
2. **Hide on app deactivation:** simpler, but does not catch clicks on another window in the same app.
3. **Dismiss on key-window resignation:** can also fire during programmatic panel transitions, including the accessibility guide flow, so it does not distinguish a user clicking outside from an intentional hide.

## Design

Have `CapturePanel` own local and global mouse-down monitors for as long as it is visible. Ignore events whose window is the capture panel. For outside events, invoke a callback wired by `AppCoordinator` to `dismissCapture()`. Return local events unchanged so the underlying window still receives the click. Stop monitoring when the panel is ordered out or closed; restart when it is shown, including restoration after the accessibility guide.

The implementation should stay within `CapturePanel.swift` and `AppCoordinator.swift` unless existing lifecycle details require otherwise.

## Acceptance

- `⌘1` opens the capture panel as before.
- Clicking inside the panel leaves it open.
- Clicking outside the panel in this app or another app dismisses it, while the clicked target still responds.
- The close button, Escape key, and accessibility guide restoration continue to work.
