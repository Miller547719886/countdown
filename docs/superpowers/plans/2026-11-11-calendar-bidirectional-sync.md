# Apple 日历双向同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不引入服务器或 iOS 客户端的前提下，让截点事项与用户选择的 Apple 日历关联事件双向同步，并安全处理权限、冲突和失联事件。

**Architecture:** 将纯同步标记、事件标题/notes 解析、冲突决策放进 `JiedianCore`，用可自动运行的核心检查固定行为。新增主 actor `CalendarSyncService` 负责 EventKit 权限、可写日历、事件 CRUD、外部变更 reconcile 和持久化配置；`AppCoordinator` 统一转发本地事项变更并把服务状态提供给设置页。关联事件使用 `jiedian://item/<UUID>` 标记，EventKit ID 只做快速索引。

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, EventKit, Combine, Foundation, 现有 `JiedianCore` 检查 executable。

**Spec:** `docs/superpowers/specs/2026-11-11-calendar-bidirectional-sync-design.md`

## Global Constraints

- 原生 SwiftUI/AppKit，最低 macOS 14；使用 EventKit 的 `requestFullAccessToEvents` 路径。
- `ItemStore` 仍是主线程隔离的本地领域存储；EventKit service 也在主 actor 协调，避免 UI 与 JSON 同时写入同一事项。
- Info.plist 需要声明日历用途说明；Package 需要链接 EventKit。
- EventKit 事件表示为从 deadline 开始、持续 1 分钟的非全天事件，并在事件开始时设置提醒。
- 只有带 `jiedian://item/<UUID>` 标记的关联事件参与双向同步；普通日历事件不导入。
- 日历端删除只解除关联并保留本地事项；本地删除不为同步错误保留隐形事项，错误显示在设置页的全局状态。
- 关闭同步不删除已有日历事件；显式解除关联时才按用户选择删除它们。
- 不修改现有截图、全局快捷键、通知和纸张/墨色/朱砂视觉系统。

## Review Focus

- **旧 JSON 缺少新增字段**：解码应回退到 `createdAt`/`unlinked`，由 Task 1/2 的兼容性检查固定。
- **用户文字包含 `✓` 或换行 notes**：只能剥离截点自己维护的前缀/标记，不能破坏用户内容，由 Task 1 的 marker 解析检查固定。
- **EventKit ID 在同步中变化**：应先用保存 ID、再用 URL 标记恢复，并把重复标记标为需要处理，由 Task 3 的解析/重发现检查固定。
- **自写事件触发外部变更通知**：不能循环写入或重复添加标题前缀，由 Task 4 的同步队列/重入检查和手动 reconcile 验证覆盖。
- **权限拒绝、只读日历、日历端删除**：本地事项仍可用，状态可重试且不会静默丢失，由 Task 3/5 的错误路径检查和手动验收覆盖。

---

### Task 1: 纯同步模型、标记和冲突决策

**Files:**
- Create: `Sources/JiedianCore/CalendarSyncModels.swift`
- Modify: `Sources/JiedianChecks/main.swift`

**Interfaces:**
- Produces `public enum CalendarSyncState: String, Codable, Sendable` with `unlinked`, `synced`, `needsAttention`.
- Produces `public struct CalendarLink: Codable, Equatable, Sendable` with optional `eventIdentifier`, `calendarItemExternalIdentifier`, `calendarIdentifier`, and `lastSyncedAt`.
- Produces `public enum CalendarMarker` with `url(for:itemID:isCompleted:)`, `parse(url:)`, `applyCompletionPrefix(to:isCompleted:)`, `removeCompletionPrefix(from:)`, `itemText(fromEventTitle:isCompleted:)`, and a notes marker append/replace parser that preserves user notes.
- Produces `public enum CalendarConflictResolver` with a deterministic `winner(localUpdatedAt:eventUpdatedAt:) -> .local | .event | .needsAttention` result.
- Produces `public struct CalendarSyncIntent: Equatable, Sendable` describing a local mutation (`upsert`, `remove`, `reconcile`) without importing EventKit, so core checks and the app service share the same re-entry contract.
- Produces `public struct CalendarEventCandidate: Equatable, Sendable` and a marker-based selector that chooses the newest candidate while reporting duplicates needing attention.

- [x] **Step 1: Write failing core checks** in `JiedianChecks/main.swift` for:
  - `jiedian://item/<UUID>` round-trips the UUID and completion state.
  - `✓ ` is added once, removed only when it is the maintained prefix, and a user title such as `✓ review` is otherwise preserved.
  - The notes marker can be replaced without deleting surrounding user notes.
  - Duplicate marker candidates choose the newest event and report the duplicate condition.
  - local newer, event newer, and equal/unknown timestamps choose the documented winner.
- [x] **Step 2: Run `swift run JiedianChecks`** and verify the new checks fail because the model/parser types do not exist.
- [x] **Step 3: Implement the smallest pure types** in `CalendarSyncModels.swift`; use a versioned marker payload so future fields can be added without importing unmarked events.
- [x] **Step 4: Run `swift run JiedianChecks`** and verify all marker and conflict checks pass with no regressions.
- [x] **Step 5: Commit** `git add Sources/JiedianCore/CalendarSyncModels.swift Sources/JiedianChecks/main.swift && git commit -m "feat: add calendar sync markers"`.

### Task 2: Backward-compatible item links and mutation timestamps

**Files:**
- Modify: `Sources/JiedianCore/CaptureItem.swift`
- Modify: `Sources/JiedianCore/ItemStore.swift`
- Modify: `Sources/JiedianChecks/main.swift`

**Interfaces:**
- `CaptureItem` gains `var updatedAt: Date`, `var calendarLink: CalendarLink?`, and `var calendarSyncState: CalendarSyncState`.
- `CaptureItem.init` keeps all current call sites source-compatible and defaults `updatedAt` to `createdAt`, link to `nil`, and state to `.unlinked`.
- `ItemStore.update(_ item: CaptureItem, updatedAt: Date? = nil) -> Bool` normalizes text, preserves linked metadata, and uses the supplied event timestamp only for calendar-originated updates.
- `ItemStore.complete(_ id: UUID) -> CaptureItem?`, `restore(_ id: UUID) -> CaptureItem?`, and `delete(_ id: UUID) -> CaptureItem?` return the affected value while remaining source-compatible for ignored results.

- [x] **Step 1: Write failing core checks** for legacy JSON decoding with no new keys, `updatedAt` changing on local update/complete/restore, preserving a `CalendarLink` through reload, and returning the removed item from `delete`.
- [x] **Step 2: Run `swift run JiedianChecks`** and verify the checks fail on missing fields/signatures or incorrect timestamps.
- [x] **Step 3: Add explicit `Codable` keys and `init(from:)`** in `CaptureItem`, falling back to `createdAt` and `.unlinked`; update `ItemStore` persistence/mutation methods and rollback paths without changing existing sorting or attachment behavior.
- [x] **Step 4: Run `swift run JiedianChecks`** and verify old/new records, screenshot attachments, sorting, overdue, complete, restore, and deletion checks all pass.
- [x] **Step 5: Commit** `git add Sources/JiedianCore/CaptureItem.swift Sources/JiedianCore/ItemStore.swift Sources/JiedianChecks/main.swift && git commit -m "feat: persist calendar links on items"`.

### Task 3: EventKit service and event reconciliation

**Files:**
- Create: `Sources/JiedianCore/CalendarEventProjection.swift`
- Create: `Sources/JiedianApp/CalendarSyncService.swift`
- Modify: `Package.swift`
- Modify: `Resources/Info.plist`

**Interfaces:**
- `@MainActor final class CalendarSyncService: ObservableObject` owns one long-lived `EKEventStore` and exposes `accessStatus`, `availableCalendars`, `selectedCalendarIdentifier`, `syncStateText`, `lastSyncAt`, `pendingCount`, and `lastError` for SwiftUI.
- `requestAccess() async`, `refreshAccessAndCalendars()`, `selectCalendar(identifier:)`, `syncExistingItems()`, `retrySync()`, `syncLocalMutation(before:after:)`, `reconcile()`, and `unlinkAll(deleteEvents:)` are the service entry points.
- `CalendarOption` is an app-facing value containing calendar ID, title, source title, writable flag, and iCloud/source classification; the UI never receives raw mutable `EKCalendar` objects.
- `CalendarEventProjection` is a pure core DTO built from a `CaptureItem`, fixing title, deadline, one-minute end, marker URL, completion state, and the owned notes segment before EventKit mapping.

- [x] **Step 1: Write failing core checks** in `JiedianChecks` for a projection at deadline `D`: title/prefix, start `D`, end `D + 60s`, marker URL, and completion notes are exactly the values the EventKit adapter must apply.
- [x] **Step 2: Run `swift run JiedianChecks`** and verify the projection checks fail because `CalendarEventProjection` does not exist.
- [x] **Step 3: Implement `CalendarEventProjection`** in `JiedianCore`, then link EventKit and add calendar usage descriptions (`NSCalendarsFullAccessUsageDescription`, with the legacy usage key retained for older system behavior) in the package and plist.
- [x] **Step 4: Implement permission and calendar discovery** using macOS 14 full event access, filtering to calendars that support events and `allowsContentModifications`, and persist only the selected calendar ID/title/source fallback in `UserDefaults`.
- [x] **Step 5: Implement event CRUD**: map the projection to a one-minute non-all-day event with a zero-offset alarm; update only title/start/end/owned notes; remove events only for explicit local deletion or `unlinkAll(deleteEvents: true)`.
- [x] **Step 6: Implement re-discovery and reconcile**: use saved event ID first, then external ID/calendar ID, then scan a bounded ±4-year window for the URL marker; handle duplicate markers as `.needsAttention`, external deletion as unlinked local state, and event title/start changes as local updates using `lastModifiedDate`.
- [x] **Step 7: Observe `EKEventStoreChangedNotification`** with a 0.5-second debounce, serialize work on the main actor, guard local writes against re-entrant notifications, and expose global errors instead of throwing away local items.
- [x] **Step 8: Run `swift build -c release`** and fix only EventKit/API availability or concurrency diagnostics; run `swift run JiedianChecks` to keep core checks green.
- [x] **Step 9: Commit** `git add Sources/JiedianCore/CalendarEventProjection.swift Sources/JiedianApp/CalendarSyncService.swift Package.swift Resources/Info.plist && git commit -m "feat: sync linked items with EventKit"`.

### Task 4: Wire local mutations and app lifecycle

**Files:**
- Modify: `Sources/JiedianCore/CalendarSyncModels.swift`
- Modify: `Sources/JiedianApp/AppCoordinator.swift`
- Modify: `Sources/JiedianApp/JiedianApp.swift`
- Modify: `Sources/JiedianApp/MainWindowView.swift`
- Modify: `Sources/JiedianApp/EditItemSheet.swift`
- Modify: `Sources/JiedianApp/CapturePanelView.swift`

**Interfaces:**
- `AppCoordinator` retains/configures `CalendarSyncService`, exposes it (or forwards its published settings state), and wraps `update`, `complete`, `restore`, and `delete` so every successful local mutation calls `syncLocalMutation(before:after:)`.
- Existing save flow calls the service after `ItemStore.add` persists; capture save remains usable when calendar access is unavailable.
- Main window and edit sheet call coordinator mutation wrappers rather than mutating `ItemStore` directly.

- [x] **Step 1: Write a failing integration seam** in `JiedianChecks` for a local mutation producing one `CalendarSyncIntent` and for a calendar-originated update not being re-written as a second local mutation; use the pure intent/guard type from Task 1, not a live calendar store.
- [x] **Step 2: Run `swift run JiedianChecks`** and verify the seam fails before coordinator wiring exists.
- [x] **Step 3: Add coordinator wrappers and service configuration** in `JiedianApp`; keep the existing notification scheduling and screenshot behavior unchanged.
- [x] **Step 4: Replace direct UI mutations** in `MainWindowView` and `EditItemSheet` with coordinator calls; pass the coordinator where the views already have access to the store.
- [x] **Step 5: Start service configuration/reconcile once in `JiedianApp`** after the store is available, and ensure app relaunch rehydrates the selected calendar and linked-item state.
- [x] **Step 6: Run `swift run JiedianChecks` and `swift build -c release`**; verify no existing capture/main-window behavior regresses.
- [x] **Step 7: Commit** `git add Sources/JiedianCore/CalendarSyncModels.swift Sources/JiedianApp/AppCoordinator.swift Sources/JiedianApp/JiedianApp.swift Sources/JiedianApp/MainWindowView.swift Sources/JiedianApp/EditItemSheet.swift Sources/JiedianApp/CapturePanelView.swift Sources/JiedianChecks/main.swift && git commit -m "feat: route local mutations through calendar sync"`.

### Task 5: Settings UI, permission recovery, and explicit migration

**Files:**
- Create: `Sources/JiedianApp/CalendarSyncSettingsView.swift`
- Modify: `Sources/JiedianApp/SettingsView.swift`
- Modify: `Sources/JiedianApp/DesignSystem.swift` only if a new control needs an existing-style token

**Interfaces:**
- `CalendarSyncSettingsView` consumes `AppCoordinator`/`CalendarSyncService` published state and renders permission, calendar picker, iCloud explanation, sync status, “同步现有事项”, “重试同步”, “打开系统设置”, and “解除关联” actions.
- `SettingsView` embeds the new section without changing existing accessibility, notification, or hot-key rows.

- [x] **Step 1: Write a failing UI compile seam** by referencing `CalendarSyncSettingsView` from `SettingsView` and assert the service state labels/helpers in a small pure check where possible.
- [x] **Step 2: Run `swift build -c release`** and verify the missing view/state references fail before implementation.
- [x] **Step 3: Implement the settings section** with the existing paper/ink/vermilion styles, explicit permission-denied recovery text, writable calendar list, selected calendar persistence, and global error/pending counts.
- [x] **Step 4: Implement explicit “同步现有事项”** to create links only on demand; disabling sync stops future automatic writes and does not remove events; unlink action asks before optionally deleting linked events.
- [x] **Step 5: Run `swift build -c release`** and verify the settings sheet fits at its minimum size and existing settings controls still compile.
- [x] **Step 6: Commit** `git add Sources/JiedianApp/CalendarSyncSettingsView.swift Sources/JiedianApp/SettingsView.swift Sources/JiedianApp/DesignSystem.swift && git commit -m "feat: add calendar sync settings"`.

### Task 6: Full verification and handoff

**Files:**
- Modify: `README.md`
- Modify: `PRODUCT.md`
- Modify: `progress.md`

- [x] **Step 1: Run the complete core checks** with `swift run JiedianChecks`; expected output includes marker, persistence, sorting, overdue, complete, restore, and screenshot attachment checks.
- [x] **Step 2: Build the release app** with `swift build -c release`; expected exit code 0 with no EventKit availability warnings.
- [x] **Step 3: Package and inspect the app** with `sh scripts/build-app.sh`; verify `codesign --verify --deep --strict --verbose=2 dist/截点.app` and confirm the plist contains the calendar usage descriptions.
- [x] **Step 4: Run `git diff --check` and review the diff** for scope, accidental changes to screenshots/permissions, and no untracked generated data.
- [x] **Step 5: Manually verify in a disposable iCloud test calendar** only if the user grants Calendar access: create/edit/complete/restore/delete in both directions, move the event, delete it on the calendar side, and confirm non-owned events are untouched. Skipped because Calendar access was not granted in this turn.
- [x] **Step 6: Update README/Product/progress** with setup caveats: Calendar permission, writable iCloud calendar requirement, linked-event-only import, and the safe deletion behavior.
- [x] **Step 7: Commit** `git add README.md PRODUCT.md progress.md docs/superpowers/specs/2026-11-11-calendar-bidirectional-sync-design.md docs/superpowers/plans/2026-11-11-calendar-bidirectional-sync.md && git commit -m "docs: describe calendar bidirectional sync"`.

## Self-review

- **Spec coverage:** permissions and calendar selection are Task 3/5; linked ownership and marker semantics are Task 1/3; local persistence is Task 2; local and external mutation paths are Task 4/3; conflict/deletion semantics are Task 3; iCloud caveat and manual acceptance are Task 5/6.
- **Step scan:** each task starts with a failing seam/check, implements one bounded responsibility, then runs the relevant core/build verification before its commit.
- **Type consistency:** `CalendarLink`, `CalendarSyncState`, and marker helpers are defined in Task 1; `CaptureItem` consumes them in Task 2; the service consumes both in Task 3; coordinator/UI consume service APIs in Tasks 4/5.
- **Review focus coverage:** every listed failure mode names its owning task and test/manual check; EventKit-only paths are explicitly separated from the core executable because live permissions cannot be automated safely.
- **Proportion:** the plan adds six independently reviewable tasks while leaving EventKit method bodies to the implementer; exact product decisions are carried by the spec and interface blocks.
