# Configurable Global Hotkey

## Intent

Change the macOS global capture shortcut from Command+1 to Option+R by default and let each user choose a different key combination in Settings.

## Goals

- Use Option+R when no shortcut preference has been saved.
- Record a custom key combination in Settings, persist it across launches, and apply it immediately.
- Keep the global capture action and show the active shortcut consistently in Settings, the main window, menu bar, onboarding, and capture panel.
- Preserve the existing registration status and error reporting.

## Non-goals and constraints

- Preserve the app's standard Command+Q, Command+W, Command+H, and Command+M menu shortcuts; these combinations cannot be assigned to capture.
- The current package, UI, and shortcut registration are macOS-only. This change does not add a Windows client or Windows Alt+R behavior. Alt+R remains the intended mapping if a Windows client is added later.
- Keep Carbon as the global shortcut registration mechanism.
- Do not add shortcut conflict scanning beyond reporting Carbon registration failures.

## Approaches

- A fixed Option+R shortcut would be the smallest change, but would not satisfy customization.
- A list of preset shortcuts is simple to implement, but prevents users from choosing combinations outside that list.
- A Settings shortcut recorder supports custom key-plus-modifier combinations within Carbon's registration model. Standard app menu combinations remain reserved. This is the selected approach because the request asks for customization.

## Design

Settings will provide a recorder for a non-modifier key with at least one of Command, Option, Control, or Shift. Escape cancels recording. A local key-event monitor consumes app key equivalents while recording so a menu command cannot quit or close the app; the four standard Command menu shortcuts above are rejected with an explanation. The selected key code and modifier flags will be persisted in `UserDefaults`; when no preference exists, Option+R is used. Updating the shortcut unregisters the current Carbon hotkey and registers the selected combination immediately. Registration failures remain visible through the existing status field and retry action.

The Settings description, main-window badge and empty state, menu-bar action, accessibility guide, and capture-panel hint will use the configured combination. README and product documentation will describe Option+R as the macOS default and customization in Settings.

## Implementation calls

- Store the physical key code and Carbon modifier mask, plus a display label suitable for the captured key, in app preferences.
- Keep shortcut state and Carbon registration lifecycle in `AppCoordinator`; keep keyboard capture in a small AppKit-backed Settings control.
- If registration fails, leave the chosen preference visible and expose the failure through existing status and retry UI.
