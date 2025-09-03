//
//  BulkImportService.swift
//  Yiana
//
//  Service for importing multiple PDF files at once
//

import Foundation
import PDFKit
import Combine

struct BulkImportResult {
    let successful: [ImportResult]
    let failed: [(url: URL, error: Error)]
    
    var totalProcessed: Int {
        successful.count + failed.count
    }
    
    var successRate: Double {
        guard totalProcessed > 0 else { return 0 }
        return Double(successful.count) / Double(totalProcessed)
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
    
    init(folderPath: String = "") {
        self.folderPath = folderPath
        self.importService = ImportService(folderPath: folderPath)
    }
    
    var progressPublisher: AnyPublisher<BulkImportProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    /// Import multiple PDF files, creating a new document for each
    func importPDFs(
        from urls: [URL],
        withTitles titles: [String]? = nil
    ) async -> BulkImportResult {
        guard !urls.isEmpty else {
            return BulkImportResult(successful: [], failed: [])
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        var successful: [ImportResult] = []
        var failed: [(URL, Error)] = []
        
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
                }
                progressSubject.send(progress)
                
                // Import the PDF
                do {
                    let result = try importService.importPDF(
                        from: url,
                        mode: .createNew(title: title)
                    )
                    successful.append(result)
                    
                    // Clean up temporary file if it's in the temp directory
                    if url.path.contains(NSTemporaryDirectory()) {
                        try? FileManager.default.removeItem(at: url)
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
        NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
        
        return BulkImportResult(successful: successful, failed: failed)
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
            
            // Replace underscores and hyphens with spaces
            title = title
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            
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
            
            // Capitalize appropriately
            title = title
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return title.isEmpty ? filename : title
        }
    }
}