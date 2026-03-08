//
//  WorkListViewModel.swift
//  Yiana
//

import Foundation
import Combine

/// Observable view model managing the work list.
///
/// Uses `ObservableObject` + `@Published` per project convention.
/// All file I/O runs in `Task.detached` (`.task {}` inherits main actor).
class WorkListViewModel: ObservableObject {
    @Published var entries: [WorkListEntry] = []
    @Published var matchCounts: [UUID: Int] = [:]

    private let repository = WorkListRepository.shared
    private let searchIndex = SearchIndexService.shared
    private var observers: [NSObjectProtocol] = []
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // Cache iCloud container URL on main thread before any detached file I/O
        repository.cacheContainerURL()

        // Watch for document changes to auto-resolve unresolved entries
        let documentsObserver = NotificationCenter.default.addObserver(
            forName: .yianaDocumentsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.autoResolveUnresolved() }
        }
        observers.append(documentsObserver)

        // Watch for Yiale work list changes
        let yialeObserver = NotificationCenter.default.addObserver(
            forName: .yialeWorkListChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let items = notification.userInfo?["items"] as? [ClinicListItem] ?? []
            self.mergeYialeItems(items)
        }
        observers.append(yialeObserver)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Load / Save

    func load() async {
        let loaded = await Task.detached { [repository] in
            try? repository.load()
        }.value

        if let workList = loaded {
            entries = workList.entries
        }
    }

    private func save() async {
        let entriesToSave = entries
        await Task.detached { [repository] in
            let workList = YianaWorkList(
                modified: ISO8601DateFormatter().string(from: Date()),
                entries: entriesToSave
            )
            try? repository.save(workList)
        }.value
    }

    // MARK: - Add / Remove

    func addManual(searchText: String) async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Skip if already present (by search text or resolved filename)
        let lowered = trimmed.lowercased()
        if entries.contains(where: {
            $0.searchText.lowercased() == lowered ||
            $0.resolvedFilename?.lowercased() == lowered
        }) { return }

        let entry = WorkListEntry(
            id: UUID(),
            searchText: trimmed,
            resolvedFilename: nil,
            source: .manual,
            added: ISO8601DateFormatter().string(from: Date())
        )
        entries.append(entry)

        // Try to auto-resolve immediately
        await resolveEntry(id: entry.id)
        await save()
    }

    /// Add a document to the work list with pre-resolved filename.
    /// `filename` should be the stem (no extension).
    func addFromDocument(filename: String) async {
        // Skip if this document is already in the list
        if entries.contains(where: { $0.resolvedFilename == filename }) { return }

        let entry = WorkListEntry(
            id: UUID(),
            searchText: filename.replacingOccurrences(of: "_", with: " "),
            resolvedFilename: filename,
            source: .document,
            added: ISO8601DateFormatter().string(from: Date())
        )
        entries.append(entry)
        await save()
    }

    func remove(entryID: UUID) async {
        entries.removeAll { $0.id == entryID }
        matchCounts.removeValue(forKey: entryID)
        await save()
    }

    func clearAll() async {
        entries.removeAll()
        matchCounts.removeAll()
        await save()
    }

    /// Check whether a document (by filename stem, no extension) is in the work list.
    func containsDocument(filename: String) -> Bool {
        entries.contains { $0.resolvedFilename == filename }
    }

    /// Toggle a document in/out of the work list.
    func toggleDocument(filename: String) async {
        if let existing = entries.first(where: { $0.resolvedFilename == filename }) {
            await remove(entryID: existing.id)
        } else {
            await addFromDocument(filename: filename)
        }
    }

    // MARK: - Resolution

    /// Resolve an entry by searching the index. Returns matching URLs.
    ///
    /// - 0 matches: returns empty, marks `?`
    /// - 1 match: auto-resolves (sets `resolvedFilename`), saves, returns the URL
    /// - N matches: returns URLs for picker (caller must handle)
    func resolve(entryID: UUID) async -> [URL] {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return [] }
        let entry = entries[index]

        let query = entry.searchText
        guard !query.isEmpty else { return [] }

        do {
            let results = try await searchIndex.search(query: query, limit: 10)

            if results.isEmpty {
                matchCounts[entryID] = 0
                return []
            } else if results.count == 1 {
                let result = results[0]
                let stem = result.url.deletingPathExtension().lastPathComponent
                entries[index].resolvedFilename = stem
                matchCounts.removeValue(forKey: entryID)
                await save()
                return [result.url]
            } else {
                matchCounts[entryID] = results.count
                return results.map(\.url)
            }
        } catch {
            matchCounts[entryID] = 0
            return []
        }
    }

    /// Manually resolve an entry to a specific URL (after picker selection).
    func resolveToURL(entryID: UUID, url: URL) async {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let stem = url.deletingPathExtension().lastPathComponent
        entries[index].resolvedFilename = stem
        matchCounts.removeValue(forKey: entryID)
        await save()
    }

    /// Look up the current URL for a resolved entry by searching for its filename.
    /// Returns nil if the document can't be found (e.g., renamed or deleted).
    func urlForResolved(_ entry: WorkListEntry) async -> URL? {
        guard let resolvedFilename = entry.resolvedFilename else { return nil }

        do {
            let results = try await searchIndex.search(query: resolvedFilename, limit: 5)
            // Find exact filename match
            return results.first { result in
                result.url.deletingPathExtension().lastPathComponent == resolvedFilename
            }?.url
        } catch {
            return nil
        }
    }

    /// Try to resolve a single entry by ID. Used internally.
    private func resolveEntry(id: UUID) async {
        _ = await resolve(entryID: id)
    }

    /// Called when documents change. Re-search for unresolved entries.
    func autoResolveUnresolved() async {
        let unresolvedIDs = entries
            .filter { $0.resolvedFilename == nil }
            .map(\.id)

        guard !unresolvedIDs.isEmpty else { return }

        var changed = false
        for id in unresolvedIDs {
            guard let index = entries.firstIndex(where: { $0.id == id }) else { continue }
            let entry = entries[index]

            do {
                let results = try await searchIndex.search(query: entry.searchText, limit: 5)
                if results.count == 1 {
                    let stem = results[0].url.deletingPathExtension().lastPathComponent
                    entries[index].resolvedFilename = stem
                    matchCounts.removeValue(forKey: id)
                    changed = true
                } else {
                    matchCounts[id] = results.count
                }
            } catch {
                // Ignore — will retry on next documents change
            }
        }

        if changed {
            await save()
        }
    }

    // MARK: - Yiale Merge

    /// Merge items from Yiale sync. New MRNs are added at front, removed MRNs are deleted.
    func mergeYialeItems(_ items: [ClinicListItem]) {
        let incomingMRNs = Set(items.map(\.mrn))
        let existingMRNs = Set(entries.compactMap(\.yialeMRN))

        // Remove entries whose MRN is no longer in the Yiale list
        entries.removeAll { entry in
            guard let mrn = entry.yialeMRN, entry.source == .yiale else { return false }
            return !incomingMRNs.contains(mrn)
        }

        // Add new entries at the front (preserving Yiale order)
        let newItems = items.filter { !existingMRNs.contains($0.mrn) }
        if !newItems.isEmpty {
            let newEntries = ClinicListParser.toWorkListEntries(newItems)
            entries.insert(contentsOf: newEntries, at: 0)
        }

        Task { await save() }
    }

    /// Import clinic list items from a pasted text.
    func importClinicList(_ text: String) async {
        let items = ClinicListParser.parse(text)
        guard !items.isEmpty else { return }

        let newEntries = ClinicListParser.toWorkListEntries(items)
        entries.insert(contentsOf: newEntries, at: 0)

        // Try to auto-resolve new entries
        for entry in newEntries {
            await resolveEntry(id: entry.id)
        }
        await save()
    }

    var entryCount: Int { entries.count }
}
