import AppKit
import SwiftUI
import JiedianCore

struct CapturePanelView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var draft = CaptureDraft(text: "", deadline: CaptureDraft.defaultDeadline())
    @State private var saveScreenshot = false
    @State private var screenshotData: Data?
    @State private var screenshotImage: NSImage?
    @State private var screenshotError: ScreenshotCaptureError?
    @State private var screenshotTask: Task<Void, Never>?
    @State private var isCapturingScreenshot = false
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
                    screenshotSection
                    if let captureSaveError = coordinator.captureSaveError {
                        Text(captureSaveError)
                            .font(TypeScale.small)
                            .foregroundStyle(Palette.vermilion)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .onAppear {
                    draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                    resetScreenshotDraft()
                    focusedField = session.text.isEmpty ? .text : .date
                }
                .onChange(of: coordinator.captureSession?.id) { _, _ in
                    guard let session = coordinator.captureSession else { return }
                    draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                    resetScreenshotDraft()
                    focusedField = session.text.isEmpty ? .text : .date
                }
            }
        }
        .frame(width: 560)
        .background(Palette.paperRaised)
        .preferredColorScheme(.light)
        .onExitCommand { coordinator.dismissCapture() }
        .onDisappear { screenshotTask?.cancel() }
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
                Button("查看设置步骤") {
                    coordinator.showAccessibilityGuide(restoreCapturePanel: true)
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
                    sourceApp: coordinator.captureSession?.sourceApp,
                    screenshotData: saveScreenshot ? screenshotData : nil
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
        saveScreenshot = false
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
