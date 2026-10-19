import Foundation

public struct CaptureItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var deadline: Date
    public let createdAt: Date
    public var completedAt: Date?
    public var sourceApp: String?

    public init(
        id: UUID = UUID(),
        text: String,
        deadline: Date,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        sourceApp: String? = nil
    ) {
        self.id = id
        self.text = text
        self.deadline = deadline
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.sourceApp = sourceApp
    }

    public var isCompleted: Bool { completedAt != nil }

    public func isOverdue(at now: Date = Date()) -> Bool {
        !isCompleted && deadline < now
    }
}
