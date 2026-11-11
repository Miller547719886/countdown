import Foundation

public struct CaptureItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var deadline: Date
    public let createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var sourceApp: String?
    public var screenshotFilename: String?
    public var calendarLink: CalendarLink?
    public var calendarSyncState: CalendarSyncState

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case deadline
        case createdAt
        case updatedAt
        case completedAt
        case sourceApp
        case screenshotFilename
        case calendarLink
        case calendarSyncState
    }

    public init(
        id: UUID = UUID(),
        text: String,
        deadline: Date,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        completedAt: Date? = nil,
        sourceApp: String? = nil,
        screenshotFilename: String? = nil,
        calendarLink: CalendarLink? = nil,
        calendarSyncState: CalendarSyncState = .unlinked
    ) {
        self.id = id
        self.text = text
        self.deadline = deadline
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.completedAt = completedAt
        self.sourceApp = sourceApp
        self.screenshotFilename = screenshotFilename
        self.calendarLink = calendarLink
        self.calendarSyncState = calendarSyncState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.deadline = try container.decode(Date.self, forKey: .deadline)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        self.sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        self.screenshotFilename = try container.decodeIfPresent(String.self, forKey: .screenshotFilename)
        self.calendarLink = try container.decodeIfPresent(CalendarLink.self, forKey: .calendarLink)
        self.calendarSyncState = try container.decodeIfPresent(
            CalendarSyncState.self,
            forKey: .calendarSyncState
        ) ?? .unlinked
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(deadline, forKey: .deadline)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try container.encodeIfPresent(screenshotFilename, forKey: .screenshotFilename)
        try container.encodeIfPresent(calendarLink, forKey: .calendarLink)
        try container.encode(calendarSyncState, forKey: .calendarSyncState)
    }

    public var isCompleted: Bool { completedAt != nil }

    public func isOverdue(at now: Date = Date()) -> Bool {
        !isCompleted && deadline < now
    }
}
