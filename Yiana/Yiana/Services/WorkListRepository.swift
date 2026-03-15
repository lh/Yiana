//
//  WorkListRepository.swift
//  Yiana
//

import Foundation

/// Reads and writes the `.worklist.json` file from the iCloud container.
///
/// All file I/O is expected to be called from `Task.detached` — callers must ensure this.
/// The container URL must be cached from the main thread before any file operations.
class WorkListRepository {
    static let shared = WorkListRepository()

    private let filename = ".worklist.json"
    private let legacyFilename = ".yiana-worklist.json"
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

    private var documentsURL: URL? {
        cachedContainerURL?.appendingPathComponent("Documents")
    }

    private var fileURL: URL? {
        documentsURL?.appendingPathComponent(filename)
    }

    private var legacyFileURL: URL? {
        documentsURL?.appendingPathComponent(legacyFilename)
    }

    func load() throws -> SharedWorkList {
        // One-time migration: merge legacy .yiana-worklist.json into .worklist.json
        migrateLegacyIfNeeded()
        return try loadFromDisk()
    }

    /// Read .worklist.json without triggering migration. Used by mergeAndSave to avoid recursion.
    private func loadFromDisk() throws -> SharedWorkList {
        guard let url = fileURL else {
            return SharedWorkList(modified: ISO8601DateFormatter().string(from: Date()), items: [])
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return SharedWorkList(modified: ISO8601DateFormatter().string(from: Date()), items: [])
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SharedWorkList.self, from: data)
    }

    func save(_ workList: SharedWorkList) throws {
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

    /// Merge-before-write: read current file, union with in-memory items by id,
    /// prefer items with more data (e.g. resolvedFilename set).
    func mergeAndSave(items: [SharedWorkListItem]) throws {
        let existing = (try? loadFromDisk()) ?? SharedWorkList(
            modified: ISO8601DateFormatter().string(from: Date()), items: []
        )

        var merged: [String: SharedWorkListItem] = [:]
        for item in existing.items {
            merged[item.id] = item
        }
        for item in items {
            if let current = merged[item.id] {
                // Prefer the item with resolvedFilename if the other doesn't have one
                if current.resolvedFilename == nil && item.resolvedFilename != nil {
                    merged[item.id] = item
                } else if item.resolvedFilename == nil && current.resolvedFilename != nil {
                    // Keep current
                } else {
                    merged[item.id] = item
                }
            } else {
                merged[item.id] = item
            }
        }

        let workList = SharedWorkList(
            modified: ISO8601DateFormatter().string(from: Date()),
            items: Array(merged.values).sorted { $0.added > $1.added }
        )
        try save(workList)
    }

    // MARK: - Legacy Migration

    private func migrateLegacyIfNeeded() {
        guard let legacyURL = legacyFileURL,
              FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        guard let data = try? Data(contentsOf: legacyURL),
              let legacy = try? JSONDecoder().decode(LegacyYianaWorkList.self, from: data) else {
            // Can't decode — just delete the legacy file
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }

        // Convert legacy entries to shared format
        let converted = legacy.entries.map { entry -> SharedWorkListItem in
            let source: String
            switch entry.source {
            case "yiale": source = "clinic_list"
            case "document": source = "document"
            default: source = "manual"
            }

            // Parse surname/firstName from searchText (best effort)
            let parts = entry.searchText.components(separatedBy: " ")
            let surname = parts.first
            let firstName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil

            return SharedWorkListItem(
                id: entry.yialeMRN ?? entry.id.uuidString,
                mrn: entry.yialeMRN,
                surname: surname,
                firstName: firstName,
                resolvedFilename: entry.resolvedFilename,
                source: source,
                added: entry.added
            )
        }

        // Merge converted entries into the current file (if any)
        if !converted.isEmpty {
            try? mergeAndSave(items: converted)
        }

        // Delete legacy file
        try? FileManager.default.removeItem(at: legacyURL)
    }
}
