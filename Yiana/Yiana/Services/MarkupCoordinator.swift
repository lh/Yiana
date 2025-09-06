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
    private let originalPDFData: Data
    private let pageIndex: Int
    
    // MARK: - Initialization
    
    init(pdfData: Data, currentPageIndex: Int, completion: @escaping (Result<Data, Error>) -> Void) throws {
        // Validate inputs
        guard let pdfDocument = PDFDocument(data: pdfData),
              currentPageIndex >= 0,
              currentPageIndex < pdfDocument.pageCount,
              let currentPage = pdfDocument.page(at: currentPageIndex) else {
            throw MarkupError.invalidPDF
        }
        
        // Store original data for merging later
        self.originalPDFData = pdfData
        self.pageIndex = currentPageIndex
        self.completion = completion
        
        // Create single-page PDF
        let singlePagePDF = PDFDocument()
        singlePagePDF.insert(currentPage, at: 0)
        
        guard let singlePageData = singlePagePDF.dataRepresentation() else {
            throw MarkupError.invalidPDF
        }
        
        // Create a temporary file for QLPreviewController
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "markup_page_\(currentPageIndex)_\(UUID().uuidString).pdf"
        let tempURL = tempDir.appendingPathComponent(tempFileName)
        
        // Write single page PDF data to temp file
        try singlePageData.write(to: tempURL)
        
        self.sourceURL = tempURL
        self.tempFileURL = tempURL
        
        super.init()
        
        print("DEBUG Markup: Extracted page \(currentPageIndex + 1) for markup")
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
        // Read the marked-up single page PDF
        do {
            let markedPageData = try Data(contentsOf: modifiedContentsURL)
            
            // Verify it's valid PDF data
            guard let markedPagePDF = PDFDocument(data: markedPageData),
                  markedPagePDF.pageCount == 1,
                  let markedPage = markedPagePDF.page(at: 0) else {
                completion(.failure(MarkupError.invalidPDF))
                return
            }
            
            // Load the original full document
            guard let originalPDF = PDFDocument(data: originalPDFData) else {
                completion(.failure(MarkupError.invalidPDF))
                return
            }
            
            // Replace the page in the original document
            originalPDF.removePage(at: pageIndex)
            originalPDF.insert(markedPage, at: pageIndex)
            
            // Get the complete document with the marked-up page
            guard let completeData = originalPDF.dataRepresentation() else {
                completion(.failure(MarkupError.invalidPDF))
                return
            }
            
            // Log for debugging
            print("DEBUG Markup: Successfully merged marked page \(pageIndex + 1) back into document")
            print("DEBUG Markup: Final document has \(originalPDF.pageCount) pages")
            
            // Return the complete document with the marked-up page
            completion(.success(completeData))
            
            // Clean up the modified file
            try? FileManager.default.removeItem(at: modifiedContentsURL)
            
        } catch {
            print("DEBUG Markup: Failed to process marked page - \(error)")
            completion(.failure(error))
        }
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        // This is called when the controller is dismissed
        // If the user saved, didSaveEditedCopyOf would have been called first
        // If not, this means they cancelled or dismissed without saving
        print("DEBUG Markup: Preview controller dismissed - user may have cancelled markup")
    }
    
    func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
        // This is called when the user makes changes
        print("DEBUG Markup: User is actively editing the document")
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