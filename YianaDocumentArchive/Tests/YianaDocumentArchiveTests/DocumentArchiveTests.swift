import XCTest
@testable import YianaDocumentArchive

final class DocumentArchiveTests: XCTestCase {
    func testWriteAndReadRoundTrip() throws {
        let metadata = Data("{\"title\":\"Test\"}".utf8)
        let pdfData = Data([0x25, 0x50, 0x44, 0x46, 0x2D])

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yianazip")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try DocumentArchive.write(metadata: metadata, pdf: .data(pdfData), to: tempURL)
        let payload = try DocumentArchive.read(from: tempURL)

        XCTAssertEqual(payload.metadata, metadata)
        XCTAssertEqual(payload.pdfData, pdfData)
        XCTAssertEqual(payload.formatVersion, DocumentArchive.currentFormatVersion)
    }

    func testWriteAndReadMetadataOnly() throws {
        let metadata = Data("{\"title\":\"No PDF\"}".utf8)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yianazip")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try DocumentArchive.write(metadata: metadata, pdf: nil, to: tempURL)
        let payload = try DocumentArchive.read(from: tempURL)

        XCTAssertEqual(payload.metadata, metadata)
        XCTAssertNil(payload.pdfData)
    }

    func testReadFromData() throws {
        let metadata = Data("{\"title\":\"Inline\"}".utf8)
        let pdfData = Data([0x25, 0x50, 0x44, 0x46])

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yianazip")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try DocumentArchive.write(metadata: metadata, pdf: .data(pdfData), to: tempURL)
        let archiveData = try Data(contentsOf: tempURL)

        let payload = try DocumentArchive.read(from: archiveData)
        XCTAssertEqual(payload.metadata, metadata)
        XCTAssertEqual(payload.pdfData, pdfData)
    }
}
