import Foundation
import os.log

/// Reads and writes `.worklist.json` from the iCloud container.
/// All methods perform file I/O — call from `Task.detached`.
final class WorkListRepository {
    private static let logger = Logger(
        subsystem: "com.vitygas.Yiana",
        category: "WorkListRepository"
    )

    private let ubiquityIdentifier = "iCloud.com.vitygas.Yiana"

    /// Resolve the `.worklist.json` URL.
    /// Uses the cached container URL from `WorkListSyncService` if available,
    /// otherwise computes it directly (must not be called from `Task.detached`).
    private func workListURL() -> URL? {
        if let cached = WorkListSyncService.shared.cachedContainerURL {
            return cached
                .appendingPathComponent("Documents")
                .appendingPathComponent(".worklist.json")
        }
        guard let container = FileManager.default.url(
            forUbiquityContainerIdentifier: ubiquityIdentifier
        ) else {
            Self.logger.warning("iCloud container unavailable")
            return nil
        }
        return container
            .appendingPathComponent("Documents")
            .appendingPathComponent(".worklist.json")
    }

    func load() throws -> WorkList {
        guard let url = workListURL() else {
            return WorkList(
                modified: ISO8601DateFormatter().string(from: Date()),
                items: []
            )
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return WorkList(
                modified: ISO8601DateFormatter().string(from: Date()),
                items: []
            )
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorkList.self, from: data)
    }

    func save(_ workList: WorkList) throws {
        guard let url = workListURL() else {
            Self.logger.error("Cannot save — iCloud container unavailable")
            return
        }

        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        let tmpURL = url.appendingPathExtension("tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workList)
        try data.write(to: tmpURL, options: .atomic)

        if fm.fileExists(atPath: url.path) {
            _ = try fm.replaceItemAt(url, withItemAt: tmpURL)
        } else {
            try fm.moveItem(at: tmpURL, to: url)
        }

        Self.logger.info("Saved work list with \(workList.items.count) items")
    }
}
