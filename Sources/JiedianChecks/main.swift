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
