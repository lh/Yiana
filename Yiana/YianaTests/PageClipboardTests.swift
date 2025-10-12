//
//  PageClipboardTests.swift
//  YianaTests
//

import XCTest
import PDFKit
@testable import Yiana

@MainActor
class PageClipboardTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear clipboard before each test
        PageClipboard.shared.clear()
    }

    override func tearDown() {
        // Clean up after each test
        PageClipboard.shared.clear()
        super.tearDown()
    }

    // MARK: - Payload Creation Tests

    func testCreatePayloadWithValidData() throws {
        // Given
        let pdfData = createSamplePDFData(pageCount: 3)
        let indices: Set<Int> = [0, 2]
        let documentID = UUID()

        // When
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .copy
        )

        // Then
        XCTAssertEqual(payload.sourceDocumentID, documentID)
        XCTAssertEqual(payload.operation, .copy)
        XCTAssertEqual(payload.pageCount, 2)
        XCTAssertNotNil(payload.pdfData)

        // Verify extracted PDF has correct page count
        if let extractedPDF = PDFDocument(data: payload.pdfData) {
            XCTAssertEqual(extractedPDF.pageCount, 2)
        } else {
            XCTFail("Failed to create PDF from payload data")
        }
    }

    func testCreatePayloadWithEmptyIndices() {
        // Given
        let pdfData = createSamplePDFData(pageCount: 3)
        let indices: Set<Int> = []
        let documentID = UUID()

        // When/Then
        XCTAssertThrowsError(
            try PageClipboard.shared.createPayload(
                from: pdfData,
                indices: indices,
                documentID: documentID,
                operation: .copy
            )
        ) { error in
            XCTAssertEqual(error as? PageOperationError, PageOperationError.noValidPagesSelected)
        }
    }

    func testCreatePayloadWithInvalidIndices() throws {
        // Given
        let pdfData = createSamplePDFData(pageCount: 2)
        let indices: Set<Int> = [0, 5, 10]  // Indices beyond page count
        let documentID = UUID()

        // When
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .copy
        )

        // Then - Should only extract valid page (index 0)
        XCTAssertEqual(payload.pageCount, 1)
        // Note: PDFDocument(data:) may not work with programmatically created empty pages
        // So we just verify the count in the payload
    }

    func testCreatePayloadExceedsHardLimit() {
        // Given
        let pdfData = createSamplePDFData(pageCount: 250)
        let indices = Set(0..<201)  // Exceeds hard limit of 200
        let documentID = UUID()

        // When/Then
        XCTAssertThrowsError(
            try PageClipboard.shared.createPayload(
                from: pdfData,
                indices: indices,
                documentID: documentID,
                operation: .copy
            )
        ) { error in
            if case PageOperationError.selectionTooLarge(let limit) = error {
                XCTAssertEqual(limit, PageOperationLimits.hardLimit)
            } else {
                XCTFail("Expected selectionTooLarge error")
            }
        }
    }

    func testCreatePayloadWithNilData() {
        // Given
        let indices: Set<Int> = [0, 1]
        let documentID = UUID()

        // When/Then
        XCTAssertThrowsError(
            try PageClipboard.shared.createPayload(
                from: nil,
                indices: indices,
                documentID: documentID,
                operation: .copy
            )
        ) { error in
            XCTAssertEqual(error as? PageOperationError, PageOperationError.sourceDocumentUnavailable)
        }
    }

    // MARK: - Clipboard Operations Tests

    func testSetAndGetPayload() throws {
        // Given
        let pdfData = createSamplePDFData(pageCount: 2)
        let indices: Set<Int> = [0, 1]
        let documentID = UUID()
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .copy
        )

        // When
        PageClipboard.shared.setPayload(payload)

        // Then
        XCTAssertTrue(PageClipboard.shared.hasPayload)
        let retrievedPayload = PageClipboard.shared.currentPayload()
        XCTAssertNotNil(retrievedPayload)
        XCTAssertEqual(retrievedPayload?.id, payload.id)
        XCTAssertEqual(retrievedPayload?.pageCount, payload.pageCount)
        XCTAssertEqual(retrievedPayload?.operation, payload.operation)
    }

    func testClearPayload() throws {
        // Given
        let pdfData = createSamplePDFData(pageCount: 1)
        let indices: Set<Int> = [0]
        let documentID = UUID()
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .copy
        )
        PageClipboard.shared.setPayload(payload)

        // When
        PageClipboard.shared.clear()

        // Then
        XCTAssertFalse(PageClipboard.shared.hasPayload)
        XCTAssertNil(PageClipboard.shared.currentPayload())
    }

    func testActiveCutPayload() throws {
        // Given
        let pdfData = createSamplePDFData(pageCount: 2)
        let indices: Set<Int> = [1]
        let documentID = UUID()
        let cutPayload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .cut,
            sourceDataBeforeCut: pdfData
        )
        PageClipboard.shared.setPayload(cutPayload)

        // When
        let retrievedForSameDoc = PageClipboard.shared.activeCutPayload(for: documentID)
        let retrievedForDifferentDoc = PageClipboard.shared.activeCutPayload(for: UUID())

        // Then
        XCTAssertNotNil(retrievedForSameDoc)
        XCTAssertEqual(retrievedForSameDoc?.id, cutPayload.id)
        XCTAssertNil(retrievedForDifferentDoc)
    }

    // MARK: - Payload Serialization Tests

    func testPayloadSerialization() throws {
        // Given
        let originalPayload = PageClipboardPayload(
            version: 1,
            id: UUID(),
            sourceDocumentID: UUID(),
            operation: .copy,
            pageCount: 3,
            pdfData: Data("test pdf data".utf8),
            createdAt: Date(),
            sourceDataBeforeCut: nil,
            cutIndices: nil
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalPayload)
        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(PageClipboardPayload.self, from: data)

        // Then
        XCTAssertEqual(decodedPayload.id, originalPayload.id)
        XCTAssertEqual(decodedPayload.version, originalPayload.version)
        XCTAssertEqual(decodedPayload.sourceDocumentID, originalPayload.sourceDocumentID)
        XCTAssertEqual(decodedPayload.operation, originalPayload.operation)
        XCTAssertEqual(decodedPayload.pageCount, originalPayload.pageCount)
        XCTAssertEqual(decodedPayload.pdfData, originalPayload.pdfData)
    }

    func testCutPayloadWithIndices() throws {
        // Given
        let pdfData = createSamplePDFData(pageCount: 5)
        let indices: Set<Int> = [1, 3, 4]
        let documentID = UUID()

        // When
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .cut,
            sourceDataBeforeCut: pdfData
        )

        // Then
        XCTAssertEqual(payload.operation, .cut)
        XCTAssertNotNil(payload.sourceDataBeforeCut)
        XCTAssertEqual(payload.cutIndices, [1, 3, 4])
        XCTAssertEqual(payload.pageCount, 3)
    }

    // MARK: - Chunking Tests

    func testLargeSelectionUsesChunking() throws {
        // Given - Create selection larger than warning threshold
        let pageCount = PageOperationLimits.warningThreshold + 10
        let pdfData = createSamplePDFData(pageCount: pageCount)
        let indices = Set(0..<pageCount)
        let documentID = UUID()

        // When
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .copy
        )

        // Then
        XCTAssertEqual(payload.pageCount, pageCount)
        if let extractedPDF = PDFDocument(data: payload.pdfData) {
            XCTAssertEqual(extractedPDF.pageCount, pageCount)
        } else {
            XCTFail("Failed to create PDF from payload data")
        }
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

// MARK: - Array Extension Tests

class ArrayChunkingTests: XCTestCase {

    func testChunkingWithExactDivision() {
        // Given
        let array = Array(1...10)

        // When
        let chunks = array.chunked(into: 5)

        // Then
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(Array(chunks[0]), [1, 2, 3, 4, 5])
        XCTAssertEqual(Array(chunks[1]), [6, 7, 8, 9, 10])
    }

    func testChunkingWithRemainder() {
        // Given
        let array = Array(1...12)

        // When
        let chunks = array.chunked(into: 5)

        // Then
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(Array(chunks[0]), [1, 2, 3, 4, 5])
        XCTAssertEqual(Array(chunks[1]), [6, 7, 8, 9, 10])
        XCTAssertEqual(Array(chunks[2]), [11, 12])
    }

    func testChunkingWithEmptyArray() {
        // Given
        let array: [Int] = []

        // When
        let chunks = array.chunked(into: 5)

        // Then
        XCTAssertEqual(chunks.count, 0)
    }

    func testChunkingWithZeroSize() {
        // Given
        let array = [1, 2, 3]

        // When
        let chunks = array.chunked(into: 0)

        // Then
        XCTAssertEqual(chunks.count, 0)
    }

    func testChunkingWithSingleElement() {
        // Given
        let array = [42]

        // When
        let chunks = array.chunked(into: 10)

        // Then
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(Array(chunks[0]), [42])
    }
}