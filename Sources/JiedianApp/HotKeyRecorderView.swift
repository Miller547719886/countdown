import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotKeyRecorderView: View {
    let shortcut: GlobalHotKeyShortcut
    let isRecording: Bool
    let onBeginRecording: () -> Void
    let onCapture: (GlobalHotKeyShortcut) -> Void
    let onCancel: () -> Void

    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Button(isRecording ? "正在录制…" : "更改快捷键") {
                    validationMessage = nil
                    onBeginRecording()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isRecording)

                ShortcutKey(label: shortcut.displayLabel)

                Button("恢复默认") {
                    validationMessage = nil
                    onCapture(.defaultShortcut)
                }
                .buttonStyle(QuietButtonStyle())
                .disabled(shortcut.isDefault || isRecording)
            }

            if isRecording {
                Text("按住修饰键后按一个按键；按 Esc 取消。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkMuted)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.vermilion)
            }

            HotKeyInputRecorder(
                isRecording: isRecording,
                onCapture: { shortcut in
                    validationMessage = nil
                    onCapture(shortcut)
                },
                onCancel: {
                    validationMessage = nil
                    onCancel()
                },
                onInvalidInput: { message in
                    validationMessage = message
                }
            )
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
        }
        .onDisappear {
            if isRecording {
                onCancel()
            }
        }
    }
}

private struct HotKeyInputRecorder: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (GlobalHotKeyShortcut) -> Void
    let onCancel: () -> Void
    let onInvalidInput: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCapture: onCapture,
            onCancel: onCancel,
            onInvalidInput: onInvalidInput
        )
    }

    func makeNSView(context: Context) -> HotKeyInputView {
        let view = HotKeyInputView()
        view.onKeyDown = { event in
            context.coordinator.handle(event)
        }
        view.onResignFirstResponder = {
            context.coordinator.cancel()
        }
        return view
    }

    func updateNSView(_ view: HotKeyInputView, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.onCancel = onCancel
        context.coordinator.onInvalidInput = onInvalidInput
        view.setRecording(isRecording)

        if isRecording {
            DispatchQueue.main.async {
                guard let window = view.window,
                      window.firstResponder !== view else {
                    return
                }
                window.makeFirstResponder(view)
            }
        } else if view.window?.firstResponder === view {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(nil)
            }
        }
    }

    static func dismantleNSView(_ view: HotKeyInputView, coordinator: Coordinator) {
        if view.isRecording {
            coordinator.cancel()
        }
        view.stopMonitoring()
    }

    final class Coordinator {
        var onCapture: (GlobalHotKeyShortcut) -> Void
        var onCancel: () -> Void
        var onInvalidInput: (String) -> Void

        init(
            onCapture: @escaping (GlobalHotKeyShortcut) -> Void,
            onCancel: @escaping () -> Void,
            onInvalidInput: @escaping (String) -> Void
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
            self.onInvalidInput = onInvalidInput
        }

        func handle(_ event: NSEvent) {
            if event.keyCode == UInt16(kVK_Escape) {
                cancel()
                return
            }

            let hasModifier = event.modifierFlags.contains(.command)
                || event.modifierFlags.contains(.option)
                || event.modifierFlags.contains(.control)
                || event.modifierFlags.contains(.shift)
            guard hasModifier else {
                onInvalidInput("请至少使用一个 Command、Option、Control 或 Shift 修饰键。")
                return
            }

            let reservedAppMenuKeyCodes = [
                UInt16(kVK_ANSI_Q),
                UInt16(kVK_ANSI_W),
                UInt16(kVK_ANSI_H),
                UInt16(kVK_ANSI_M)
            ]
            if event.modifierFlags.contains(.command),
               reservedAppMenuKeyCodes.contains(event.keyCode) {
                onInvalidInput("⌘Q、⌘W、⌘H 和 ⌘M 是应用菜单快捷键，请选择其他组合。")
                return
            }

            guard let shortcut = GlobalHotKeyShortcut(event: event) else {
                onInvalidInput("无法识别这个按键，请换用字母、数字、标点、方向键或 F1–F12。")
                return
            }

            onCapture(shortcut)
        }

        func cancel() {
            onCancel()
        }
    }
}

private final class HotKeyInputView: NSView {
    private(set) var isRecording = false
    var onKeyDown: ((NSEvent) -> Void)?
    var onResignFirstResponder: (() -> Void)?
    private var localKeyEventMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    func setRecording(_ isRecording: Bool) {
        self.isRecording = isRecording
        if isRecording {
            installLocalKeyEventMonitor()
        } else {
            removeLocalKeyEventMonitor()
        }
    }

    func stopMonitoring() {
        removeLocalKeyEventMonitor()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        onKeyDown?(event)
    }

    override func resignFirstResponder() -> Bool {
        let wasRecording = isRecording
        let didResign = super.resignFirstResponder()
        if didResign, wasRecording {
            onResignFirstResponder?()
        }
        return didResign
    }

    private func installLocalKeyEventMonitor() {
        guard localKeyEventMonitor == nil else { return }
        localKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.onKeyDown?(event)
            return nil
        }
    }

    private func removeLocalKeyEventMonitor() {
        guard let localKeyEventMonitor else { return }
        NSEvent.removeMonitor(localKeyEventMonitor)
        self.localKeyEventMonitor = nil
    }
}
