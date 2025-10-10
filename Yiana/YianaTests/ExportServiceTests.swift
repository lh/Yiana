import XCTest
import PDFKit
import YianaDocumentArchive
@testable import Yiana

final class ExportServiceTests: XCTestCase {

    func testExportToPDFExtractsPayload() throws {
        let tempDir = try TempDir.makeUnique()
        let sourceURL = tempDir.appendingPathComponent("Source.yianazip")
        let destinationURL = tempDir.appendingPathComponent("Output.pdf")

        // Build archive payload
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Export Me",
            created: Date(),
            modified: Date(),
            pageCount: 1,
            tags: [],
            ocrCompleted: false,
            fullText: nil
        )
        let metadataBytes = try JSONEncoder().encode(metadata)
        let pdfDocument = PDFDocument()
        pdfDocument.insert(PDFPage(), at: 0)
        let pdfBytes = try XCTUnwrap(pdfDocument.dataRepresentation())

        try DocumentArchive.write(
            metadata: metadataBytes,
            pdf: .data(pdfBytes),
            to: sourceURL,
            formatVersion: DocumentArchive.currentFormatVersion
        )

        let service = ExportService()
        try service.exportToPDF(from: sourceURL, to: destinationURL)

        let exported = try Data(contentsOf: destinationURL)
        XCTAssertEqual(exported, pdfBytes)
        XCTAssertNotNil(PDFDocument(data: exported))
    }

    func testExportFailsWithoutSeparator() throws {
        let tempDir = try TempDir.makeUnique()
        let sourceURL = tempDir.appendingPathComponent("Corrupt.yianazip")
        try Data("no separator".utf8).write(to: sourceURL)

        let service = ExportService()
        XCTAssertThrowsError(try service.exportToPDF(from: sourceURL, to: sourceURL.appendingPathExtension("pdf")))
    }
}
