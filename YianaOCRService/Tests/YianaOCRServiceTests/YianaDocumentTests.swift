import XCTest
@testable import YianaOCRService

final class YianaDocumentTests: XCTestCase {
    private let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])

    func testParseBinaryYianazip() throws {
        // Build binary format: metadata JSON + separator + PDF bytes
        let meta = DocumentMetadata(title: "Test Doc", pageCount: 2, ocrCompleted: false)
        let metaData = try JSONEncoder().encode(meta)
        var raw = Data()
        raw.append(metaData)
        raw.append(separator)
        raw.append(Data([0x25, 0x50, 0x44, 0x46])) // "%PDF" header bytes (minimal)

        let doc = try YianaDocument(data: raw)
        XCTAssertEqual(doc.metadata.title, "Test Doc")
        XCTAssertEqual(doc.metadata.pageCount, 2)
        XCTAssertNotNil(doc.pdfData)
    }

    func testParsePureJSONMetadata() throws {
        let meta = DocumentMetadata(title: "JSON Only", pageCount: 0, ocrCompleted: true)
        let data = try JSONEncoder().encode(meta)
        let doc = try YianaDocument(data: data)
        XCTAssertEqual(doc.metadata.title, "JSON Only")
        XCTAssertNil(doc.pdfData)
    }
}

