# 日历年月快速跳转实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在日历模式中用原生年份/月菜单快速跳转浏览月份，同时保留翻月按钮。

**Architecture:** 将 `calendarMonth` 作为唯一浏览状态，为它提供年份和月份绑定。年月选择器更新该状态，不触碰截止日期；翻月按钮在支持范围边界停止。

**Tech Stack:** SwiftUI、Foundation `Calendar`、现有 `JiedianApp` 目标。

**Spec:** `docs/superpowers/specs/2026-11-12-calendar-month-jump-design.md`

## Global Constraints

- 保留现有日历格、截止日期、休/班、节气、今天及过去日期行为。
- 年份选择范围是 1900–2100，月份选择范围是 1–12。
- 不添加依赖，不引入文本日期解析。

## Review Focus

- 改变浏览年月时，已选截止日期必须保持不变。
- 翻月按钮到达 1900 年 1 月或 2100 年 12 月时必须禁用。
- 年、月菜单须有可辨识的辅助功能名称。

---

### Task 1: 在日历标题栏添加年月选择器

**Files:**
- Modify: `Sources/JiedianApp/CapturePanelView.swift`
- Create: `docs/superpowers/specs/2026-11-12-calendar-month-jump-design.md`
- Create: `docs/superpowers/plans/2026-11-12-calendar-month-jump.md`

**Interfaces:**
- Consumes: 现有 `calendarMonth: Date` 浏览状态和 `shiftCalendarMonth(by:)`。
- Produces: `calendarYearBinding`、`calendarMonthBinding` 与 `setCalendarMonth(year:month:)`，均限于 `CapturePanelView`。

- [x] 在现有标题栏中将静态年月标题换成两个 `.menu` 风格的 SwiftUI `Picker`：年份 1900...2100、月份 1...12。给控件设置可访问名称和提示。
- [x] 选择年月时只用公历年月组件更新 `calendarMonth`，并将日设为 1；不更改 `draft.deadline`。
- [x] 保留前后翻月按钮；在 1900 年 1 月禁用向前，在 2100 年 12 月禁用向后。
- [x] 删除不再使用的静态标题格式化属性，保持标题栏紧凑并沿用现有字体与颜色。
- [x] 运行 `swift build -c release` 确认 SwiftUI 控件和绑定可编译。
