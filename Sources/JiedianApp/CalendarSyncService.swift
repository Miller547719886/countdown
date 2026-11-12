import AppKit
import Combine
import EventKit
import Foundation
import JiedianCore

struct CalendarOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let sourceTitle: String
    let isWritable: Bool
    let isCloudBacked: Bool

    var displayName: String {
        sourceTitle.isEmpty ? title : "\(title) · \(sourceTitle)"
    }
}

@MainActor
final class CalendarSyncService: ObservableObject {
    @Published private(set) var accessStatus: EKAuthorizationStatus
    @Published private(set) var availableCalendars: [CalendarOption] = []
    @Published private(set) var selectedCalendarIdentifier: String?
    @Published private(set) var isEnabled = false
    @Published private(set) var syncStateText = "未开启"
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var pendingCount = 0
    @Published private(set) var lastError: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var settingsOpenFailed = false

    private let eventStore: EKEventStore
    private let defaults: UserDefaults
    private weak var store: ItemStore?
    private var changeObserver: NSObjectProtocol?
    private var reconcileTask: Task<Void, Never>?
    private var isApplyingLocalChange = false
    private var isConfigured = false

    private enum DefaultsKey {
        static let enabled = "calendarSync.enabled.v1"
        static let calendarIdentifier = "calendarSync.calendarIdentifier.v1"
        static let calendarTitle = "calendarSync.calendarTitle.v1"
        static let calendarSourceTitle = "calendarSync.calendarSourceTitle.v1"
        static let lastSyncAt = "calendarSync.lastSyncAt.v1"
    }

    init(
        eventStore: EKEventStore = EKEventStore(),
        defaults: UserDefaults = .standard
    ) {
        self.eventStore = eventStore
        self.defaults = defaults
        self.accessStatus = EKEventStore.authorizationStatus(for: .event)
        self.selectedCalendarIdentifier = defaults.string(forKey: DefaultsKey.calendarIdentifier)
        self.isEnabled = defaults.bool(forKey: DefaultsKey.enabled)
        self.lastSyncAt = defaults.object(forKey: DefaultsKey.lastSyncAt) as? Date
        updateStatusText()
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
        reconcileTask?.cancel()
    }

    func configure(store: ItemStore) {
        self.store = store
        isConfigured = true
        updatePendingCount()
        refreshAccessAndCalendars()
        if isEnabled, selectedCalendarIdentifier != nil {
            reconcile()
        }
    }

    func requestAccess() async {
        if #available(macOS 14.0, *) {
            await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { [weak self] granted, error in
                    Task { @MainActor in
                        guard let self else {
                            continuation.resume()
                            return
                        }
                        if let error {
                            self.lastError = "无法访问 Apple 日历：\(error.localizedDescription)"
                        } else if !granted {
                            self.lastError = "日历访问权限未开启。请在系统设置中允许“截点”访问日历。"
                        } else {
                            self.lastError = nil
                        }
                        self.refreshAccessAndCalendars()
                        continuation.resume()
                    }
                }
            }
        } else {
            lastError = "当前 macOS 版本不支持完整的日历访问。"
            refreshAccessAndCalendars()
        }
    }

    func refreshAccessAndCalendars() {
        accessStatus = EKEventStore.authorizationStatus(for: .event)
        guard hasFullAccess else {
            availableCalendars = []
            updateStatusText()
            return
        }

        availableCalendars = eventStore
            .calendars(for: .event)
            .filter { $0.allowedEntityTypes.contains(.event) && $0.allowsContentModifications }
            .map(CalendarOption.init)
            .sorted {
                if $0.isCloudBacked != $1.isCloudBacked {
                    return $0.isCloudBacked && !$1.isCloudBacked
                }
                if $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                return $0.sourceTitle.localizedStandardCompare($1.sourceTitle) == .orderedAscending
            }

        restoreSelectedCalendar()
        installChangeObserverIfNeeded()
        updateStatusText()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled else {
            isEnabled = false
            defaults.set(false, forKey: DefaultsKey.enabled)
            updateStatusText()
            return
        }
        guard hasFullAccess,
              let calendar = selectedCalendar(),
              calendar.allowsContentModifications else {
            lastError = "请先允许日历权限并选择一个可写日历。"
            updateStatusText()
            return
        }
        isEnabled = true
        defaults.set(true, forKey: DefaultsKey.enabled)
        lastError = nil
        updateStatusText()
    }

    func openCalendarSettings() {
        settingsOpenFailed = false
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            settingsOpenFailed = true
            return
        }
        settingsOpenFailed = !NSWorkspace.shared.open(url)
    }

    func selectCalendar(identifier: String?) {
        let wasEnabled = isEnabled
        guard let identifier,
              let option = availableCalendars.first(where: { $0.id == identifier }),
              let calendar = eventStore.calendar(withIdentifier: identifier),
              option.isWritable,
              calendar.allowsContentModifications else {
            selectedCalendarIdentifier = nil
            isEnabled = false
            defaults.removeObject(forKey: DefaultsKey.calendarIdentifier)
            defaults.set(false, forKey: DefaultsKey.enabled)
            updateStatusText()
            return
        }

        selectedCalendarIdentifier = identifier
        isEnabled = wasEnabled
        defaults.set(identifier, forKey: DefaultsKey.calendarIdentifier)
        defaults.set(option.title, forKey: DefaultsKey.calendarTitle)
        defaults.set(option.sourceTitle, forKey: DefaultsKey.calendarSourceTitle)
        defaults.set(wasEnabled, forKey: DefaultsKey.enabled)
        lastError = nil
        updateStatusText()
    }

    func syncExistingItems() {
        guard beginSyncOperation() else { return }
        defer { endSyncOperation() }
        guard let store else { return }

        for item in store.items {
            upsert(item)
        }
    }

    func retrySync() {
        lastError = nil
        if isEnabled {
            syncExistingItems()
        } else {
            refreshAccessAndCalendars()
        }
    }

    func syncLocalMutation(before: CaptureItem?, after: CaptureItem?) {
        guard isEnabled, !isApplyingLocalChange else { return }
        guard beginSyncOperation() else { return }
        defer { endSyncOperation() }

        if let after {
            upsert(after)
        } else if let before {
            remove(before)
        }
    }

    func syncNewItem(_ item: CaptureItem) {
        syncLocalMutation(before: nil, after: item)
    }

    func reconcile() {
        guard isEnabled, !isApplyingLocalChange else { return }
        guard beginSyncOperation() else { return }
        defer { endSyncOperation() }
        guard let store else { return }

        for item in store.items where item.calendarLink != nil {
            reconcile(item)
        }
    }

    func unlinkAll(deleteEvents: Bool) {
        guard let store else { return }
        isApplyingLocalChange = true
        isSyncing = true
        defer {
            isApplyingLocalChange = false
            isSyncing = false
            updateStatusText()
        }

        for item in store.items where item.calendarLink != nil {
            if deleteEvents {
                guard remove(item) else {
                    markNeedsAttention(item)
                    continue
                }
            }
            var unlinked = item
            unlinked.calendarLink = nil
            unlinked.calendarSyncState = .unlinked
            _ = store.update(unlinked, updatedAt: item.updatedAt)
        }

        isEnabled = false
        defaults.set(false, forKey: DefaultsKey.enabled)
        selectedCalendarIdentifier = nil
        defaults.removeObject(forKey: DefaultsKey.calendarIdentifier)
    }

    private var hasFullAccess: Bool {
        accessStatus == .fullAccess
    }

    private func beginSyncOperation() -> Bool {
        guard isConfigured else { return false }
        guard hasFullAccess else {
            lastError = "请先允许“截点”访问 Apple 日历。"
            updateStatusText()
            return false
        }
        guard isEnabled else {
            updateStatusText()
            return false
        }
        guard let calendar = selectedCalendar(), calendar.allowsContentModifications else {
            lastError = "请选择一个可写的 Apple 日历。"
            updateStatusText()
            return false
        }
        isSyncing = true
        updateStatusText()
        return true
    }

    private func endSyncOperation() {
        isSyncing = false
        lastSyncAt = Date()
        defaults.set(lastSyncAt, forKey: DefaultsKey.lastSyncAt)
        updatePendingCount()
        updateStatusText()
    }

    private func selectedCalendar() -> EKCalendar? {
        guard let selectedCalendarIdentifier else { return nil }
        return eventStore.calendar(withIdentifier: selectedCalendarIdentifier)
    }

    private func upsert(_ item: CaptureItem) {
        guard let calendar = selectedCalendar(), calendar.allowsContentModifications else {
            lastError = "目标日历不可写，事项已保留在截点中。"
            markNeedsAttention(item)
            return
        }

        isApplyingLocalChange = true
        defer { isApplyingLocalChange = false }

        do {
            let projection = CalendarEventProjection(item: item)
            let lookup = event(for: item, calendar: calendar)
            let event = lookup.event ?? EKEvent(eventStore: eventStore)
            if let existingCalendar = lookup.event?.calendar {
                guard existingCalendar.allowsContentModifications else {
                    lastError = "关联事件所在日历不可写，事项已保留在截点中。"
                    markNeedsAttention(item)
                    return
                }
            } else {
                event.calendar = calendar
            }
            event.title = projection.title
            event.startDate = projection.startDate
            event.endDate = projection.endDate
            event.isAllDay = false
            event.url = projection.markerURL
            event.notes = CalendarMarker.upsertNotesMarker(
                in: lookup.event?.notes ?? projection.notes,
                itemID: item.id,
                isCompleted: item.isCompleted,
                completionPrefixIsOwned: projection.completionPrefixIsOwned
            )
            if lookup.event == nil {
                event.alarms = []
                event.addAlarm(EKAlarm(relativeOffset: 0))
            }

            try eventStore.save(event, span: .thisEvent)

            var linked = item
            linked.calendarLink = CalendarLink(
                eventIdentifier: event.eventIdentifier,
                calendarItemExternalIdentifier: event.calendarItemExternalIdentifier,
                calendarIdentifier: event.calendar?.calendarIdentifier ?? calendar.calendarIdentifier,
                lastSyncedAt: event.lastModifiedDate ?? Date()
            )
            linked.calendarSyncState = lookup.hasDuplicates ? .needsAttention : .synced
            _ = store?.update(linked, updatedAt: item.updatedAt)
            if lookup.hasDuplicates {
                lastError = "发现多个相同的截点日历事件，已保留最近修改的一项。"
            }
        } catch {
            lastError = "同步到 Apple 日历失败：\(error.localizedDescription)"
            markNeedsAttention(item)
        }
    }

    @discardableResult
    private func remove(_ item: CaptureItem) -> Bool {
        guard hasFullAccess else {
            lastError = "请先允许“截点”访问 Apple 日历。"
            return false
        }
        guard let calendar = selectedCalendar(), calendar.allowsContentModifications else {
            lastError = "请选择一个可写的 Apple 日历后再删除关联事件。"
            return false
        }
        let lookup = event(for: item, calendar: calendar)
        guard let event = lookup.event else { return true }

        let wasApplyingLocalChange = isApplyingLocalChange
        isApplyingLocalChange = true
        defer { isApplyingLocalChange = wasApplyingLocalChange }
        do {
            try eventStore.remove(event, span: .thisEvent)
            return true
        } catch {
            lastError = "无法从 Apple 日历删除事项：\(error.localizedDescription)"
            return false
        }
    }

    private func reconcile(_ item: CaptureItem) {
        guard let calendar = selectedCalendar() else { return }
        let lookup = event(for: item, calendar: calendar)
        guard let event = lookup.event else {
            var unlinked = item
            unlinked.calendarLink = nil
            unlinked.calendarSyncState = .needsAttention
            _ = store?.update(unlinked, updatedAt: item.updatedAt)
            return
        }

        guard let marker = CalendarMarker.parse(url: event.url)
                ?? CalendarMarker.notesMarker(in: event.notes),
              marker.itemID == item.id else {
            markNeedsAttention(item)
            return
        }

        let eventDate = event.lastModifiedDate ?? Date()
        if let lastSyncedAt = item.calendarLink?.lastSyncedAt, eventDate <= lastSyncedAt {
            return
        }

        switch CalendarConflictResolver.winner(
            localUpdatedAt: item.updatedAt,
            eventUpdatedAt: eventDate
        ) {
        case .local:
            upsert(item)
        case .event:
            var updated = item
            updated.text = CalendarMarker.itemText(
                fromEventTitle: event.title ?? item.text,
                isCompleted: marker.isCompleted,
                completionPrefixIsOwned: marker.completionPrefixIsOwned
            )
            updated.deadline = event.startDate
            updated.completedAt = marker.isCompleted ? eventDate : nil
            updated.calendarLink = CalendarLink(
                eventIdentifier: event.eventIdentifier,
                calendarItemExternalIdentifier: event.calendarItemExternalIdentifier,
                calendarIdentifier: event.calendar?.calendarIdentifier ?? calendar.calendarIdentifier,
                lastSyncedAt: eventDate
            )
            let calendarIsWritable = event.calendar?.allowsContentModifications ?? false
            updated.calendarSyncState = lookup.hasDuplicates || !calendarIsWritable
                ? .needsAttention
                : .synced
            if store?.update(updated, updatedAt: eventDate) == true {
                NotificationService.shared.update(
                    before: item,
                    after: store?.item(withID: item.id) ?? updated
                )
            }
            if lookup.hasDuplicates {
                lastError = "发现多个相同的截点日历事件，请在设置中处理。"
            } else if !calendarIsWritable {
                lastError = "关联事件所在日历不可写，日历改动已保存在截点中。"
            }
        case .needsAttention:
            markNeedsAttention(item)
        }
    }

    private func markNeedsAttention(_ item: CaptureItem) {
        guard let store else { return }
        var updated = item
        updated.calendarSyncState = .needsAttention
        _ = store.update(updated, updatedAt: item.updatedAt)
        updatePendingCount()
    }

    private struct EventLookup {
        let event: EKEvent?
        let hasDuplicates: Bool
    }

    private func event(for item: CaptureItem, calendar: EKCalendar) -> EventLookup {
        if let identifier = item.calendarLink?.eventIdentifier,
           let event = eventStore.event(withIdentifier: identifier),
           marker(for: event)?.itemID == item.id {
            return EventLookup(event: event, hasDuplicates: false)
        }

        let start = Calendar.current.date(byAdding: .year, value: -2, to: item.deadline)
            ?? item.deadline.addingTimeInterval(-2 * 365 * 24 * 60 * 60)
        let end = Calendar.current.date(byAdding: .year, value: 2, to: item.deadline)
            ?? item.deadline.addingTimeInterval(2 * 365 * 24 * 60 * 60)
        let events = eventStore.events(
            matching: eventStore.predicateForEvents(
                withStart: start,
                end: end,
                calendars: candidateCalendars(
                    selected: calendar,
                    linkedCalendarIdentifier: item.calendarLink?.calendarIdentifier
                )
            )
        )
        let matches = events.filter { marker(for: $0)?.itemID == item.id }
        let candidates = matches.map {
            CalendarEventCandidate(
                identifier: $0.eventIdentifier,
                externalIdentifier: $0.calendarItemExternalIdentifier,
                calendarIdentifier: $0.calendar?.calendarIdentifier,
                lastModifiedDate: $0.lastModifiedDate
            )
        }
        let selection = CalendarMarker.selectCandidate(
            candidates,
            preferredExternalIdentifier: item.calendarLink?.calendarItemExternalIdentifier
        )
        let selectedEvent = selection.candidate.flatMap { candidate in
            matches.first { $0.eventIdentifier == candidate.identifier }
        }
        return EventLookup(event: selectedEvent, hasDuplicates: selection.hasDuplicates)
    }

    private func candidateCalendars(selected calendar: EKCalendar, linkedCalendarIdentifier: String?) -> [EKCalendar] {
        var calendars: [EKCalendar] = []
        var identifiers = Set<String>()

        func append(_ candidate: EKCalendar?) {
            guard let candidate, identifiers.insert(candidate.calendarIdentifier).inserted else { return }
            calendars.append(candidate)
        }

        append(calendar)
        append(linkedCalendarIdentifier.flatMap(eventStore.calendar(withIdentifier:)))
        for candidate in eventStore.calendars(for: .event) {
            append(candidate)
        }
        return calendars
    }

    private func marker(for event: EKEvent) -> CalendarMarkerPayload? {
        CalendarMarker.parse(url: event.url) ?? CalendarMarker.notesMarker(in: event.notes)
    }

    private func restoreSelectedCalendar() {
        let storedIdentifier = defaults.string(forKey: DefaultsKey.calendarIdentifier)
        let storedTitle = defaults.string(forKey: DefaultsKey.calendarTitle)
        let storedSourceTitle = defaults.string(forKey: DefaultsKey.calendarSourceTitle)
        if let storedIdentifier,
           availableCalendars.contains(where: { $0.id == storedIdentifier }) {
            selectedCalendarIdentifier = storedIdentifier
            return
        }

        if let fallback = availableCalendars.first(where: {
            $0.title == storedTitle && $0.sourceTitle == storedSourceTitle
        }) {
            selectedCalendarIdentifier = fallback.id
            defaults.set(fallback.id, forKey: DefaultsKey.calendarIdentifier)
            return
        }

        selectedCalendarIdentifier = nil
    }

    private func installChangeObserverIfNeeded() {
        guard changeObserver == nil else { return }
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleReconcile()
            }
        }
    }

    private func scheduleReconcile() {
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    private func updatePendingCount() {
        pendingCount = CalendarSyncStatus.pendingCount(store?.items ?? [])
    }

    private func updateStatusText() {
        if isSyncing {
            syncStateText = "同步中…"
        } else if !isEnabled {
            syncStateText = "未开启"
        } else if !hasFullAccess {
            syncStateText = "需要日历权限"
        } else if selectedCalendarIdentifier == nil {
            syncStateText = "请选择日历"
        } else if lastError != nil {
            syncStateText = "需要处理"
        } else if pendingCount > 0 {
            syncStateText = "\(pendingCount) 项待同步"
        } else {
            syncStateText = "已同步"
        }
    }
}

private extension CalendarOption {
    init(calendar: EKCalendar) {
        let sourceType = calendar.source?.sourceType
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.sourceTitle = calendar.source?.title ?? ""
        self.isWritable = calendar.allowsContentModifications
        self.isCloudBacked = sourceType == .calDAV || sourceType == .mobileMe
    }
}

private enum CalendarSyncError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            "保存日历事件失败。"
        }
    }
}
