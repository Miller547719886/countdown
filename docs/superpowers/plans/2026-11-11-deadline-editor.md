# 截止时间编辑器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在截取面板中加入共享状态的快捷/日历截止时间编辑器，并默认选中截图保存。

**Architecture:** `CapturePanelView` 继续拥有草稿状态；新增一个 tab 状态和可复用的时间字段视图，所有日期和时间操作直接写入同一个 `draft.deadline`。截图草稿在每次新会话初始化时默认开启并启动现有捕获任务。

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, ScreenCaptureKit, JiedianCore。

**Spec:** `docs/superpowers/specs/2026-11-11-deadline-editor-design.md`

## Global Constraints

- 原生 macOS SwiftUI，最低 macOS 14。
- 不改变 `CaptureItem` 持久化格式、通知逻辑或主窗口展示。
- 沿用现有纸张、墨色、朱砂视觉系统和截图权限恢复路径。
- 快捷日期固定提供本周一至日、下周一至日；时间默认 08:00:00 且不提供时间快捷按钮。

## Review Focus

- 新会话首次显示时截图是否默认选中并开始预览捕获；捕获失败后是否仍可取消勾选并保存。
- 快捷日期按钮是否始终覆盖 14 个日期，且选中某日不会改变当前时分秒。
- 秒字段输入是否被限制在 00–59，且更新能反映到同一个截止时间。
- 在快捷 tab 与日历 tab 间切换时，日期和时分秒是否保持一致。
- 过去时间、空事项、取消和保存快捷键等原有行为是否保持。

### Task 1: Pin date/time behavior with testable helpers

**Files:**
- Create: `Sources/JiedianCore/DeadlinePlanner.swift`
- Modify: `Sources/JiedianApp/CapturePanelView.swift`
- Test: `Sources/JiedianChecks/main.swift`

**Interfaces:**
- Produces `DeadlinePlanner.defaultDeadline(now:calendar:)` at 08:00:00 and `DeadlinePlanner.weekDateChoices(now:calendar:)` with 14 localized date choices; produces `DeadlinePlanner.clampedSeconds(_:)` for the UI.

- [x] **Step 1: Write failing checks** for 08:00:00 default, 14 date choices in Monday-first order, and seconds clamping.
- [x] **Step 2: Run `swift run JiedianChecks`** and confirm the new assertions fail before implementation.
- [x] **Step 3: Implement the smallest helper changes** in `DeadlinePlanner` and preserve the existing save/validation contract.
- [x] **Step 4: Run `swift run JiedianChecks`** and confirm the new assertions pass.

### Task 2: Build the two-tab deadline editor

**Files:**
- Modify: `Sources/JiedianApp/CapturePanelView.swift`

**Interfaces:**
- Consumes `DeadlinePlanner.weekDateChoices(now:calendar:)` and the shared `draft.deadline`.
- Produces the quick tab, calendar tab, shared time controls, and seconds field.

- [x] **Step 1: Add a failing compile/test seam** for the new deadline mode and seconds control if the helper is extracted; otherwise use the Task 1 checks as the seam.
- [x] **Step 2: Implement the tab chrome and quick view** with two side-by-side columns: date choices on the left, editable time on the right.
- [x] **Step 3: Implement the calendar view** with a month calendar on the left and editable hour/minute/second fields on the right.
- [x] **Step 4: Wire every control to the shared deadline** and mark the deadline confirmed on explicit selection/edit.
- [x] **Step 5: Run `swift build -c release`** and fix any SwiftUI/AppKit compile diagnostics.

### Task 3: Default screenshot selection and reset behavior

**Files:**
- Modify: `Sources/JiedianApp/CapturePanelView.swift`

**Interfaces:**
- Consumes the existing `startScreenshotCapture`, `clearScreenshotData`, and capture-session lifecycle.
- Produces a default-on screenshot draft without changing explicit cancellation or permission recovery.

- [x] **Step 1: Set new-session screenshot state to enabled** and start capture after the draft is initialized.
- [x] **Step 2: Keep unchecking the toggle as an explicit cancellation path** and preserve retry/error behavior.
- [x] **Step 3: Run the full core checks and release build** after the UI/state changes.

### Task 4: Finish verification

**Files:**
- Modify: `task_plan.md`, `progress.md`

- [x] **Step 1: Run `swift run JiedianChecks`.
- [x] **Step 2: Run `swift build -c release`.
- [x] **Step 3: Run `git diff --check` and review the diff for scope.
- [x] **Step 4: Update the planning files with evidence and any remaining limitation (runtime Screen Recording permission is user-controlled).**
