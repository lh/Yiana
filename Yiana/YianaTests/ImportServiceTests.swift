import XCTest
@testable import Yiana

final class ImportServiceTests: XCTestCase {
    private let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])

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
        let metaData = try JSONEncoder().encode(meta)
        var existingData = Data()
        existingData.append(metaData)
        existingData.append(separator)
        existingData.append(existingPDF)
        try existingData.write(to: existingURL)

        // Arrange: new 2-page PDF to append
        let importPDFURL = tmp.appendingPathComponent("Append").appendingPathExtension("pdf")
        let appendPDF = TestPDFFactory.makePDFData(pageCount: 2)
        try appendPDF.write(to: importPDFURL)

        // Act
        let service = ImportService()
        _ = try service.importPDF(from: importPDFURL, mode: .appendToExisting(targetURL: existingURL))

        // Assert: read merged file and inspect
        let merged = try Data(contentsOf: existingURL)
        guard let sepRange = merged.range(of: separator) else {
            return XCTFail("Missing separator in merged document")
        }
        let metaMerged = merged.subdata(in: 0..<sepRange.lowerBound)
        let pdfMerged = merged.subdata(in: sepRange.upperBound..<merged.count)
        let decoded = try JSONDecoder().decode(DocumentMetadata.self, from: metaMerged)

        XCTAssertEqual(decoded.title, "Existing")
        XCTAssertEqual(decoded.pageCount, 3, "Page count should update to 3 after append")
        XCTAssertFalse(decoded.ocrCompleted, "OCR should be marked incomplete after content changes")
        XCTAssertGreaterThan(decoded.modified.timeIntervalSince1970, 0)
        // Basic PDF sanity
        XCTAssertGreaterThan(pdfMerged.count, 0)
    }

    func testAppendInvalidPDFThrows() throws {
        let tmp = try TempDir.makeUnique()
        let existingURL = tmp.appendingPathComponent("Doc").appendingPathExtension("yianazip")

        // Create a minimal valid yianazip with empty PDF payload
        let meta = DocumentMetadata(id: UUID(), title: "Doc", created: Date(), modified: Date(), pageCount: 0, tags: [], ocrCompleted: false)
        var data = try JSONEncoder().encode(meta)
        data.append(separator)
        try data.write(to: existingURL)

        // Create a bogus PDF file
        let bogus = tmp.appendingPathComponent("bogus").appendingPathExtension("pdf")
        try Data([0x00, 0x01, 0x02]).write(to: bogus)

        let service = ImportService()
        XCTAssertThrowsError(try service.importPDF(from: bogus, mode: .appendToExisting(targetURL: existingURL)))
    }
}

