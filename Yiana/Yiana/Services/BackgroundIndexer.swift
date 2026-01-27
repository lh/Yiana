//
//  BackgroundIndexer.swift
//  Yiana
//
//  Background service to index documents on app launch
//

import Foundation
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

    private init() {}

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

    private func performIndexing() async {
        isIndexing = true
        indexedCount = 0
        totalCount = 0
        indexProgress = 0.0

        print("🔍 Starting background document indexing...")

        // Move heavy file I/O off the main actor to avoid blocking UI
        let documentsToIndex: [(url: URL, metadata: DocumentMetadata)] = await Task.detached(priority: .utility) {
            // Get all documents recursively (file system scan)
            let repository = DocumentRepository()
            let allDocuments = repository.allDocumentsRecursive()

            // Check which documents are already indexed
            var needsIndexing: [(url: URL, metadata: DocumentMetadata)] = []

            for item in allDocuments {
                // Check if task was cancelled
                if Task.isCancelled { return [] }

                // Extract metadata directly using DocumentArchive (not MainActor-isolated)
                guard let (metadataData, _) = try? DocumentArchive.readMetadata(from: item.url),
                      let metadata = try? JSONDecoder().decode(DocumentMetadata.self, from: metadataData) else {
                    continue
                }

                // Check if already indexed
                let isIndexed = (try? await self.searchIndex.isDocumentIndexed(id: metadata.id)) ?? false

                if !isIndexed {
                    needsIndexing.append((url: item.url, metadata: metadata))
                }
            }

            return needsIndexing
        }.value

        // Check if cancelled during file scan
        if Task.isCancelled {
            print("⚠️ Indexing cancelled by user")
            isIndexing = false
            return
        }

        totalCount = documentsToIndex.count
        print("📝 \(documentsToIndex.count) documents need indexing")

        // Index documents in batches to avoid overwhelming the system
        let batchSize = 10
        var corruptionDetected = false

        for (index, item) in documentsToIndex.enumerated() {
            // Check if task was cancelled
            if Task.isCancelled {
                print("⚠️ Indexing cancelled by user")
                isIndexing = false
                return
            }

            // Use fullText from metadata (already embedded in .yianazip file)
            let fullText = item.metadata.fullText ?? ""

            // Index the document
            do {
                try await searchIndex.indexDocument(
                    id: item.metadata.id,
                    url: item.url,
                    title: item.metadata.title,
                    fullText: fullText,
                    tags: item.metadata.tags,
                    metadata: item.metadata
                )

                indexedCount += 1
                indexProgress = Double(indexedCount) / Double(documentsToIndex.count)

                if indexedCount % 10 == 0 {
                    print("✓ Indexed \(indexedCount)/\(documentsToIndex.count) documents")
                }
            } catch {
                let errorString = String(describing: error)
                if errorString.contains("index corruption") || errorString.contains("database disk image is malformed") {
                    print("🔴 Database corruption detected!")
                    corruptionDetected = true
                    break
                }
                print("⚠️ Failed to index \(item.metadata.title): \(error)")
            }

            // Small delay every batch to avoid blocking main thread
            if (index + 1) % batchSize == 0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }

        // Handle database corruption
        if corruptionDetected {
            print("🔧 Attempting to recover from database corruption...")
            if (try? await searchIndex.resetDatabase()) != nil {
                print("✓ Database reset successful - restarting indexing")
                indexAllDocuments()
                return
            } else {
                print("❌ Failed to reset database")
            }
        }

        // Optimize the index after bulk indexing
        if documentsToIndex.count > 0 {
            print("🔧 Optimizing search index...")
            try? await searchIndex.optimize()
        }

        print("✅ Background indexing complete: \(indexedCount) documents indexed")

        isIndexing = false
        indexProgress = 1.0
    }

}
