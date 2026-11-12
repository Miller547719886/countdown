# Configurable Global Hotkey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Replace the macOS Command+1 capture shortcut with a configurable global shortcut that defaults to Option+R.

**Architecture:** Keep shortcut values and display formatting in a small app type, capture user input in an AppKit-backed SwiftUI control, and keep Carbon registration and persistence in `AppCoordinator`. The settings view and main-window badge read the same shortcut value.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, Carbon, `UserDefaults`.

**Spec:** `docs/superpowers/specs/2026-11-12-configurable-global-hotkey-design.md`

## Global Constraints

- The package targets macOS 14 and uses Carbon for global shortcut registration.
- An unset preference resolves to Option+R.
- The recorder requires a non-modifier key and at least one of Command, Option, Control, or Shift; Escape cancels recording, and app menu key equivalents are intercepted while recording.
- This change does not add a Windows client or Windows Alt+R behavior.
- Do not add or run tests for this task; compile the app target as the implementation check.

## Review Focus

- Missing preferences select Option+R, including on an existing install.
- A bare key without a modifier cannot replace the global shortcut.
- Escape leaves the saved shortcut unchanged.
- A custom shortcut remains selected after relaunch.
- Carbon registration failures stay visible and can be retried from Settings; Command+Q/W/H/M cannot quit or close the app during recording and cannot be saved as capture shortcuts.

---

### Task 1: Add a configurable macOS capture shortcut

**Files:**
- Create: `Sources/JiedianApp/GlobalHotKeyShortcut.swift`
- Create: `Sources/JiedianApp/HotKeyRecorderView.swift`
- Modify: `Sources/JiedianApp/AppCoordinator.swift`
- Modify: `Sources/JiedianApp/SettingsView.swift`
- Modify: `Sources/JiedianApp/MainWindowView.swift`
- Modify: `Sources/JiedianApp/MenuBarView.swift`
- Modify: `Sources/JiedianApp/AccessibilityPermissionGuideView.swift`
- Modify: `Sources/JiedianApp/CapturePanelView.swift`
- Modify: `README.md`
- Modify: `PRODUCT.md`

**Interfaces:**
- `GlobalHotKeyShortcut` provides the default Option+R combination, persisted key code and Carbon modifier mask, and a display label.
- `HotKeyRecorderView` reports a validated key-code/modifier combination or cancels without changing the current value.
- `AppCoordinator` exposes the active shortcut and a method to save and re-register a replacement.

- [x] Define `GlobalHotKeyShortcut` with key code, Carbon modifiers, display label, default Option+R, and `UserDefaults` load/save behavior. When only part of the preference is present or the values are invalid, load the default.
- [x] Implement `HotKeyRecorderView` using an AppKit view that captures a non-modifier key and Command/Option/Control/Shift flags. Require at least one modifier, intercept menu key equivalents, reject Command+Q/W/H/M, and treat Escape as cancellation.
- [x] Update `AppCoordinator` to load the preference on launch, install one event handler, replace the registered hotkey when the setting changes, and retain status/error reporting for failed registrations.
- [x] Update `SettingsView` with the active shortcut, a recording action, a way to restore Option+R, and the existing retry action when registration fails. Update every other shortcut hint in the main window, menu bar, accessibility guide, and capture panel to use the same display label.
- [x] Replace Command+1 references in `README.md` and `PRODUCT.md` with the Option+R macOS default and mention Settings customization.
- [x] Run `swift build -c debug`.

**Verification:** `swift build -c debug` exits successfully. Review the code paths for the five input and failure conditions listed above; no test files or test commands are part of this task.
