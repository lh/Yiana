//
//  DocumentViewModel.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation
import SwiftUI
import PDFKit

#if os(iOS)
import UIKit
import PDFKit

@MainActor
class DocumentViewModel: ObservableObject {
    @Published var title: String {
        didSet {
            if title != oldValue && title != document.metadata.title {
                hasChanges = true
                scheduleAutoSave()
            }
        }
    }
    
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    @Published var pdfData: Data? {
        didSet {
            if pdfData != oldValue {
                document.pdfData = pdfData
                hasChanges = true
                scheduleAutoSave()
            }
        }
    }
    
    var autoSaveEnabled = false {
        didSet {
            if autoSaveEnabled && hasChanges {
                scheduleAutoSave()
            }
        }
    }
    
    private let document: NoteDocument
    private var autoSaveTask: Task<Void, Never>?
    
    init(document: NoteDocument) {
        self.document = document
        self.title = document.metadata.title
        self.pdfData = document.pdfData
    }
    
    func save() async -> Bool {
        guard hasChanges else {
            print("DEBUG DocumentViewModel: No changes to save")
            return true
        }

        print("DEBUG DocumentViewModel: Starting save...")
        print("DEBUG DocumentViewModel: PDF data size: \(pdfData?.count ?? 0) bytes")

        isSaving = true
        errorMessage = nil

        // Update document
        document.metadata.title = title
        document.metadata.modified = Date()

        // Update page count from PDF data
        if let pdfData = pdfData,
           let pdfDocument = PDFDocument(data: pdfData) {
            document.metadata.pageCount = pdfDocument.pageCount
            print("DEBUG DocumentViewModel: Updated page count to \(pdfDocument.pageCount)")
        }

        // Update document's PDF data
        document.pdfData = pdfData

        print("DEBUG DocumentViewModel: Saving to \(document.fileURL.path)")

        // Save
        return await withCheckedContinuation { continuation in
            document.save(to: document.fileURL, for: .forOverwriting) { success in
                Task { @MainActor in
                    self.isSaving = false
                    if success {
                        self.hasChanges = false
                        print("DEBUG DocumentViewModel: Save successful!")

                        // Index the document for search after successful save
                        Task {
                            await self.indexDocument()
                        }
                    } else {
                        self.errorMessage = "Failed to save document"
                        print("DEBUG DocumentViewModel: Save failed!")
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }

    /// Index the document in the search database
    private func indexDocument() async {
        do {
            // Extract OCR text if available
            let ocrText = extractOCRText(for: document.fileURL)

            // Get tags as string array
            let tags = document.metadata.tags

            // Index the document
            try await SearchIndexService.shared.indexDocument(
                id: document.metadata.id,
                url: document.fileURL,
                title: document.metadata.title,
                fullText: ocrText,
                tags: tags,
                metadata: document.metadata
            )

            print("✓ Indexed document for search: \(document.metadata.title)")
        } catch {
            print("⚠️ Failed to index document: \(error)")
        }
    }

    /// Extract OCR text from the OCR results JSON file
    private func extractOCRText(for documentURL: URL) -> String {
        // Build path to OCR results directory
        let ocrResultsDir = documentURL.deletingLastPathComponent().appendingPathComponent(".ocr_results")
        let documentName = documentURL.deletingPathExtension().lastPathComponent
        let ocrFile = ocrResultsDir.appendingPathComponent(documentName).appendingPathExtension("json")

        guard FileManager.default.fileExists(atPath: ocrFile.path) else {
            return ""
        }

        do {
            let data = try Data(contentsOf: ocrFile)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let pages = json?["pages"] as? [[String: Any]] else {
                return ""
            }

            // Concatenate text from all pages
            let allText = pages.compactMap { page in
                page["text"] as? String
            }.joined(separator: "\n")

            return allText
        } catch {
            print("⚠️ Failed to read OCR file: \(error)")
            return ""
        }
    }
    
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        
        guard autoSaveEnabled && hasChanges else { return }
        
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if !Task.isCancelled {
                _ = await save()
            }
        }
    }
}

#else

// Placeholder - macOS document editing will come later
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var title = "Document viewing not yet supported on macOS"
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    var pdfData: Data? { nil }
    var autoSaveEnabled = false
    
    init() {}
    
    func save() async -> Bool {
        return false
    }
}
#endif
