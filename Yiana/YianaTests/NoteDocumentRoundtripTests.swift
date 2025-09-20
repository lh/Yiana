import XCTest
import UniformTypeIdentifiers
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
}

