# Product

<!-- impeccable:product-schema 1 -->

## Platform

Native macOS desktop UI.

## Stack

Native SwiftUI with AppKit integration for global shortcuts, accessibility text capture, menu bar access, and window management. No server and no account.

## Users

One person working across notes, messages, documents, and browsers who wants to turn a sentence they are already reading or writing into a deadline-bearing task without switching context first.

## Product Purpose

Let the user select text in any app, press Command-1, and immediately turn that selection into a personal item with a required deadline. Keep the resulting items visible as a calm, scannable countdown list.

## Positioning

A capture-first deadline slip for macOS: the selected sentence becomes the task, and its deadline becomes the thing the interface is organized around.

## Operating Context

The user is mid-reading or mid-writing in another app when a thought needs to be remembered. The app must capture without making them retype the sentence, then ask for a deadline in a compact floating panel. Items are reviewed from the main window or menu bar. All data stays on the Mac.

## Capabilities and Constraints

- Register Command-1 as a system-wide shortcut while the app is running.
- Read the current selection from the frontmost app through macOS Accessibility, with a clipboard-based fallback when Accessibility exposes no selected text.
- Require a deadline before an item can be saved. Presets are explicit choices; custom date and time are also supported.
- Persist items locally and show active items in deadline order with live countdown and overdue state.
- Complete, restore, edit, and delete items.
- Show completed items separately. Do not include progress percentages, progress bars, or goal decomposition.
- Offer local deadline notifications when the user has granted notification permission.
- Keep the app usable when Accessibility permission is not yet granted: the capture panel opens and allows manual entry, while the main window explains how to enable selection capture.
- Local-first, single-user storage. No account, sync, analytics, or server.

## Product Principles

- Capture in one keystroke and one required decision: the deadline.
- Preserve the user's own words exactly; the selection is the task title.
- Make time legible before metadata: date, time, remaining interval, and overdue state.
- Prefer native macOS behavior and familiar controls over invented interactions.
- Keep the visual surface calm enough to scan, but specific enough to remember.
- Keep personal text and deadlines on the device.
