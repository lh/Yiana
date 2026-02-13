//
//  DocumentListViewModel.swift
//  Yiana
//

import Foundation
import SwiftUI
import PDFKit
import YianaDocumentArchive
import Combine
import GRDB

enum SortOption: String, CaseIterable {
    case title = "Title"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case size = "Size"

    var sortColumn: SortColumn {
        switch self {
        case .title: return .title
        case .dateModified: return .dateModified
        case .dateCreated: return .dateCreated
        case .size: return .fileSize
        }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let documentURL: URL
    let matchType: MatchType
    let snippet: String?
    let pageNumber: Int?  // 1-based page number
    let searchTerm: String?

    enum MatchType {
        case title
        case content
        case both
    }
}

@MainActor
class DocumentListViewModel: ObservableObject {
    @Published var documents: [DocumentListItem] = []
    @Published var folderURLs: [URL] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentFolderName: String = "Documents"
    @Published var folderPath: [String] = []

    /// Number of documents being filtered out due to iCloud sync (UUID placeholders)
    @Published var syncingDocumentCount: Int = 0

    /// Whether iCloud sync is in progress (has placeholder files)
    var isSyncing: Bool { syncingDocumentCount > 0 }

    // Search results
    @Published var otherFolderResults: [(item: DocumentListItem, path: String)] = []
    @Published var isSearching = false
    @Published var isSearchInProgress = false
    @Published var searchResults: [SearchResult] = []

    private let repository: DocumentRepository
    private var allFolderURLs: [URL] = []
    private var currentSearchText = ""
    private var currentSortOption: SortOption = .title
    private var currentSortAscending = true
    private let searchIndex = SearchIndexService.shared

    // GRDB ValueObservation for automatic list updates
    private var observationCancellable: AnyDatabaseCancellable?

    // Search debouncing and cancellation
    private var searchTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?

    var documentsDirectory: URL { repository.documentsDirectory }

    init(repository: DocumentRepository? = nil) {
        self.repository = repository ?? DocumentRepository()
    }

    func loadDocuments() async {
        #if DEBUG
        let loadStart = CFAbsoluteTimeGetCurrent()
        #endif
        isLoading = true
        errorMessage = nil

        await Task.yield()

        // Folders still come from filesystem (they're not in the DB)
        allFolderURLs = repository.folderURLs()
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        currentFolderName = repository.currentFolderName
        folderPath = repository.folderPathComponents
        folderURLs = allFolderURLs

        // Start GRDB ValueObservation -- it will push document updates automatically
        observeDocuments()

        isLoading = false
        #if DEBUG
        SyncPerfLog.shared.countLoadDocuments(ms: (CFAbsoluteTimeGetCurrent() - loadStart) * 1000)
        #endif
    }

    /// Start (or restart) a ValueObservation that pushes document list updates
    /// whenever the underlying DB rows change. GRDB coalesces rapid writes
    /// so we get far fewer callbacks than raw notification-based reloads.
    private func observeDocuments() {
        observationCancellable?.cancel()

        // Don't observe while searching -- search has its own query path
        guard currentSearchText.isEmpty else { return }

        let folder = repository.currentFolderPath
        let sort = currentSortOption.sortColumn
        let asc = currentSortAscending

        let orderColumn: String
        switch sort {
        case .title: orderColumn = "title"
        case .dateModified: orderColumn = "modified_date"
        case .dateCreated: orderColumn = "created_date"
        case .fileSize: orderColumn = "file_size"
        }
        let orderDirection = asc ? "ASC" : "DESC"

        let observation = ValueObservation.tracking { db in
            let sql = """
                SELECT * FROM documents_metadata
                WHERE folder_path = ?
                ORDER BY \(orderColumn) \(orderDirection)
                """
            return try SearchIndexService.DocumentMetadataRecord
                .fetchAll(db, sql: sql, arguments: [folder])
        }

        observationCancellable = observation.start(
            in: SearchIndexService.shared.reader,
            scheduling: .immediate
        ) { error in
            #if DEBUG
            print("ValueObservation error: \(error)")
            #endif
        } onChange: { [weak self] records in
            guard let self else { return }
            #if DEBUG
            SyncPerfLog.shared.countObservation()
            #endif
            self.documents = records.map { DocumentListItem(record: $0) }
            self.syncingDocumentCount = records.filter(\.isPlaceholder).count
        }
    }

    func createNewDocument(title: String) async -> URL? {
        let url = repository.newDocumentURL(title: title)
        return url
    }

    func deleteDocument(at url: URL) async throws {
        do {
            // Find the document in our list to get its ID
            if let item = documents.first(where: { $0.url == url }) {
                try? await searchIndex.removeDocument(id: item.id)
            } else {
                // Fallback: extract metadata from file
                if let metadata = try? NoteDocument.extractMetadata(from: url) {
                    try? await searchIndex.removeDocument(id: metadata.id)
                }
            }

            try repository.deleteDocument(at: url)
            documents.removeAll { $0.url == url }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            throw error
        }
    }

    func duplicateDocument(at url: URL) async throws {
        do {
            _ = try repository.duplicateDocument(at: url)
            await loadDocuments()
        } catch {
            errorMessage = "Failed to duplicate: \(error.localizedDescription)"
            throw error
        }
    }

    func deleteDocuments(ids: Set<UUID>) async throws {
        var failCount = 0
        for id in ids {
            guard let item = documents.first(where: { $0.id == id })
                    ?? otherFolderResults.first(where: { $0.item.id == id })?.item else {
                failCount += 1
                continue
            }
            do {
                try await deleteDocument(at: item.url)
            } catch {
                failCount += 1
            }
        }
        if failCount > 0 {
            errorMessage = "Failed to delete \(failCount) of \(ids.count) documents"
        }
    }

    func moveDocuments(ids: Set<UUID>, toFolder folderPath: String) async throws {
        var failCount = 0
        for id in ids {
            guard let item = documents.first(where: { $0.id == id })
                    ?? otherFolderResults.first(where: { $0.item.id == id })?.item else {
                failCount += 1
                continue
            }
            guard !item.isPlaceholder else { continue }
            do {
                let newURL = try repository.moveDocument(at: item.url, toFolder: folderPath)
                let newFolderPath = newURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
                let newTitle = newURL.deletingPathExtension().lastPathComponent
                try await searchIndex.updateDocumentPath(
                    documentId: item.id,
                    newURL: newURL,
                    newFolderPath: newFolderPath,
                    newTitle: newTitle
                )
            } catch {
                failCount += 1
            }
        }
        await refresh()
        await loadDocuments()
        if failCount > 0 {
            errorMessage = "Failed to move \(failCount) of \(ids.count) documents"
        }
    }

    /// Refresh folder list only. Document list updates automatically via ValueObservation.
    func refresh() async {
        allFolderURLs = repository.folderURLs()
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if currentSearchText.isEmpty {
            folderURLs = allFolderURLs
        }
    }

    // MARK: - Sorting

    func sortDocuments(by option: SortOption, ascending: Bool = true) async {
        currentSortOption = option
        currentSortAscending = ascending

        // Restart observation with new sort order
        if !isSearching {
            observeDocuments()
        }
    }

    // MARK: - Folder Navigation

    func navigateToFolder(_ folderName: String) async {
        repository.navigateToFolder(folderName)
        await loadDocuments()
    }

    func navigateToParent() async {
        repository.navigateToParent()
        await loadDocuments()
    }

    func navigateToRoot() async {
        repository.navigateToRoot()
        await loadDocuments()
    }

    func navigateToPathComponent(at index: Int) async {
        let components = repository.folderPathComponents
        guard index < components.count else { return }

        let newPath = components.prefix(index + 1).joined(separator: "/")

        repository.navigateToRoot()
        if !newPath.isEmpty {
            repository.navigateToFolder(newPath)
        }
        await loadDocuments()
    }

    func createFolder(name: String) async -> Bool {
        do {
            try repository.createFolder(name: name)
            await loadDocuments()
            return true
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - File Management

    func moveDocument(_ item: DocumentListItem, toFolder folderPath: String) async throws {
        let newURL = try repository.moveDocument(at: item.url, toFolder: folderPath)
        let newFolderPath = newURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
        let newTitle = newURL.deletingPathExtension().lastPathComponent
        try await searchIndex.updateDocumentPath(
            documentId: item.id,
            newURL: newURL,
            newFolderPath: newFolderPath,
            newTitle: newTitle
        )
        await refresh()
    }

    func renameDocument(_ item: DocumentListItem, newName: String) async throws {
        guard newName != item.title else { return }
        let newURL = try repository.renameDocument(at: item.url, newName: newName)
        let folderPath = newURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
        let newTitle = newURL.deletingPathExtension().lastPathComponent
        try await searchIndex.updateDocumentPath(
            documentId: item.id,
            newURL: newURL,
            newFolderPath: folderPath,
            newTitle: newTitle
        )
    }

    func renameFolder(_ folderURL: URL, newName: String) async throws {
        let oldRelativePath = folderURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
        let oldFolderPath: String
        if oldRelativePath.isEmpty {
            oldFolderPath = folderURL.lastPathComponent
        } else {
            oldFolderPath = oldRelativePath + "/" + folderURL.lastPathComponent
        }

        let newURL = try repository.renameFolder(at: folderURL, newName: newName)

        let newRelativePath = newURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
        let newFolderPath: String
        if newRelativePath.isEmpty {
            newFolderPath = newURL.lastPathComponent
        } else {
            newFolderPath = newRelativePath + "/" + newURL.lastPathComponent
        }

        try await searchIndex.updateDocumentsInFolder(
            oldFolderPath: oldFolderPath,
            newFolderPath: newFolderPath,
            documentsDirectory: repository.documentsDirectory
        )
        await loadDocuments()
    }

    func moveFolder(_ folderURL: URL, toFolder targetPath: String) async throws {
        // Compute old relative path for DB update
        let oldRelativePath = folderURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
        let oldFolderPath: String
        if oldRelativePath.isEmpty {
            oldFolderPath = folderURL.lastPathComponent
        } else {
            oldFolderPath = oldRelativePath + "/" + folderURL.lastPathComponent
        }

        let newURL = try repository.moveFolder(at: folderURL, toFolder: targetPath)

        // Compute new relative path after move
        let newRelativePath = newURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
        let newFolderPath: String
        if newRelativePath.isEmpty {
            newFolderPath = newURL.lastPathComponent
        } else {
            newFolderPath = newRelativePath + "/" + newURL.lastPathComponent
        }

        try await searchIndex.updateDocumentsInFolder(
            oldFolderPath: oldFolderPath,
            newFolderPath: newFolderPath,
            documentsDirectory: repository.documentsDirectory
        )
        await loadDocuments()
    }

    func deleteFolder(_ folderURL: URL) async throws {
        let relativePath = folderURL.relativeFolderPath(relativeTo: repository.documentsDirectory)
        let folderPath: String
        if relativePath.isEmpty {
            folderPath = folderURL.lastPathComponent
        } else {
            folderPath = relativePath + "/" + folderURL.lastPathComponent
        }

        try await searchIndex.removeDocumentsInFolder(folderPath: folderPath)
        try repository.deleteFolder(at: folderURL)
        await loadDocuments()
    }

    func folderContents(at url: URL) -> DocumentRepository.FolderContents {
        repository.folderContents(at: url)
    }

    func allFolderPaths() -> [(name: String, path: String)] {
        var result: [(name: String, path: String)] = [("Documents", "")]
        collectFolders(at: repository.documentsDirectory, relativePath: "", into: &result)
        return result
    }

    private func collectFolders(at directory: URL, relativePath: String, into result: inout [(name: String, path: String)]) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let folders = urls.filter { url in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { return false }
            // Skip iCloud UUID placeholders and hidden folders
            return UUID(uuidString: url.lastPathComponent) == nil
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        for folder in folders {
            let path = relativePath.isEmpty ? folder.lastPathComponent : relativePath + "/" + folder.lastPathComponent
            result.append((name: folder.lastPathComponent, path: path))
            collectFolders(at: folder, relativePath: path, into: &result)
        }
    }

    // MARK: - Search

    nonisolated private func searchPDFContent(at url: URL, for searchText: String) async -> (snippet: String, pageNumber: Int?)? {
        if let ocrResult = searchOCRContentWithPageInfo(at: url, for: searchText) {
            return (snippet: ocrResult.snippet, pageNumber: ocrResult.pageNumber)
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        if let pdfData = extractPDFData(from: data),
           let pdfDocument = PDFDocument(data: pdfData) {

            let selections = pdfDocument.findString(searchText, withOptions: .caseInsensitive)

            if !selections.isEmpty, let firstMatch = selections.first {
                if let page = firstMatch.pages.first,
                   let pageText = page.string {
                    let snippet = extractSnippet(from: pageText, around: searchText)
                    let pageIndex = pdfDocument.index(for: page)
                    return (snippet: snippet, pageNumber: pageIndex + 1)
                }
            }
        }

        return nil
    }

    nonisolated private func getDocumentsDirectory(from documentURL: URL) -> URL? {
        let pathComponents = documentURL.pathComponents
        if let docsIndex = pathComponents.firstIndex(of: "Documents") {
            let docsPath = "/" + pathComponents[0...docsIndex].dropFirst().joined(separator: "/")
            return URL(fileURLWithPath: docsPath)
        }

        let fileManager = FileManager.default
        var current = documentURL.deletingLastPathComponent()

        while current.path != "/" {
            var isDir: ObjCBool = false
            let ocrPath = current.appendingPathComponent(".ocr_results").path
            if fileManager.fileExists(atPath: ocrPath, isDirectory: &isDir), isDir.boolValue {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent == current { break }
            current = parent
        }

        return documentURL.deletingLastPathComponent()
    }

    nonisolated private func searchOCRContentWithPageInfo(at documentURL: URL, for searchText: String) -> (snippet: String, pageNumber: Int)? {
        guard let documentsDir = getDocumentsDirectory(from: documentURL) else { return nil }
        let docParent = documentURL.deletingLastPathComponent().standardizedFileURL
        let baseComponents = documentsDir.standardizedFileURL.pathComponents
        let parentComponents = docParent.pathComponents

        let trimmedComponents: [String]
        if parentComponents.starts(with: baseComponents) {
            trimmedComponents = Array(parentComponents.dropFirst(baseComponents.count))
        } else {
            trimmedComponents = parentComponents
        }

        let trimmedPath = trimmedComponents.joined(separator: "/")

        let ocrResultsDir = documentsDir
            .appendingPathComponent(".ocr_results")
            .appendingPathComponent(trimmedPath)

        let baseFileName = documentURL.deletingPathExtension().lastPathComponent
        let jsonURL = ocrResultsDir.appendingPathComponent("\(baseFileName).json")

        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            return nil
        }

        do {
            let jsonData = try Data(contentsOf: jsonURL)
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let pages = json["pages"] as? [[String: Any]] {

                for page in pages {
                    if let pageText = page["text"] as? String,
                       let pageNumber = page["pageNumber"] as? Int {
                        if pageText.lowercased().contains(searchText.lowercased()) {
                            let snippet = extractSnippet(from: pageText, around: searchText)
                            return (snippet: snippet, pageNumber: pageNumber)
                        }
                    }
                }
            }
        } catch {
            #if DEBUG
            print("DEBUG: Error reading OCR data: \(error)")
            #endif
        }

        return nil
    }

    nonisolated private func extractPDFData(from data: Data) -> Data? {
        let pdfHeader = "%PDF"
        if let string = String(data: data.prefix(4), encoding: .ascii), string == pdfHeader {
            return data
        }

        if let payload = try? DocumentArchive.read(from: data) {
            return payload.pdfData
        }

        return nil
    }

    nonisolated private func extractSnippet(from text: String, around searchTerm: String, contextLength: Int = 50) -> String {
        let lowercaseText = text.lowercased()
        let lowercaseSearch = searchTerm.lowercased()

        guard let range = lowercaseText.range(of: lowercaseSearch) else {
            return ""
        }

        let startIndex = text.index(range.lowerBound, offsetBy: -contextLength, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: contextLength, limitedBy: text.endIndex) ?? text.endIndex

        var snippet = String(text[startIndex..<endIndex])

        snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "  ", with: " ")

        if startIndex != text.startIndex {
            snippet = "..." + snippet
        }
        if endIndex != text.endIndex {
            snippet = snippet + "..."
        }

        return snippet
    }

    /// Search using FTS5 index (fast path)
    private func searchUsingIndex(query: String) async -> Bool {
        guard !query.isEmpty else {
            return false
        }

        do {
            searchResults = []
            otherFolderResults = []

            let results = try await searchIndex.search(query: query, limit: 100)

            if results.isEmpty {
                documents = []
                folderURLs = []
                searchResults = []
                otherFolderResults = []
                isSearching = true
                return true
            }

            let currentPath = repository.currentFolderPath
            var currentFolderTitleItems: [DocumentListItem] = []
            var currentFolderContentItems: [DocumentListItem] = []
            var otherItems: [(item: DocumentListItem, path: String)] = []
            var newSearchResults: [SearchResult] = []

            for result in results {
                guard FileManager.default.fileExists(atPath: result.url.path) else {
                    continue
                }

                let item = DocumentListItem(searchResult: result)
                let title = result.url.deletingPathExtension().lastPathComponent
                let titleContainsQuery = title.lowercased().contains(query.lowercased())
                let matchType: SearchResult.MatchType = titleContainsQuery ? .both : .content

                newSearchResults.append(SearchResult(
                    documentURL: result.url,
                    matchType: matchType,
                    snippet: result.snippet,
                    pageNumber: nil,
                    searchTerm: query
                ))

                // Partition by folder
                if result.folderPath == currentPath {
                    if titleContainsQuery {
                        currentFolderTitleItems.append(item)
                    } else {
                        currentFolderContentItems.append(item)
                    }
                } else {
                    let displayPath = result.folderPath.isEmpty ? "Documents" : result.folderPath.replacingOccurrences(of: "/", with: " > ")
                    otherItems.append((item: item, path: displayPath))
                }
            }

            searchResults = newSearchResults
            // Title matches first, then content matches
            documents = currentFolderTitleItems + currentFolderContentItems
            isSearching = true

            // Filter folders
            let searchLower = query.lowercased()
            folderURLs = allFolderURLs.filter { url in
                url.lastPathComponent.lowercased().contains(searchLower)
            }

            otherFolderResults = otherItems.sorted { $0.item.title < $1.item.title }

            return true

        } catch {
            #if DEBUG
            print("FTS5 index search failed: \(error), falling back to brute force")
            #endif
            return false
        }
    }

    func filterDocuments(searchText: String) async {
        searchDebounceTask?.cancel()
        searchTask?.cancel()

        currentSearchText = searchText

        if searchText.isEmpty {
            await applyFilter()
            return
        }

        // Cancel observation while searching -- search has its own query path
        observationCancellable?.cancel()
        observationCancellable = nil

        // Bypass debounce in tests
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            await performSearch(searchText: searchText)
            return
        }

        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                searchTask = Task {
                    await performSearch(searchText: searchText)
                }
            } catch {
                // cancelled
            }
        }
    }

    private func performSearch(searchText: String) async {
        guard !Task.isCancelled else { return }

        await MainActor.run {
            isSearchInProgress = true
        }

        await applyFilter()

        await MainActor.run {
            isSearchInProgress = false
        }
    }

    private func applyFilter() async {
        if currentSearchText.isEmpty {
            // No filter -- restart observation for automatic updates
            isSearching = false
            folderURLs = allFolderURLs
            otherFolderResults = []
            searchResults = []
            observeDocuments()
            return
        } else {
            guard !Task.isCancelled else { return }

            // Try FTS5 index first (fast path)
            let usedIndex = await searchUsingIndex(query: currentSearchText)
            if usedIndex { return }

            // Brute-force fallback (should rarely execute)
            let searchLower = currentSearchText.lowercased()
            await MainActor.run {
                isSearching = true
                searchResults = []
            }

            // Load all documents from DB for brute force
            let allRecords: [SearchIndexService.DocumentMetadataRecord]
            do {
                allRecords = try await searchIndex.allDocuments()
            } catch {
                return
            }

            let currentPath = repository.currentFolderPath
            var currentFolderItems: [DocumentListItem] = []
            var otherItems: [(item: DocumentListItem, path: String)] = []
            var newSearchResults: [SearchResult] = []

            for record in allRecords {
                if Task.isCancelled { return }

                let item = DocumentListItem(record: record)
                let titleMatch = item.title.lowercased().contains(searchLower) ||
                    item.url.deletingPathExtension().lastPathComponent.lowercased().contains(searchLower)

                let contentResult = await searchPDFContent(at: item.url, for: currentSearchText)

                if !titleMatch && contentResult == nil { continue }

                let matchType: SearchResult.MatchType
                if titleMatch && contentResult != nil {
                    matchType = .both
                } else if titleMatch {
                    matchType = .title
                } else {
                    matchType = .content
                }

                newSearchResults.append(SearchResult(
                    documentURL: item.url,
                    matchType: matchType,
                    snippet: contentResult?.snippet,
                    pageNumber: contentResult?.pageNumber,
                    searchTerm: currentSearchText
                ))

                if item.folderPath == currentPath {
                    currentFolderItems.append(item)
                } else {
                    let displayPath = item.folderPath.isEmpty ? "Documents" : item.folderPath.replacingOccurrences(of: "/", with: " > ")
                    otherItems.append((item: item, path: displayPath))
                }
            }

            if Task.isCancelled { return }

            await MainActor.run {
                searchResults = newSearchResults
                documents = currentFolderItems
                folderURLs = allFolderURLs.filter { $0.lastPathComponent.lowercased().contains(searchLower) }
                otherFolderResults = otherItems.sorted { $0.item.title < $1.item.title }
            }
        }
    }
}
