import XCTest
import PDFKit
@testable import Yiana

final class OnDeviceOCRServiceTests: XCTestCase {
    private let service = OnDeviceOCRService.shared

    func testRecognizesTextFromPDF() async throws {
        let pdfData = TestPDFFactory.makePDFWithText(["Hello World"])
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")

        let result = await service.recognizeText(in: pdfData)

        XCTAssertEqual(result.pageCount, 1)
        XCTAssertTrue(
            result.fullText.localizedCaseInsensitiveContains("Hello"),
            "OCR should find 'Hello' in text, got: \(result.fullText)"
        )
        XCTAssertGreaterThan(result.confidence, 0)
    }

    func testReturnsEmptyForInvalidData() async {
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let result = await service.recognizeText(in: garbage)

        XCTAssertTrue(result.fullText.isEmpty)
        XCTAssertEqual(result.pageCount, 0)
        XCTAssertEqual(result.confidence, 0)
    }

    func testMultiPageConcatenation() async throws {
        let pdfData = TestPDFFactory.makePDFWithText([
            "First Page Content",
            "Second Page Content",
            "Third Page Content"
        ])

        let result = await service.recognizeText(in: pdfData)

        XCTAssertEqual(result.pageCount, 3)
        XCTAssertTrue(
            result.fullText.localizedCaseInsensitiveContains("First"),
            "Should find text from first page"
        )
        XCTAssertTrue(
            result.fullText.localizedCaseInsensitiveContains("Third"),
            "Should find text from third page"
        )
        XCTAssertGreaterThan(result.confidence, 0)
    }

    func testReturnsEmptyForEmptyData() async {
        let result = await service.recognizeText(in: Data())
        XCTAssertTrue(result.fullText.isEmpty)
        XCTAssertEqual(result.pageCount, 0)
    }
}
