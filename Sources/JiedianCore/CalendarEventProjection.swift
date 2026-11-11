import Foundation

public struct CalendarEventProjection: Equatable, Sendable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let markerURL: URL
    public let notes: String
    public let isCompleted: Bool

    public init(item: CaptureItem) {
        self.isCompleted = item.isCompleted
        self.title = CalendarMarker.applyCompletionPrefix(
            to: item.text,
            isCompleted: item.isCompleted
        )
        self.startDate = item.deadline
        self.endDate = item.deadline.addingTimeInterval(60)
        self.markerURL = CalendarMarker.url(
            for: item.id,
            isCompleted: item.isCompleted
        )
        self.notes = CalendarMarker.upsertNotesMarker(
            in: nil,
            itemID: item.id,
            isCompleted: item.isCompleted
        )
    }
}
