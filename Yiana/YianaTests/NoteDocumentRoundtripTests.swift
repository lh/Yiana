import XCTest
import UniformTypeIdentifiers
import PDFKit
import YianaDocumentArchive
@testable import Yiana

final class NoteDocumentRoundtripTests: XCTestCase {
    func testRoundtripMetadataAndPDF() throws {
        #if os(iOS)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("yianazip")
        let doc = NoteDocument(fileURL: url)
        let pdf = TestPDFFactory.makePDFData(pageCount: 1)
        doc.pdfData = pdf
        doc.metadata = DocumentMetadata(id: UUID(), title: "Hello", created: Date(), modified: Date(), pageCount: 1, tags: [], ocrCompleted: false, fullText: nil)

        // Serialize
        let data = try XCTUnwrap(doc.contents(forType: UTType.yianaDocument.identifier) as? Data)

        // Deserialize into a new instance
        let doc2 = NoteDocument(fileURL: url)
        try doc2.load(fromContents: data, ofType: UTType.yianaDocument.identifier)

        XCTAssertEqual(doc2.metadata.title, "Hello")
        XCTAssertEqual(doc2.metadata.pageCount, 1)
        XCTAssertNotNil(doc2.pdfData)
        #else
        // macOS build of tests does not use NoteDocument
        #endif
    }

    func testRoundtripEmptyDocument() throws {
        #if os(iOS)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("yianazip")
        let doc = NoteDocument(fileURL: url)
        doc.pdfData = nil  // Empty document
        doc.metadata = DocumentMetadata(id: UUID(), title: "Empty", created: Date(), modified: Date(), pageCount: 0, tags: [], ocrCompleted: false, fullText: nil)

        // Serialize
        let data = try XCTUnwrap(doc.contents(forType: UTType.yianaDocument.identifier) as? Data)

        // Deserialize
        let doc2 = NoteDocument(fileURL: url)
        try doc2.load(fromContents: data, ofType: UTType.yianaDocument.identifier)

        XCTAssertEqual(doc2.metadata.title, "Empty")
        XCTAssertEqual(doc2.metadata.pageCount, 0)
        // pdfData should be nil or empty
        XCTAssertTrue(doc2.pdfData == nil || doc2.pdfData?.isEmpty == true)
        #else
        // macOS test
        #endif
    }

    func testRoundtripWithMetadataFields() throws {
        #if os(iOS)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("yianazip")
        let doc = NoteDocument(fileURL: url)
        let pdf = TestPDFFactory.makePDFData(pageCount: 2)
        doc.pdfData = pdf

        let testDate = Date(timeIntervalSince1970: 1234567890)
        doc.metadata = DocumentMetadata(
            id: UUID(),
            title: "Test Doc",
            created: testDate,
            modified: testDate,
            pageCount: 2,
            tags: ["tag1", "tag2"],
            ocrCompleted: true,
            fullText: "Some OCR text",
            hasPendingTextPage: false
        )

        // Serialize
        let data = try XCTUnwrap(doc.contents(forType: UTType.yianaDocument.identifier) as? Data)

        // Deserialize
        let doc2 = NoteDocument(fileURL: url)
        try doc2.load(fromContents: data, ofType: UTType.yianaDocument.identifier)

        // Verify all metadata preserved
        XCTAssertEqual(doc2.metadata.title, "Test Doc")
        XCTAssertEqual(doc2.metadata.pageCount, 2)
        XCTAssertEqual(doc2.metadata.tags, ["tag1", "tag2"])
        XCTAssertTrue(doc2.metadata.ocrCompleted)
        XCTAssertEqual(doc2.metadata.fullText, "Some OCR text")
        XCTAssertEqual(doc2.metadata.created.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 0.001)
        #else
        // macOS test
        #endif
    }

    func testMultipleRoundtripsProduceSameData() throws {
        #if os(iOS)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("yianazip")
        let doc = NoteDocument(fileURL: url)
        let pdf = TestPDFFactory.makePDFData(pageCount: 1)
        doc.pdfData = pdf
        doc.metadata = DocumentMetadata(id: UUID(), title: "Stable", created: Date(), modified: Date(), pageCount: 1, tags: [], ocrCompleted: false, fullText: nil)

        // First serialize
        let data1 = try XCTUnwrap(doc.contents(forType: UTType.yianaDocument.identifier) as? Data)

        // Load and serialize again
        let doc2 = NoteDocument(fileURL: url)
        try doc2.load(fromContents: data1, ofType: UTType.yianaDocument.identifier)
        let data2 = try XCTUnwrap(doc2.contents(forType: UTType.yianaDocument.identifier) as? Data)

        // Load and serialize a third time
        let doc3 = NoteDocument(fileURL: url)
        try doc3.load(fromContents: data2, ofType: UTType.yianaDocument.identifier)
        let data3 = try XCTUnwrap(doc3.contents(forType: UTType.yianaDocument.identifier) as? Data)

        let decoded1 = try metadata(from: data1)
        let decoded2 = try metadata(from: data2)
        let decoded3 = try metadata(from: data3)

        XCTAssertEqual(decoded1.title, decoded2.title)
        XCTAssertEqual(decoded2.title, decoded3.title)
        XCTAssertEqual(decoded1.pageCount, decoded2.pageCount)
        XCTAssertEqual(decoded2.pageCount, decoded3.pageCount)
        #else
        // macOS test
        #endif
    }

    func testRoundtripLargeDocument() throws {
        #if os(iOS)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("yianazip")
        let doc = NoteDocument(fileURL: url)

        // Create a larger PDF (50 pages)
        let pdf = TestPDFFactory.makePDFData(pageCount: 50)
        doc.pdfData = pdf
        doc.metadata = DocumentMetadata(id: UUID(), title: "Large Doc", created: Date(), modified: Date(), pageCount: 50, tags: [], ocrCompleted: false, fullText: nil)

        // Serialize
        let data = try XCTUnwrap(doc.contents(forType: UTType.yianaDocument.identifier) as? Data)

        // Verify we're handling a reasonably large file
        XCTAssertGreaterThan(data.count, 100_000, "Large document should be >100KB")

        // Deserialize
        let doc2 = NoteDocument(fileURL: url)
        try doc2.load(fromContents: data, ofType: UTType.yianaDocument.identifier)

        XCTAssertEqual(doc2.metadata.title, "Large Doc")
        XCTAssertEqual(doc2.metadata.pageCount, 50)
        XCTAssertNotNil(doc2.pdfData)

        // Verify PDF is still valid
        let loadedPDF = try XCTUnwrap(PDFDocument(data: doc2.pdfData ?? Data()))
        XCTAssertEqual(loadedPDF.pageCount, 50)
        #else
        // macOS test
        #endif
    }
}

#if os(iOS)
private func metadata(from data: Data) throws -> DocumentMetadata {
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("yianazip")
    try data.write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }
    let payload = try DocumentArchive.read(from: tempURL)
    return try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)
}
#endif
