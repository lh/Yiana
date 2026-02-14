import XCTest
import UniformTypeIdentifiers
@testable import Yiana

final class DocumentDragItemTests: XCTestCase {

    override func tearDown() {
        DocumentDragItem.inFlight = nil
        super.tearDown()
    }

    // MARK: - makeItemProvider sets inFlight

    func testMakeItemProvider_setsInFlight() {
        let originalID = UUID()
        let item = DocumentDragItem(
            id: originalID,
            documentURL: URL(fileURLWithPath: "/tmp/fake.yianazip")
        )

        XCTAssertNil(DocumentDragItem.inFlight)
        _ = item.makeItemProvider()
        XCTAssertEqual(DocumentDragItem.inFlight?.id, originalID)
    }

    // MARK: - PDF type is registered for external drops

    func testMakeItemProvider_registersPDFType() {
        let item = DocumentDragItem(
            id: UUID(),
            documentURL: URL(fileURLWithPath: "/tmp/fake.yianazip")
        )
        let provider = item.makeItemProvider()

        XCTAssertTrue(
            provider.registeredTypeIdentifiers.contains(UTType.pdf.identifier),
            "NSItemProvider should register the PDF type for external drops"
        )
    }

    // MARK: - inFlight is cleared on nil assignment

    func testInFlight_canBeCleared() {
        let item = DocumentDragItem(
            id: UUID(),
            documentURL: URL(fileURLWithPath: "/tmp/fake.yianazip")
        )
        _ = item.makeItemProvider()
        XCTAssertNotNil(DocumentDragItem.inFlight)

        DocumentDragItem.inFlight = nil
        XCTAssertNil(DocumentDragItem.inFlight)
    }

    // MARK: - Static type ID matches expected string

    func testInternalTypeID_matchesExpectedValue() {
        XCTAssertEqual(
            DocumentDragItem.internalTypeID,
            "com.vitygas.yiana.drag-item"
        )
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let originalID = UUID()
        let originalURL = URL(fileURLWithPath: "/tmp/test.yianazip")
        let item = DocumentDragItem(id: originalID, documentURL: originalURL)

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DocumentDragItem.self, from: data)

        XCTAssertEqual(decoded.id, originalID)
        XCTAssertEqual(decoded.documentURL, originalURL)
    }
}
