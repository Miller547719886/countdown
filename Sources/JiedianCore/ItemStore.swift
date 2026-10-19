import Combine
import Foundation

@MainActor
public final class ItemStore: ObservableObject {
    @Published public private(set) var items: [CaptureItem] = []
    @Published public private(set) var loadError: String?

    private let fileURL: URL
    private let now: () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.now = now
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        load()
    }

    public var activeItems: [CaptureItem] {
        items
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.deadline == rhs.deadline { return lhs.createdAt < rhs.createdAt }
                return lhs.deadline < rhs.deadline
            }
    }

    public var completedItems: [CaptureItem] {
        items
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    public var overdueCount: Int {
        activeItems.filter { $0.deadline < now() }.count
    }

    public var nearestItem: CaptureItem? {
        activeItems.first
    }

    @discardableResult
    public func add(
        text: String,
        deadline: Date,
        sourceApp: String?,
        screenshotData: Data? = nil
    ) -> CaptureItem? {
        let cleanText = Self.normalized(text)
        guard !cleanText.isEmpty, deadline.timeIntervalSince1970.isFinite else { return nil }

        let itemID = UUID()
        var screenshotFilename: String?
        var screenshotURL: URL?
        if let screenshotData {
            guard !screenshotData.isEmpty else {
                loadError = "截图内容为空，请重新截取。"
                return nil
            }
            let filename = "\(itemID.uuidString.lowercased()).png"
            let url = attachmentsDirectoryURL.appendingPathComponent(filename)
            do {
                try FileManager.default.createDirectory(
                    at: attachmentsDirectoryURL,
                    withIntermediateDirectories: true
                )
                try screenshotData.write(to: url, options: .atomic)
                screenshotFilename = filename
                screenshotURL = url
            } catch {
                loadError = "无法保存截图：\(error.localizedDescription)"
                return nil
            }
        }

        let item = CaptureItem(
            id: itemID,
            text: cleanText,
            deadline: deadline,
            createdAt: now(),
            sourceApp: sourceApp,
            screenshotFilename: screenshotFilename
        )
        items.append(item)
        guard persist() else {
            items.removeAll { $0.id == item.id }
            if let screenshotURL { try? FileManager.default.removeItem(at: screenshotURL) }
            return nil
        }
        return item
    }

    public func update(_ item: CaptureItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.text = Self.normalized(item.text)
        guard !updated.text.isEmpty else { return }
        items[index] = updated
        persist()
    }

    public func complete(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].completedAt = now()
        persist()
    }

    public func restore(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].completedAt = nil
        persist()
    }

    public func delete(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: index)
        guard persist() else {
            items.insert(removed, at: min(index, items.count))
            return
        }
        if let screenshotURL = screenshotURL(for: removed) {
            try? FileManager.default.removeItem(at: screenshotURL)
        }
    }

    public func item(withID id: UUID) -> CaptureItem? {
        items.first { $0.id == id }
    }

    public var storageURL: URL { fileURL }

    public var attachmentsDirectoryURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("attachments", isDirectory: true)
    }

    public func screenshotURL(for item: CaptureItem) -> URL? {
        let expectedFilename = "\(item.id.uuidString.lowercased()).png"
        guard item.screenshotFilename == expectedFilename else { return nil }
        let url = attachmentsDirectoryURL.appendingPathComponent(expectedFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try decoder.decode([CaptureItem].self, from: data)
            loadError = nil
        } catch {
            loadError = "无法读取本地事项：\(error.localizedDescription)"
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
            loadError = nil
            return true
        } catch {
            loadError = "无法保存事项：\(error.localizedDescription)"
            return false
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func defaultFileURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["JIEDIAN_STORAGE_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return support
            .appendingPathComponent("Jiedian", isDirectory: true)
            .appendingPathComponent("items.json")
    }
}
