import Foundation

public struct CalendarEventProjection: Equatable, Sendable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let markerURL: URL
    public let notes: String
    public let isCompleted: Bool
    public let completionPrefixIsOwned: Bool

    public init(item: CaptureItem) {
        self.isCompleted = item.isCompleted
        self.completionPrefixIsOwned = item.isCompleted && !item.text.hasPrefix("✓ ")
        self.title = CalendarMarker.applyCompletionPrefix(
            to: item.text,
            isCompleted: item.isCompleted
        )
        self.startDate = item.deadline
        self.endDate = item.deadline.addingTimeInterval(60)
        self.markerURL = CalendarMarker.url(
            for: item.id,
            isCompleted: item.isCompleted,
            completionPrefixIsOwned: self.completionPrefixIsOwned
        )
        self.notes = CalendarMarker.upsertNotesMarker(
            in: nil,
            itemID: item.id,
            isCompleted: item.isCompleted,
            completionPrefixIsOwned: self.completionPrefixIsOwned
        )
    }
}
