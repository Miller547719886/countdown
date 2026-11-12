# 可配置提前提醒与新建事项自动同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让新待办可设置多条提前提醒，并在 Apple Calendar 同步开启时于保存后自动同步。

**Architecture:** 在 JiedianCore 保存兼容旧数据的提醒规则和日期计算；CapturePanelView 编辑规则，AppCoordinator 负责通知生命周期；CalendarSyncService 提供明确的新建同步入口，沿用 EventKit upsert。

**Tech Stack:** Swift 5.10、SwiftUI、UserNotifications、EventKit、JSON。

**Spec:** `docs/superpowers/specs/2026-11-12-configurable-reminders-and-auto-calendar-sync-design.md`

## Global Constraints

- 最低平台为 macOS 14；使用原生框架与现有视觉系统。
- 新提醒默认提前 N 到 1 天、每天 08:00；提醒次数默认 1。
- 缺少提醒字段的旧 JSON 继续在截止时刻提醒。
- 通知权限未授权时仍允许保存事项；日历同步关闭时不得写入 EventKit。

## Review Focus

- 旧 JSON 缺少提醒字段：必须继续在截止时刻提醒。
- 提醒次数增减：行数与默认 N…1 天数一致，已有自定义日期保持稳定。
- 修改截止日期：相对规则随期限重算，自定义日期超出期限时阻止保存并提示。
- 完成、恢复、删除、修改：分别取消、重建或更新正确的通知请求，不留下过期提醒。
- 日历权限或同步关闭：事项仍保存成功；只有已启用并配置日历时才执行新建同步。

---

### Task 1: 提醒模型与本地持久化

**Files:**
- Create: `Sources/JiedianCore/DeadlineReminder.swift`
- Modify: `Sources/JiedianCore/CaptureItem.swift`
- Modify: `Sources/JiedianCore/ItemStore.swift`

**Interfaces:**
- `DeadlineReminderMode`: `.relative` 与 `.custom`。
- `DeadlineReminder`: 保存模式、提前天数、时刻与可选自定义日期，并能相对期限计算触发时刻。
- `ReminderPlanner.defaultReminders(count:)` 与 `resize(_:to:)`：生成默认规则并调整次数。
- `CaptureItem.reminders` 与 `ItemStore.add(..., reminders:)`：持久化新规则。

- [x] 添加提醒模式、默认计划、次数调整和触发时刻计算。
- [x] 将提醒数组加入 `CaptureItem` 编解码；缺少字段的老记录回退为截止时刻提醒。
- [x] 将提醒数组接入 `ItemStore.add`，新建事项默认一条提前一天 08:00。
- [x] 检查 JSON 兼容路径与新增字段的调用点。

### Task 2: 创建表单与本地通知生命周期

**Files:**
- Modify: `Sources/JiedianApp/CapturePanelView.swift`
- Modify: `Sources/JiedianApp/AppCoordinator.swift`
- Modify: `Sources/JiedianApp/SettingsView.swift`

**Interfaces:**
- `CaptureDraft.reminders` 与 `reminderCount` 驱动动态提醒行。
- `NotificationService` 按提醒触发时刻创建日历通知，并支持重排与取消。
- Coordinator 在新增、修改、完成、恢复、删除时维护通知。

- [x] 在期限表单后添加提醒次数控件，默认 1；0 为不提醒，最多 30 次。
- [x] 为每条提醒提供相对天数/时间和自定义日历/时间两种编辑方式，默认 N 到 1 天、08:00。
- [x] 将提醒规则传入保存流程；自定义提醒晚于期限时给出错误并禁用保存。
- [x] 用稳定请求标识安排未来通知；启动时重建活动事项的通知，修改/完成/恢复/删除时重排或取消。
- [x] 更新设置页对本地提醒行为的说明。

### Task 3: 新建事项自动同步与产品说明

**Files:**
- Modify: `Sources/JiedianApp/CalendarSyncService.swift`
- Modify: `Sources/JiedianApp/AppCoordinator.swift`
- Modify: `Sources/JiedianApp/CalendarSyncSettingsView.swift`
- Modify: `README.md`
- Modify: `PRODUCT.md`

**Interfaces:**
- `CalendarSyncService.syncNewItem(_:)` 对已保存的新事项执行启用状态受控的本地 upsert。
- Coordinator 在 `ItemStore.add` 成功后调用 `syncNewItem`。

- [x] 添加新建事项同步入口，并从保存成功路径直接调用。
- [x] 明确区分新建自动同步与旧事项显式迁移。
- [x] 更新产品说明，注明多条提前提醒与新建事项自动同步。
- [x] 运行 `swift build -c release` 与 `git diff --check`，读取完整结果并记录未验证的部分。

**Verification:** `swift build -c release` exited 0; `git diff --check` exited 0. Automated behavior checks were not run.
