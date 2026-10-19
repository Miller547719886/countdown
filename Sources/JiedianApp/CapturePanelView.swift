import SwiftUI
import JiedianCore

struct CapturePanelView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var draft = CaptureDraft(text: "", deadline: CaptureDraft.defaultDeadline())
    @FocusState private var focusedField: Field?

    private enum Field { case text, date, time }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader
            Rule(color: Palette.ruleLight)

            if let session = coordinator.captureSession {
                VStack(alignment: .leading, spacing: 18) {
                    sourceLine(session)
                    textEditor
                    deadlineSection
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .onAppear {
                    draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                    focusedField = session.text.isEmpty ? .text : .date
                }
                .onChange(of: coordinator.captureSession?.id) { _, _ in
                    guard let session = coordinator.captureSession else { return }
                    draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                    focusedField = session.text.isEmpty ? .text : .date
                }
            }
        }
        .frame(width: 560)
        .background(Palette.paperRaised)
        .preferredColorScheme(.light)
        .onExitCommand { coordinator.dismissCapture() }
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
            Text("⌘ 1")
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
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    private func sourceLine(_ session: CaptureSession) -> some View {
        HStack(spacing: 7) {
            Image(systemName: session.captureMethod == .manual ? "keyboard" : "selection.pin.in.out")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
            Text(session.captureMethod.label)
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkMuted)
            if let app = session.sourceApp {
                Text("· \(app)")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            }
            Spacer()
            if session.captureMethod == .manual && !coordinator.accessibilityTrusted {
                Button("开启选区捕获") {
                    coordinator.openAccessibilitySettings()
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
                .frame(height: 92)
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
            HStack {
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

            HStack(spacing: 7) {
                ForEach(CaptureDraft.quickChoices()) { choice in
                    Button {
                        draft.deadline = choice.deadline
                        draft.deadlineConfirmed = true
                    } label: {
                        Text(choice.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 9)
                            .frame(height: 27)
                            .background(isSelected(choice) ? Palette.paperDeep : Palette.paperRaised)
                            .overlay(Rectangle().stroke(isSelected(choice) ? Palette.inkFaint : Palette.ruleLight, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                FieldBox {
                    DatePicker("", selection: $draft.deadline, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .font(TypeScale.body)
                        .focused($focusedField, equals: .date)
                }
                .frame(width: 190)
                .onChange(of: draft.deadline) { _, _ in
                    draft.deadlineConfirmed = true
                }

                FieldBox {
                    DatePicker("", selection: $draft.deadline, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .font(TypeScale.body)
                        .focused($focusedField, equals: .time)
                }
                .frame(width: 116)

                Spacer()
                Text(draft.deadlineConfirmed ? "期限已确认" : "请确认期限")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
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
                    sourceApp: coordinator.captureSession?.sourceApp
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!draft.canSave)
        }
    }

    private var deadlineFeedback: String {
        if draft.isPast { return "这个时间已经过去，请重新选择" }
        return DeadlineText.relative(to: draft.deadline)
    }

    private func isSelected(_ choice: CaptureDraft.QuickChoice) -> Bool {
        abs(draft.deadline.timeIntervalSince(choice.deadline)) < 60
    }
}

struct CaptureDraft {
    var text: String
    var deadline: Date
    var deadlineConfirmed = false

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedText.isEmpty && deadlineConfirmed && deadline > Date() }
    var isPast: Bool { deadline <= Date() }

    static func defaultDeadline(now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let tonight = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
        if tonight > now.addingTimeInterval(1_800) {
            return tonight
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    static func quickChoices(now: Date = Date()) -> [QuickChoice] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let tomorrowAtNine = date(at: 9, on: tomorrow, calendar: calendar)
        var choices: [QuickChoice] = []

        let todayAtSix = date(at: 18, on: today, calendar: calendar)
        if todayAtSix > now {
            choices.append(QuickChoice(label: "今天 18:00", deadline: todayAtSix))
        }

        let tonightAtTen = date(at: 22, on: today, calendar: calendar)
        if tonightAtTen > now {
            choices.append(QuickChoice(label: "今晚 22:00", deadline: tonightAtTen))
        }

        choices.append(QuickChoice(label: "明天 09:00", deadline: tomorrowAtNine))

        let monday = nextMonday(after: now, calendar: calendar)
        if !calendar.isDate(monday, equalTo: tomorrowAtNine, toGranularity: .minute) {
            choices.append(QuickChoice(label: "下周一", deadline: monday))
        }
        return choices
    }

    func asSession(sourceApp: String?, method: SelectionReader.Method) -> CaptureSession {
        CaptureSession(text: trimmedText, sourceApp: sourceApp, captureMethod: method)
    }

    struct QuickChoice: Identifiable {
        let label: String
        let deadline: Date
        var id: String { label }
    }

    private static func date(at hour: Int, on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private static func nextMonday(after now: Date, calendar: Calendar) -> Date {
        var date = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        while calendar.component(.weekday, from: date) != 2 {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return Self.date(at: 9, on: date, calendar: calendar)
    }
}
