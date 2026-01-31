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
            let ocrText = extractOCRText(for: document.fileURL)
            let tags = document.metadata.tags

            // Compute folder path relative to documents root
            let repository = DocumentRepository()
            let docsPath = repository.documentsDirectory.standardizedFileURL.path
            let parentPath = document.fileURL.deletingLastPathComponent().standardizedFileURL.path
            let folderPath: String
            if parentPath.hasPrefix(docsPath) {
                let relative = String(parentPath.dropFirst(docsPath.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                folderPath = relative
            } else {
                folderPath = ""
            }

            let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: document.fileURL.path)[.size] as? Int64) ?? 0

            try await SearchIndexService.shared.indexDocument(
                id: document.metadata.id,
                url: document.fileURL,
                title: document.metadata.title,
                fullText: ocrText,
                tags: tags,
                metadata: document.metadata,
                folderPath: folderPath,
                fileSize: fileSize
            )
        } catch {
            print("Failed to index document: \(error)")
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
        guard let currentData = pdfData, let pdfDocument = PDFDocument(data: currentData) else { return }

        let sortedIndices = indices.sorted(by: >)
        for index in sortedIndices where index >= 0 && index < pdfDocument.pageCount {
            pdfDocument.removePage(at: index)
        }

        guard let updatedData = pdfDocument.dataRepresentation() else { return }

        pdfData = updatedData

        // Update page processing states: remove deleted pages and renumber remaining
        // Convert 0-based indices to 1-based page numbers for removal
        let removedPageNumbers = Set(indices.map { $0 + 1 })
        var newStates = document.metadata.pageProcessingStates.filter { !removedPageNumbers.contains($0.pageNumber) }
        // Renumber remaining states sequentially
        for i in 0..<newStates.count {
            newStates[i] = PageProcessingState(
                pageNumber: i + 1,
                needsOCR: newStates[i].needsOCR,
                needsExtraction: newStates[i].needsExtraction,
                ocrProcessedAt: newStates[i].ocrProcessedAt,
                addressExtractedAt: newStates[i].addressExtractedAt
            )
        }
        document.metadata.pageProcessingStates = newStates
        document.metadata.pageCount = pdfDocument.pageCount
        document.metadata.modified = Date()
        hasChanges = true

        await refreshDisplayPDF()
    }

    func duplicatePages(at indices: [Int]) async {
        guard let currentData = pdfData, let pdfDocument = PDFDocument(data: currentData) else { return }

        let sortedIndices = indices.sorted()
        var insertedCount = 0
        var insertedPositions: [Int] = [] // Track where new pages are inserted (0-based)
        #if DEBUG
        print("DEBUG Sidebar: duplicating pages", sortedIndices)
        print("DEBUG Sidebar: initial page count", pdfDocument.pageCount)
        #endif

        for index in sortedIndices {
            let adjustedIndex = index + insertedCount
            guard adjustedIndex >= 0 && adjustedIndex < pdfDocument.pageCount,
                  let original = pdfDocument.page(at: adjustedIndex) else { continue }

            let insertIndex = min(adjustedIndex + 1, pdfDocument.pageCount)
            if let copy = original.copy() as? PDFPage {
                pdfDocument.insert(copy, at: insertIndex)
                insertedPositions.append(insertIndex)
                insertedCount += 1
                #if DEBUG
                print("DEBUG Sidebar: inserted copy of page", adjustedIndex, "at", insertIndex)
                #endif
            }
        }

        guard let updatedData = pdfDocument.dataRepresentation() else { return }

        #if DEBUG
        print("DEBUG Sidebar: new page count", pdfDocument.pageCount)
        #endif

        pdfData = updatedData

        // Update page processing states: insert new states for duplicated pages
        var newStates: [PageProcessingState] = []
        let newPageCount = pdfDocument.pageCount
        var oldStateIndex = 0
        let insertedSet = Set(insertedPositions)

        for pageIndex in 0..<newPageCount {
            if insertedSet.contains(pageIndex) {
                // This is a duplicated page - mark as needing OCR
                newStates.append(PageProcessingState(
                    pageNumber: pageIndex + 1,
                    needsOCR: true,
                    needsExtraction: false
                ))
            } else {
                // Existing page - preserve state with updated page number
                if oldStateIndex < document.metadata.pageProcessingStates.count {
                    let oldState = document.metadata.pageProcessingStates[oldStateIndex]
                    newStates.append(PageProcessingState(
                        pageNumber: pageIndex + 1,
                        needsOCR: oldState.needsOCR,
                        needsExtraction: oldState.needsExtraction,
                        ocrProcessedAt: oldState.ocrProcessedAt,
                        addressExtractedAt: oldState.addressExtractedAt
                    ))
                    oldStateIndex += 1
                } else {
                    // Fallback for missing state
                    newStates.append(PageProcessingState(pageNumber: pageIndex + 1, needsOCR: true))
                }
            }
        }
        document.metadata.pageProcessingStates = newStates
        document.metadata.pageCount = newPageCount
        document.metadata.modified = Date()
        hasChanges = true

        await refreshDisplayPDF()
    }

    #if DEBUG
    func logDocumentSnapshot(context: String) {
        if let data = pdfData, let doc = PDFDocument(data: data) {
            print("DEBUG DocSnapshot[", context, "]: pdfData pages =", doc.pageCount)
            for pageIndex in 0..<doc.pageCount {
                let text = doc.page(at: pageIndex)?.string ?? "<no text>"
                print("  pdfData page", pageIndex, ":", text.prefix(40))
            }
        } else {
            print("DEBUG DocSnapshot[", context, "]: pdfData is nil")
        }
        if let data = displayPDFData, let doc = PDFDocument(data: data) {
            print("DEBUG DocSnapshot[", context, "]: displayPDFData pages =", doc.pageCount)
            for pageIndex in 0..<doc.pageCount {
                let text = doc.page(at: pageIndex)?.string ?? "<no text>"
                print("  display page", pageIndex, ":", text.prefix(40))
            }
        } else {
            print("DEBUG DocSnapshot[", context, "]: displayPDFData is nil")
        }
    }
    #endif

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
    // MARK: - Page Copy/Cut/Paste Operations

    /// The document's unique identifier
    var documentID: UUID {
        document.metadata.id
    }

    /// Ensures the document is in a valid state for modifications
    func ensureDocumentIsAvailable() throws {
        #if os(iOS)
        // Check for closed state
        if document.documentState.contains(.closed) {
            throw PageOperationError.documentClosed
        }

        // Log conflict state for monitoring but don't block operations yet
        if document.documentState.contains(.inConflict) {
            print("[WARNING] Document '\(document.metadata.title)' is in conflict state during page operation")
            print("[WARNING] Document state flags: \(document.documentState.rawValue)")
            // TODO: Once conflict detection is reliable, uncomment the following:
            // throw PageOperationError.documentInConflict
            // For now, we log but allow the operation to proceed
        }
        #endif
    }

    /// Copies pages at the specified zero-based indices
    func copyPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        try ensureDocumentIsAvailable()

        // Filter out provisional pages
        let validIndices = indices.filter { index in
            if let provisionalRange = provisionalPageRange {
                return !provisionalRange.contains(index)
            }
            return true
        }

        guard !validIndices.isEmpty else {
            throw PageOperationError.provisionalPagesNotSupported
        }

        return try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: validIndices,
            documentID: documentID,
            operation: .copy
        )
    }

    /// Cuts pages at the specified zero-based indices (removes them after creating payload)
    func cutPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        try ensureDocumentIsAvailable()

        // Filter out provisional pages
        let validIndices = indices.filter { index in
            if let provisionalRange = provisionalPageRange {
                return !provisionalRange.contains(index)
            }
            return true
        }

        guard !validIndices.isEmpty else {
            throw PageOperationError.provisionalPagesNotSupported
        }

        // Store current state for potential recovery
        let sourceDataBeforeCut = pdfData

        // Create the payload before removing pages
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: validIndices,
            documentID: documentID,
            operation: .cut,
            sourceDataBeforeCut: sourceDataBeforeCut
        )

        // Now remove the pages
        await removePages(at: Array(validIndices))

        return payload
    }

    /// Inserts pages from a clipboard payload at the specified index
    /// - Parameters:
    ///   - payload: The page clipboard payload
    ///   - insertIndex: Zero-based index where to insert (nil = append to end)
    /// - Returns: Number of pages inserted
    @discardableResult
    func insertPages(from payload: PageClipboardPayload, at insertIndex: Int?) async throws -> Int {
        try ensureDocumentIsAvailable()

        guard let currentData = pdfData,
              let targetPDF = PDFDocument(data: currentData),
              let sourcePDF = PDFDocument(data: payload.pdfData) else {
            throw PageOperationError.sourceDocumentUnavailable
        }

        // Determine insertion point
        let insertAt = insertIndex ?? targetPDF.pageCount

        // Insert pages
        var insertedCount = 0
        for sourcePageIndex in 0..<sourcePDF.pageCount {
            autoreleasepool {
                if let page = sourcePDF.page(at: sourcePageIndex),
                   let pageCopy = page.copy() as? PDFPage {
                    targetPDF.insert(pageCopy, at: insertAt + insertedCount)
                    insertedCount += 1
                }
            }
        }

        guard insertedCount > 0 else {
            throw PageOperationError.insertionFailed
        }

        // Update the document
        guard let updatedData = targetPDF.dataRepresentation() else {
            throw PageOperationError.unableToSerialise
        }

        pdfData = updatedData

        // Update page processing states: insert new states for added pages
        var newStates: [PageProcessingState] = []
        let newPageCount = targetPDF.pageCount

        for pageIndex in 0..<newPageCount {
            let pageNumber = pageIndex + 1
            if pageIndex >= insertAt && pageIndex < insertAt + insertedCount {
                // This is a newly inserted page - mark as needing OCR
                newStates.append(PageProcessingState(
                    pageNumber: pageNumber,
                    needsOCR: true,
                    needsExtraction: false
                ))
            } else {
                // Existing page - find and preserve its state
                let oldPageIndex = pageIndex < insertAt ? pageIndex : pageIndex - insertedCount
                if oldPageIndex < document.metadata.pageProcessingStates.count {
                    let oldState = document.metadata.pageProcessingStates[oldPageIndex]
                    newStates.append(PageProcessingState(
                        pageNumber: pageNumber,
                        needsOCR: oldState.needsOCR,
                        needsExtraction: oldState.needsExtraction,
                        ocrProcessedAt: oldState.ocrProcessedAt,
                        addressExtractedAt: oldState.addressExtractedAt
                    ))
                } else {
                    // Fallback for missing state
                    newStates.append(PageProcessingState(pageNumber: pageNumber, needsOCR: true))
                }
            }
        }

        // Update metadata
        document.metadata.pageProcessingStates = newStates
        document.metadata.pageCount = newPageCount
        document.metadata.modified = Date()
        hasChanges = true

        await refreshDisplayPDF()

        // Clear provisional range if we inserted at or before it
        if let provisionalRange = provisionalPageRange,
           let insertAt = insertIndex,
           insertAt <= provisionalRange.lowerBound {
            let shift = insertedCount
            self.provisionalPageRange = (provisionalRange.lowerBound + shift)..<(provisionalRange.upperBound + shift)
        }

        return insertedCount
    }

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

import UniformTypeIdentifiers

// Extension to define the yianaDocument UTType
extension UTType {
    static let yianaDocument = UTType(exportedAs: "com.vitygas.yiana.document")
}

// macOS implementation with full page operations support
@MainActor
final class DocumentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var title: String = "Document" {
        didSet {
            guard title != oldValue else { return }
            if let document = document {
                document.metadata.title = title
                hasChanges = true
                scheduleAutosave()
            }
        }
    }

    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?

    @Published var pdfData: Data? {
        didSet {
            guard pdfData != oldValue else { return }
            if document != nil {
                hasChanges = true
                scheduleAutosave()
            }
        }
    }

    // MARK: - Computed Properties

    var displayPDFData: Data? { pdfData }
    var provisionalPageRange: Range<Int>? { nil }  // macOS doesn't support provisional pages yet

    var documentID: UUID {
        document?.metadata.id ?? UUID()
    }

    var isReadOnly: Bool {
        guard let document = document else { return true }
        guard let fileURL = document.fileURL else {
            // Unsaved documents (no fileURL yet) should still allow edits
            return false
        }
        return !FileManager.default.isWritableFile(atPath: fileURL.path)
    }

    // MARK: - Private Properties

    weak var document: NoteDocument?
    private var autosaveTask: Task<Void, Never>?
    private let autosaveDelay: TimeInterval = 2.0

    // MARK: - Initialization

    /// Primary initializer for document-based operations
    init(document: NoteDocument) {
        self.document = document
        self.title = document.metadata.title
        self.pdfData = document.pdfData

        // Update document metadata when properties change
        self.hasChanges = false
    }

    /// Secondary initializer for legacy/test compatibility
    init(pdfData: Data?) {
        self.pdfData = pdfData
        // Note: This is for legacy support only. Production code should use init(document:)
    }

    // MARK: - Save Operations

    func save() async -> Bool {
        guard let document = document else { return false }

        // Return true immediately if no changes to match iOS behavior
        guard hasChanges else { return true }

        isSaving = true
        defer { isSaving = false }

        // Update metadata
        document.metadata.modified = Date()
        if let pdfData = pdfData,
           let pdfDocument = PDFDocument(data: pdfData) {
            document.metadata.pageCount = pdfDocument.pageCount
        }

        // Update document's PDF data
        document.pdfData = pdfData

        // Save the document
        do {
            if let fileURL = document.fileURL {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    // Use the correct UTType identifier
                    let typeIdentifier = document.fileType ?? UTType.yianaDocument.identifier
                    document.save(to: fileURL, ofType: typeIdentifier, for: .saveOperation) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                hasChanges = false
                return true
            }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            print("Save failed: \(error)")
        }

        return false
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()

        guard hasChanges else { return }

        autosaveTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(autosaveDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                _ = await save()
            } catch {
                // Task cancelled, ignore
            }
        }
    }

    // MARK: - Page Operations Helpers

    private func removePages(at indices: [Int]) async {
        guard let currentData = pdfData,
              let pdfDocument = PDFDocument(data: currentData) else { return }

        // Sort indices in descending order to remove from end to beginning
        let sortedIndices = indices.sorted(by: >)
        for index in sortedIndices where index >= 0 && index < pdfDocument.pageCount {
            pdfDocument.removePage(at: index)
        }

        guard let updatedData = pdfDocument.dataRepresentation() else { return }
        pdfData = updatedData

        // Update page processing states: remove deleted pages and renumber remaining
        if let document = document {
            let removedPageNumbers = Set(indices.map { $0 + 1 })
            var newStates = document.metadata.pageProcessingStates.filter { !removedPageNumbers.contains($0.pageNumber) }
            for i in 0..<newStates.count {
                newStates[i] = PageProcessingState(
                    pageNumber: i + 1,
                    needsOCR: newStates[i].needsOCR,
                    needsExtraction: newStates[i].needsExtraction,
                    ocrProcessedAt: newStates[i].ocrProcessedAt,
                    addressExtractedAt: newStates[i].addressExtractedAt
                )
            }
            document.metadata.pageProcessingStates = newStates
            document.metadata.pageCount = pdfDocument.pageCount
            document.metadata.modified = Date()
            hasChanges = true
        }
    }

    // MARK: - Page Copy/Cut/Paste Operations

    func ensureDocumentIsAvailable() throws {
        guard document != nil else {
            throw PageOperationError.sourceDocumentUnavailable
        }

        if isReadOnly {
            throw PageOperationError.documentReadOnly
        }
    }

    /// Copies pages at the specified zero-based indices
    func copyPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        // Copy is a read-only operation, so we don't need write access
        guard !indices.isEmpty else {
            throw PageOperationError.noValidPagesSelected
        }

        return try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .copy
        )
    }

    /// Cuts pages at the specified zero-based indices (removes them after creating payload)
    func cutPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        try ensureDocumentIsAvailable()

        guard !indices.isEmpty else {
            throw PageOperationError.noValidPagesSelected
        }

        // Store current state for undo
        let sourceDataBeforeCut = pdfData

        // Register undo operation
        if let undoManager = document?.undoManager {
            undoManager.registerUndo(withTarget: self) { target in
                Task { @MainActor in
                    target.pdfData = sourceDataBeforeCut
                    target.hasChanges = true
                    target.scheduleAutosave()
                }
            }
            undoManager.setActionName("Cut Pages")
        }

        // Create the payload before removing pages
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .cut,
            sourceDataBeforeCut: sourceDataBeforeCut
        )

        // Now remove the pages
        await removePages(at: Array(indices))

        return payload
    }

    /// Inserts pages from a clipboard payload at the specified index
    /// - Returns: Number of pages inserted
    @discardableResult
    func insertPages(from payload: PageClipboardPayload, at insertIndex: Int?) async throws -> Int {
        try ensureDocumentIsAvailable()

        guard let currentData = pdfData,
              let targetPDF = PDFDocument(data: currentData),
              let sourcePDF = PDFDocument(data: payload.pdfData) else {
            throw PageOperationError.sourceDocumentUnavailable
        }

        // Determine insertion point
        let insertAt = insertIndex ?? targetPDF.pageCount

        // Store current state for undo
        let originalPDFData = pdfData

        // Insert pages with autoreleasepool to minimize memory pressure
        var insertedCount = 0
        for sourcePageIndex in 0..<sourcePDF.pageCount {
            autoreleasepool {
                if let page = sourcePDF.page(at: sourcePageIndex),
                   let pageCopy = page.copy() as? PDFPage {
                    targetPDF.insert(pageCopy, at: insertAt + insertedCount)
                    insertedCount += 1
                }
            }
        }

        guard insertedCount > 0 else {
            throw PageOperationError.insertionFailed
        }

        // Update the document
        guard let updatedData = targetPDF.dataRepresentation() else {
            throw PageOperationError.unableToSerialise
        }

        // Register undo operation
        if let undoManager = document?.undoManager {
            undoManager.registerUndo(withTarget: self) { target in
                Task { @MainActor in
                    target.pdfData = originalPDFData
                    target.hasChanges = true
                    target.scheduleAutosave()
                }
            }
            undoManager.setActionName("Paste Pages")
        }

        pdfData = updatedData

        // Update page processing states: insert new states for added pages
        if let document = document {
            var newStates: [PageProcessingState] = []
            let newPageCount = targetPDF.pageCount

            for pageIndex in 0..<newPageCount {
                let pageNumber = pageIndex + 1
                if pageIndex >= insertAt && pageIndex < insertAt + insertedCount {
                    // This is a newly inserted page - mark as needing OCR
                    newStates.append(PageProcessingState(
                        pageNumber: pageNumber,
                        needsOCR: true,
                        needsExtraction: false
                    ))
                } else {
                    // Existing page - find and preserve its state
                    let oldPageIndex = pageIndex < insertAt ? pageIndex : pageIndex - insertedCount
                    if oldPageIndex < document.metadata.pageProcessingStates.count {
                        let oldState = document.metadata.pageProcessingStates[oldPageIndex]
                        newStates.append(PageProcessingState(
                            pageNumber: pageNumber,
                            needsOCR: oldState.needsOCR,
                            needsExtraction: oldState.needsExtraction,
                            ocrProcessedAt: oldState.ocrProcessedAt,
                            addressExtractedAt: oldState.addressExtractedAt
                        ))
                    } else {
                        // Fallback for missing state
                        newStates.append(PageProcessingState(pageNumber: pageNumber, needsOCR: true))
                    }
                }
            }

            document.metadata.pageProcessingStates = newStates
            document.metadata.pageCount = newPageCount
            document.metadata.modified = Date()
        }

        return insertedCount
    }
}
#endif
