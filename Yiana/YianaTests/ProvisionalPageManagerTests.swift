import XCTest
import PDFKit
import CoreGraphics
#if os(iOS)
import UIKit
#else
import AppKit
#endif
@testable import Yiana

final class ProvisionalPageManagerTests: XCTestCase {

    func testCombinedDataAppendsProvisionalPage() async throws {
        let manager = ProvisionalPageManager()
        let baseData = makePDF(with: "Base")
        let provisionalData = makePDF(with: "Draft")

        await manager.updateProvisionalData(provisionalData)
        let result = await manager.combinedData(using: baseData)

        guard let combinedData = result.data,
              let combinedDocument = PDFDocument(data: combinedData) else {
            return XCTFail("Expected combined PDF data")
        }
        XCTAssertEqual(combinedDocument.pageCount, 2, "Combined document should have two pages")
        XCTAssertEqual(result.provisionalRange, 1..<2, "Provisional page should appear after saved pages")
    }

    func testClearingProvisionalReturnsSavedDocument() async throws {
        let manager = ProvisionalPageManager()
        let baseData = makePDF(with: "Saved")
        await manager.updateProvisionalData(nil)

        let result = await manager.combinedData(using: baseData)
        XCTAssertEqual(result.data, baseData)
        XCTAssertNil(result.provisionalRange)
    }

    private func makePDF(with text: String) -> Data {
        #if os(iOS)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        return renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14)
            ]
            (text as NSString).draw(at: CGPoint(x: 24, y: 24), withAttributes: attributes)
        }
        #else
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 200, height: 200)
        guard let consumer = CGDataConsumer(data: data) else {
            return Data()
        }
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        context.beginPDFPage(nil)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 14)
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: 24, y: 176)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()
        return data as Data
        #endif
    }
}
