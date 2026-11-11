import Foundation
import JiedianCore

@main
struct JiedianChecks {
    @MainActor
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JiedianChecks-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("items.json")
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let markerItemID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let activeMarkerURL = CalendarMarker.url(for: markerItemID, isCompleted: false)
        guard let activeMarker = CalendarMarker.parse(url: activeMarkerURL),
              activeMarker.itemID == markerItemID,
              !activeMarker.isCompleted else {
            throw CheckFailure("active calendar marker did not round-trip: \(activeMarkerURL.absoluteString), parsed=\(String(describing: CalendarMarker.parse(url: activeMarkerURL)))")
        }

        let completedMarkerURL = CalendarMarker.url(for: markerItemID, isCompleted: true)
        guard let completedMarker = CalendarMarker.parse(url: completedMarkerURL),
              completedMarker.itemID == markerItemID,
              completedMarker.isCompleted else {
            throw CheckFailure("completed calendar marker did not round-trip")
        }

        guard CalendarMarker.applyCompletionPrefix(to: "review", isCompleted: true) == "✓ review",
              CalendarMarker.applyCompletionPrefix(to: "✓ review", isCompleted: true) == "✓ review",
              CalendarMarker.removeCompletionPrefix(from: "✓ review") == "review",
              CalendarMarker.itemText(fromEventTitle: "✓ review", isCompleted: false) == "✓ review",
              CalendarMarker.itemText(fromEventTitle: "✓ review", isCompleted: true) == "review" else {
            throw CheckFailure("calendar completion title prefix was not handled safely")
        }

        let userNotes = "用户备注\n不要覆盖这一行"
        let markedNotes = CalendarMarker.upsertNotesMarker(
            in: userNotes,
            itemID: markerItemID,
            isCompleted: true
        )
        guard markedNotes.contains(userNotes),
              CalendarMarker.notesMarker(in: markedNotes)?.itemID == markerItemID,
              CalendarMarker.notesMarker(in: markedNotes)?.isCompleted == true else {
            throw CheckFailure("calendar notes marker did not preserve user notes")
        }
        let updatedNotes = CalendarMarker.upsertNotesMarker(
            in: markedNotes,
            itemID: markerItemID,
            isCompleted: false
        )
        guard updatedNotes.contains(userNotes),
              CalendarMarker.notesMarker(in: updatedNotes)?.isCompleted == false else {
            throw CheckFailure("calendar notes marker was not replaced in place")
        }

        let olderEvent = CalendarEventCandidate(
            identifier: "older",
            lastModifiedDate: now.addingTimeInterval(-60)
        )
        let newerEvent = CalendarEventCandidate(
            identifier: "newer",
            lastModifiedDate: now.addingTimeInterval(60)
        )
        let duplicateSelection = CalendarMarker.selectCandidate([olderEvent, newerEvent])
        guard duplicateSelection.candidate?.identifier == "newer",
              duplicateSelection.hasDuplicates else {
            throw CheckFailure("duplicate calendar markers did not choose the newest event")
        }

        guard CalendarConflictResolver.winner(
            localUpdatedAt: now.addingTimeInterval(60),
            eventUpdatedAt: now
        ) == .local,
        CalendarConflictResolver.winner(
            localUpdatedAt: now,
            eventUpdatedAt: now.addingTimeInterval(60)
        ) == .event,
        CalendarConflictResolver.winner(
            localUpdatedAt: now,
            eventUpdatedAt: now
        ) == .needsAttention,
        CalendarConflictResolver.winner(
            localUpdatedAt: nil,
            eventUpdatedAt: now
        ) == .needsAttention else {
            throw CheckFailure("calendar conflict winner was not deterministic")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let deadlineDefault = DeadlinePlanner.defaultDeadline(now: now, calendar: calendar)
        let defaultComponents = calendar.dateComponents([.hour, .minute, .second], from: deadlineDefault)
        guard defaultComponents.hour == 8,
              defaultComponents.minute == 0,
              defaultComponents.second == 0 else {
            throw CheckFailure("default deadline time is not 08:00:00")
        }

        let dateChoices = DeadlinePlanner.weekDateChoices(now: now, calendar: calendar)
        guard dateChoices.count == 14,
              dateChoices.prefix(7).allSatisfy({ $0.weekOffset == 0 }),
              dateChoices.suffix(7).allSatisfy({ $0.weekOffset == 1 }),
              dateChoices.map({ calendar.component(.weekday, from: $0.date) }) == [2, 3, 4, 5, 6, 7, 1,
                                                                                    2, 3, 4, 5, 6, 7, 1] else {
            throw CheckFailure("date choices are not Monday-first current/next weeks")
        }

        guard DeadlinePlanner.clampedSeconds(-1) == 0,
              DeadlinePlanner.clampedSeconds(37) == 37,
              DeadlinePlanner.clampedSeconds(60) == 59 else {
            throw CheckFailure("seconds were not clamped to 00...59")
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let todayLabel = DeadlinePlanner.dateLabel(now, now: now, calendar: calendar)
        let tomorrowLabel = DeadlinePlanner.dateLabel(tomorrow, now: now, calendar: calendar)
        guard todayLabel == "\(DeadlineText.date(now, calendar: calendar)) · 今天",
              tomorrowLabel == DeadlineText.date(tomorrow, calendar: calendar) else {
            throw CheckFailure("date labels did not include month/day and today marker: \(todayLabel) / \(tomorrowLabel)")
        }

        let store = ItemStore(fileURL: fileURL, now: { now })
        guard store.add(text: "  第二件事  ", deadline: now.addingTimeInterval(7_200), sourceApp: "Safari") != nil else {
            throw CheckFailure("empty add returned nil")
        }
        guard store.add(text: "第一件事", deadline: now.addingTimeInterval(3_600), sourceApp: "Notes") != nil else {
            throw CheckFailure("empty add returned nil")
        }
        guard store.activeItems.map(\.text) == ["第一件事", "第二件事"] else {
            throw CheckFailure("active items are not deadline-sorted")
        }

        let reloaded = ItemStore(fileURL: fileURL, now: { now })
        guard reloaded.activeItems.map(\.text) == ["第一件事", "第二件事"] else {
            throw CheckFailure("items did not survive persistence")
        }
        guard store.add(text: "  \n  ", deadline: now.addingTimeInterval(60), sourceApp: nil) == nil else {
            throw CheckFailure("whitespace-only text was accepted")
        }

        let overdue = store.add(text: "已经错过", deadline: now.addingTimeInterval(-60), sourceApp: nil)!
        guard store.overdueCount == 1, overdue.isOverdue(at: now) else {
            throw CheckFailure("overdue state was not computed")
        }
        store.complete(overdue.id)
        guard store.activeItems.count == 2, store.completedItems.count == 1 else {
            throw CheckFailure("complete did not move the item")
        }
        store.restore(overdue.id)
        guard store.activeItems.count == 3 else {
            throw CheckFailure("restore did not return the item")
        }

        let screenshotPayload = Data("test-png-payload".utf8)
        guard let itemWithScreenshot = store.add(
            text: "带截图的事项",
            deadline: now.addingTimeInterval(9_000),
            sourceApp: "Safari",
            screenshotData: screenshotPayload
        ), let attachmentURL = store.screenshotURL(for: itemWithScreenshot),
           try Data(contentsOf: attachmentURL) == screenshotPayload else {
            throw CheckFailure("screenshot attachment was not written next to its item")
        }

        let storeAfterScreenshot = ItemStore(fileURL: fileURL, now: { now })
        guard let reloadedScreenshotItem = storeAfterScreenshot.item(withID: itemWithScreenshot.id),
              reloadedScreenshotItem.screenshotFilename == itemWithScreenshot.screenshotFilename,
              storeAfterScreenshot.screenshotURL(for: reloadedScreenshotItem) == attachmentURL else {
            throw CheckFailure("screenshot attachment reference did not survive reload")
        }

        let legacyRecord = Data("""
        [{"id":"44444444-4444-4444-4444-444444444444","text":"旧记录","deadline":"2023-11-14T22:13:20Z","createdAt":"2023-11-14T22:13:20Z","completedAt":null,"sourceApp":null}]
        """.utf8)
        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .iso8601
        let decodedLegacyRecord = try legacyDecoder.decode([CaptureItem].self, from: legacyRecord)
        guard decodedLegacyRecord.first?.screenshotFilename == nil else {
            throw CheckFailure("legacy item did not decode without a screenshot field")
        }

        store.delete(itemWithScreenshot.id)
        guard !FileManager.default.fileExists(atPath: attachmentURL.path) else {
            throw CheckFailure("deleting an item left its screenshot attachment behind")
        }

        print("Jiedian core checks passed: capture, validation, sorting, persistence, overdue, complete, restore, screenshot attachments")
    }
}

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
