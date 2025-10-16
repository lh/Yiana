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

    /// Get suggested filename for export
    func suggestedFileName(for documentURL: URL) -> String {
        // Use the document name without extension
        let baseName = documentURL.deletingPathExtension().lastPathComponent
        return "\(baseName).pdf"
    }

    #if os(iOS)
    /// Create a temporary URL for sharing
    func createTemporaryPDF(from documentURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = suggestedFileName(for: documentURL)
        let tempURL = tempDir.appendingPathComponent(fileName)

        try exportToPDF(from: documentURL, to: tempURL)
        return tempURL
    }
    #endif
}
