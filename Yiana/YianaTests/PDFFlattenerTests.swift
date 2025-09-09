
import XCTest
import PDFKit
@testable import Yiana

class PDFFlattenerTests: XCTestCase {

    var flattener: PDFFlattener!

    override func setUp() {
        super.setUp()
        flattener = PDFFlattener()
    }

    override func tearDown() {
        flattener = nil
        super.tearDown()
    }

    /// Tests that a basic annotation is successfully flattened onto a page.
    func testBasicFlattening() {
        // 1. Create a sample PDF page.
        let originalPage = PDFPage()

        // 2. Create and add a sample text annotation to the original page.
        let annotationBounds = CGRect(x: 100, y: 100, width: 200, height: 50)
        let annotation = PDFAnnotation(bounds: annotationBounds, forType: .freeText, withProperties: nil)
        annotation.contents = "Hello, World!"
        originalPage.addAnnotation(annotation)
        
        XCTAssertEqual(originalPage.annotations.count, 1, "Original page should have 1 annotation before flattening.")

        // 3. Flatten the page with the annotation.
        let newPage = flattener.flattenAnnotations(on: originalPage, annotations: [annotation])

        // 4. Verify the new page is not nil.
        XCTAssertNotNil(newPage, "Flattening should produce a new page.")

        // 5. Verify that the new page has no annotation objects, as they have been flattened.
        XCTAssertEqual(newPage?.annotations.count, 0, "The new page should have 0 annotations after flattening.")
    }

    /// Tests that the searchable text layer of a page is preserved after flattening.
    func testTextLayerPreservation() {
        // 1. Create a sample PDF page with known searchable text using CoreGraphics and AppKit.
        let knownText = "This is the searchable text on the original page."
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size

        let pdfData = NSMutableData()
        var mediaBox = pageBounds
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            XCTFail("Failed to create PDF context for test.")
            return
        }

        context.beginPDFPage(nil)
        
        // Use AppKit/CoreText to draw a string, creating a text layer.
        let attributedString = NSAttributedString(string: knownText, attributes: [.font: NSFont.systemFont(ofSize: 24)])
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let framePath = CGPath(rect: pageBounds.insetBy(dx: 72, dy: 72), transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attributedString.length), framePath, nil)
        CTFrameDraw(frame, context)

        context.endPDFPage()
        context.closePDF()

        guard let document = PDFDocument(data: pdfData as Data),
              let originalPage = document.page(at: 0) else {
            XCTFail("Failed to create sample PDF page with text.")
            return
        }
        
        // Sanity check that the original page has the text.
        XCTAssertTrue(originalPage.string?.contains(knownText) ?? false, "Test setup failed: Original page should contain the known text.")

        // 2. Create and add a sample annotation.
        let annotation = PDFAnnotation(bounds: CGRect(x: 72, y: 72, width: 100, height: 20), forType: .highlight, withProperties: nil)
        originalPage.addAnnotation(annotation)

        // 3. Flatten the page.
        let newPage = flattener.flattenAnnotations(on: originalPage, annotations: [annotation])
        XCTAssertNotNil(newPage, "Flattening should produce a new page.")

        // 4. Assert that the new page's `string` property still contains the original text.
        XCTAssertTrue(newPage?.string?.contains(knownText) ?? false, "The flattened page should still contain the original searchable text.")
        XCTAssertEqual(newPage?.annotations.count, 0, "The flattened page should have no annotation objects.")
    }

    /// Tests that flattening a page with no annotations results in a visually identical page.
    func testFlattenWithNoAnnotations() {
        // 1. Create a sample PDF page. A blank page is sufficient for this test.
        let originalPage = PDFPage()
        let originalPageText = originalPage.string

        // 2. Flatten the page with an empty annotations array.
        let newPage = flattener.flattenAnnotations(on: originalPage, annotations: [])
        XCTAssertNotNil(newPage, "Flattening with no annotations should still produce a new page.")

        // 3. Verify the new page's content is identical to the original.
        // We check this by comparing the searchable text content, which should be unchanged.
        XCTAssertEqual(newPage?.string, originalPageText, "Page content should be identical when flattening with no annotations.")
        XCTAssertEqual(newPage?.annotations.count, 0, "New page should have no annotations.")
    }

    /// Tests that the system handles an invalid page gracefully.
    func testErrorHandlingForInvalidPage() {
        // 1. Create a mock PDFPage that returns a zero-sized bounding box,
        // which should cause the CGContext creation to fail.
        let invalidPage = MockBadPDFPage()

        // 2. Attempt to flatten the invalid page.
        let newPage = flattener.flattenAnnotations(on: invalidPage, annotations: [])

        // 3. Assert that the flatten method returns nil, handling the error gracefully.
        XCTAssertNil(newPage, "Flattening an invalid page should fail and return nil.")
    }
}

// MARK: - Helper Mocks

private class MockBadPDFPage: PDFPage {
    // By overriding bounds to return a zero rect, we can force the
    // CGContext creation in the flattener to fail, allowing us to test the error path.
    override func bounds(for box: PDFDisplayBox) -> NSRect {
        return .zero
    }
}
