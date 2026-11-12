import AppKit
import SwiftUI
import JiedianCore

struct CapturePanelView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var draft = CaptureDraft(text: "", deadline: CaptureDraft.defaultDeadline())
    @State private var saveScreenshot = true
    @State private var deadlineMode: DeadlineEditorMode = .quick
    @State private var calendarMonth = Date()
    @State private var screenshotData: Data?
    @State private var screenshotImage: NSImage?
    @State private var screenshotError: ScreenshotCaptureError?
    @State private var screenshotTask: Task<Void, Never>?
    @State private var isCapturingScreenshot = false
    @FocusState private var focusedField: Field?

    private enum Field { case text, date, time }
    private enum DeadlineEditorMode: String, CaseIterable, Identifiable {
        case quick = "快捷设置"
        case calendar = "日历设置"

        var id: String { rawValue }
    }

    private let secondsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = 0
        formatter.maximum = 59
        formatter.minimumIntegerDigits = 2
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader
            Rule(color: Palette.ruleLight)

            if let session = coordinator.captureSession {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 12) {
                        sourceLine(session)
                        textEditor
                        deadlineSection
                        reminderSection
                        screenshotSection
                        if let captureSaveError = coordinator.captureSaveError {
                            Text(captureSaveError)
                                .font(TypeScale.small)
                                .foregroundStyle(Palette.vermilion)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .onAppear {
                        draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                        deadlineMode = .quick
                        calendarMonth = draft.deadline
                        resetScreenshotDraft()
                        focusedField = session.text.isEmpty ? .text : .date
                    }
                    .onChange(of: coordinator.captureSession?.id) { _, _ in
                        guard let session = coordinator.captureSession else { return }
                        draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                        deadlineMode = .quick
                        calendarMonth = draft.deadline
                        resetScreenshotDraft()
                        focusedField = session.text.isEmpty ? .text : .date
                    }
                }
                .scrollIndicators(.automatic)
                .frame(minHeight: 400, alignment: .top)
            }
        }
        .frame(width: 520)
        .background(Palette.paperRaised)
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.light)
        .onExitCommand { coordinator.dismissCapture() }
        .onDisappear { screenshotTask?.cancel() }
        .onChange(of: coordinator.capturePanelSpaceToggleRequest) { _, _ in
            saveScreenshot.toggle()
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 11) {
            Rectangle().fill(Palette.vermilion).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("截下一件事")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ink)
                Text(draft.trimmedText.isEmpty ? "写下这件事，再给它一个期限。" : "原话已就位。现在，给它一个期限。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer()
            Text(coordinator.globalHotKeyShortcut.displayLabel)
                .font(TypeScale.mono)
                .foregroundStyle(Palette.inkFaint)
            Button {
                coordinator.dismissCapture()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(QuietButtonStyle())
            .help("关闭")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func sourceLine(_ session: CaptureSession) -> some View {
        if session.captureMethod == .manual && !coordinator.accessibilityTrusted {
            HStack {
                Spacer()
                Button("查看设置步骤") {
                    coordinator.showSetupGuide(restoreCapturePanel: true)
                }
                .buttonStyle(.plain)
                .font(TypeScale.small)
                .foregroundStyle(Palette.vermilion)
            }
        }
    }

    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("事项")
                .font(TypeScale.label)
                .foregroundStyle(Palette.inkFaint)
            TextEditor(text: $draft.text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .text)
                .padding(.horizontal, 7)
                .padding(.vertical, 7)
                .frame(height: 80)
                .background(Palette.paper)
                .overlay(Rectangle().stroke(focusedField == .text ? Palette.inkFaint : Palette.ruleLight, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if draft.text.isEmpty {
                        Text("在这里输入要记住的事…")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.inkFaint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("截止时间")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.inkFaint)
                Text("必填")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.vermilion)
                Spacer()
                Text(deadlineFeedback)
                    .font(TypeScale.small)
                    .foregroundStyle(draft.isPast ? Palette.vermilion : Palette.inkMuted)
            }

            Picker("截止时间视图", selection: $deadlineMode) {
                ForEach(DeadlineEditorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 224)

            Group {
                switch deadlineMode {
                case .quick:
                    quickDeadlineEditor
                case .calendar:
                    calendarDeadlineEditor
                }
            }
        }
        .onChange(of: deadlineMode) { _, mode in
            if mode == .calendar {
                calendarMonth = draft.deadline
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("提前多久提醒我")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.inkFaint)
                    Text("默认依次提前 N 到 1 天，早上 08:00 提醒。")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                }
                Spacer(minLength: 8)
                Stepper(value: $draft.reminderCount, in: 0...ReminderPlanner.maximumReminderCount) {
                    Text(draft.reminderCount == 0 ? "关闭" : "\(draft.reminderCount) 次")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.ink)
                }
                .accessibilityLabel("提醒次数")
            }

            if draft.reminders.isEmpty {
                Text("这条事项不会提前提醒。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            } else {
                ForEach(draft.reminders.indices, id: \.self) { index in
                    reminderEditor(at: index)
                    if index < draft.reminders.count - 1 {
                        Rule(color: Palette.ruleLight)
                    }
                }
            }

            if draft.hasCustomReminderAfterDeadline {
                Text("自定义提醒时间必须早于截止时间。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.vermilion)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
    }

    private func reminderEditor(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("第 \(index + 1) 次提醒")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Picker(
                    "第 \(index + 1) 次提醒方式",
                    selection: reminderModeBinding(at: index)
                ) {
                    Text("提前天数").tag(DeadlineReminderMode.relative)
                    Text("自定义").tag(DeadlineReminderMode.custom)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            if draft.reminders[index].mode == .relative {
                HStack(spacing: 8) {
                    Stepper(
                        value: reminderDaysBinding(at: index),
                        in: 1...ReminderPlanner.maximumDaysBeforeDeadline
                    ) {
                        Text("提前 \(draft.reminders[index].daysBeforeDeadline) 天")
                            .font(TypeScale.small)
                            .foregroundStyle(Palette.inkMuted)
                    }
                    .accessibilityLabel("第 \(index + 1) 次提前天数")

                    Spacer(minLength: 4)
                    DatePicker(
                        "",
                        selection: reminderTimeBinding(at: index),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .accessibilityLabel("第 \(index + 1) 次提醒时间")
                }
            } else {
                DatePicker(
                    "自定义日期",
                    selection: customReminderDateBinding(at: index),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .accessibilityLabel("第 \(index + 1) 次自定义提醒日期")

                HStack(spacing: 8) {
                    Text("提醒时间")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                    DatePicker(
                        "",
                        selection: customReminderTimeBinding(at: index),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .accessibilityLabel("第 \(index + 1) 次自定义提醒时间")
                    Spacer()
                }
            }
        }
        .padding(.vertical, 7)
    }

    private func reminderModeBinding(at index: Int) -> Binding<DeadlineReminderMode> {
        Binding(
            get: { draft.reminders[index].mode },
            set: { mode in
                var reminder = draft.reminders[index]
                if mode == .custom, reminder.mode != .custom {
                    reminder.customDate = reminder.fireDate(relativeTo: draft.deadline) ?? draft.deadline
                }
                reminder.mode = mode
                draft.reminders[index] = reminder
            }
        )
    }

    private func reminderDaysBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: { draft.reminders[index].daysBeforeDeadline },
            set: { draft.reminders[index].daysBeforeDeadline = $0 }
        )
    }

    private func reminderTimeBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                timePickerValue(
                    hour: draft.reminders[index].hour,
                    minute: draft.reminders[index].minute
                )
            },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                draft.reminders[index].hour = components.hour ?? 8
                draft.reminders[index].minute = components.minute ?? 0
            }
        )
    }

    private func customReminderDateBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                draft.reminders[index].customDate
                    ?? draft.reminders[index].fireDate(relativeTo: draft.deadline)
                    ?? draft.deadline
            },
            set: { value in
                let calendar = Calendar.current
                let current = draft.reminders[index].customDate ?? value
                let time = calendar.dateComponents([.hour, .minute], from: current)
                var components = calendar.dateComponents([.era, .year, .month, .day], from: value)
                components.hour = time.hour ?? 8
                components.minute = time.minute ?? 0
                components.second = 0
                draft.reminders[index].customDate = calendar.date(from: components) ?? value
            }
        )
    }

    private func customReminderTimeBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                let current = draft.reminders[index].customDate
                    ?? draft.reminders[index].fireDate(relativeTo: draft.deadline)
                    ?? draft.deadline
                let components = Calendar.current.dateComponents([.hour, .minute], from: current)
                return timePickerValue(hour: components.hour ?? 8, minute: components.minute ?? 0)
            },
            set: { value in
                let calendar = Calendar.current
                let current = draft.reminders[index].customDate
                    ?? draft.reminders[index].fireDate(relativeTo: draft.deadline)
                    ?? draft.deadline
                let time = calendar.dateComponents([.hour, .minute], from: value)
                var components = calendar.dateComponents([.era, .year, .month, .day], from: current)
                components.hour = time.hour ?? 8
                components.minute = time.minute ?? 0
                components.second = 0
                draft.reminders[index].customDate = calendar.date(from: components) ?? current
            }
        )
    }

    private func timePickerValue(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }

    private var quickDeadlineEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                deadlineSubheading("日期设置")
                weekDateRow(weekOffset: 0)
                weekDateRow(weekOffset: 1)
            }

            VStack(alignment: .leading, spacing: 7) {
                Rule(color: Palette.ruleLight)
                    .padding(.bottom, 2)
                deadlineSubheading("时间设置")
                deadlineTimeControls
                Text("可直接填写，缺省为 08:00:00")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 166, alignment: .leading)
        }
    }

    private var calendarDeadlineEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                deadlineSubheading("日期设置")
                calendarView
            }

            VStack(alignment: .leading, spacing: 7) {
                Rule(color: Palette.ruleLight)
                    .padding(.bottom, 2)
                deadlineSubheading("时间设置")
                deadlineTimeControls
                Text("时、分、秒均可编辑")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
    }

    private func deadlineSubheading(_ title: String) -> some View {
        Text(title)
            .font(TypeScale.section)
            .foregroundStyle(Palette.ink)
    }

    private func weekDateRow(weekOffset: Int) -> some View {
        HStack(spacing: 6) {
            Text(weekOffset == 0 ? "本周" : "下周")
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 32, alignment: .leading)

            ForEach(DeadlinePlanner.weekDateChoices().filter { $0.weekOffset == weekOffset }) { choice in
                dateChoiceButton(choice)
            }
        }
    }

    private func dateChoiceButton(_ choice: DeadlineDateChoice) -> some View {
        let isBeforeToday = DeadlinePlanner.isBeforeToday(choice.date)

        return Button {
            selectDeadlineDate(choice.date)
        } label: {
            VStack(spacing: 3) {
                Text(choice.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(
                        isBeforeToday
                            ? Palette.inkFaint
                            : (isSelected(choice) ? Palette.ink : Palette.inkMuted)
                    )
                    .lineLimit(1)
                HStack(spacing: 2) {
                    Text(DeadlineText.date(choice.date))
                    if Calendar.current.isDateInToday(choice.date) {
                        Text("· 今天")
                            .foregroundStyle(Palette.vermilion)
                    }
                }
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(Palette.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                isSelected(choice) && !isBeforeToday
                    ? Palette.paperDeep
                    : Palette.paperRaised
            )
            .overlay(
                Rectangle()
                    .stroke(
                        isSelected(choice) && !isBeforeToday
                            ? Palette.inkFaint
                            : Palette.ruleLight,
                        lineWidth: 1
                    )
            )
            .opacity(isBeforeToday ? 0.52 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isBeforeToday)
        .accessibilityLabel(
            isBeforeToday
                ? "选择\(choice.label)，\(DeadlinePlanner.dateLabel(choice.date))，已过去"
                : "选择\(choice.label)，\(DeadlinePlanner.dateLabel(choice.date))"
        )
    }

    private var calendarView: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Button {
                    shiftCalendarMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("上个月")
                .disabled(!canNavigateToPreviousCalendarMonth)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    Picker("年份", selection: calendarYearBinding) {
                        ForEach(calendarYearRange, id: \.self) { year in
                            Text("\(year)年").tag(year)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(TypeScale.section)
                    .tint(Palette.ink)
                    .accessibilityLabel("日历年份")
                    .accessibilityHint("选择要浏览的年份")
                    .help("选择年份")

                    Picker("月份", selection: calendarMonthBinding) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(TypeScale.section)
                    .tint(Palette.ink)
                    .accessibilityLabel("日历月份")
                    .accessibilityHint("选择要浏览的月份")
                    .help("选择月份")
                }

                Spacer(minLength: 0)

                Button {
                    shiftCalendarMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("下个月")
                .disabled(!canNavigateToNextCalendarMonth)
            }

            HStack(spacing: 6) {
                ForEach(calendarWeekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: calendarColumns, spacing: 6) {
                ForEach(Array(calendarMonthDates.enumerated()), id: \.offset) { _, date in
                    calendarDayCell(date)
                }
            }

            calendarLegend
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Palette.paper)
        .overlay(Rectangle().stroke(Palette.ruleLight, lineWidth: 1))
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }

    private var calendarWeekdayLabels: [String] {
        ["一", "二", "三", "四", "五", "六", "日"]
    }

    private var calendarLegend: some View {
        HStack(spacing: 10) {
            calendarLegendItem(label: "休", text: "休息日", color: Palette.vermilion)
            calendarLegendItem(label: "班", text: "调休上班", color: Palette.olive)
            calendarLegendItem(label: "节气", text: "二十四节气", color: Palette.inkFaint)
            Spacer(minLength: 0)
        }
        .font(TypeScale.small)
        .foregroundStyle(Palette.inkFaint)
        .padding(.top, 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("日历标记：休息日、调休上班、二十四节气")
    }

    private func calendarLegendItem(label: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
        }
    }

    private let calendarYearRange = 1900...2100

    private var calendarYear: Int {
        Calendar.current.component(.year, from: calendarMonth)
    }

    private var calendarMonthNumber: Int {
        Calendar.current.component(.month, from: calendarMonth)
    }

    private var calendarYearBinding: Binding<Int> {
        Binding(
            get: { calendarYear },
            set: { setCalendarMonth(year: $0, month: calendarMonthNumber) }
        )
    }

    private var calendarMonthBinding: Binding<Int> {
        Binding(
            get: { calendarMonthNumber },
            set: { setCalendarMonth(year: calendarYear, month: $0) }
        )
    }

    private var canNavigateToPreviousCalendarMonth: Bool {
        calendarYear > calendarYearRange.lowerBound || calendarMonthNumber > 1
    }

    private var canNavigateToNextCalendarMonth: Bool {
        calendarYear < calendarYearRange.upperBound || calendarMonthNumber < 12
    }

    private func setCalendarMonth(year: Int, month: Int) {
        guard calendarYearRange.contains(year), (1...12).contains(month) else { return }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        calendarMonth = Calendar.current.date(from: components) ?? calendarMonth
    }

    private var calendarMonthDates: [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: calendarMonth)
        guard let monthStart = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingBlankCount = (weekday + 5) % 7
        var dates = [Date?](repeating: nil, count: leadingBlankCount)
        for day in dayRange {
            dates.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }

        let cellCount = ((dates.count + 6) / 7) * 7
        dates.append(contentsOf: [Date?](repeating: nil, count: cellCount - dates.count))
        return dates
    }

    @ViewBuilder
    private func calendarDayCell(_ date: Date?) -> some View {
        if let date {
            let calendar = Calendar.current
            let selected = calendar.isDate(date, inSameDayAs: draft.deadline)
            let isToday = calendar.isDateInToday(date)
            let isBeforeToday = DeadlinePlanner.isBeforeToday(date, calendar: calendar)
            let info = ChineseCalendarData.info(for: date, calendar: calendar)
            Button {
                selectDeadlineDate(date)
                calendarMonth = date
            } label: {
                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .foregroundStyle(
                                isBeforeToday
                                    ? Palette.inkFaint
                                    : (selected ? Palette.ink : Palette.inkMuted)
                            )
                        Circle()
                            .fill(isToday ? Palette.vermilion : Color.clear)
                            .frame(width: 4, height: 4)
                    }

                    HStack(spacing: 2) {
                        if let holiday = info.holiday {
                            Text("\(holiday.kind.badge)\(holiday.name)")
                                .foregroundStyle(holidayColor(for: holiday))
                        }
                        if let solarTerm = info.solarTerm {
                            Text(solarTerm)
                                .foregroundStyle(Palette.inkFaint)
                        }
                    }
                    .font(.system(size: 8.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    selected && !isBeforeToday
                        ? Palette.paperDeep
                        : Palette.paperRaised
                )
                .overlay(
                    Rectangle()
                        .stroke(
                            selected && !isBeforeToday
                                ? Palette.inkFaint
                                : Palette.ruleLight,
                            lineWidth: 1
                        )
                )
                .opacity(isBeforeToday ? 0.52 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isBeforeToday)
            .accessibilityLabel(
                calendarAccessibilityLabel(
                    for: date,
                    info: info,
                    isToday: isToday,
                    isBeforeToday: isBeforeToday
                )
            )
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityHidden(true)
        }
    }

    private func holidayColor(for holiday: ChineseCalendarHoliday) -> Color {
        holiday.kind == .offDay ? Palette.vermilion : Palette.olive
    }

    private func calendarAccessibilityLabel(
        for date: Date,
        info: ChineseCalendarDayInfo,
        isToday: Bool,
        isBeforeToday: Bool
    ) -> String {
        var parts = [DeadlineText.date(date)]
        if isToday { parts.append("今天") }
        if isBeforeToday { parts.append("已过去") }
        if let holiday = info.holiday {
            parts.append("\(holiday.name)，\(holiday.kind.accessibilityLabel)")
        }
        if let solarTerm = info.solarTerm {
            parts.append("节气\(solarTerm)")
        }
        return parts.joined(separator: "，")
    }

    private func shiftCalendarMonth(by value: Int) {
        let calendar = Calendar.current
        guard let shiftedMonth = calendar.date(
            byAdding: .month,
            value: value,
            to: calendarMonth
        ) else {
            return
        }
        let components = calendar.dateComponents([.year, .month], from: shiftedMonth)
        guard let year = components.year, let month = components.month else { return }
        setCalendarMonth(year: year, month: month)
    }

    private func selectDeadlineDate(_ date: Date) {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: draft.deadline)
        draft.deadline = calendar.date(
            bySettingHour: time.hour ?? 8,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: date
        ) ?? date
        draft.deadlineConfirmed = true
        calendarMonth = draft.deadline
    }

    private var deadlineTimeControls: some View {
        HStack(spacing: 4) {
            FieldBox {
                DatePicker("", selection: $draft.deadline, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .font(TypeScale.body)
                    .focused($focusedField, equals: .time)
                    .onChange(of: draft.deadline) { _, _ in
                        draft.deadlineConfirmed = true
                    }
            }
            .frame(width: 112)

            Text(":")
                .font(TypeScale.mono)
                .foregroundStyle(Palette.inkMuted)

            FieldBox {
                TextField("秒", value: secondsBinding, formatter: secondsFormatter)
                    .textFieldStyle(.plain)
                    .font(TypeScale.mono)
                    .multilineTextAlignment(.center)
                    .frame(width: 34)
                    .accessibilityLabel("秒")
            }
            .frame(width: 50)
        }
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: {
                Calendar.current.component(.second, from: draft.deadline)
            },
            set: { value in
                let seconds = DeadlinePlanner.clampedSeconds(value)
                draft.deadline = Calendar.current.date(
                    bySetting: .second,
                    value: seconds,
                    of: draft.deadline
                ) ?? draft.deadline
                draft.deadlineConfirmed = true
            }
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("取消") {
                coordinator.dismissCapture()
            }
            .buttonStyle(QuietButtonStyle())
            .keyboardShortcut(.cancelAction)
            Spacer()
            Text("会保存到这台 Mac")
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkFaint)
            Button("记下这件事") {
                coordinator.saveCapture(
                    text: draft.trimmedText,
                    deadline: draft.deadline,
                    sourceApp: coordinator.captureSession?.sourceApp,
                    screenshotData: saveScreenshot ? screenshotData : nil,
                    reminders: draft.reminders
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(
                !draft.canSave || isCapturingScreenshot || (saveScreenshot && screenshotData == nil)
            )
        }
    }

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 12) {
                Toggle(isOn: $saveScreenshot) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("保存截图")
                            .font(TypeScale.label)
                            .foregroundStyle(Palette.ink)
                        Text("截取当前屏幕，不含截点面板；仅保存在这台 Mac。")
                            .font(TypeScale.small)
                            .foregroundStyle(Palette.inkFaint)
                    }
                }
                .toggleStyle(.checkbox)

                Spacer(minLength: 0)

                if isCapturingScreenshot {
                    ProgressView()
                        .controlSize(.small)
                        .help("正在截取当前屏幕")
                } else if let screenshotImage {
                    Image(nsImage: screenshotImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 46)
                        .clipped()
                        .overlay(Rectangle().stroke(Palette.ruleLight, lineWidth: 1))
                        .accessibilityLabel("待保存截图预览")
                }
            }

            if let screenshotError {
                HStack(alignment: .center, spacing: 8) {
                    Text(screenshotError.localizedDescription)
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.vermilion)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if case .permissionDenied = screenshotError {
                        Button("打开系统设置") {
                            coordinator.openScreenRecordingSettings()
                        }
                        .buttonStyle(.plain)
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.vermilion)
                    }
                    Button("重试") {
                        startScreenshotCapture()
                    }
                    .buttonStyle(.plain)
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkMuted)
                }
            }

            if coordinator.screenRecordingSettingsOpenFailed {
                Text("无法自动打开系统设置。请手动进入：隐私与安全性 → 屏幕录制。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.vermilion)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
        .onChange(of: saveScreenshot) { _, enabled in
            if enabled {
                startScreenshotCapture()
            } else {
                clearScreenshotData()
            }
        }
    }

    private func startScreenshotCapture() {
        screenshotTask?.cancel()
        screenshotData = nil
        screenshotImage = nil
        screenshotError = nil
        isCapturingScreenshot = true

        let sessionID = coordinator.captureSession?.id
        screenshotTask = Task { @MainActor in
            do {
                let data = try await ScreenshotCaptureService.capturePNG()
                guard !Task.isCancelled,
                      saveScreenshot,
                      coordinator.captureSession?.id == sessionID else { return }
                guard let image = NSImage(data: data) else {
                    screenshotError = .imageEncodingFailed
                    screenshotData = nil
                    screenshotImage = nil
                    isCapturingScreenshot = false
                    screenshotTask = nil
                    return
                }
                screenshotData = data
                screenshotImage = image
            } catch let error as ScreenshotCaptureError {
                guard !Task.isCancelled,
                      coordinator.captureSession?.id == sessionID else { return }
                screenshotError = error
            } catch {
                guard !Task.isCancelled,
                      coordinator.captureSession?.id == sessionID else { return }
                screenshotError = .captureFailed
            }
            isCapturingScreenshot = false
            screenshotTask = nil
        }
    }

    private func clearScreenshotData() {
        screenshotTask?.cancel()
        screenshotTask = nil
        screenshotData = nil
        screenshotImage = nil
        screenshotError = nil
        isCapturingScreenshot = false
    }

    private func resetScreenshotDraft() {
        clearScreenshotData()
        if saveScreenshot {
            startScreenshotCapture()
        } else {
            saveScreenshot = true
        }
    }

    private var deadlineFeedback: String {
        if draft.isPast { return "这个时间已经过去，请重新选择" }
        return DeadlineText.relative(to: draft.deadline)
    }

    private func isSelected(_ choice: DeadlineDateChoice) -> Bool {
        Calendar.current.isDate(choice.date, inSameDayAs: draft.deadline)
    }
}

struct CaptureDraft {
    var text: String
    var deadline: Date
    var deadlineConfirmed = false
    var reminders = ReminderPlanner.defaultReminders()

    var reminderCount: Int {
        get { reminders.count }
        set { reminders = ReminderPlanner.resize(reminders, to: newValue) }
    }

    var hasCustomReminderAfterDeadline: Bool {
        reminders.contains { reminder in
            guard reminder.mode == .custom else { return false }
            guard let customDate = reminder.customDate else { return true }
            return customDate >= deadline
        }
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool {
        !trimmedText.isEmpty
            && deadlineConfirmed
            && deadline > Date()
            && !hasCustomReminderAfterDeadline
    }
    var isPast: Bool { deadline <= Date() }

    static func defaultDeadline(now: Date = Date()) -> Date {
        DeadlinePlanner.defaultDeadline(now: now)
    }

    func asSession(sourceApp: String?, method: SelectionReader.Method) -> CaptureSession {
        CaptureSession(text: trimmedText, sourceApp: sourceApp, captureMethod: method)
    }

}
