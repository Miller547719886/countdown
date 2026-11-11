# Disable Past Deadline Days Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent new-item date pickers from selecting dates before today while keeping today and all future dates available.

**Architecture:** Put the date-only boundary in `DeadlinePlanner` as a public, calendar-injectable helper so the rule is deterministic and shared by both capture date views. Apply the helper to the quick date buttons and custom month grid; leave `EditItemSheet` and time-level validation unchanged.

**Tech Stack:** Swift 5.10, SwiftUI, Foundation `Calendar`, the repository's `JiedianChecks` executable checks.

**Spec:** `docs/superpowers/specs/2026-11-11-disable-past-deadline-days-design.md`

## Global Constraints

- Compare dates at `Calendar.startOfDay`, not full timestamps.
- Keep past dates visible but disabled; do not hide or shift the week/month layout.
- Keep today selectable and preserve the existing future-time save validation.
- Do not change existing-item editing behavior.

## Review Focus

- Yesterday and earlier: buttons/cells remain visible, cannot mutate the draft, and expose “已过去” to assistive technology. Covered by the date-boundary tests and UI call sites.
- Today at midnight: remains selectable even when the current time is later in the day. Covered by the today boundary test.
- Future day: remains selectable. Covered by the future boundary test.
- Previous-month navigation: past cells are disabled without disabling month navigation. Covered by the calendar call site inspection/build.
- Existing-item editor: no code path or validation is changed. Covered by diff review.

### Task 1: Add a deterministic date boundary

**Files:**
- Modify: `Sources/JiedianChecks/main.swift` (extend the existing core check executable)
- Modify: `Sources/JiedianCore/DeadlinePlanner.swift`

**Interfaces:**
- Produces `DeadlinePlanner.isBeforeToday(_:now:calendar:) -> Bool` for UI callers and tests.

- [x] **Step 1: Extend `JiedianChecks` with fixed-calendar assertions for yesterday, today, and tomorrow.**
- [x] **Step 2: Run `swift run JiedianChecks` and verify it fails to compile because the helper does not yet exist.**
- [x] **Step 3: Implement `DeadlinePlanner.isBeforeToday` by comparing `startOfDay(for:)` values in the supplied calendar.**
- [x] **Step 4: Run `swift run JiedianChecks` and verify all core checks pass.**

### Task 2: Apply the boundary to both new-item date views

**Files:**
- Modify: `Sources/JiedianApp/CapturePanelView.swift:265-295` (quick date buttons)
- Modify: `Sources/JiedianApp/CapturePanelView.swift:387-425` (calendar day cells)

**Interfaces:**
- Consumes: `DeadlinePlanner.isBeforeToday` from Task 1.
- Produces: disabled, still-visible past date controls with accessible status text.

- [x] **Step 1: Add the two UI call sites** that consume `DeadlinePlanner.isBeforeToday`, keeping the derived flag local to each date control.
- [x] **Step 2: Add `.disabled(isBeforeToday)` plus muted styling and an “已过去” accessibility suffix to quick buttons and calendar cells; leave month navigation and today enabled.**
- [x] **Step 3: Run `swift run JiedianChecks` and `swift build -c release` to verify the boundary checks and the macOS app compile.**

### Task 3: Final verification

**Files:**
- No additional product files.

- [ ] **Step 1: Inspect the diff to confirm `EditItemSheet.swift`, `CaptureDraft.canSave`, and default deadline behavior are unchanged.**
- [ ] **Step 2: Run `swift run JiedianChecks` and `swift build -c release`, recording their exit codes.**
- [ ] **Step 3: Run the Impeccable detector on changed UI targets.**

