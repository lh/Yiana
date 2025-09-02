import XCTest
@testable import YianaOCRService

final class ExporterTests: XCTestCase {
    func makeMinimalResult() -> OCRResult {
        let word = Word(text: "Hello", boundingBox: BoundingBox(x: 0, y: 0, width: 0.1, height: 0.05), confidence: 0.9)
        let line = TextLine(text: "Hello", boundingBox: BoundingBox(x: 0, y: 0, width: 0.5, height: 0.1), words: [word])
        let block = TextBlock(text: "Hello", boundingBox: BoundingBox(x: 0, y: 0, width: 1, height: 0.2), confidence: 0.9, lines: [line])
        let page = OCRPage(pageNumber: 1, text: "Hello page", textBlocks: [block], formFields: nil, confidence: 0.95)
        let meta = ProcessingMetadata(processingTime: 0.1, pageCount: 1, detectedLanguages: ["en"], warnings: [], options: .default)
        return OCRResult(id: UUID(), processedAt: Date(), documentId: UUID(), engineVersion: "1.0.0", pages: [page], extractedData: nil, confidence: 0.95, metadata: meta)
    }

    func testJSONExporterProducesJSON() throws {
        let result = makeMinimalResult()
        let data = try JSONExporter(prettyPrint: false).export(result)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["engineVersion"] as? String, "1.0.0")
    }

    func testXMLExporterProducesXML() throws {
        let result = makeMinimalResult()
        let data = try XMLExporter().export(result)
        let xml = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("<OCRResult>"))
        XCTAssertTrue(xml.contains("<Pages>"))
        XCTAssertTrue(xml.contains("<Page number=\"1\">"))
    }

    func testHOCRExporterProducesHTML() throws {
        let result = makeMinimalResult()
        let data = try HOCRExporter().export(result)
        let html = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("ocr_page"))
        XCTAssertTrue(html.contains("ocrx_word"))
    }
}

