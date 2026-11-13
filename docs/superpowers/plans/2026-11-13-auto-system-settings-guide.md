# 首次启动自动打开系统设置向导 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans (recommended for this small native change) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在首次运行且未获得辅助功能权限时，自动打开 macOS 辅助功能设置，同时保留现有应用内初次使用向导。

**Architecture:** 继续由 `AppCoordinator` 负责首次运行判定、向导生命周期和系统设置深链接。首次向导异步显示后，复用 `openAccessibilitySettings()` 打开现有 Accessibility 深链接；现有 UserDefaults 关闭标记和手动入口不变。

**Tech Stack:** Swift 5.10、SwiftUI、AppKit、ApplicationServices、macOS 14。

**Spec:** `docs/superpowers/specs/2026-11-13-auto-system-settings-guide-design.md`

## Global Constraints

- 只在首次运行向导尚未关闭且当前 Accessibility 未授权时自动跳转。
- 不调用会修改系统权限的 API，不移除手动设置入口。
- 不改变现有向导关闭标记、权限轮询和失败文案。

## Review Focus

- 已授权用户首次看到向导时不应被带到无关的系统设置页；由首次运行逻辑验证。
- 向导已关闭或后续启动不应重复打开系统设置；由 UserDefaults 标记验证。
- 自动跳转失败仍应沿用 `accessibilitySettingsOpenFailed` 状态；由现有打开方法和构建检查覆盖。
- 应用内向导必须先于深链接显示，避免用户只看到系统设置；由异步调用顺序和代码审查覆盖。
- 手动打开系统设置、重新检查和权限轮询行为不能回归；由现有编译及静态检查覆盖。

### Task 1: 首次向导自动深链接

**Files:**
- Modify: `Sources/JiedianApp/AppCoordinator.swift` (`showFirstRunSetupGuideIfNeeded`)
- Create: `Sources/JiedianCore/FirstRunSetupPolicy.swift`
- Modify: `Sources/JiedianChecks/main.swift`
- Test: `swift run JiedianChecks`, `swift build -c release`, and `git diff --check`

**Interfaces:**
- Consumes: existing `showSetupGuide()`, `refreshAccessibilityPermission()`, `openAccessibilitySettings()`, and `hasDismissedSetupGuide`.
- Produces: a testable `FirstRunSetupPolicy.shouldOpenAccessibilitySettings(isGuideDismissed:accessibilityTrusted:)` decision and first-run scheduling that presents the guide and then opens Accessibility Settings only when `AXIsProcessTrusted()` is false.

- [x] **Step 1: Write the failing policy check**

  Add checks to `JiedianChecks` for the three states: first run + untrusted returns `true`; first run + trusted returns `false`; dismissed + untrusted returns `false`.

- [x] **Step 2: Run the check to verify it fails**

  Run: `swift run JiedianChecks`

  Expected: compilation fails because `FirstRunSetupPolicy` is not defined.

- [x] **Step 3: Implement the policy and first-run async closure**

  Add the pure policy in `Sources/JiedianCore/FirstRunSetupPolicy.swift`. Keep the existing one-time guards. After `showSetupGuide()`, refresh the Accessibility state; if `FirstRunSetupPolicy` returns `true`, call `openAccessibilitySettings()`. Do not alter dismissal keys or manual actions.

- [x] **Step 4: Run the checks to verify they pass**

  Run: `swift run JiedianChecks`

  Expected: exit code 0 and the existing core checks plus the first-run policy checks pass.

- [x] **Step 5: Run the release build**

  Run: `swift build -c release`

  Expected: exit code 0 and the `JiedianApp` target compiles.

- [x] **Step 6: Run whitespace validation**

  Run: `git diff --check`

  Expected: no output and exit code 0.

### Task 2: Scope review and verification

**Files:**
- Review: `Sources/JiedianApp/AppCoordinator.swift`
- Review: `Sources/JiedianCore/FirstRunSetupPolicy.swift`
- Review: `docs/superpowers/specs/2026-11-13-auto-system-settings-guide-design.md`

**Interfaces:**
- Consumes: Task 1 implementation and existing setup-guide behavior.
- Produces: verified behavior summary for handoff.

- [x] **Step 1: Inspect the diff**

  Run: `git diff -- Sources/JiedianApp/AppCoordinator.swift`

  Expected: only first-run scheduling changes; no changes to permission mutation, dismissal markers, or manual settings actions.

- [x] **Step 2: Run the project checks**

  Run: `swift run JiedianChecks`

  Expected: exit code 0 and all core checks pass.

- [x] **Step 3: Re-run whitespace validation**

  Run: `git diff --check`

  Expected: no output and exit code 0.
