# Chinese Calendar Annotations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add verified Chinese statutory holiday/make-up-workday and 24-solar-term annotations to the existing capture-panel month calendar.

**Architecture:** Keep `CapturePanelView` as a presentation layer and add a synchronous, read-only `ChineseCalendarData` query in `JiedianCore`. Vendor the Swift-native `Tyme4Swift 1.5.0` package for solar terms and bundle annual `NateScarlet/holiday-cn` JSON files for official holiday schedules; missing holiday years return no holiday marker instead of inferred data.

**Tech Stack:** Swift 5.10, Swift Package Manager, macOS 14+, SwiftUI, Foundation, local MIT `Tyme4Swift` package, `Codable` JSON resources.

**Spec:** `docs/superpowers/specs/2026-11-11-chinese-calendar-annotations-design.md`

## Global Constraints

- Do not hand-write annual statutory-holiday or make-up-workday rules.
- Use `Tyme4Swift 1.5.0` for solar-term dates; support its 1900—2100 calendar range.
- Bundle `holiday-cn` annual JSON with its official `papers` URLs and retain MIT notices.
- Missing holiday coverage must be represented as no holiday marker, never as a guessed schedule.
- Preserve existing date selection, past-date disabling, and deadline persistence behavior.

## Review Focus

- A date present in `holiday-cn` as `isOffDay: false` must be shown as “班”, not “休”; covered by the core data test for 2026-02-14.
- A date with no bundled annual file must not be marked by weekday inference; covered by the uncovered-year test for 2028-01-01.
- A solar-term date that is not a holiday must still show its term; covered by the 2026-02-04 立春 test.
- A date can have both a holiday and a solar term; covered by the core info shape and the calendar-cell accessibility construction/build inspection.
- Invalid/missing bundled JSON must not make the calendar query crash; covered by the loader's skip-invalid behavior and full check run.

---

### Task 1: Pin upstream data and dependency resources

**Files:**
- Modify: `Package.swift`
- Create: `Vendor/Tyme4Swift/` (upstream package at 1.5.0, including its MIT license/version record)
- Create: `Sources/JiedianCore/Resources/Holidays/2007.json` through `2027.json` (unmodified `NateScarlet/holiday-cn` files)
- Create: `Sources/JiedianCore/Resources/ThirdParty/holiday-cn-LICENSE.txt`
- Create: `THIRD_PARTY_NOTICES.md`

**Interfaces:**
- Produces a local `Tyme4Swift` package product available to `JiedianCore`.
- Produces `Bundle.module` resources under `Holidays/` and `ThirdParty/`.

- [ ] **Step 1: Verify upstream inputs before copying**

  Pin `Tyme4Swift` to release 1.5.0 and copy its unmodified source/package/license. Fetch the currently available `holiday-cn` year files 2007—2027 without rewriting their JSON contents; retain each file's `papers` field.

- [ ] **Step 2: Update `Package.swift`**

  Add `.package(path: "Vendor/Tyme4Swift")`, make `JiedianCore` depend on product `Tyme4Swift`, and add `.copy("Resources/Holidays")` plus `.copy("Resources/ThirdParty")` to the core target.

- [ ] **Step 3: Check resource/dependency resolution**

  Run `swift package describe` and verify the local package resolves and the core target owns both resource directories.

---

### Task 2: Add the core calendar annotation query with tests first

**Files:**
- Modify: `Sources/JiedianChecks/main.swift`
- Create: `Sources/JiedianCore/ChineseCalendarData.swift`

**Interfaces:**
- Produces `ChineseCalendarHolidayKind`, `ChineseCalendarHoliday`, `ChineseCalendarDayInfo`.
- Produces `ChineseCalendarData.info(for:calendar:) -> ChineseCalendarDayInfo`.

- [ ] **Step 1: Write the failing checks**

  Add fixed Gregorian/UTC checks to `JiedianChecks`:

  ```swift
  var chineseCalendar = Calendar(identifier: .gregorian)
  chineseCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
  let springFestivalDay = chineseCalendar.date(from: DateComponents(year: 2026, month: 2, day: 16))!
  let makeUpWorkday = chineseCalendar.date(from: DateComponents(year: 2026, month: 2, day: 14))!
  let lichun = chineseCalendar.date(from: DateComponents(year: 2026, month: 2, day: 4))!
  let uncovered = chineseCalendar.date(from: DateComponents(year: 2028, month: 1, day: 1))!

  let offInfo = ChineseCalendarData.info(for: springFestivalDay, calendar: chineseCalendar)
  guard offInfo.holiday == ChineseCalendarHoliday(name: "春节", kind: .offDay) else { throw CheckFailure(...) }

  let workInfo = ChineseCalendarData.info(for: makeUpWorkday, calendar: chineseCalendar)
  guard workInfo.holiday == ChineseCalendarHoliday(name: "春节", kind: .makeUpWorkday) else { throw CheckFailure(...) }

  let termInfo = ChineseCalendarData.info(for: lichun, calendar: chineseCalendar)
  guard termInfo.solarTerm == "立春" else { throw CheckFailure(...) }

  guard ChineseCalendarData.info(for: uncovered, calendar: chineseCalendar).holiday == nil else {
      throw CheckFailure("uncovered holiday year was inferred")
  }
  ```

- [ ] **Step 2: Run the checks to verify the expected failure**

  Run `swift run JiedianChecks`.

  Expected: compilation fails because `ChineseCalendarData` and its value types do not exist yet; do not treat this as a passing check.

- [ ] **Step 3: Implement the minimal data model and query**

  In `ChineseCalendarData.swift`, define the public `Equatable, Sendable` value types above. Load `Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Holidays")`, decode the upstream `{ year, papers, days }` shape, merge valid records in ascending announcement-year order, and map `isOffDay` to `.offDay`/`.makeUpWorkday`. Extract the Chinese part of `name` for display. For solar terms, convert supplied Gregorian components to `SolarDay.fromYmd`, return `termDay.solarTerm.getName()` only when `dayIndex == 0` and the year is 1900...2100; return nil on unsupported or invalid dates.

- [ ] **Step 4: Run the checks to verify green**

  Run `swift run JiedianChecks`.

  Expected: all existing checks plus the four new calendar annotation checks pass.

- [ ] **Step 5: Commit the core data layer**

  ```sh
  git add Package.swift Sources/JiedianCore/ChineseCalendarData.swift Sources/JiedianChecks/main.swift Sources/JiedianCore/Resources Vendor/Tyme4Swift THIRD_PARTY_NOTICES.md
  git commit -m "feat: add verified Chinese calendar data"
  ```

---

### Task 3: Render annotations in the month calendar

**Files:**
- Modify: `Sources/JiedianApp/CapturePanelView.swift`
- Modify: `Sources/JiedianApp/DesignSystem.swift` only if a shared annotation color/token is needed

**Interfaces:**
- Consumes `ChineseCalendarData.info(for:calendar:)` and the public value types from Task 2.
- Produces visible “休”/“班” and solar-term labels, a small legend, and complete accessibility labels without changing selection callbacks.

- [ ] **Step 1: Add the failing UI/build expectation**

  Update the calendar-cell implementation to request `ChineseCalendarData.info` and add a temporary compile-time use of `holiday.badge`/`solarTerm`; run `swift build` before adding the final layout so the old cell cannot satisfy the new reference.

- [ ] **Step 2: Implement the calendar-cell annotations**

  Keep the existing day number, selected background, today dot, disabled past-date state, and `selectDeadlineDate` callback. Under the number, render a compact label row: red `休` for `.offDay`, olive `班` for `.makeUpWorkday`, and the solar-term name in muted ink; allow both when they coexist. Increase only the cell's minimum height as needed and add a legend below the weekday/grid rows explaining the markers.

- [ ] **Step 3: Add accessibility text**

  Build the cell's accessibility label from the date plus “今天/已过去” and, when present, the full holiday name/kind and solar-term name. Do not rely on color alone.

- [ ] **Step 4: Verify the app target**

  Run `swift build -c release` and `git diff --check`.

  Expected: the release build and whitespace check pass; no date-selection or deadline checks regress.

---

### Task 4: Audit provenance and final verification

**Files:**
- Modify: `README.md` if a short data-source note is useful
- Review: `THIRD_PARTY_NOTICES.md`, `Vendor/Tyme4Swift/LICENSE`, `Sources/JiedianCore/Resources/ThirdParty/holiday-cn-LICENSE.txt`

- [ ] **Step 1: Confirm provenance is visible**

  Verify the notice names `6tail/tyme4swift` 1.5.0 and `NateScarlet/holiday-cn`, their MIT license texts, the fixed resource coverage (2007—2027), and the official `papers` URLs remain present.

- [ ] **Step 2: Run the complete verification set**

  ```sh
  swift run JiedianChecks
  swift build -c release
  git diff --check
  ```

  Expected: all commands exit 0. Report the exact upstream/data coverage and any intentionally unsupported years; do not claim holiday coverage beyond the bundled files.

