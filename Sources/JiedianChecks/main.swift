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
              completedMarker.isCompleted,
              completedMarker.completionPrefixIsOwned else {
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

        let whitespaceNotes = "  开头空白\n用户内容\n结尾空白  \n"
        let whitespaceMarkedNotes = CalendarMarker.upsertNotesMarker(
            in: whitespaceNotes,
            itemID: markerItemID,
            isCompleted: false
        )
        guard CalendarMarker.removeNotesMarker(from: whitespaceMarkedNotes) == whitespaceNotes else {
            throw CheckFailure("calendar notes marker changed user whitespace")
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

        let preferredExternalEvent = CalendarEventCandidate(
            identifier: "moved-calendar-event",
            externalIdentifier: "external-1",
            calendarIdentifier: "calendar-moved",
            lastModifiedDate: now
        )
        let unrelatedExternalEvent = CalendarEventCandidate(
            identifier: "same-item-different-event",
            externalIdentifier: "external-other",
            calendarIdentifier: "calendar-selected",
            lastModifiedDate: now.addingTimeInterval(60)
        )
        let preferredSelection = CalendarMarker.selectCandidate(
            [preferredExternalEvent, unrelatedExternalEvent],
            preferredExternalIdentifier: "external-1"
        )
        guard preferredSelection.candidate?.identifier == "moved-calendar-event",
              preferredSelection.hasDuplicates else {
            throw CheckFailure("calendar external identifier was not preferred while retaining duplicate state")
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

        guard CalendarSyncStatus.pendingCount([
            CaptureItem(text: "已同步", deadline: now, createdAt: now, calendarSyncState: .synced),
            CaptureItem(text: "待处理", deadline: now, createdAt: now, calendarSyncState: .needsAttention)
        ]) == 1,
        CalendarSyncStatus.pendingSummary(2) == "还有 2 项需要处理。" else {
            throw CheckFailure("calendar pending status text/count was incorrect")
        }

        let routerItem = CaptureItem(
            id: markerItemID,
            text: "路由事项",
            deadline: now.addingTimeInterval(900),
            createdAt: now,
            calendarLink: CalendarLink(eventIdentifier: "event-router")
        )
        guard CalendarSyncIntentRouter.intent(
            before: nil,
            after: routerItem,
            origin: .local
        ) == .upsert(itemID: markerItemID),
        CalendarSyncIntentRouter.intent(
            before: routerItem,
            after: nil,
            origin: .local
        ) == .remove(
            itemID: markerItemID,
            link: routerItem.calendarLink
        ),
        CalendarSyncIntentRouter.intent(
            before: routerItem,
            after: routerItem,
            origin: .calendar
        ) == nil else {
            throw CheckFailure("calendar sync intent router did not guard mutation origin")
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

        let projectionDeadline = now.addingTimeInterval(600)
        let projectionItem = CaptureItem(
            id: markerItemID,
            text: "投影事项",
            deadline: projectionDeadline,
            createdAt: now
        )
        let projection = CalendarEventProjection(item: projectionItem)
        guard projection.title == "投影事项",
              projection.startDate == projectionDeadline,
              projection.endDate == projectionDeadline.addingTimeInterval(60),
              CalendarMarker.parse(url: projection.markerURL)?.itemID == markerItemID,
              CalendarMarker.parse(url: projection.markerURL)?.isCompleted == false,
              CalendarMarker.notesMarker(in: projection.notes)?.itemID == markerItemID,
              CalendarMarker.notesMarker(in: projection.notes)?.isCompleted == false else {
            throw CheckFailure("active calendar event projection was incorrect")
        }

        let userCheckmarkProjection = CalendarEventProjection(item: CaptureItem(
            id: markerItemID,
            text: "✓ review",
            deadline: projectionDeadline,
            createdAt: now
        ))
        guard userCheckmarkProjection.title == "✓ review" else {
            throw CheckFailure("active user title beginning with a checkmark was changed")
        }

        let completedProjectionItem = CaptureItem(
            id: markerItemID,
            text: "投影事项",
            deadline: projectionDeadline,
            createdAt: now,
            completedAt: now
        )
        let completedProjection = CalendarEventProjection(item: completedProjectionItem)
        guard completedProjection.title == "✓ 投影事项",
              CalendarMarker.parse(url: completedProjection.markerURL)?.isCompleted == true,
              CalendarMarker.notesMarker(in: completedProjection.notes)?.isCompleted == true else {
            throw CheckFailure("completed calendar event projection was incorrect")
        }

        let completedLiteralCheckmarkProjection = CalendarEventProjection(item: CaptureItem(
            id: markerItemID,
            text: "✓ review",
            deadline: projectionDeadline,
            createdAt: now,
            completedAt: now
        ))
        guard completedLiteralCheckmarkProjection.title == "✓ review",
              CalendarMarker.parse(url: completedLiteralCheckmarkProjection.markerURL)?.completionPrefixIsOwned == false,
              CalendarMarker.notesMarker(in: completedLiteralCheckmarkProjection.notes)?.completionPrefixIsOwned == false,
              CalendarMarker.itemText(
                  fromEventTitle: "✓ review",
                  isCompleted: true,
                  completionPrefixIsOwned: false
              ) == "✓ review" else {
            throw CheckFailure("completed literal checkmark title was mistaken for a maintained prefix")
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
        guard let decodedLegacyItem = decodedLegacyRecord.first,
              decodedLegacyItem.screenshotFilename == nil,
              decodedLegacyItem.updatedAt == decodedLegacyItem.createdAt,
              decodedLegacyItem.calendarLink == nil,
              decodedLegacyItem.calendarSyncState == .unlinked else {
            throw CheckFailure("legacy item did not decode without a screenshot field")
        }

        var timestampNow = now
        let timestampStoreURL = directory.appendingPathComponent("timestamp-items.json")
        let timestampStore = ItemStore(fileURL: timestampStoreURL, now: { timestampNow })
        guard let timestampItem = timestampStore.add(
            text: "更新时间事项",
            deadline: now.addingTimeInterval(10_000),
            sourceApp: nil
        ), timestampItem.updatedAt == now else {
            throw CheckFailure("new item did not initialize updatedAt from createdAt")
        }

        timestampNow = now.addingTimeInterval(120)
        var locallyUpdatedItem = timestampItem
        locallyUpdatedItem.text = "本地更新"
        guard timestampStore.update(locallyUpdatedItem),
              timestampStore.item(withID: timestampItem.id)?.updatedAt == timestampNow else {
            throw CheckFailure("local item update did not refresh updatedAt")
        }

        timestampNow = now.addingTimeInterval(240)
        guard let completedTimestampItem = timestampStore.complete(timestampItem.id),
              completedTimestampItem.updatedAt == timestampNow else {
            throw CheckFailure("complete did not refresh updatedAt or return the item")
        }

        timestampNow = now.addingTimeInterval(360)
        guard let restoredTimestampItem = timestampStore.restore(timestampItem.id),
              restoredTimestampItem.updatedAt == timestampNow else {
            throw CheckFailure("restore did not refresh updatedAt or return the item")
        }

        let eventUpdatedAt = now.addingTimeInterval(480)
        var linkedTimestampItem = restoredTimestampItem
        linkedTimestampItem.text = "日历更新"
        linkedTimestampItem.calendarLink = CalendarLink(
            eventIdentifier: "event-1",
            calendarItemExternalIdentifier: "external-1",
            calendarIdentifier: "calendar-1",
            lastSyncedAt: eventUpdatedAt
        )
        linkedTimestampItem.calendarSyncState = .synced
        guard timestampStore.update(linkedTimestampItem, updatedAt: eventUpdatedAt),
              timestampStore.item(withID: timestampItem.id)?.updatedAt == eventUpdatedAt else {
            throw CheckFailure("calendar-originated update did not preserve its event timestamp")
        }

        var staleLocalEdit = linkedTimestampItem
        staleLocalEdit.text = "旧编辑面板内容"
        staleLocalEdit.calendarLink = nil
        staleLocalEdit.calendarSyncState = .unlinked
        timestampNow = now.addingTimeInterval(600)
        guard timestampStore.update(staleLocalEdit),
              timestampStore.item(withID: timestampItem.id)?.calendarLink == linkedTimestampItem.calendarLink,
              timestampStore.item(withID: timestampItem.id)?.calendarSyncState == .synced else {
            throw CheckFailure("stale local edit erased newer calendar metadata")
        }

        let reloadedTimestampStore = ItemStore(fileURL: timestampStoreURL, now: { timestampNow })
        guard let reloadedTimestampItem = reloadedTimestampStore.item(withID: timestampItem.id),
              reloadedTimestampItem.calendarLink == linkedTimestampItem.calendarLink,
              reloadedTimestampItem.calendarSyncState == .synced,
              let removedTimestampItem = reloadedTimestampStore.delete(timestampItem.id),
              removedTimestampItem.id == timestampItem.id,
              reloadedTimestampStore.item(withID: timestampItem.id) == nil else {
            throw CheckFailure("calendar link did not survive reload or delete did not return the item")
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
