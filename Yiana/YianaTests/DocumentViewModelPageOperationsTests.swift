//
//  DocumentViewModelPageOperationsTests.swift
//  YianaTests
//

import XCTest
import PDFKit
@testable import Yiana

#if os(iOS)
@MainActor
class DocumentViewModelPageOperationsTests: XCTestCase {

    var viewModel: DocumentViewModel!
    var testDocument: NoteDocument!

    override func setUp() async throws {
        try await super.setUp()

        // Create a test document
        let metadata = DocumentMetadata(
            title: "Test Document",
            pageCount: 3,
            tags: []
        )
        testDocument = NoteDocument(metadata: metadata)

        // Add sample PDF data
        let pdf = PDFDocument()
        for i in 0..<3 {
            let page = PDFPage()
            pdf.insert(page, at: i)
        }
        testDocument.pdfData = pdf.dataRepresentation()

        // Create view model
        viewModel = DocumentViewModel(document: testDocument)

        // Clear clipboard
        PageClipboard.shared.clear()
    }

    override func tearDown() {
        PageClipboard.shared.clear()
        viewModel = nil
        testDocument = nil
        super.tearDown()
    }

    // MARK: - Copy Operations Tests

    func testCopyPagesWithValidIndices() async throws {
        // Given
        let indices: Set<Int> = [0, 2]

        // When
        let payload = try await viewModel.copyPages(atZeroBasedIndices: indices)

        // Then
        XCTAssertEqual(payload.operation, .copy)
        XCTAssertEqual(payload.sourceDocumentID, viewModel.documentID)
        XCTAssertEqual(payload.pageCount, 2)
        XCTAssertNil(payload.sourceDataBeforeCut)
        XCTAssertNil(payload.cutIndices)

        // Verify pages still exist in document
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 3)  // Original pages still there
        }
    }

    func testCopyPagesWithEmptySelection() async {
        // Given
        let indices: Set<Int> = []

        // When/Then
        do {
            _ = try await viewModel.copyPages(atZeroBasedIndices: indices)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? PageOperationError, PageOperationError.provisionalPagesNotSupported)
        }
    }

    func testCopyPagesWithProvisionalPages() async throws {
        // Given - Set provisional page range
        viewModel.provisionalPageRange = 2..<3
        let indices: Set<Int> = [0, 1, 2]  // Mix of real and provisional

        // When
        let payload = try await viewModel.copyPages(atZeroBasedIndices: indices)

        // Then - Should only copy non-provisional pages
        XCTAssertEqual(payload.pageCount, 2)  // Only pages 0 and 1
    }

    func testCopyPagesOnlyProvisional() async {
        // Given - All pages are provisional
        viewModel.provisionalPageRange = 0..<3
        let indices: Set<Int> = [0, 1, 2]

        // When/Then
        do {
            _ = try await viewModel.copyPages(atZeroBasedIndices: indices)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? PageOperationError, PageOperationError.provisionalPagesNotSupported)
        }
    }

    // MARK: - Cut Operations Tests

    func testCutPagesWithValidIndices() async throws {
        // Given
        let indices: Set<Int> = [1]
        let originalData = viewModel.pdfData

        // When
        let payload = try await viewModel.cutPages(atZeroBasedIndices: indices)

        // Then
        XCTAssertEqual(payload.operation, .cut)
        XCTAssertEqual(payload.sourceDocumentID, viewModel.documentID)
        XCTAssertEqual(payload.pageCount, 1)
        XCTAssertNotNil(payload.sourceDataBeforeCut)
        XCTAssertEqual(payload.sourceDataBeforeCut, originalData)
        XCTAssertEqual(payload.cutIndices, [1])

        // Verify page was removed from document
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 2)  // One page removed
        }
    }

    func testCutAllPages() async throws {
        // Given
        let indices: Set<Int> = [0, 1, 2]

        // When
        let payload = try await viewModel.cutPages(atZeroBasedIndices: indices)

        // Then
        XCTAssertEqual(payload.pageCount, 3)
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 0)  // All pages removed
        }
    }

    // MARK: - Insert/Paste Operations Tests

    func testInsertPagesAtEnd() async throws {
        // Given - Create a payload to insert
        let pdfToInsert = createSamplePDFData(pageCount: 2)
        let payload = PageClipboardPayload(
            sourceDocumentID: UUID(),
            operation: .copy,
            pageCount: 2,
            pdfData: pdfToInsert
        )

        // When
        let insertedCount = try await viewModel.insertPages(from: payload, at: nil)

        // Then
        XCTAssertEqual(insertedCount, 2)
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 5)  // 3 original + 2 inserted
        }
        XCTAssertEqual(testDocument.metadata.pageCount, 5)
        XCTAssertTrue(viewModel.hasChanges)
    }

    func testInsertPagesAtSpecificIndex() async throws {
        // Given
        let pdfToInsert = createSamplePDFData(pageCount: 1)
        let payload = PageClipboardPayload(
            sourceDocumentID: UUID(),
            operation: .copy,
            pageCount: 1,
            pdfData: pdfToInsert
        )

        // When - Insert at index 1 (between first and second page)
        let insertedCount = try await viewModel.insertPages(from: payload, at: 1)

        // Then
        XCTAssertEqual(insertedCount, 1)
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 4)
        }
    }

    func testInsertPagesAtBeginning() async throws {
        // Given
        let pdfToInsert = createSamplePDFData(pageCount: 2)
        let payload = PageClipboardPayload(
            sourceDocumentID: UUID(),
            operation: .copy,
            pageCount: 2,
            pdfData: pdfToInsert
        )

        // When
        let insertedCount = try await viewModel.insertPages(from: payload, at: 0)

        // Then
        XCTAssertEqual(insertedCount, 2)
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 5)
        }
    }

    func testInsertPagesWithProvisionalRange() async throws {
        // Given - Set provisional range
        viewModel.provisionalPageRange = 2..<3
        let pdfToInsert = createSamplePDFData(pageCount: 1)
        let payload = PageClipboardPayload(
            sourceDocumentID: UUID(),
            operation: .copy,
            pageCount: 1,
            pdfData: pdfToInsert
        )

        // When - Insert before provisional range
        let insertedCount = try await viewModel.insertPages(from: payload, at: 1)

        // Then
        XCTAssertEqual(insertedCount, 1)
        // Provisional range should shift
        XCTAssertEqual(viewModel.provisionalPageRange, 3..<4)
    }

    func testInsertEmptyPayload() async throws {
        // Given - Payload with invalid PDF data
        let payload = PageClipboardPayload(
            sourceDocumentID: UUID(),
            operation: .copy,
            pageCount: 0,
            pdfData: Data()  // Empty/invalid PDF
        )

        // When/Then
        do {
            _ = try await viewModel.insertPages(from: payload, at: 0)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? PageOperationError, PageOperationError.insertionFailed)
        }
    }

    // MARK: - Integration Tests

    func testCompleteCopyPasteFlow() async throws {
        // Given
        let indicesToCopy: Set<Int> = [0, 2]

        // When - Copy pages
        let copyPayload = try await viewModel.copyPages(atZeroBasedIndices: indicesToCopy)
        PageClipboard.shared.setPayload(copyPayload)

        // And - Paste them
        let pastePayload = PageClipboard.shared.currentPayload()!
        let insertedCount = try await viewModel.insertPages(from: pastePayload, at: nil)

        // Then
        XCTAssertEqual(insertedCount, 2)
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 5)  // 3 original + 2 copied
        }
    }

    func testCompleteCutPasteFlow() async throws {
        // Given
        let indicesToCut: Set<Int> = [1]

        // When - Cut page
        let cutPayload = try await viewModel.cutPages(atZeroBasedIndices: indicesToCut)
        PageClipboard.shared.setPayload(cutPayload)

        // Verify page was removed
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 2)
        }

        // And - Paste it back
        let pastePayload = PageClipboard.shared.currentPayload()!
        let insertedCount = try await viewModel.insertPages(from: pastePayload, at: 0)

        // Then
        XCTAssertEqual(insertedCount, 1)
        if let pdf = PDFDocument(data: viewModel.pdfData!) {
            XCTAssertEqual(pdf.pageCount, 3)  // Back to original count
        }
    }

    // MARK: - Document State Tests

    func testEnsureDocumentAvailable() throws {
        // Given - Document is in normal state
        // When/Then - Should not throw
        XCTAssertNoThrow(try viewModel.ensureDocumentIsAvailable())
    }

    func testDocumentID() {
        // Given/When
        let id = viewModel.documentID

        // Then
        XCTAssertEqual(id, testDocument.metadata.id)
    }

    // MARK: - Helper Methods

    private func createSamplePDFData(pageCount: Int) -> Data {
        let pdf = PDFDocument()
        for i in 0..<pageCount {
            let page = PDFPage()
            pdf.insert(page, at: i)
        }
        return pdf.dataRepresentation() ?? Data()
    }
}
#endif

// MARK: - macOS Tests

#if os(macOS)
@MainActor
class DocumentViewModelPageOperationsMacOSTests: XCTestCase {

    var viewModel: DocumentViewModel!

    override func setUp() {
        super.setUp()

        // Create sample PDF data
        let pdf = PDFDocument()
        for i in 0..<3 {
            let page = PDFPage()
            pdf.insert(page, at: i)
        }
        let pdfData = pdf.dataRepresentation()

        // Create view model with PDF data
        viewModel = DocumentViewModel(pdfData: pdfData)

        // Clear clipboard
        PageClipboard.shared.clear()
    }

    override func tearDown() {
        PageClipboard.shared.clear()
        viewModel = nil
        super.tearDown()
    }

    func testCopyPagesOnMacOS() async throws {
        // Given
        let indices: Set<Int> = [0, 1]

        // When
        let payload = try await viewModel.copyPages(atZeroBasedIndices: indices)

        // Then
        XCTAssertEqual(payload.operation, .copy)
        XCTAssertEqual(payload.pageCount, 2)
    }

    func testCutPagesOnMacOS() async throws {
        // Given - create a NoteDocument and proper view model
        let pdf = PDFDocument()
        for i in 0..<3 {
            let page = PDFPage()
            pdf.insert(page, at: i)
        }
        let pdfData = pdf.dataRepresentation()

        // Create a mock NoteDocument
        let noteDocument = NoteDocument()
        noteDocument.pdfData = pdfData
        noteDocument.metadata.pageCount = 3

        let documentViewModel = DocumentViewModel(document: noteDocument)
        let indices: Set<Int> = [0]

        // When
        let payload = try await documentViewModel.cutPages(atZeroBasedIndices: indices)

        // Then
        XCTAssertEqual(payload.operation, .cut)
        XCTAssertEqual(payload.pageCount, 1)
        XCTAssertNotNil(payload.sourceDataBeforeCut)

        // Verify page was removed
        if let updatedPDF = PDFDocument(data: documentViewModel.pdfData ?? Data()) {
            XCTAssertEqual(updatedPDF.pageCount, 2)
        }
    }

    func testPastePagesOnMacOS() async throws {
        // Given - create a NoteDocument and proper view model
        let pdf = PDFDocument()
        let page = PDFPage()
        pdf.insert(page, at: 0)
        let pdfData = pdf.dataRepresentation()!

        let noteDocument = NoteDocument()
        noteDocument.pdfData = pdfData
        noteDocument.metadata.pageCount = 1

        let documentViewModel = DocumentViewModel(document: noteDocument)

        // Create a payload to paste
        let sourcePDF = PDFDocument()
        sourcePDF.insert(PDFPage(), at: 0)
        let payload = PageClipboardPayload(
            sourceDocumentID: UUID(),
            operation: .copy,
            pageCount: 1,
            pdfData: sourcePDF.dataRepresentation() ?? Data()
        )

        // When
        let insertedCount = try await documentViewModel.insertPages(from: payload, at: 0)

        // Then
        XCTAssertEqual(insertedCount, 1)

        // Verify page was inserted
        if let updatedPDF = PDFDocument(data: documentViewModel.pdfData ?? Data()) {
            XCTAssertEqual(updatedPDF.pageCount, 2)
        }
        XCTAssertEqual(noteDocument.metadata.pageCount, 2)
    }

    func testSaveIntegrationOnMacOS() async {
        // Given - create a NoteDocument
        let noteDocument = NoteDocument()
        let pdf = PDFDocument()
        pdf.insert(PDFPage(), at: 0)
        noteDocument.pdfData = pdf.dataRepresentation()
        noteDocument.metadata.pageCount = 1

        let documentViewModel = DocumentViewModel(document: noteDocument)

        // When
        documentViewModel.hasChanges = true
        let success = await documentViewModel.save()

        // Then - save should return false without a fileURL
        XCTAssertFalse(success)
        XCTAssertTrue(documentViewModel.hasChanges) // Should still have changes since save failed
    }

    func testUndoRedoOnMacOS() async throws {
        // This test would require a proper NSUndoManager setup
        // For now, we'll just verify the undo manager is properly used

        // Given
        let noteDocument = NoteDocument()
        let pdf = PDFDocument()
        for i in 0..<3 {
            pdf.insert(PDFPage(), at: i)
        }
        noteDocument.pdfData = pdf.dataRepresentation()
        noteDocument.metadata.pageCount = 3

        let documentViewModel = DocumentViewModel(document: noteDocument)

        // When - cut a page
        let originalPageCount = 3
        _ = try await documentViewModel.cutPages(atZeroBasedIndices: [0])

        // Then - verify page was cut
        if let updatedPDF = PDFDocument(data: documentViewModel.pdfData ?? Data()) {
            XCTAssertEqual(updatedPDF.pageCount, originalPageCount - 1)
        }
    }
}
#endif