import XCTest
import YianaDocumentArchive
@testable import YianaOCRService

private enum TempDir {
    static func makeUnique(subpath: String = UUID().uuidString) throws -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("YianaOCRTests", isDirectory: true)
        let url = base.appendingPathComponent(subpath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

final class YianaDocumentTests: XCTestCase {

    func testParseBinaryYianazip() throws {
        let meta = DocumentMetadata(title: "Test Doc", pageCount: 2, ocrCompleted: false)
        let metaData = try JSONEncoder().encode(meta)
        let archiveData = try makeArchiveData(metadata: metaData, pdf: Data([0x25, 0x50, 0x44, 0x46]))

        let doc = try YianaDocument(data: archiveData)
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

    func testSaveProducesZipFormat() throws {
        let tempDir = try TempDir.makeUnique()
        let url = tempDir.appendingPathComponent("Legacy.yianazip")
        let meta = DocumentMetadata(title: "Legacy Save", pageCount: 3, ocrCompleted: false)
        let pdfBytes = Data([0x25, 0x50, 0x44, 0x46, 0x0A]) // "%PDF\n"
        let document = YianaDocument(metadata: meta, pdfData: pdfBytes)

        try document.save(to: url)

        let payload = try DocumentArchive.read(from: url)
        let decoded = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)

        XCTAssertEqual(decoded.title, meta.title)
        XCTAssertEqual(decoded.pageCount, meta.pageCount)
        XCTAssertEqual(payload.pdfData, pdfBytes)
    }

    func testExportDataMatchesSaveFormat() throws {
        let meta = DocumentMetadata(title: "Export Data", pageCount: 1, ocrCompleted: true)
        let pdfBytes = Data([0x25, 0x50, 0x44, 0x46])
        let document = YianaDocument(metadata: meta, pdfData: pdfBytes)

        let raw = try document.exportData()
        let payload = try DocumentArchive.read(from: raw)
        let decoded = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)

        XCTAssertEqual(decoded.title, meta.title)
        XCTAssertEqual(payload.pdfData, pdfBytes)
    }

    private func makeArchiveData(metadata: Data, pdf: Data?) throws -> Data {
        let tempDir = try TempDir.makeUnique()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("yianazip")
        try DocumentArchive.write(
            metadata: metadata,
            pdf: pdf.map { .data($0) },
            to: tempURL,
            formatVersion: DocumentArchive.currentFormatVersion
        )
        let data = try Data(contentsOf: tempURL)
        return data
    }
}
