import XCTest
import PDFKit
import YianaDocumentArchive
@testable import Yiana

final class ImportServiceTests: XCTestCase {

    func testAppendMergesAndUpdatesMetadata() throws {
        // Arrange: existing 1-page document
        let tmp = try TempDir.makeUnique()
        let existingURL = tmp.appendingPathComponent("Existing").appendingPathExtension("yianazip")

        let existingPDF = TestPDFFactory.makePDFData(pageCount: 1)
        let meta = DocumentMetadata(id: UUID(),
                                    title: "Existing",
                                    created: Date(timeIntervalSince1970: 0),
                                    modified: Date(timeIntervalSince1970: 0),
                                    pageCount: 1,
                                    tags: [],
                                    ocrCompleted: true,
                                    fullText: nil)
        try writeArchive(metadata: meta, pdfData: existingPDF, to: existingURL)

        // Arrange: new 2-page PDF to append
        let importPDFURL = tmp.appendingPathComponent("Append").appendingPathExtension("pdf")
        let appendPDF = TestPDFFactory.makePDFData(pageCount: 2)
        try appendPDF.write(to: importPDFURL)

        // Act
        let service = ImportService()
        _ = try service.importPDF(from: importPDFURL, mode: .appendToExisting(targetURL: existingURL))

        // Assert: read merged file and inspect
        let payload = try DocumentArchive.read(from: existingURL)
        let decoded = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)

        XCTAssertEqual(decoded.title, "Existing")
        XCTAssertEqual(decoded.pageCount, 3, "Page count should update to 3 after append")
        XCTAssertFalse(decoded.ocrCompleted, "OCR should be marked incomplete after content changes")
        XCTAssertGreaterThan(decoded.modified.timeIntervalSince1970, 0)
        // Basic PDF sanity
        XCTAssertGreaterThan(payload.pdfData?.count ?? 0, 0)
    }

    func testAppendInvalidPDFThrows() throws {
        let tmp = try TempDir.makeUnique()
        let existingURL = tmp.appendingPathComponent("Doc").appendingPathExtension("yianazip")

        // Create a minimal valid yianazip with empty PDF payload
        let meta = DocumentMetadata(id: UUID(), title: "Doc", created: Date(), modified: Date(), pageCount: 0, tags: [], ocrCompleted: false)
        try writeArchive(metadata: meta, pdfData: nil, to: existingURL)

        // Create a bogus PDF file
        let bogus = tmp.appendingPathComponent("bogus").appendingPathExtension("pdf")
        try Data([0x00, 0x01, 0x02]).write(to: bogus)

        let service = ImportService()
        XCTAssertThrowsError(try service.importPDF(from: bogus, mode: .appendToExisting(targetURL: existingURL)))
    }

    func testCreateNewDocumentFromPDF() throws {
        // Arrange: Create a PDF to import
        let tmp = try TempDir.makeUnique()
        let pdfURL = tmp.appendingPathComponent("Import").appendingPathExtension("pdf")
        let pdfData = TestPDFFactory.makePDFData(pageCount: 3)
        try pdfData.write(to: pdfURL)

        // Act: Import as new document
        let service = ImportService()
        let result = try service.importPDF(from: pdfURL, mode: .createNew(title: "My Imported Doc"))

        // Assert: Check created file
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))

        let payload = try DocumentArchive.read(from: result.url)
        let metadata = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)

        XCTAssertEqual(metadata.title, "My Imported Doc")
        XCTAssertEqual(metadata.pageCount, 3)
        XCTAssertFalse(metadata.ocrCompleted)
        let savedPDF = try XCTUnwrap(payload.pdfData)
        XCTAssertGreaterThan(savedPDF.count, 0)

        // Verify PDF is valid
        XCTAssertNotNil(PDFDocument(data: savedPDF))
    }

    func testAppendPreservesExistingPages() throws {
        // Arrange: Create document with 2 pages
        let tmp = try TempDir.makeUnique()
        let existingURL = tmp.appendingPathComponent("Doc").appendingPathExtension("yianazip")

        let originalPDF = TestPDFFactory.makePDFData(pageCount: 2)
        let meta = DocumentMetadata(id: UUID(),
                                    title: "Original",
                                    created: Date(),
                                    modified: Date(),
                                    pageCount: 2,
                                    tags: ["test"],
                                    ocrCompleted: false)
        try writeArchive(metadata: meta, pdfData: originalPDF, to: existingURL)

        // Arrange: New PDF with 1 page
        let importURL = tmp.appendingPathComponent("New").appendingPathExtension("pdf")
        let newPDF = TestPDFFactory.makePDFData(pageCount: 1)
        try newPDF.write(to: importURL)

        // Act: Append
        let service = ImportService()
        _ = try service.importPDF(from: importURL, mode: .appendToExisting(targetURL: existingURL))

        // Assert: Load and verify
        let payload = try DocumentArchive.read(from: existingURL)
        let mergedPDF = try XCTUnwrap(PDFDocument(data: payload.pdfData ?? Data()))

        XCTAssertEqual(mergedPDF.pageCount, 3, "Should have 2 original + 1 new = 3 pages")
    }

    func testAppendResetsOCRFlag() throws {
        // Arrange: Document with OCR completed
        let tmp = try TempDir.makeUnique()
        let existingURL = tmp.appendingPathComponent("Doc").appendingPathExtension("yianazip")

        let pdf = TestPDFFactory.makePDFData(pageCount: 1)
        let meta = DocumentMetadata(id: UUID(),
                                    title: "Completed",
                                    created: Date(),
                                    modified: Date(),
                                    pageCount: 1,
                                    tags: [],
                                    ocrCompleted: true,  // OCR was completed
                                    fullText: "Some text")
        try writeArchive(metadata: meta, pdfData: pdf, to: existingURL)

        // Arrange: New PDF to append
        let importURL = tmp.appendingPathComponent("New").appendingPathExtension("pdf")
        let newPDF = TestPDFFactory.makePDFData(pageCount: 1)
        try newPDF.write(to: importURL)

        // Act: Append
        let service = ImportService()
        _ = try service.importPDF(from: importURL, mode: .appendToExisting(targetURL: existingURL))

        // Assert: OCR flag should be reset
        let payload = try DocumentArchive.read(from: existingURL)
        let updatedMeta = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)

        XCTAssertFalse(updatedMeta.ocrCompleted, "OCR should be marked incomplete after appending new content")
        XCTAssertEqual(updatedMeta.pageCount, 2)
    }

    func testAppendUpdatesModifiedDate() throws {
        // Arrange: Document with old modified date
        let tmp = try TempDir.makeUnique()
        let existingURL = tmp.appendingPathComponent("Doc").appendingPathExtension("yianazip")

        let oldDate = Date(timeIntervalSince1970: 1000)
        let pdf = TestPDFFactory.makePDFData(pageCount: 1)
        let meta = DocumentMetadata(id: UUID(),
                                    title: "Old",
                                    created: oldDate,
                                    modified: oldDate,
                                    pageCount: 1,
                                    tags: [],
                                    ocrCompleted: false)
        try writeArchive(metadata: meta, pdfData: pdf, to: existingURL)

        // Wait a moment to ensure time difference
        Thread.sleep(forTimeInterval: 0.1)

        // Arrange: New PDF
        let importURL = tmp.appendingPathComponent("New").appendingPathExtension("pdf")
        let newPDF = TestPDFFactory.makePDFData(pageCount: 1)
        try newPDF.write(to: importURL)

        // Act: Append
        let service = ImportService()
        _ = try service.importPDF(from: importURL, mode: .appendToExisting(targetURL: existingURL))

        // Assert: Modified date should be updated
        let payload = try DocumentArchive.read(from: existingURL)
        let updatedMeta = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)

        XCTAssertGreaterThan(updatedMeta.modified, oldDate, "Modified date should be updated to current time")
    }
}

private func writeArchive(metadata: DocumentMetadata, pdfData: Data?, to url: URL) throws {
    let metadataData = try JSONEncoder().encode(metadata)
    try DocumentArchive.write(
        metadata: metadataData,
        pdf: pdfData.map { .data($0) },
        to: url,
        formatVersion: DocumentArchive.currentFormatVersion
    )
}
