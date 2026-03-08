//
//  WorkListRepository.swift
//  Yiana
//

import Foundation

/// Reads and writes the `.yiana-worklist.json` file from the iCloud container.
///
/// All file I/O is expected to be called from `Task.detached` — callers must ensure this.
/// The container URL must be cached from the main thread before any file operations.
class WorkListRepository {
    static let shared = WorkListRepository()

    private let filename = ".yiana-worklist.json"
    private var cachedContainerURL: URL?

    /// Call from main thread to cache the iCloud container URL.
    /// `url(forUbiquityContainerIdentifier:)` returns nil from `Task.detached`.
    func cacheContainerURL() {
        if cachedContainerURL == nil {
            cachedContainerURL = FileManager.default.url(
                forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana"
            )
        }
    }

    private var fileURL: URL? {
        guard let container = cachedContainerURL else { return nil }
        return container.appendingPathComponent("Documents").appendingPathComponent(filename)
    }

    func load() throws -> YianaWorkList {
        guard let url = fileURL else {
            return YianaWorkList(modified: ISO8601DateFormatter().string(from: Date()), entries: [])
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return YianaWorkList(modified: ISO8601DateFormatter().string(from: Date()), entries: [])
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(YianaWorkList.self, from: data)
    }

    func save(_ workList: YianaWorkList) throws {
        guard let url = fileURL else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workList)

        // Atomic write: temp file + replaceItemAt
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }
}
