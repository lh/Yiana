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
                Task {
                    await refreshDisplayPDF()
                }
            }
        }
    }
    @Published private(set) var displayPDFData: Data?
    @Published private(set) var provisionalPageRange: Range<Int>?

    var autoSaveEnabled = false {
        didSet {
            if autoSaveEnabled && hasChanges {
                scheduleAutoSave()
            }
        }
    }

    private let document: NoteDocument
    private var autoSaveTask: Task<Void, Never>?
    private let textRenderService = TextPageRenderService.shared
    private let provisionalManager = ProvisionalPageManager()
    
    init(document: NoteDocument) {
        self.document = document
        self.title = document.metadata.title
        self.pdfData = document.pdfData
        self.displayPDFData = document.pdfData
        self.provisionalPageRange = nil
        Task {
            await refreshDisplayPDF()
        }
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

    var metadataSnapshot: DocumentMetadata {
        document.metadata
    }

    func updatePendingTextPageFlag(_ hasDraft: Bool) {
        guard document.metadata.hasPendingTextPage != hasDraft else { return }
        document.metadata.hasPendingTextPage = hasDraft
        hasChanges = true
        scheduleAutoSave()
    }
    
    func setProvisionalPreviewData(_ data: Data?) async {
        await provisionalManager.updateProvisionalData(data)
        await refreshDisplayPDF()
    }

    func removePages(at indices: [Int]) async {
        guard let currentData = pdfData, let document = PDFDocument(data: currentData) else { return }

        let sortedIndices = indices.sorted(by: >)
        for index in sortedIndices where index >= 0 && index < document.pageCount {
            document.removePage(at: index)
        }

        guard let updatedData = document.dataRepresentation() else { return }

        pdfData = updatedData
        await refreshDisplayPDF()
    }

    func duplicatePages(at indices: [Int]) async {
        guard let currentData = pdfData, let document = PDFDocument(data: currentData) else { return }

        let sortedIndices = indices.sorted()
        var insertedCount = 0

        for index in sortedIndices {
            let adjustedIndex = index + insertedCount
            guard adjustedIndex >= 0 && adjustedIndex < document.pageCount,
                  let original = document.page(at: adjustedIndex) else { continue }

            let insertIndex = min(adjustedIndex + 1, document.pageCount)
            if let copy = original.copy() as? PDFPage {
                document.insert(copy, at: insertIndex)
                insertedCount += 1
            }
        }

        guard let updatedData = document.dataRepresentation() else { return }

        pdfData = updatedData
        await refreshDisplayPDF()
    }
    
    private func refreshDisplayPDF() async {
        let savedData = pdfData
        let result = await provisionalManager.combinedData(using: savedData)
        await MainActor.run {
            if let combined = result.data {
                self.displayPDFData = combined
            } else {
                self.displayPDFData = savedData
            }
            self.provisionalPageRange = result.provisionalRange
        }
    }

    /// Renders the provided Markdown into a PDF page, appends it to the current document,
    /// and updates metadata/search fields accordingly.
    @discardableResult
    func appendTextPage(
        markdown: String,
        appendPlainTextToMetadata: Bool,
        cachedRenderedPage: Data? = nil,
        cachedPlainText: String? = nil
    ) async throws -> (plainText: String, addedPages: Int) {
        let existingData = pdfData

        let combinedData: Data
        let plainText: String
        let addedPages: Int
        let renderedPageData: Data

        if let cachedRenderedPage,
           let appendedDocument = PDFDocument(data: cachedRenderedPage),
           appendedDocument.pageCount > 0 {
            let baseDocument: PDFDocument
            if let existingData, let existing = PDFDocument(data: existingData) {
                baseDocument = existing
            } else {
                baseDocument = PDFDocument()
            }

            addedPages = appendedDocument.pageCount
            for index in 0..<addedPages {
                guard let page = appendedDocument.page(at: index) else { continue }
                if let copiedPage = page.copy() as? PDFPage {
                    baseDocument.insert(copiedPage, at: baseDocument.pageCount)
                } else {
                    baseDocument.insert(page, at: baseDocument.pageCount)
                }
            }

            guard let mergedData = baseDocument.dataRepresentation() else {
                throw NSError(domain: "TextPageRender", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to merge cached rendered page"])
            }

            combinedData = mergedData
            plainText = cachedPlainText ?? markdown
            renderedPageData = cachedRenderedPage
        } else {
            let result = try await textRenderService.renderAndAppend(markdown: markdown, existingPDFData: existingData)
            combinedData = result.combinedPDF
            plainText = result.plainText
            addedPages = result.addedPages
            renderedPageData = result.renderedPagePDF
        }

        pdfData = combinedData

        if let updatedPDF = PDFDocument(data: combinedData) {
            document.metadata.pageCount = updatedPDF.pageCount
        }

        document.metadata.modified = Date()
        document.metadata.hasPendingTextPage = false

        if appendPlainTextToMetadata {
            let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if var existing = document.metadata.fullText, !existing.isEmpty {
                    existing.append("\n\n")
                    existing.append(trimmed)
                    document.metadata.fullText = existing
                } else {
                    document.metadata.fullText = trimmed
                }
            }
        }

#if DEBUG
        if let combinedDoc = PDFDocument(data: combinedData) {
            let lastIndex = combinedDoc.pageCount - 1
            let pageString = combinedDoc.page(at: lastIndex)?.string ?? "<nil>"
            print("DEBUG DocumentViewModel: Combined PDF last page string length = \(pageString.count)")
            print("DEBUG DocumentViewModel: Combined PDF last page string = \n\(pageString)")
        } else {
            print("DEBUG DocumentViewModel: Failed to load combined PDF for logging")
        }
#endif

        hasChanges = true
        scheduleAutoSave()

        #if DEBUG
        DebugRenderedPageStore.shared.store(data: renderedPageData, near: document.fileURL)
        #endif

        return (plainText: plainText, addedPages: addedPages)
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
