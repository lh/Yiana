//
//  MarkupCoordinator.swift
//  Yiana
//
//  Coordinates the markup workflow using QLPreviewController
//

import Foundation
import QuickLook
import PDFKit

#if os(iOS)
import UIKit

/// Coordinates the markup workflow for PDFs using QLPreviewController
class MarkupCoordinator: NSObject {
    
    // MARK: - Properties
    
    private let sourceURL: URL
    private let completion: (Result<Data, Error>) -> Void
    private var tempFileURL: URL?
    
    // MARK: - Initialization
    
    init(pdfData: Data, completion: @escaping (Result<Data, Error>) -> Void) throws {
        // Create a temporary file for QLPreviewController
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "markup_\(UUID().uuidString).pdf"
        let tempURL = tempDir.appendingPathComponent(tempFileName)
        
        // Write PDF data to temp file
        try pdfData.write(to: tempURL)
        
        self.sourceURL = tempURL
        self.tempFileURL = tempURL
        self.completion = completion
        
        super.init()
    }
    
    deinit {
        // Clean up temporary file
        if let tempURL = tempFileURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
    
    // MARK: - Public Methods
    
    /// Creates and configures a QLPreviewController for markup
    func createPreviewController() -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = self
        controller.delegate = self
        return controller
    }
}

// MARK: - QLPreviewControllerDataSource

extension MarkupCoordinator: QLPreviewControllerDataSource {
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return sourceURL as QLPreviewItem
    }
}

// MARK: - QLPreviewControllerDelegate

extension MarkupCoordinator: QLPreviewControllerDelegate {
    
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        // Allow editing/markup
        return .updateContents
    }
    
    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        // Read the marked-up PDF
        do {
            let markedPDFData = try Data(contentsOf: modifiedContentsURL)
            
            // Verify it's valid PDF data
            guard let pdfDocument = PDFDocument(data: markedPDFData) else {
                completion(.failure(MarkupError.invalidPDF))
                return
            }
            
            // Log for debugging
            print("DEBUG Markup: Successfully received marked PDF with \(pdfDocument.pageCount) pages")
            
            // Return the marked-up data
            completion(.success(markedPDFData))
            
            // Clean up the modified file
            try? FileManager.default.removeItem(at: modifiedContentsURL)
            
        } catch {
            print("DEBUG Markup: Failed to read marked PDF - \(error)")
            completion(.failure(error))
        }
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        // If dismissed without saving, this is called
        // We don't treat this as an error - user simply cancelled
        print("DEBUG Markup: Preview controller dismissed")
    }
}

// MARK: - Error Types

enum MarkupError: LocalizedError {
    case invalidPDF
    case fileSizeTooLarge
    case backupFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "The marked-up document is not a valid PDF"
        case .fileSizeTooLarge:
            return "This document is too large for markup (maximum 50MB)"
        case .backupFailed:
            return "Failed to create backup before markup"
        }
    }
}

// MARK: - File Size Check

extension MarkupCoordinator {
    
    /// Maximum file size for markup in megabytes
    static let maxFileSizeMB = 50
    
    /// Checks if PDF data is within size limit for markup
    static func canMarkup(pdfData: Data) -> Bool {
        let fileSizeMB = Double(pdfData.count) / (1024.0 * 1024.0)
        return fileSizeMB <= Double(maxFileSizeMB)
    }
    
    /// Returns file size in MB as a formatted string
    static func formattedFileSize(for data: Data) -> String {
        let fileSizeMB = Double(data.count) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", fileSizeMB)
    }
}

#endif