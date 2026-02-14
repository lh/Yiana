//
//  ExportService.swift
//  Yiana
//
//  Service for exporting Yiana documents back to PDF files
//

import Foundation
import PDFKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import YianaDocumentArchive

enum ExportError: LocalizedError {
    case noPDFData
    case writeFailed
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .noPDFData:
            return "No PDF data found in document"
        case .writeFailed:
            return "Failed to write PDF file"
        case .invalidDocument:
            return "Invalid document format"
        }
    }
}

class ExportService {
    /// Export a single Yiana document to PDF
    func exportToPDF(from documentURL: URL, to destinationURL: URL) throws {
        let payload: DocumentArchivePayload
        do {
            payload = try DocumentArchive.read(from: documentURL)
        } catch {
            throw ExportError.invalidDocument
        }
        guard let pdfData = payload.pdfData, !pdfData.isEmpty else {
            throw ExportError.noPDFData
        }
        guard PDFDocument(data: pdfData) != nil else {
            throw ExportError.invalidDocument
        }

        do {
            try pdfData.write(to: destinationURL)
        } catch {
            throw ExportError.writeFailed
        }
    }

    /// Export multiple documents to a folder
    func exportMultipleToPDF(from documentURLs: [URL], to folderURL: URL, progressHandler: ((Double) -> Void)? = nil) -> (successful: [URL], failed: [(url: URL, error: Error)]) {
        var successful: [URL] = []
        var failed: [(url: URL, error: Error)] = []

        for (index, documentURL) in documentURLs.enumerated() {
            let fileName = documentURL.deletingPathExtension().lastPathComponent + ".pdf"
            let destinationURL = folderURL.appendingPathComponent(fileName)

            do {
                try exportToPDF(from: documentURL, to: destinationURL)
                successful.append(destinationURL)
            } catch {
                failed.append((documentURL, error))
            }

            // Report progress
            let progress = Double(index + 1) / Double(documentURLs.count)
            progressHandler?(progress)
        }

        return (successful, failed)
    }

    // MARK: - Bulk Export with Directory Structure

    /// Result of a bulk export operation
    struct BulkExportResult {
        let successfulCount: Int
        let failedItems: [(relativePath: String, fileName: String, error: Error)]
        let destinationFolder: URL
    }

    /// Export documents preserving their directory structure
    /// - Parameters:
    ///   - documents: Array of (documentURL, relativePath) tuples from DocumentRepository
    ///   - destinationFolder: Root folder for exported PDFs
    ///   - progressHandler: Called with (currentIndex, totalCount, currentFileName)
    /// - Returns: BulkExportResult with success count and any failures
    func exportWithStructure(
        documents: [(url: URL, relativePath: String)],
        to destinationFolder: URL,
        progressHandler: ((Int, Int, String) -> Void)? = nil
    ) -> BulkExportResult {
        var successCount = 0
        var failures: [(relativePath: String, fileName: String, error: Error)] = []
        let fileManager = FileManager.default

        for (index, document) in documents.enumerated() {
            let fileName = document.url.deletingPathExtension().lastPathComponent
            progressHandler?(index, documents.count, fileName)

            // Build destination path preserving structure
            var targetFolder = destinationFolder
            if !document.relativePath.isEmpty {
                targetFolder = destinationFolder.appendingPathComponent(document.relativePath)
            }

            // Create subdirectories if needed
            do {
                try fileManager.createDirectory(at: targetFolder, withIntermediateDirectories: true)
            } catch {
                failures.append((document.relativePath, fileName, error))
                continue
            }

            // Determine final filename, handling conflicts
            let pdfFileName = availableFileName(
                baseName: fileName,
                extension: "pdf",
                in: targetFolder
            )
            let destinationURL = targetFolder.appendingPathComponent(pdfFileName)

            // Export the PDF
            do {
                try exportToPDF(from: document.url, to: destinationURL)
                successCount += 1
            } catch {
                failures.append((document.relativePath, fileName, error))
            }
        }

        // Final progress update
        progressHandler?(documents.count, documents.count, "")

        return BulkExportResult(
            successfulCount: successCount,
            failedItems: failures,
            destinationFolder: destinationFolder
        )
    }

    /// Find an available filename, appending " 2", " 3" etc. if file exists
    private func availableFileName(baseName: String, extension ext: String, in folder: URL) -> String {
        let fileManager = FileManager.default
        var candidate = "\(baseName).\(ext)"
        var url = folder.appendingPathComponent(candidate)

        if !fileManager.fileExists(atPath: url.path) {
            return candidate
        }

        // File exists, find next available number
        var counter = 2
        while fileManager.fileExists(atPath: url.path) {
            candidate = "\(baseName) \(counter).\(ext)"
            url = folder.appendingPathComponent(candidate)
            counter += 1
        }

        return candidate
    }

    // MARK: - Utilities

    /// Get suggested filename for export
    func suggestedFileName(for documentURL: URL) -> String {
        // Use the document name without extension
        let baseName = documentURL.deletingPathExtension().lastPathComponent
        return "\(baseName).pdf"
    }

    /// Create a temporary URL for sharing or drag export
    func createTemporaryPDF(from documentURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = suggestedFileName(for: documentURL)
        let tempURL = tempDir.appendingPathComponent(fileName)

        try exportToPDF(from: documentURL, to: tempURL)
        return tempURL
    }
}
