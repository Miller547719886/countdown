# 待办提醒编辑与返回主窗口 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 让已创建待办可编辑完整提醒计划，并能从创建面板返回主窗口。

**Architecture:** 新建 SwiftUI `ReminderEditorView`，让创建面板和编辑表单共用同一提醒编辑与校验逻辑。把自定义提醒截止时间校验收口到 `ReminderPlanner`；协调器提供返回动作，先清除创建面板关闭后的自动隐藏状态，再关闭面板并显示主窗口。

**Tech Stack:** Swift 5.10、macOS 14、SwiftUI、AppKit。

**Spec:** `docs/superpowers/specs/2026-11-13-editable-reminders-and-main-window-return-design.md`

## Global Constraints

- 使用现有 SwiftUI 和设计系统样式，保留 0–30 次提醒、1–365 天的范围。
- 返回主窗口时清除待处理的自动隐藏标记，再关闭创建面板并调用现有主窗口显示逻辑。
- 回主窗口视为关闭未保存的创建面板，不保存当前草稿。

## Review Focus

- 提醒次数为 0 时，不显示提醒行，仍可保存待办。
- 提醒次数增加或减少时，既有提醒行和相对天数默认值按 `ReminderPlanner.resize` 的规则更新。
- 提前天数输入保留 1–365 范围；提醒时间与天数输入保持同一紧凑行。
- 自定义日期和时间使用字段样式并排；自定义提醒在截止时间之前有效，达到或超过截止时间时显示提示并阻止保存。
- 从其他应用触发创建面板后点“回到主窗口”，面板关闭且主窗口显示，不触发自动隐藏。

## Files and Responsibilities

- Create `Sources/JiedianApp/ReminderEditorView.swift`: shared reminder count, mode, date/time controls, and validation message.
- Modify `Sources/JiedianCore/DeadlineReminder.swift`: expose shared custom-reminder deadline validation through `ReminderPlanner`.
- Modify `Sources/JiedianApp/CapturePanelView.swift`: use the shared editor and add the return button.
- Modify `Sources/JiedianApp/EditItemSheet.swift`: edit and save the reminder array with the shared editor.
- Modify `Sources/JiedianApp/AppCoordinator.swift`: return-to-main handoff that avoids the existing post-dismiss auto-hide path.

Execution method: Native implementation in this thread. The user asked to implement the approved design here; the changes are small and sequential, with the editor shared across both forms.

---

### Task 1: Shared Reminder Editor and Validation

**Files:**
- Create: `Sources/JiedianApp/ReminderEditorView.swift`
- Modify: `Sources/JiedianCore/DeadlineReminder.swift`

**Interfaces:**
- Produces `ReminderEditorView(reminders: Binding<[DeadlineReminder]>, deadline: Date)`.
- Produces `ReminderPlanner.hasCustomReminderAtOrAfterDeadline(_:deadline:) -> Bool` for creation, editing, and shared editor validation.

- [x] Add `ReminderPlanner.hasCustomReminderAtOrAfterDeadline(_:deadline:)`; return `true` for a custom reminder without a date or with a date greater than or equal to the deadline.
- [x] Build `ReminderEditorView` with a 0–30 count binding that resizes through `ReminderPlanner.resize`, the existing relative/custom mode picker, and shared validation text.
- [x] Replace the relative-days stepper label with a numeric field clamped to 1–365; keep its time picker adjacent in the same row.
- [x] Render custom date and custom time with `.field` pickers in one compact horizontal row; preserve the selected date while changing time and vice versa.
- [x] Run `swift build -c release`; expected: exit code 0.

### Task 2: Reuse the Editor in Create and Edit Forms

**Files:**
- Modify: `Sources/JiedianApp/CapturePanelView.swift`
- Modify: `Sources/JiedianApp/EditItemSheet.swift`

**Interfaces:**
- Consumes `ReminderEditorView` and `ReminderPlanner.hasCustomReminderAtOrAfterDeadline(_:deadline:)` from Task 1.
- `EditItemSheet` owns `@State reminders: [DeadlineReminder]`, initialized from `item.reminders`, and writes that value back on save.

- [x] Replace `CapturePanelView`'s inline reminder controls and bindings with `ReminderEditorView`; delegate `CaptureDraft`'s custom-date validity check to `ReminderPlanner`.
- [x] Add reminder state and the shared editor to `EditItemSheet`; set `updated.reminders` before invoking `onSave`.
- [x] Disable edit saving and show the shared validation message when a custom reminder is at or after the deadline.
- [x] Run `swift build -c release`; expected: exit code 0.

### Task 3: Return from Capture Panel to Main Window

**Files:**
- Modify: `Sources/JiedianApp/AppCoordinator.swift`
- Modify: `Sources/JiedianApp/CapturePanelView.swift`

**Interfaces:**
- Produces `AppCoordinator.returnToMainWindow()`: clear `shouldHideAppAfterCaptureDismissal`, call `dismissCapture()`, then call `showMainWindow()`.

- [x] Add `returnToMainWindow()` without changing the existing dismiss behavior for close and cancel.
- [x] Add a visible “回到主窗口” button to `CapturePanelView.panelHeader` that calls the new coordinator action.
- [x] Run `swift build -c release` and `git diff --check`; expected: both exit code 0.

## Verification Limits

No automated tests are added or run for this task. Verify behavior through the review focus above and a successful release build.
