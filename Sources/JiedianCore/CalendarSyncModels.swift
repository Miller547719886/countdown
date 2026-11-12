import Foundation

public enum CalendarSyncState: String, Codable, Sendable {
    case unlinked
    case synced
    case needsAttention
}

public struct CalendarLink: Codable, Equatable, Sendable {
    public var eventIdentifier: String?
    public var calendarItemExternalIdentifier: String?
    public var calendarIdentifier: String?
    public var lastSyncedAt: Date?

    public init(
        eventIdentifier: String? = nil,
        calendarItemExternalIdentifier: String? = nil,
        calendarIdentifier: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.eventIdentifier = eventIdentifier
        self.calendarItemExternalIdentifier = calendarItemExternalIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct CalendarMarkerPayload: Equatable, Sendable {
    public let itemID: UUID
    public let isCompleted: Bool
    public let completionPrefixIsOwned: Bool

    public init(
        itemID: UUID,
        isCompleted: Bool,
        completionPrefixIsOwned: Bool? = nil
    ) {
        self.itemID = itemID
        self.isCompleted = isCompleted
        self.completionPrefixIsOwned = completionPrefixIsOwned ?? isCompleted
    }
}

public struct CalendarEventCandidate: Equatable, Sendable {
    public let identifier: String
    public let externalIdentifier: String?
    public let calendarIdentifier: String?
    public let lastModifiedDate: Date?

    public init(
        identifier: String,
        externalIdentifier: String? = nil,
        calendarIdentifier: String? = nil,
        lastModifiedDate: Date?
    ) {
        self.identifier = identifier
        self.externalIdentifier = externalIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.lastModifiedDate = lastModifiedDate
    }
}

public struct CalendarEventCandidateSelection: Equatable, Sendable {
    public let candidate: CalendarEventCandidate?
    public let hasDuplicates: Bool

    public init(candidate: CalendarEventCandidate?, hasDuplicates: Bool) {
        self.candidate = candidate
        self.hasDuplicates = hasDuplicates
    }
}

public enum CalendarMarker {
    private static let scheme = "jiedian"
    private static let host = "item"
    private static let completionQueryName = "completed"
    private static let completionPrefixQueryName = "prefix"
    private static let notesBegin = "[截点同步 v1]"
    private static let notesEnd = "[/截点同步]"
    private static let completionPrefix = "✓ "

    public static func url(
        for itemID: UUID,
        isCompleted: Bool,
        completionPrefixIsOwned: Bool? = nil
    ) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(itemID.uuidString.lowercased())"
        components.queryItems = [
            URLQueryItem(
                name: completionQueryName,
                value: isCompleted ? "1" : "0"
            ),
            URLQueryItem(
                name: completionPrefixQueryName,
                value: isCompleted && (completionPrefixIsOwned ?? true) ? "1" : "0"
            )
        ]
        return components.url!
    }

    public static func parse(url: URL?) -> CalendarMarkerPayload? {
        guard let url,
              url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let itemID = UUID(uuidString: url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
              let completedValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?
                  .first(where: { $0.name == completionQueryName })?
                  .value,
              let isCompleted = parseBoolean(completedValue) else {
            return nil
        }
        let completionPrefixIsOwned = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == completionPrefixQueryName })?
            .value
            .flatMap(parseBoolean)
            ?? isCompleted
        return CalendarMarkerPayload(
            itemID: itemID,
            isCompleted: isCompleted,
            completionPrefixIsOwned: isCompleted && completionPrefixIsOwned
        )
    }

    public static func applyCompletionPrefix(to title: String, isCompleted: Bool) -> String {
        guard isCompleted else { return title }
        return title.hasPrefix(completionPrefix) ? title : completionPrefix + title
    }

    public static func removeCompletionPrefix(from title: String) -> String {
        guard title.hasPrefix(completionPrefix) else { return title }
        return String(title.dropFirst(completionPrefix.count))
    }

    public static func itemText(
        fromEventTitle title: String,
        isCompleted: Bool,
        completionPrefixIsOwned: Bool
    ) -> String {
        isCompleted && completionPrefixIsOwned ? removeCompletionPrefix(from: title) : title
    }

    public static func itemText(fromEventTitle title: String, isCompleted: Bool) -> String {
        itemText(
            fromEventTitle: title,
            isCompleted: isCompleted,
            completionPrefixIsOwned: isCompleted
        )
    }

    public static func upsertNotesMarker(
        in notes: String?,
        itemID: UUID,
        isCompleted: Bool,
        completionPrefixIsOwned: Bool? = nil
    ) -> String {
        let withoutMarker = notesWithoutMarker(notes)
        let marker = [
            notesBegin,
            "item=\(itemID.uuidString.lowercased())",
            "completed=\(isCompleted ? "1" : "0")",
            "prefix=\(isCompleted && (completionPrefixIsOwned ?? true) ? "1" : "0")",
            notesEnd
        ].joined(separator: "\n")

        guard !withoutMarker.isEmpty else { return marker }
        return "\(withoutMarker)\n\n\(marker)"
    }

    public static func removeNotesMarker(from notes: String?) -> String? {
        let withoutMarker = notesWithoutMarker(notes)
        return withoutMarker.isEmpty ? nil : withoutMarker
    }

    public static func notesMarker(in notes: String?) -> CalendarMarkerPayload? {
        guard let block = markerBlock(in: notes) else { return nil }
        let values = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(into: [String: String]()) { result, line in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                result[parts[0]] = parts[1]
            }
        guard let itemValue = values["item"],
              let itemID = UUID(uuidString: itemValue),
              let completedValue = values["completed"],
              let isCompleted = parseBoolean(completedValue) else {
            return nil
        }
        let completionPrefixIsOwned = values["prefix"].flatMap(parseBoolean) ?? isCompleted
        return CalendarMarkerPayload(
            itemID: itemID,
            isCompleted: isCompleted,
            completionPrefixIsOwned: isCompleted && completionPrefixIsOwned
        )
    }

    public static func selectCandidate(
        _ candidates: [CalendarEventCandidate],
        preferredExternalIdentifier: String? = nil
    ) -> CalendarEventCandidateSelection {
        let preferredCandidates: [CalendarEventCandidate]
        if let preferredExternalIdentifier {
            let matches = candidates.filter { $0.externalIdentifier == preferredExternalIdentifier }
            preferredCandidates = matches.isEmpty ? candidates : matches
        } else {
            preferredCandidates = candidates
        }

        let candidate = preferredCandidates.max { lhs, rhs in
            if let lhsDate = lhs.lastModifiedDate, let rhsDate = rhs.lastModifiedDate,
               lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            if lhs.lastModifiedDate != nil, rhs.lastModifiedDate == nil { return false }
            if lhs.lastModifiedDate == nil, rhs.lastModifiedDate != nil { return true }
            return lhs.identifier > rhs.identifier
        }
        return CalendarEventCandidateSelection(
            candidate: candidate,
            hasDuplicates: candidates.count > 1
        )
    }

    private static func parseBoolean(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "1", "true": true
        case "0", "false": false
        default: nil
        }
    }

    private static func markerBlock(in notes: String?) -> String? {
        guard let notes,
              let start = notes.range(of: notesBegin),
              let end = notes.range(of: notesEnd, range: start.upperBound..<notes.endIndex) else {
            return nil
        }
        let blockStart = notes.index(start.upperBound, offsetBy: 1, limitedBy: notes.endIndex)
            ?? start.upperBound
        return String(notes[blockStart..<end.lowerBound])
    }

    private static func notesWithoutMarker(_ notes: String?) -> String {
        guard let notes, let start = notes.range(of: notesBegin) else {
            return notes ?? ""
        }
        guard let end = notes.range(of: notesEnd, range: start.upperBound..<notes.endIndex) else {
            return notes
        }

        var removalStart = start.lowerBound
        if let separatorStart = notes.index(start.lowerBound, offsetBy: -2, limitedBy: notes.startIndex),
           String(notes[separatorStart..<start.lowerBound]) == "\n\n" {
            removalStart = separatorStart
        }

        var removalEnd = end.upperBound
        if removalStart == notes.startIndex,
           notes[removalEnd...].hasPrefix("\n\n") {
            removalEnd = notes.index(removalEnd, offsetBy: 2)
        }

        var result = notes
        result.removeSubrange(removalStart..<removalEnd)
        return result
    }
}

public enum CalendarConflictWinner: Equatable, Sendable {
    case local
    case event
    case needsAttention
}

public enum CalendarConflictResolver {
    public static func winner(
        localUpdatedAt: Date?,
        eventUpdatedAt: Date?
    ) -> CalendarConflictWinner {
        guard let localUpdatedAt, let eventUpdatedAt else { return .needsAttention }
        if localUpdatedAt > eventUpdatedAt { return .local }
        if eventUpdatedAt > localUpdatedAt { return .event }
        return .needsAttention
    }
}

public enum CalendarSyncIntent: Equatable, Sendable {
    case upsert(itemID: UUID)
    case remove(itemID: UUID, link: CalendarLink?)
    case reconcile
}

public enum CalendarMutationOrigin: Equatable, Sendable {
    case local
    case calendar
}

public enum CalendarSyncIntentRouter {
    public static func intent(
        before: CaptureItem?,
        after: CaptureItem?,
        origin: CalendarMutationOrigin
    ) -> CalendarSyncIntent? {
        guard origin == .local else { return nil }
        switch (before, after) {
        case (nil, let after):
            guard let after else { return nil }
            return .upsert(itemID: after.id)
        case (let before, nil):
            guard let before else { return nil }
            return .remove(itemID: before.id, link: before.calendarLink)
        case (_, let after):
            guard let after else { return nil }
            return .upsert(itemID: after.id)
        }
    }
}

public enum CalendarSyncStatus {
    public static func pendingCount(_ items: [CaptureItem]) -> Int {
        items.filter { $0.calendarSyncState != .synced }.count
    }

    public static func pendingSummary(_ count: Int) -> String {
        "还有 \(count) 项需要处理。"
    }
}

public enum CalendarSyncSettingsCopy {
    public static let allowSyncToAppleCalendar = "允许同步到 Apple Calendar"
}
