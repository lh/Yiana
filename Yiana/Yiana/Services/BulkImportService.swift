//
//  BulkImportService.swift
//  Yiana
//
//  Service for importing multiple PDF files at once
//

import Foundation
import PDFKit
import Combine

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

    var totalProcessed: Int {
        successful.count + failed.count + timedOut.count
    }

    var successRate: Double {
        guard totalProcessed > 0 else { return 0 }
        return Double(successful.count) / Double(totalProcessed)
    }

    var hasTimedOutFiles: Bool {
        !timedOut.isEmpty
    }
}

struct BulkImportProgress {
    let currentFile: String
    let currentIndex: Int
    let totalFiles: Int
    let progress: Double

    var progressDescription: String {
        "Processing \(currentIndex) of \(totalFiles): \(currentFile)"
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

    init(folderPath: String = "") {
        self.folderPath = folderPath
        self.importService = ImportService(folderPath: folderPath)
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
            return BulkImportResult(successful: [], failed: [], timedOut: [])
        }

        await MainActor.run {
            isProcessing = true
        }

        var successful: [ImportResult] = []
        var failed: [(URL, Error)] = []
        var timedOut: [URL] = []

        // Process in batches for better performance with large numbers
        let batchSize = 10
        let batches = stride(from: 0, to: urls.count, by: batchSize).map {
            Array(urls[$0..<min($0 + batchSize, urls.count)])
        }

        for (batchIndex, batch) in batches.enumerated() {
            for (indexInBatch, url) in batch.enumerated() {
                let index = batchIndex * batchSize + indexInBatch

                // Determine title
                let title: String
                if let titles = titles, index < titles.count {
                    title = titles[index]
                } else {
                    title = url.deletingPathExtension().lastPathComponent
                }

                // Update progress
                let progress = BulkImportProgress(
                    currentFile: url.lastPathComponent,
                    currentIndex: index + 1,
                    totalFiles: urls.count,
                    progress: Double(index + 1) / Double(urls.count)
                )

                await MainActor.run {
                    self.currentProgress = progress
                    self.progressSubject.send(progress)
                }

                // Import the PDF with timeout protection
                do {
                    let result = try await importWithTimeout(url: url, title: title)
                    successful.append(result)

                    // Clean up temporary file if it's in the temp directory
                    if url.path.contains(NSTemporaryDirectory()) {
                        try? FileManager.default.removeItem(at: url)
                    }
                } catch let error as BulkImportError {
                    // Handle timeout separately for better reporting
                    if case .timedOut = error {
                        timedOut.append(url)
                        print("⚠️ Import timed out for: \(url.lastPathComponent)")
                    } else {
                        failed.append((url, error))
                    }
                } catch {
                    failed.append((url, error))
                }
            }

            // Small delay between batches to prevent overwhelming the system
            if batchIndex < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds between batches
            }
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
        if !timedOut.isEmpty {
            print("⚠️ \(timedOut.count) files timed out during import")
        }

        return BulkImportResult(successful: successful, failed: failed, timedOut: timedOut)
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
