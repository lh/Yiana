//
//  BulkImportService.swift
//  Yiana
//
//  Service for importing multiple PDF files at once
//

import Foundation
import PDFKit
import Combine
import CryptoKit
import YianaDocumentArchive

enum BulkImportError: LocalizedError {
    case timedOut(URL)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .timedOut(let url):
            return "Import timed out for \(url.lastPathComponent)"
        case .cancelled:
            return "Import was cancelled"
        }
    }
}

struct BulkImportResult {
    let successful: [ImportResult]
    let failed: [(url: URL, error: Error)]
    let timedOut: [URL]
    let skippedDuplicates: [(url: URL, existingURL: URL)]

    var totalProcessed: Int {
        successful.count + failed.count + timedOut.count
    }

    var totalSkipped: Int {
        skippedDuplicates.count
    }

    var successRate: Double {
        guard totalProcessed > 0 else { return 0 }
        return Double(successful.count) / Double(totalProcessed)
    }

    var hasTimedOutFiles: Bool {
        !timedOut.isEmpty
    }

    var hasDuplicates: Bool {
        !skippedDuplicates.isEmpty
    }
}

enum ImportPhase {
    case preparing
    case indexingLibrary(current: Int, total: Int)
    case importing(current: Int, total: Int, file: String)
    case takingBreather
    case finishing

    var description: String {
        switch self {
        case .preparing:
            return "Warming up..."
        case .indexingLibrary(let current, let total):
            return "Checking library (\(current)/\(total))..."
        case .importing(let current, let total, let file):
            let shortName = file.count > 30 ? String(file.prefix(27)) + "..." : file
            return "Importing \(current) of \(total): \(shortName)"
        case .takingBreather:
            return "Brief pause..."
        case .finishing:
            return "Wrapping up..."
        }
    }

    var funMessage: String? {
        switch self {
        case .preparing:
            return "Brewing..."
        case .indexingLibrary:
            return "Memorizing your library..."
        case .takingBreather:
            return "Catching breath..."
        case .finishing:
            return "Almost there..."
        default:
            return nil
        }
    }
}

struct BulkImportProgress {
    let phase: ImportPhase
    let currentIndex: Int
    let totalFiles: Int
    let progress: Double

    var progressDescription: String {
        phase.description
    }

    var funDescription: String? {
        phase.funMessage
    }
}

class BulkImportService: ObservableObject {
    @Published var isProcessing = false
    @Published var currentProgress: BulkImportProgress?

    private let folderPath: String
    private let importService: ImportService
    private let progressSubject = PassthroughSubject<BulkImportProgress, Never>()

    /// Timeout for individual file imports (30 seconds)
    private let importTimeout: UInt64 = 30_000_000_000

    /// How often to take a breather (every N files)
    private let breatherInterval = 25

    /// How long to pause during breather (milliseconds)
    private let breatherDurationMs: UInt64 = 500

    /// Cache of existing document hashes (hash -> URL)
    private var existingHashCache: [String: URL] = [:]

    init(folderPath: String = "") {
        self.folderPath = folderPath
        self.importService = ImportService(folderPath: folderPath)
    }

    /// Compute SHA256 hash of data
    private func computeDataHash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Pre-scan all existing documents and cache their hashes
    private func buildHashCache() async {
        let repository = DocumentRepository()
        if !folderPath.isEmpty {
            repository.navigateToFolder(folderPath)
        }

        let existingDocs = repository.documentURLs()

        for (index, docURL) in existingDocs.enumerated() {
            // Update progress
            let progress = BulkImportProgress(
                phase: .indexingLibrary(current: index + 1, total: existingDocs.count),
                currentIndex: index + 1,
                totalFiles: existingDocs.count,
                progress: Double(index + 1) / Double(existingDocs.count)
            )
            await MainActor.run {
                self.currentProgress = progress
                self.progressSubject.send(progress)
            }

            // Extract and cache the hash
            autoreleasepool {
                if let payload = try? DocumentArchive.read(from: docURL),
                   let pdfData = payload.pdfData {
                    let hash = computeDataHash(pdfData)
                    existingHashCache[hash] = docURL
                }
            }

            // Small yield every 50 to keep UI responsive
            if index % 50 == 0 {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }

    /// Check if a hash already exists in the cache
    /// Returns the existing document URL if duplicate, nil otherwise
    private func existingDocument(forHash hash: String) -> URL? {
        return existingHashCache[hash]
    }

    /// Add a newly imported document to the cache using pre-computed hash
    private func addToCache(url: URL, hash: String) {
        existingHashCache[hash] = url
    }

    var progressPublisher: AnyPublisher<BulkImportProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    /// Import a single PDF with timeout protection
    private func importWithTimeout(
        url: URL,
        title: String
    ) async throws -> ImportResult {
        try await withThrowingTaskGroup(of: ImportResult.self) { group in
            // Task 1: The actual import
            group.addTask {
                try self.importService.importPDF(
                    from: url,
                    mode: .createNew(title: title)
                )
            }

            // Task 2: Timeout watchdog
            group.addTask {
                try await Task.sleep(nanoseconds: self.importTimeout)
                throw BulkImportError.timedOut(url)
            }

            // Return first result (success or timeout), cancel the other
            guard let result = try await group.next() else {
                throw BulkImportError.cancelled
            }
            group.cancelAll()
            return result
        }
    }

    /// Import multiple PDF files, creating a new document for each
    func importPDFs(
        from urls: [URL],
        withTitles titles: [String]? = nil
    ) async -> BulkImportResult {
        guard !urls.isEmpty else {
            return BulkImportResult(successful: [], failed: [], timedOut: [], skippedDuplicates: [])
        }

        await MainActor.run {
            isProcessing = true
        }

        // Phase 1: Prepare - show we're starting
        let prepProgress = BulkImportProgress(
            phase: .preparing,
            currentIndex: 0,
            totalFiles: urls.count,
            progress: 0
        )
        await MainActor.run {
            self.currentProgress = prepProgress
            self.progressSubject.send(prepProgress)
        }

        // Phase 2: Build hash cache for duplicate detection
        existingHashCache.removeAll()
        await buildHashCache()

        var successful: [ImportResult] = []
        var failed: [(URL, Error)] = []
        var timedOut: [URL] = []
        var skippedDuplicates: [(url: URL, existingURL: URL)] = []

        // Phase 3: Import files
        for (index, url) in urls.enumerated() {
            // Take a brief breather every N files
            if index > 0 && index % breatherInterval == 0 {
                let breatherProgress = BulkImportProgress(
                    phase: .takingBreather,
                    currentIndex: index,
                    totalFiles: urls.count,
                    progress: Double(index) / Double(urls.count)
                )
                await MainActor.run {
                    self.currentProgress = breatherProgress
                    self.progressSubject.send(breatherProgress)
                }
                try? await Task.sleep(nanoseconds: breatherDurationMs * 1_000_000)
            }

            // Determine title
            let title: String
            if let titles = titles, index < titles.count {
                title = titles[index]
            } else {
                title = url.deletingPathExtension().lastPathComponent
            }

            // Update progress
            let progress = BulkImportProgress(
                phase: .importing(current: index + 1, total: urls.count, file: url.lastPathComponent),
                currentIndex: index + 1,
                totalFiles: urls.count,
                progress: Double(index + 1) / Double(urls.count)
            )

            await MainActor.run {
                self.currentProgress = progress
                self.progressSubject.send(progress)
            }

            // Read PDF data and compute hash ONCE for this file
            guard let pdfData = try? Data(contentsOf: url) else {
                failed.append((url, NSError(domain: "BulkImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not read file"])))
                continue
            }
            let pdfHash = computeDataHash(pdfData)

            // Check for duplicates using pre-computed hash (O(1) lookup)
            if let existingURL = existingDocument(forHash: pdfHash) {
                skippedDuplicates.append((url: url, existingURL: existingURL))
                print("Skipped duplicate: \(url.lastPathComponent)")
                continue
            }

            // Import the PDF with timeout protection
            do {
                let result = try await importWithTimeout(url: url, title: title)
                successful.append(result)

                // Add to cache using pre-computed hash (no re-read needed)
                addToCache(url: result.url, hash: pdfHash)

                // Clean up temporary file if it's in the temp directory
                if url.path.contains(NSTemporaryDirectory()) {
                    try? FileManager.default.removeItem(at: url)
                }
            } catch let error as BulkImportError {
                // Handle timeout separately for better reporting
                if case .timedOut = error {
                    timedOut.append(url)
                    print("Import timed out for: \(url.lastPathComponent)")
                } else {
                    failed.append((url, error))
                }
            } catch {
                failed.append((url, error))
            }

            // Small yield every 10 files to keep things smooth
            if index % 10 == 0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        // Phase 4: Finishing up
        let finishProgress = BulkImportProgress(
            phase: .finishing,
            currentIndex: urls.count,
            totalFiles: urls.count,
            progress: 1.0
        )
        await MainActor.run {
            self.currentProgress = finishProgress
            self.progressSubject.send(finishProgress)
        }

        await MainActor.run {
            isProcessing = false
            currentProgress = nil
        }

        // Notify that documents have changed
        await MainActor.run {
            NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
        }

        // Log summary
        if !skippedDuplicates.isEmpty {
            print("⏭️ \(skippedDuplicates.count) duplicate files skipped")
        }
        if !timedOut.isEmpty {
            print("⚠️ \(timedOut.count) files timed out during import")
        }

        return BulkImportResult(successful: successful, failed: failed, timedOut: timedOut, skippedDuplicates: skippedDuplicates)
    }

    /// Validate that all URLs are valid PDFs before importing
    func validatePDFs(_ urls: [URL]) -> [(url: URL, isValid: Bool, error: String?)] {
        return urls.map { url in
            do {
                let data = try Data(contentsOf: url)
                if PDFDocument(data: data) != nil {
                    return (url, true, nil)
                } else {
                    return (url, false, "Not a valid PDF file")
                }
            } catch {
                return (url, false, error.localizedDescription)
            }
        }
    }

    /// Generate suggested titles from file names
    func suggestedTitles(for urls: [URL]) -> [String] {
        return urls.map { url in
            let filename = url.deletingPathExtension().lastPathComponent

            // Clean up common patterns in filenames
            var title = filename

            // Remove UUID patterns (8-4-4-4-12 hexadecimal)
            let uuidPattern = #"[A-Fa-f0-9]{8}[-_]?[A-Fa-f0-9]{4}[-_]?[A-Fa-f0-9]{4}[-_]?[A-Fa-f0-9]{4}[-_]?[A-Fa-f0-9]{12}"#
            if let regex = try? NSRegularExpression(pattern: uuidPattern) {
                let range = NSRange(location: 0, length: title.utf16.count)
                title = regex.stringByReplacingMatches(
                    in: title,
                    range: range,
                    withTemplate: ""
                )
            }

            // Remove timestamp prefixes (e.g., "1735123456789_")
            let timestampPattern = #"^\d{10,13}[_-]"#
            if let regex = try? NSRegularExpression(pattern: timestampPattern) {
                let range = NSRange(location: 0, length: title.utf16.count)
                title = regex.stringByReplacingMatches(
                    in: title,
                    range: range,
                    withTemplate: ""
                )
            }

            // Don't mess with underscores and hyphens - keep them as-is!
            // Users want their filenames preserved exactly

            // Remove date patterns like 2024-01-15 or 20240115
            let datePatterns = [
                #"^\d{4}-\d{2}-\d{2}\s*"#,
                #"^\d{8}\s*"#,
                #"\s*\d{4}-\d{2}-\d{2}$"#,
                #"\s*\d{8}$"#
            ]

            for pattern in datePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let range = NSRange(location: 0, length: title.utf16.count)
                    title = regex.stringByReplacingMatches(
                        in: title,
                        range: range,
                        withTemplate: ""
                    )
                }
            }

            // Clean up multiple spaces
            title = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

            // Just trim whitespace - don't mess with capitalization either!
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)

            return title.isEmpty ? filename : title
        }
    }
}
