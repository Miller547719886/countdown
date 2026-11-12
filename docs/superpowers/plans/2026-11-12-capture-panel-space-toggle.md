# 截取面板空格切换截图保存实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在截取面板聚焦且没有表单控件聚焦时，用纯空格切换“保存截图”；其他焦点场景保持原有空格行为。

**Architecture:** 在 `JiedianCore` 中放置不依赖 UI 的按键资格判断，覆盖 key window、纯空格和表单焦点条件；在 `JiedianApp` 中用专用 `NSPanel` 子类识别第一响应者的控件祖先并在符合条件时发出切换请求。`CapturePanelView` 观察请求计数并切换现有 `saveScreenshot` 状态，截图采集逻辑保持不变。

**Tech Stack:** Swift 5.10/6.1、SwiftUI、AppKit、Foundation、Swift Package Manager、现有 `JiedianChecks` 可执行检查。

**Spec:** `docs/superpowers/specs/2026-11-12-capture-panel-space-toggle-design.md`

## Global Constraints

- 仅响应截取面板收到的纯空格按键，不改变现有 `cmd+1` 全局快捷键。
- 面板是 key window、且第一响应者不是输入框或其他 `NSControl`（包括其子视图）时，切换 SwiftUI 的 `saveScreenshot` 状态。
- 被表单控件聚焦时不拦截空格，由原控件继续处理。
- 不新增全局空格快捷键，不在面板未聚焦时响应。
- 不改变截图采集、取消、重试、保存和 `cmd+return` 行为，不新增依赖。

## Review Focus

- 普通面板内容聚焦时按空格应切换；测试归入 Task 1 的允许路径。
- 文本输入框、日期/时间输入框或其他表单控件聚焦时应不切换；测试归入 Task 1 的表单焦点路径。
- 空格带 Command/Option/Control/Shift 等修饰键时应不切换；测试归入 Task 1 的修饰键路径。
- 非空格按键不应切换；测试归入 Task 1 的按键路径。
- 面板不是 key window 时不应切换；测试归入 Task 1 的窗口路径。

---

### Task 1: 按键资格判断与失败测试

**Files:**
- Modify: `Sources/JiedianChecks/main.swift`（新增按键行为断言）
- Create: `Sources/JiedianCore/CapturePanelKeyboardBehavior.swift`（Task 1 后半段）

**Interfaces:**
- Produces: `CapturePanelKeyboardBehavior.shouldToggleSaveScreenshot(keyCode:hasModifier:isKeyWindow:isFormControlFocused:) -> Bool`；调用方传入按键码、是否带设备无关修饰键、窗口 key 状态和第一响应者是否在表单控件内。

- [ ] **Step 1: 写失败检查**

  在现有 `JiedianChecks.main()` 开头加入五个独立 guard 断言，为以下行为抛出明确的 `CheckFailure`：

  - 普通面板内容聚焦：空格键码、无修饰键、key window、无表单焦点时断言为 `true`。
  - 表单控件聚焦：同样输入但 `isFormControlFocused == true` 时断言为 `false`。
  - 面板非 key window：`isKeyWindow == false` 时断言为 `false`。
  - 带修饰键：`hasModifier == true` 时断言为 `false`。
  - 非空格键：使用其他键码时断言为 `false`。

- [ ] **Step 2: 运行失败测试确认缺少生产接口**

  Run: `swift run JiedianChecks`

  Expected: 编译失败，原因是 `CapturePanelKeyboardBehavior` 尚未定义；不能因为测试脚本或已有检查失败而失败。

- [ ] **Step 3: 实现最小资格判断**

  在 `Sources/JiedianCore/CapturePanelKeyboardBehavior.swift` 定义 `public enum CapturePanelKeyboardBehavior`，提供 `public static let spaceKeyCode: UInt16 = 49` 和上述静态方法。方法只在四个条件同时满足时返回 `true`：键码等于空格键码、没有设备无关修饰键、面板是 key window、第一响应者不在表单控件内。

- [ ] **Step 4: 运行测试确认通过**

  Run: `swift run JiedianChecks`

  Expected: 新增的 5 个按键断言与已有核心检查全部通过，无编译警告或运行时错误。

- [ ] **Step 5: 提交资格判断变更**

  ```bash
  git add Sources/JiedianChecks/main.swift Sources/JiedianCore/CapturePanelKeyboardBehavior.swift docs/superpowers/plans/2026-11-12-capture-panel-space-toggle.md
  git commit -m "test: define capture panel space key behavior"
  ```

### Task 2: 面板事件过滤与 SwiftUI 状态接线

**Files:**
- Create: `Sources/JiedianApp/CapturePanel.swift`
- Modify: `Sources/JiedianApp/AppCoordinator.swift`
- Modify: `Sources/JiedianApp/CapturePanelView.swift`

**Interfaces:**
- Consumes: `CapturePanelKeyboardBehavior.shouldToggleSaveScreenshot(...)` from Task 1.
- Produces: `CapturePanel` subclass; `AppCoordinator.capturePanelSpaceToggleRequest` request counter and `requestCapturePanelSpaceToggle()` method; `CapturePanelView` 对该计数的观察。

- [ ] **Step 1: 在 `CapturePanel` 中实现事件过滤**

  创建 `NSPanel` 子类并覆盖 `keyDown(with:)`。用 `event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty` 计算 `hasModifier`，从 `firstResponder` 沿 `nextResponder` 链检查 `NSControl` 或 `NSTextView`；将这些条件与 `isKeyWindow`、`event.keyCode` 传给 Task 1 的资格判断。返回 `true` 时调用 `onPlainSpace` 并停止传播，否则调用 `super.keyDown(with:)`。

- [ ] **Step 2: 在 `AppCoordinator` 接入面板和请求计数**

  将 `capturePanel` 类型改为 `CapturePanel`，增加从 0 开始的 `@Published` 请求计数和主线程方法 `requestCapturePanelSpaceToggle()`。在 `makeCapturePanel()` 创建 `CapturePanel`，设置 `onPlainSpace` 为弱引用 coordinator 的请求回调；其他面板样式和生命周期保持不变。

- [ ] **Step 3: 在 `CapturePanelView` 观察请求并切换状态**

  在根视图生命周期修饰符中增加对 `coordinator.capturePanelSpaceToggleRequest` 的 `onChange`，每次请求只执行一次 `saveScreenshot.toggle()`。不修改现有 `saveScreenshot` 的 `onChange`，使开启/关闭仍分别触发截图采集和清理。

- [ ] **Step 4: 编译验证事件接线**

  Run: `swift build`

  Expected: `JiedianApp` 和 `JiedianCore` 编译、链接成功；不出现 actor 隔离、AppKit 类型或 SwiftUI `onChange` 签名错误。

- [ ] **Step 5: 运行完整核心检查**

  Run: `swift run JiedianChecks`

  Expected: `JiedianChecks` 中的按键断言及包内所有核心检查通过；记录检查输出。

- [ ] **Step 6: 提交面板快捷键接线**

  ```bash
  git add Sources/JiedianApp/CapturePanel.swift Sources/JiedianApp/AppCoordinator.swift Sources/JiedianApp/CapturePanelView.swift
  git commit -m "feat: toggle screenshot saving with panel space key"
  ```

### Task 3: 发布前复核

**Files:**
- Modify: `docs/superpowers/plans/2026-11-12-capture-panel-space-toggle.md`（勾选完成项，如有必要补充验证记录）

- [ ] **Step 1: 检查差异与行为范围**

  Run: `git diff HEAD~2..HEAD --stat && git diff HEAD~2..HEAD --check`

  Expected: 仅包含设计/计划、键盘资格判断、核心检查、面板事件过滤和状态接线；无空白错误。

- [ ] **Step 2: 运行发布构建**

  Run: `swift build -c release`

  Expected: release 构建成功。

- [ ] **Step 3: 提交最终验证记录（如有变更）**

  ```bash
  git add docs/superpowers/plans/2026-11-12-capture-panel-space-toggle.md
  git commit -m "docs: record capture panel shortcut verification"
  ```
