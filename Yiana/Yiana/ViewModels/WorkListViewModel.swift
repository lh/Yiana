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
    @Published var entries: [SharedWorkListItem] = []
    @Published var matchCounts: [String: Int] = [:]

    private let repository = WorkListRepository.shared
    private let searchIndex = SearchIndexService.shared
    private var observers: [NSObjectProtocol] = []
    private var hasStarted = false
    private var autoResolveTask: Task<Void, Never>?
    private var fileWatchQuery: NSMetadataQuery?
    private var fileWatchObservers: [NSObjectProtocol] = []

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // Cache iCloud container URL on main thread before any detached file I/O
        repository.cacheContainerURL()

        // Watch for document changes to auto-resolve unresolved entries (debounced)
        let documentsObserver = NotificationCenter.default.addObserver(
            forName: .yianaDocumentsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.autoResolveTask?.cancel()
            self.autoResolveTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second debounce
                guard !Task.isCancelled else { return }
                await self.autoResolveUnresolved()
            }
        }
        observers.append(documentsObserver)

        // Watch .worklist.json for changes from Yiale
        startFileWatch()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        stopFileWatch()
    }

    // MARK: - File Watching

    private func startFileWatch() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@",
            NSMetadataItemFSNameKey, ".worklist.json")

        let gatherObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.handleFileChange()
        }
        fileWatchObservers.append(gatherObserver)

        let updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.handleFileChange()
        }
        fileWatchObservers.append(updateObserver)

        fileWatchQuery = query
        query.start()
    }

    private func stopFileWatch() {
        fileWatchQuery?.stop()
        fileWatchQuery = nil
        for observer in fileWatchObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        fileWatchObservers.removeAll()
    }

    private func handleFileChange() {
        Task { await load() }
    }

    // MARK: - Load / Save

    func load() async {
        let loaded = await Task.detached { [repository] in
            try? repository.load()
        }.value

        if let workList = loaded {
            entries = workList.items
            await prefetchResolvedDocuments()
        }
    }

    private func save() async {
        let entriesToSave = entries
        await Task.detached { [repository] in
            let workList = SharedWorkList(
                modified: ISO8601DateFormatter().string(from: Date()),
                items: entriesToSave
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
            $0.displayText.lowercased() == lowered ||
            $0.resolvedFilename?.lowercased() == lowered
        }) { return }

        // Parse "Surname Firstname" from search text
        let parts = trimmed.components(separatedBy: " ")
        let surname = parts.first
        let firstName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil

        let entry = SharedWorkListItem(
            id: UUID().uuidString,
            surname: surname,
            firstName: firstName,
            resolvedFilename: nil,
            source: "manual",
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

        // Parse surname/firstName from filename (Surname_Firstname_DOB)
        let parts = filename.components(separatedBy: "_")
        let surname = parts.count > 0 ? parts[0] : nil
        let firstName = parts.count > 1 ? parts[1] : nil

        let entry = SharedWorkListItem(
            id: UUID().uuidString,
            surname: surname,
            firstName: firstName,
            resolvedFilename: filename,
            source: "document",
            added: ISO8601DateFormatter().string(from: Date())
        )
        entries.append(entry)
        await save()
    }

    func remove(entryID: String) async {
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
    func resolve(entryID: String) async -> [URL] {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return [] }
        let entry = entries[index]

        let query = entry.displayText
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
    func resolveToURL(entryID: String, url: URL) async {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let stem = url.deletingPathExtension().lastPathComponent
        entries[index].resolvedFilename = stem
        matchCounts.removeValue(forKey: entryID)
        await save()
    }

    /// Look up the current URL for a resolved entry by searching for its filename.
    /// Returns nil if the document can't be found (e.g., renamed or deleted).
    func urlForResolved(_ entry: SharedWorkListItem) async -> URL? {
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

    /// Pre-download all resolved work list documents from iCloud.
    /// Fire-and-forget — iCloud manages the downloads in the background.
    private func prefetchResolvedDocuments() async {
        let filenames = entries.compactMap(\.resolvedFilename)
        guard !filenames.isEmpty else { return }

        let repository = DocumentRepository()
        let allDocs = await Task.detached {
            repository.allDocumentsRecursive()
        }.value

        for filename in filenames {
            guard let doc = allDocs.first(where: {
                $0.url.deletingPathExtension().lastPathComponent == filename
            }) else { continue }

            try? FileManager.default.startDownloadingUbiquitousItem(at: doc.url)
        }
    }

    /// Try to resolve a single entry by ID. Used internally.
    private func resolveEntry(id: String) async {
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
                let results = try await searchIndex.search(query: entry.displayText, limit: 5)
                if results.count == 1 {
                    let stem = results[0].url.deletingPathExtension().lastPathComponent
                    entries[index].resolvedFilename = stem
                    matchCounts.removeValue(forKey: id)
                    changed = true
                } else if matchCounts[id] != results.count {
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

    /// Import clinic list items from a pasted text.
    func importClinicList(_ text: String) async {
        let items = ClinicListParser.parse(text)
        guard !items.isEmpty else { return }

        let existingIDs = Set(entries.map(\.id))
        let newItems = items.filter { !existingIDs.contains($0.id) }
        entries.insert(contentsOf: newItems, at: 0)

        // Try to auto-resolve new entries
        for entry in newItems {
            await resolveEntry(id: entry.id)
        }
        await save()
    }

    var entryCount: Int { entries.count }
}
