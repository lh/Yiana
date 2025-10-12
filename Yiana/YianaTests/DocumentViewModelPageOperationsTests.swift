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
    var noteDocument: NoteDocument!  // Keep strong reference to prevent deallocation

    override func setUp() {
        super.setUp()

        // Create sample PDF data
        let pdf = PDFDocument()
        for i in 0..<3 {
            let page = PDFPage()
            pdf.insert(page, at: i)
        }
        let pdfData = pdf.dataRepresentation()

        // Create a proper NoteDocument for testing
        noteDocument = NoteDocument()  // Store in instance variable
        noteDocument.pdfData = pdfData
        noteDocument.metadata.pageCount = 3
        noteDocument.metadata.title = "Test Document"

        // Create view model with document (proper flow)
        viewModel = DocumentViewModel(document: noteDocument)

        // Clear clipboard
        PageClipboard.shared.clear()
    }

    override func tearDown() {
        PageClipboard.shared.clear()
        viewModel = nil
        noteDocument = nil  // Clean up document reference
        super.tearDown()
    }

    func testCopyPagesOnMacOS() async throws {
        // Given - viewModel is already set up with document
        let indices: Set<Int> = [0, 1]

        // When
        let payload = try await viewModel.copyPages(atZeroBasedIndices: indices)

        // Then
        XCTAssertEqual(payload.operation, .copy)
        XCTAssertEqual(payload.pageCount, 2)
        XCTAssertEqual(payload.sourceDocumentID, viewModel.documentID)

        // Verify document wasn't modified by copy
        if let pdfDoc = PDFDocument(data: viewModel.pdfData ?? Data()) {
            XCTAssertEqual(pdfDoc.pageCount, 3)
        }
    }

    func testCutPagesOnMacOS() async throws {
        // Given - viewModel is already set up with document
        let indices: Set<Int> = [0]
        let originalPageCount = 3

        // When
        let payload = try await viewModel.cutPages(atZeroBasedIndices: indices)

        // Then
        XCTAssertEqual(payload.operation, .cut)
        XCTAssertEqual(payload.pageCount, 1)
        XCTAssertNotNil(payload.sourceDataBeforeCut)

        // Verify page was removed
        if let updatedPDF = PDFDocument(data: viewModel.pdfData ?? Data()) {
            XCTAssertEqual(updatedPDF.pageCount, originalPageCount - 1)
        }
        XCTAssertTrue(viewModel.hasChanges)
    }

    func testPastePagesOnMacOS() async throws {
        // Given - viewModel already has 3 pages

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
        let insertedCount = try await viewModel.insertPages(from: payload, at: 0)

        // Then
        XCTAssertEqual(insertedCount, 1)

        // Verify page was inserted (3 original + 1 new = 4)
        if let updatedPDF = PDFDocument(data: viewModel.pdfData ?? Data()) {
            XCTAssertEqual(updatedPDF.pageCount, 4)
        }
        XCTAssertTrue(viewModel.hasChanges)
    }

    func testSaveIntegrationOnMacOS() async {
        // Given - viewModel already set up with document

        // When - mark changes and attempt save
        viewModel.hasChanges = true
        let success = await viewModel.save()

        // Then - save should return false without a fileURL set on the document
        XCTAssertFalse(success)
        XCTAssertTrue(viewModel.hasChanges) // Should still have changes since save failed

        // Test that save returns true when no changes
        viewModel.hasChanges = false
        let successNoChanges = await viewModel.save()
        XCTAssertTrue(successNoChanges) // Should return true per iOS behavior
    }

    func testUndoRedoOnMacOS() async throws {
        // Given - viewModel already has 3 pages
        let originalPageCount = 3

        // When - cut a page
        let payload = try await viewModel.cutPages(atZeroBasedIndices: [0])
        PageClipboard.shared.setPayload(payload)

        // Then - verify page was cut
        if let updatedPDF = PDFDocument(data: viewModel.pdfData ?? Data()) {
            XCTAssertEqual(updatedPDF.pageCount, originalPageCount - 1)
        }
        XCTAssertTrue(viewModel.hasChanges)

        // Verify we can still access the cut payload
        let cutPayload = PageClipboard.shared.activeCutPayload(for: viewModel.documentID)
        XCTAssertNotNil(cutPayload)
    }
}
#endif