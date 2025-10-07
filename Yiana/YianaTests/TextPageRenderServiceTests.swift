import XCTest
import PDFKit
@testable import Yiana

final class TextPageRenderServiceTests: XCTestCase {

    override func setUp() async throws {
        await TextPageLayoutSettings.shared.setPreferredPaperSize(.a4)
    }

    func testRenderProducesPDFData() async throws {
        let service = TextPageRenderService.shared
        let fixedDate = ISO8601DateFormatter().date(from: "2026-01-12T00:00:00Z") ?? Date()
        let output = try await service.render(markdown: "# Heading\n\nThis is **bold** text.", on: fixedDate)

        XCTAssertFalse(output.pdfData.isEmpty)
        XCTAssertTrue(output.plainText.contains("Page added"))
        XCTAssertTrue(output.plainText.contains("Heading"))
    }

    func testRenderAndAppendAddsPage() async throws {
        let service = TextPageRenderService.shared
        let first = try await service.render(markdown: "Initial text body.")
        let combined = try await service.renderAndAppend(markdown: "Second note body", existingPDFData: first.pdfData)

        XCTAssertFalse(combined.combinedPDF.isEmpty)
        XCTAssertEqual(combined.addedPages, 1)
        XCTAssertFalse(combined.renderedPagePDF.isEmpty)

        let pdfDocument = PDFDocument(data: combined.combinedPDF)
        XCTAssertEqual(pdfDocument?.pageCount, 2)
        XCTAssertTrue(combined.plainText.contains("Page added"))
        XCTAssertTrue(combined.plainText.contains("Second note body"))
        let lastPageText = pdfDocument?.page(at: 1)?.string ?? ""
        XCTAssertTrue(lastPageText.contains("Second note body"))
    }
}
