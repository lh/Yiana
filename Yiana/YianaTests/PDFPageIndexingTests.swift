import XCTest
import PDFKit
@testable import Yiana

final class PDFPageIndexingTests: XCTestCase {
    func testOneBasedAccessAndInsertRemove() {
        let data = TestPDFFactory.makePDFData(pageCount: 2)
        let doc = PDFDocument(data: data)!

        // 1-based getPage
        XCTAssertNotNil(doc.getPage(number: 1))
        XCTAssertNotNil(doc.getPage(number: 2))
        XCTAssertNil(doc.getPage(number: 0))
        XCTAssertNil(doc.getPage(number: 3))

        // Insert at position 1 (becomes new first page)
        let insertDoc = PDFDocument(data: TestPDFFactory.makePDFData(pageCount: 1))!
        if let page = insertDoc.page(at: 0) {
            doc.insertPage(page, at: 1)
        }
        XCTAssertEqual(doc.pageCount, 3)

        // Remove last page using 1-based index
        doc.removePage(byNumber: 3)
        XCTAssertEqual(doc.pageCount, 2)
    }
}

