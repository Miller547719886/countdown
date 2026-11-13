import AppKit
import Carbon.HIToolbox
import Combine
import CoreGraphics
import os
import SwiftUI
import UserNotifications
import JiedianCore

private let captureLog = Logger(subsystem: "com.xiongyufeng.jiedian", category: "capture")

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var captureSession: CaptureSession?
    @Published private(set) var capturePanelSpaceToggleRequest = 0
    @Published var accessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var accessibilitySettingsOpenFailed = false
    @Published private(set) var screenRecordingSettingsOpenFailed = false
    @Published private(set) var screenRecordingAllowed = false
    @Published var captureSaveError: String?
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var hotKeyRegistered = false
    @Published private(set) var hotKeyStatus = "尚未注册"
    @Published private(set) var globalHotKeyShortcut = GlobalHotKeyShortcut.load()
    @Published private(set) var isHotKeyRecording = false

    let calendarSyncService: CalendarSyncService
    private weak var store: ItemStore?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var capturePanel: CapturePanel?
    private var setupGuidePanel: NSPanel?
    private var setupGuideCloseObserver: SetupGuideCloseObserver?
    private var mainWindow: NSWindow?
    private var openMainWindow: (() -> Void)?
    private var shouldHideAppAfterCaptureDismissal = false
    private var permissionPollTimer: Timer?
    private var didEvaluateFirstRunSetupGuide = false
    private var shouldRestoreCapturePanelAfterGuide = false

    private static let accessibilityGuideDismissedKey = "accessibilitySetupGuideDismissed.v1"
    private static let setupGuideDismissedKey = "firstRunSetupGuideDismissed.v1"

    init() {
        calendarSyncService = CalendarSyncService()
        Task { await refreshNotificationStatus() }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func configure(store: ItemStore) {
        self.store = store
        calendarSyncService.configure(store: store)
        accessibilityTrusted = AXIsProcessTrusted()
        refreshScreenRecordingPermission()
        installGlobalHotKey()
        startPermissionPolling()
        scheduleUpcomingNotifications()
        showFirstRunSetupGuideIfNeeded()
    }

    func beginCapture() {
        captureLog.notice("beginCapture called")
        captureSaveError = nil
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
        captureSaveError = nil
        presentCapture(CaptureSession(text: "", sourceApp: nil, captureMethod: .manual))
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow.flatMap({ $0.isVisible ? $0 : nil })
            ?? NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }

    func setMainWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindow = opener
    }

    func returnToMainWindow() {
        shouldHideAppAfterCaptureDismissal = false
        dismissCapture()
        showMainWindow()
    }

    func saveCapture(
        text: String,
        deadline: Date,
        sourceApp: String?,
        screenshotData: Data? = nil,
        reminders: [DeadlineReminder] = ReminderPlanner.defaultReminders()
    ) {
        captureSaveError = nil
        guard let store else { return }
        guard let item = store.add(
            text: text,
            deadline: deadline,
            sourceApp: sourceApp,
            reminders: reminders,
            screenshotData: screenshotData
        ) else {
            captureSaveError = store.loadError ?? "无法保存这条事项，请重试。"
            return
        }
        capturePanel?.close()
        capturePanel = nil
        captureSession = nil
        NotificationService.shared.schedule(for: item)
        calendarSyncService.syncNewItem(item)
    }

    func update(_ item: CaptureItem) {
        guard let store,
              let before = store.item(withID: item.id),
              store.update(item),
              let after = store.item(withID: item.id) else {
            return
        }
        NotificationService.shared.update(before: before, after: after)
        forwardLocalMutation(before: before, after: after)
    }

    func complete(_ id: UUID) {
        guard let store,
              let before = store.item(withID: id),
              let after = store.complete(id) else {
            return
        }
        NotificationService.shared.update(before: before, after: after)
        forwardLocalMutation(before: before, after: after)
    }

    func restore(_ id: UUID) {
        guard let store,
              let before = store.item(withID: id),
              let after = store.restore(id) else {
            return
        }
        NotificationService.shared.update(before: before, after: after)
        forwardLocalMutation(before: before, after: after)
    }

    func delete(_ id: UUID) {
        guard let store,
              let before = store.item(withID: id),
              store.delete(id) != nil else {
            return
        }
        NotificationService.shared.update(before: before, after: nil)
        forwardLocalMutation(before: before, after: nil)
    }

    func dismissCapture() {
        captureSaveError = nil

        let shouldHideApp = shouldHideAppAfterCaptureDismissal
        shouldHideAppAfterCaptureDismissal = false
        if shouldHideApp {
            NSApp.hide(nil)
        }

        capturePanel?.close()
        capturePanel = nil
        captureSession = nil
    }

    func requestCapturePanelSpaceToggle() {
        capturePanelSpaceToggleRequest += 1
    }

    func openAccessibilitySettings() {
        accessibilitySettingsOpenFailed = false
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            accessibilitySettingsOpenFailed = true
            return
        }
        accessibilitySettingsOpenFailed = !NSWorkspace.shared.open(url)
    }

    func openScreenRecordingSettings() {
        screenRecordingSettingsOpenFailed = false
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            screenRecordingSettingsOpenFailed = true
            return
        }
        screenRecordingSettingsOpenFailed = !NSWorkspace.shared.open(url)
    }

    @discardableResult
    func refreshAccessibilityPermission() -> Bool {
        accessibilityTrusted = AXIsProcessTrusted()
        return accessibilityTrusted
    }

    @discardableResult
    func refreshScreenRecordingPermission() -> Bool {
        screenRecordingAllowed = CGPreflightScreenCaptureAccess()
        return screenRecordingAllowed
    }

    func showSetupGuide(restoreCapturePanel: Bool = false) {
        refreshScreenRecordingPermission()

        if restoreCapturePanel, let capturePanel, capturePanel.isVisible {
            shouldRestoreCapturePanelAfterGuide = true
            capturePanel.orderOut(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        if let setupGuidePanel {
            setupGuidePanel.makeKeyAndOrderFront(nil)
            return
        }

        let root = SetupGuideView()
            .environmentObject(self)
        let hosting = NSHostingController(rootView: root)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 660),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "初次使用设置"
        panel.contentViewController = hosting
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .normal

        let closeObserver = SetupGuideCloseObserver { [weak self] in
            self?.setupGuideDidClose()
        }
        panel.delegate = closeObserver
        setupGuidePanel = panel
        setupGuideCloseObserver = closeObserver

        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func dismissSetupGuide() {
        UserDefaults.standard.set(true, forKey: Self.setupGuideDismissedKey)
        UserDefaults.standard.set(true, forKey: Self.accessibilityGuideDismissedKey)
        setupGuidePanel?.close()
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

    func beginHotKeyRecording() {
        guard !isHotKeyRecording else { return }
        isHotKeyRecording = true
        unregisterGlobalHotKey()
        hotKeyStatus = "正在录制"
    }

    func cancelHotKeyRecording() {
        guard isHotKeyRecording else { return }
        isHotKeyRecording = false
        installGlobalHotKey()
    }

    func setGlobalHotKeyShortcut(_ shortcut: GlobalHotKeyShortcut) {
        isHotKeyRecording = false
        globalHotKeyShortcut = shortcut
        shortcut.save()
        installGlobalHotKey()
    }

    func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func installGlobalHotKey() {
        guard !isHotKeyRecording else { return }
        unregisterGlobalHotKey()
        let eventTarget = GetApplicationEventTarget()

        if eventHandler == nil {
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
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4A494544), id: 1)
        let registerStatus = RegisterEventHotKey(
            globalHotKeyShortcut.keyCode,
            globalHotKeyShortcut.modifiers,
            hotKeyID,
            eventTarget,
            0,
            &hotKeyRef
        )
        captureLog.notice("hotkey registration status: \(registerStatus, privacy: .public)")
        guard registerStatus == noErr else {
            hotKeyRef = nil
            hotKeyRegistered = false
            hotKeyStatus = "注册失败（错误码 \(registerStatus)）"
            return
        }

        hotKeyRegistered = true
        hotKeyStatus = "已注册"
    }

    private func unregisterGlobalHotKey() {
        guard let hotKeyRef else {
            hotKeyRegistered = false
            return
        }

        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
        hotKeyRegistered = false
    }

    private func presentCapture(_ session: CaptureSession) {
        if capturePanel?.isVisible != true {
            shouldHideAppAfterCaptureDismissal = !NSApp.isActive || !hasVisibleMainWindow
        }

        captureSession = session
        NSApp.activate(ignoringOtherApps: true)

        let panel = capturePanel ?? makeCapturePanel()
        capturePanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func makeCapturePanel() -> CapturePanel {
        let root = CapturePanelView()
            .environmentObject(self)
        let hosting = NSHostingController(rootView: root)
        let panel = CapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.onPlainSpace = { [weak self] in
            self?.requestCapturePanelSpaceToggle()
        }
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

    private var hasVisibleMainWindow: Bool {
        NSApp.windows.contains { window in
            !(window is NSPanel) && window.canBecomeMain && window.isVisible
        }
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAccessibilityPermission()
                self?.refreshScreenRecordingPermission()
            }
        }
    }

    private func showFirstRunSetupGuideIfNeeded() {
        guard !didEvaluateFirstRunSetupGuide else { return }
        didEvaluateFirstRunSetupGuide = true

        guard !hasDismissedSetupGuide else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.hasDismissedSetupGuide else { return }
            self.showSetupGuide()
        }
    }

    private var hasDismissedSetupGuide: Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: Self.setupGuideDismissedKey)
            || defaults.bool(forKey: Self.accessibilityGuideDismissedKey)
    }

    private func setupGuideDidClose() {
        UserDefaults.standard.set(true, forKey: Self.setupGuideDismissedKey)
        UserDefaults.standard.set(true, forKey: Self.accessibilityGuideDismissedKey)
        setupGuidePanel = nil
        setupGuideCloseObserver = nil

        guard shouldRestoreCapturePanelAfterGuide else { return }
        shouldRestoreCapturePanelAfterGuide = false
        NSApp.activate(ignoringOtherApps: true)
        capturePanel?.makeKeyAndOrderFront(nil)
    }

    private func scheduleUpcomingNotifications() {
        guard let store else { return }
        NotificationService.shared.scheduleAll(store.items)
    }

    private func forwardLocalMutation(before: CaptureItem?, after: CaptureItem?) {
        guard CalendarSyncIntentRouter.intent(
            before: before,
            after: after,
            origin: .local
        ) != nil else {
            return
        }
        calendarSyncService.syncLocalMutation(before: before, after: after)
    }
}

@MainActor
private final class SetupGuideCloseObserver: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
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

    private func identifier(for item: CaptureItem, reminderIndex: Int) -> String {
        "jiedian-reminder-\(item.id.uuidString.lowercased())-\(reminderIndex)"
    }

    private init() {}

    func schedule(for item: CaptureItem) {
        cancel(for: item)
        scheduleRequests(for: item)
    }

    func update(before: CaptureItem?, after: CaptureItem?) {
        if let before {
            cancel(for: before)
        }
        guard let after, !after.isCompleted else { return }
        schedule(for: after)
    }

    func scheduleAll(_ items: [CaptureItem]) {
        for item in items {
            cancel(for: item)
            guard !item.isCompleted else { continue }
            scheduleRequests(for: item)
        }
    }

    private func cancel(for item: CaptureItem) {
        let reminderIdentifiers = item.reminders.indices.map { identifier(for: item, reminderIndex: $0) }
        center.removePendingNotificationRequests(
            withIdentifiers: reminderIdentifiers + ["deadline-\(item.id.uuidString)"]
        )
    }

    private func scheduleRequests(for item: CaptureItem) {
        guard !item.isCompleted else { return }

        let now = Date()
        if item.deadline > now {
            scheduleNotification(
                for: item,
                fireDate: item.deadline,
                identifier: "deadline-\(item.id.uuidString)",
                title: "事项已到期"
            )
        }

        for (index, reminder) in item.reminders.enumerated() {
            guard let fireDate = reminder.fireDate(relativeTo: item.deadline),
                  fireDate > now,
                  fireDate < item.deadline else {
                continue
            }

            scheduleNotification(
                for: item,
                fireDate: fireDate,
                identifier: identifier(for: item, reminderIndex: index),
                title: "事项即将到期"
            )
        }
    }

    private func scheduleNotification(
        for item: CaptureItem,
        fireDate: Date,
        identifier: String,
        title: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = item.text
        content.sound = .default
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}
