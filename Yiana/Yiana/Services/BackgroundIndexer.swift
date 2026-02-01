//
//  BackgroundIndexer.swift
//  Yiana
//
//  Background service to index documents on app launch
//

import Foundation
import CryptoKit
import YianaDocumentArchive

/// Service that indexes all documents in the background on app launch
@MainActor
class BackgroundIndexer: ObservableObject {
    static let shared = BackgroundIndexer()

    @Published var isIndexing = false
    @Published var indexProgress: Double = 0.0
    @Published var indexedCount = 0
    @Published var totalCount = 0

    private let searchIndex = SearchIndexService.shared
    private var indexingTask: Task<Void, Never>?
    private var downloadObserver: NSObjectProtocol?

    private init() {
        downloadObserver = NotificationCenter.default.addObserver(
            forName: .yianaDocumentsDownloaded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let urls = notification.userInfo?["urls"] as? [URL] else { return }
            Task { @MainActor [weak self] in
                await self?.reindexDownloadedDocuments(urls: urls)
            }
        }
    }

    deinit {
        if let downloadObserver {
            NotificationCenter.default.removeObserver(downloadObserver)
        }
    }

    /// Start background indexing of all documents
    func indexAllDocuments() {
        // Don't start if already indexing
        guard !isIndexing else { return }

        indexingTask?.cancel()
        indexingTask = Task { @MainActor in
            await performIndexing()
        }
    }

    /// Cancel ongoing indexing
    func cancelIndexing() {
        indexingTask?.cancel()
        indexingTask = nil
        isIndexing = false
    }

    /// Re-index documents that have finished downloading from iCloud.
    /// File I/O (readMetadata) runs off the main thread to avoid blocking the UI.
    func reindexDownloadedDocuments(urls: [URL]) async {
        let searchIndex = self.searchIndex

        // Skip files already fully indexed — avoids redundant reads
        // during bulk transitions (e.g. initial gather reports all as "downloaded")
        var urlsToProcess: [URL] = []
        for url in urls {
            let fullyIndexed = (try? await searchIndex.isDocumentFullyIndexed(path: url.path)) ?? false
            if !fullyIndexed {
                urlsToProcess.append(url)
            }
        }

        guard !urlsToProcess.isEmpty else { return }

        #if DEBUG
        if urlsToProcess.count != urls.count {
            print("reindexDownloadedDocuments: \(urls.count) URLs, \(urlsToProcess.count) need reindexing")
        }
        #endif

        // Read all file metadata off the main thread
        let results = await Task.detached(priority: .utility) {
            let repository = DocumentRepository()
            var items: [(url: URL, metadata: DocumentMetadata, folderPath: String, fileSize: Int64)] = []

            for (index, url) in urlsToProcess.enumerated() {
                guard let (metadataData, _) = try? DocumentArchive.readMetadata(from: url),
                      let metadata = try? JSONDecoder().decode(DocumentMetadata.self, from: metadataData) else {
                    continue
                }
                let folderPath = url.relativeFolderPath(relativeTo: repository.documentsDirectory)
                let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                items.append((url: url, metadata: metadata, folderPath: folderPath, fileSize: fileSize))

                // Throttle file access to avoid exhausting sandbox extensions
                if (index + 1) % 10 == 0 {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms breather
                }
            }
            return items
        }.value

        // DB writes (lightweight, no file I/O) happen back on MainActor
        var reindexedCount = 0
        for item in results {
            do {
                try await searchIndex.indexDocument(
                    id: item.metadata.id,
                    url: item.url,
                    title: item.metadata.title,
                    fullText: item.metadata.fullText ?? "",
                    tags: item.metadata.tags,
                    metadata: item.metadata,
                    folderPath: item.folderPath,
                    fileSize: item.fileSize
                )
                reindexedCount += 1
            } catch {
                print("Failed to reindex downloaded document \(item.url.lastPathComponent): \(error)")
            }
        }

        if reindexedCount > 0 {
            #if DEBUG
            print("Re-indexed \(reindexedCount) downloaded documents")
            #endif
        }
    }

    private func performIndexing() async {
        isIndexing = true
        indexedCount = 0
        totalCount = 0
        indexProgress = 0.0

        #if DEBUG
        SyncPerfLog.shared.start()
        #endif
        print("Starting background document indexing...")

        // Move heavy file I/O off the main actor to avoid blocking UI
        let scanResult: (toIndex: [(url: URL, metadata: DocumentMetadata, folderPath: String, fileSize: Int64)], allPaths: Set<String>, placeholders: [(url: URL, folderPath: String)], ocrUpdates: [(url: URL, metadata: DocumentMetadata, folderPath: String, fileSize: Int64)]) = await Task.detached(priority: .utility) {
            // Get all documents recursively (file system scan)
            let repository = DocumentRepository()
            let allDocuments = repository.allDocumentsRecursive()

            // Collect all valid paths for stale pruning
            var allPaths = Set<String>()
            var needsIndexing: [(url: URL, metadata: DocumentMetadata, folderPath: String, fileSize: Int64)] = []
            var ocrUpdates: [(url: URL, metadata: DocumentMetadata, folderPath: String, fileSize: Int64)] = []
            var placeholders: [(url: URL, folderPath: String)] = []

            for item in allDocuments {
                if Task.isCancelled { return ([], Set<String>(), [], []) }

                allPaths.insert(item.url.path)

                // Skip files already fully indexed (with OCR complete) — avoids
                // opening iCloud files and exhausting sandbox extensions.
                // Documents with pending OCR are re-read in case the OCR service
                // has since updated the file.
                let fullyIndexed = (try? await self.searchIndex.isDocumentFullyIndexed(path: item.url.path)) ?? false
                if fullyIndexed { continue }

                // Skip iCloud placeholders — don't trigger on-demand downloads.
                // Both .current and .downloaded mean local data is available;
                // only .notDownloaded is a true placeholder.
                let resourceValues = try? item.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                let downloadStatus = resourceValues?.ubiquitousItemDownloadingStatus
                if downloadStatus == .notDownloaded {
                    placeholders.append((url: item.url, folderPath: item.relativePath))
                    continue
                }

                // Not indexed — need to read metadata
                guard let (metadataData, _) = try? DocumentArchive.readMetadata(from: item.url),
                      let metadata = try? JSONDecoder().decode(DocumentMetadata.self, from: metadataData) else {
                    // File exists but can't be read — likely an iCloud placeholder
                    placeholders.append((url: item.url, folderPath: item.relativePath))
                    continue
                }

                let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: item.url.path)[.size] as? Int64) ?? 0

                // If this document was indexed without OCR but now has it,
                // index it immediately so the UI updates right away
                if metadata.ocrCompleted {
                    let wasIndexedWithoutOCR = (try? await self.searchIndex.isDocumentIndexedByURL(path: item.url.path)) ?? false
                    if wasIndexedWithoutOCR {
                        ocrUpdates.append((url: item.url, metadata: metadata, folderPath: item.relativePath, fileSize: fileSize))
                        continue
                    }
                }

                needsIndexing.append((url: item.url, metadata: metadata, folderPath: item.relativePath, fileSize: fileSize))
            }

            return (needsIndexing, allPaths, placeholders, ocrUpdates)
        }.value

        // Check if cancelled during file scan
        if Task.isCancelled {
            isIndexing = false
            return
        }

        // Fast-track: immediately re-index documents whose OCR status changed
        // since last index, so stripes update without waiting for the full batch
        if !scanResult.ocrUpdates.isEmpty {
            for item in scanResult.ocrUpdates {
                do {
                    try await searchIndex.indexDocument(
                        id: item.metadata.id,
                        url: item.url,
                        title: item.metadata.title,
                        fullText: item.metadata.fullText ?? "",
                        tags: item.metadata.tags,
                        metadata: item.metadata,
                        folderPath: item.folderPath,
                        fileSize: item.fileSize
                    )
                } catch {
                    print("Failed to fast-track OCR update for \(item.url.lastPathComponent): \(error)")
                }
            }
            #if DEBUG
            print("[Indexer] Fast-tracked \(scanResult.ocrUpdates.count) OCR-updated documents")
            #endif
        }

        // Index placeholders in chunks so the main thread stays responsive
        if !scanResult.placeholders.isEmpty {
            let allPlaceholders = scanResult.placeholders.map { placeholder in
                (
                    id: UUID(stableFromPath: placeholder.url.path),
                    url: placeholder.url,
                    title: placeholder.url.deletingPathExtension().lastPathComponent,
                    folderPath: placeholder.folderPath
                )
            }
            let chunkSize = 200
            var totalInserted = 0
            for chunkStart in stride(from: 0, to: allPlaceholders.count, by: chunkSize) {
                if Task.isCancelled { break }
                let chunkEnd = min(chunkStart + chunkSize, allPlaceholders.count)
                let chunk = Array(allPlaceholders[chunkStart..<chunkEnd])
                do {
                    let inserted = try await searchIndex.indexPlaceholdersBatch(chunk)
                    totalInserted += inserted
                } catch {
                    print("Failed to batch-index placeholder chunk: \(error)")
                }
                await Task.yield()
            }
            #if DEBUG
            SyncPerfLog.shared.countPlaceholderBatch()
            print("Batch-indexed \(totalInserted) placeholder documents (of \(scanResult.placeholders.count) candidates)")
            #endif
        }

        let documentsToIndex = scanResult.toIndex
        totalCount = documentsToIndex.count
        print("\(documentsToIndex.count) documents need indexing")

        // Index documents in batches to avoid overwhelming the system
        let batchSize = 10
        var corruptionDetected = false

        for (index, item) in documentsToIndex.enumerated() {
            if Task.isCancelled {
                isIndexing = false
                return
            }

            // Use fullText from metadata (already embedded in .yianazip file)
            let fullText = item.metadata.fullText ?? ""

            do {
                try await searchIndex.indexDocument(
                    id: item.metadata.id,
                    url: item.url,
                    title: item.metadata.title,
                    fullText: fullText,
                    tags: item.metadata.tags,
                    metadata: item.metadata,
                    folderPath: item.folderPath,
                    fileSize: item.fileSize
                )

                indexedCount += 1
                indexProgress = Double(indexedCount) / Double(documentsToIndex.count)

                if indexedCount % 10 == 0 {
                    print("Indexed \(indexedCount)/\(documentsToIndex.count) documents")
                }
            } catch {
                let errorString = String(describing: error)
                if errorString.contains("index corruption") || errorString.contains("database disk image is malformed") {
                    print("Database corruption detected!")
                    corruptionDetected = true
                    break
                }
                print("Failed to index \(item.metadata.title): \(error)")
            }

            // Small delay every batch to avoid blocking main thread
            if (index + 1) % batchSize == 0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }

        // Handle database corruption
        if corruptionDetected {
            print("Attempting to recover from database corruption...")
            if (try? await searchIndex.resetDatabase()) != nil {
                print("Database reset successful - restarting indexing")
                indexAllDocuments()
                return
            } else {
                print("Failed to reset database")
            }
        }

        // Prune stale documents that no longer exist on disk
        if !scanResult.allPaths.isEmpty {
            do {
                try await searchIndex.removeStaleDocuments(validPaths: scanResult.allPaths)
            } catch {
                print("Failed to prune stale documents: \(error)")
            }
        }

        // Optimize the index after bulk indexing
        if documentsToIndex.count > 0 {
            print("Optimizing search index...")
            try? await searchIndex.optimize()
        }

        print("Background indexing complete: \(indexedCount) documents indexed")

        #if DEBUG
        SyncPerfLog.shared.stop()
        #endif

        isIndexing = false
        indexProgress = 1.0
    }

}

extension UUID {
    /// Create a deterministic UUID from a file path using SHA256
    init(stableFromPath path: String) {
        let hash = SHA256.hash(data: Data(path.utf8))
        var bytes = Array(hash.prefix(16))
        // Set version 5 (name-based SHA) and variant bits
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
