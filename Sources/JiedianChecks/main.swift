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

        print("Jiedian core checks passed: capture, validation, sorting, persistence, overdue, complete, restore")
    }
}

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
