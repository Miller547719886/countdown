import AppKit
import Carbon.HIToolbox
import Combine
import os
import SwiftUI
import UserNotifications
import JiedianCore

private let captureLog = Logger(subsystem: "com.xiongyufeng.jiedian", category: "capture")

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var captureSession: CaptureSession?
    @Published var accessibilityTrusted = AXIsProcessTrusted()
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var hotKeyRegistered = false
    @Published private(set) var hotKeyStatus = "尚未注册"

    private weak var store: ItemStore?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isHotKeyInstalled = false
    private var capturePanel: NSPanel?
    private var mainWindow: NSWindow?
    private var permissionPollTimer: Timer?

    init() {
        Task { await refreshNotificationStatus() }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func configure(store: ItemStore) {
        self.store = store
        accessibilityTrusted = AXIsProcessTrusted()
        installGlobalHotKey()
        startPermissionPolling()
        scheduleUpcomingNotifications()
    }

    func beginCapture() {
        captureLog.notice("beginCapture called")
        accessibilityTrusted = AXIsProcessTrusted()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let selfPID = ProcessInfo.processInfo.processIdentifier
        captureLog.notice("frontmost pid: \(frontmostPID ?? -1, privacy: .public), self pid: \(selfPID, privacy: .public)")
        let selection = SelectionReader.readFrontmostSelection()
        captureLog.notice("selection result: method=\(String(describing: selection.method), privacy: .public), chars=\(selection.text.count, privacy: .public)")
        let session = CaptureSession(
            text: selection.text,
            sourceApp: selection.appName,
            captureMethod: selection.method
        )
        presentCapture(session)
    }

    func beginManualCapture() {
        presentCapture(CaptureSession(text: "", sourceApp: nil, captureMethod: .manual))
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow ?? NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func saveCapture(text: String, deadline: Date, sourceApp: String?) {
        guard let store else { return }
        guard let item = store.add(text: text, deadline: deadline, sourceApp: sourceApp) else {
            return
        }
        capturePanel?.close()
        capturePanel = nil
        captureSession = nil
        NotificationService.shared.schedule(for: item)
        scheduleUpcomingNotifications()
    }

    func dismissCapture() {
        capturePanel?.close()
        capturePanel = nil
        captureSession = nil
    }

    func openAccessibilitySettings() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestNotificationPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refreshNotificationStatus()
        }
    }

    func retryGlobalHotKeyRegistration() {
        installGlobalHotKey()
    }

    func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func installGlobalHotKey() {
        guard !isHotKeyInstalled else { return }
        let eventTarget = GetApplicationEventTarget()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            eventTarget,
            { _, _, userData in
                captureLog.notice("hotkey callback fired")
                guard let userData else { return noErr }
                let coordinator = Unmanaged<AppCoordinator>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        coordinator.beginCapture()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        captureLog.notice("hotkey event handler status: \(handlerStatus, privacy: .public)")
        guard handlerStatus == noErr else {
            hotKeyStatus = "注册失败（事件处理器错误码 \(handlerStatus)）"
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4A494544), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_1),
            UInt32(cmdKey),
            hotKeyID,
            eventTarget,
            0,
            &hotKeyRef
        )
        captureLog.notice("hotkey registration status: \(registerStatus, privacy: .public)")
        guard registerStatus == noErr else {
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            hotKeyStatus = "注册失败（错误码 \(registerStatus)）"
            return
        }

        isHotKeyInstalled = true
        hotKeyRegistered = true
        hotKeyStatus = "已注册"
    }

    private func presentCapture(_ session: CaptureSession) {
        captureSession = session
        NSApp.activate(ignoringOtherApps: true)

        let panel = capturePanel ?? makeCapturePanel()
        capturePanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func makeCapturePanel() -> NSPanel {
        let root = CapturePanelView()
            .environmentObject(self)
        let hosting = NSHostingController(rootView: root)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.center()
        return panel
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.accessibilityTrusted = AXIsProcessTrusted()
            }
        }
    }

    private func scheduleUpcomingNotifications() {
        guard let store else { return }
        NotificationService.shared.scheduleAll(store.activeItems)
    }
}

struct CaptureSession: Identifiable {
    let id = UUID()
    var text: String
    let sourceApp: String?
    let captureMethod: SelectionReader.Method
}

enum SelectionReader {
    enum Method: Equatable {
        case accessibility
        case clipboard
        case manual

        var label: String {
            switch self {
            case .accessibility: "已读取当前选中文字"
            case .clipboard: "已从剪贴板读取"
            case .manual: "手动输入"
            }
        }
    }

    struct Selection {
        let text: String
        let appName: String?
        let method: Method
    }

    @MainActor
    static func readFrontmostSelection() -> Selection {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName

        if AXIsProcessTrusted(), let text = accessibilitySelection(), !text.isEmpty {
            return Selection(text: text, appName: appName, method: .accessibility)
        }

        if let text = clipboardSelection(), !text.isEmpty {
            return Selection(text: text, appName: appName, method: .clipboard)
        }

        return Selection(text: "", appName: appName, method: .manual)
    }

    @MainActor
    private static func accessibilitySelection() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedElement = focusedValue else {
            return nil
        }

        let element = unsafeDowncast(focusedElement, to: AXUIElement.self)
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
              let selected = selectedValue as? String else {
            return nil
        }
        return selected.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private static func clipboardSelection() -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        let original = pasteboard.string(forType: .string)
        let snapshot = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { values[type] = data }
            }
            return values
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        usleep(120_000)
        let selected = pasteboard.string(forType: .string)
        let selectionWasCopied = pasteboard.changeCount != initialChangeCount
        pasteboard.clearContents()
        if let snapshot {
            pasteboard.writeObjects(snapshot.map { values in
                let item = NSPasteboardItem()
                for (type, data) in values { item.setData(data, forType: type) }
                return item
            })
        } else if let original {
            pasteboard.setString(original, forType: .string)
        }

        guard selectionWasCopied, let selected else { return nil }
        return selected.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func schedule(for item: CaptureItem) {
        guard item.deadline > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "期限到了"
        content.body = item.text
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, item.deadline.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "deadline-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func scheduleAll(_ items: [CaptureItem]) {
        for item in items where item.deadline > Date() {
            schedule(for: item)
        }
    }
}
