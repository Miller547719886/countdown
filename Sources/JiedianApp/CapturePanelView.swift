import AppKit
import SwiftUI
import JiedianCore

struct CapturePanelView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var draft = CaptureDraft(text: "", deadline: CaptureDraft.defaultDeadline())
    @State private var saveScreenshot = true
    @State private var deadlineMode: DeadlineEditorMode = .quick
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
                VStack(alignment: .leading, spacing: 12) {
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
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .onAppear {
                    draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                    deadlineMode = .quick
                    resetScreenshotDraft()
                    focusedField = session.text.isEmpty ? .text : .date
                }
                .onChange(of: coordinator.captureSession?.id) { _, _ in
                    guard let session = coordinator.captureSession else { return }
                    draft = CaptureDraft(text: session.text, deadline: CaptureDraft.defaultDeadline())
                    deadlineMode = .quick
                    resetScreenshotDraft()
                    focusedField = session.text.isEmpty ? .text : .date
                }
            }
        }
        .frame(width: 520)
        .background(Palette.paperRaised)
        .ignoresSafeArea(.container, edges: .top)
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
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
    }

    private var quickDeadlineEditor: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                deadlineSubheading("日期设置")
                HStack(alignment: .top, spacing: 8) {
                    weekDateColumn(weekOffset: 0)
                    weekDateColumn(weekOffset: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Palette.ruleLight)
                .frame(width: 1)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                deadlineSubheading("日期设置")
                DatePicker(
                    "",
                    selection: $draft.deadline,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.graphical)
                .frame(width: 232, height: 214)
                .onChange(of: draft.deadline) { _, _ in
                    draft.deadlineConfirmed = true
                }
            }
            .frame(width: 232, alignment: .leading)

            Rectangle()
                .fill(Palette.ruleLight)
                .frame(width: 1)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                deadlineSubheading("时间设置")
                deadlineTimeControls
                Text("时、分、秒均可编辑")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            }
            .frame(width: 166, alignment: .leading)
        }
    }

    private func deadlineSubheading(_ title: String) -> some View {
        Text(title)
            .font(TypeScale.section)
            .foregroundStyle(Palette.ink)
    }

    private func weekDateColumn(weekOffset: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weekOffset == 0 ? "本周" : "下周")
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkFaint)

            ForEach(DeadlinePlanner.weekDateChoices().filter { $0.weekOffset == weekOffset }) { choice in
                Button {
                    let calendar = Calendar.current
                    let time = calendar.dateComponents([.hour, .minute, .second], from: draft.deadline)
                    draft.deadline = calendar.date(
                        bySettingHour: time.hour ?? 8,
                        minute: time.minute ?? 0,
                        second: time.second ?? 0,
                        of: choice.date
                    ) ?? choice.date
                    draft.deadlineConfirmed = true
                } label: {
                    VStack(spacing: 3) {
                        Text(choice.label)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(isSelected(choice) ? Palette.ink : Palette.inkMuted)
                            .lineLimit(1)
                        Text(DeadlinePlanner.dateLabel(choice.date))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Palette.inkFaint)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                        .background(isSelected(choice) ? Palette.paperDeep : Palette.paperRaised)
                        .overlay(
                            Rectangle()
                                .stroke(isSelected(choice) ? Palette.inkFaint : Palette.ruleLight, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择\(choice.label)，\(DeadlinePlanner.dateLabel(choice.date))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedText.isEmpty && deadlineConfirmed && deadline > Date() }
    var isPast: Bool { deadline <= Date() }

    static func defaultDeadline(now: Date = Date()) -> Date {
        DeadlinePlanner.defaultDeadline(now: now)
    }

    func asSession(sourceApp: String?, method: SelectionReader.Method) -> CaptureSession {
        CaptureSession(text: trimmedText, sourceApp: sourceApp, captureMethod: method)
    }

}
