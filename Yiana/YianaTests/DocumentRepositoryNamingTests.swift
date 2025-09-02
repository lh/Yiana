import XCTest
@testable import Yiana

final class DocumentRepositoryNamingTests: XCTestCase {
    func testUniqueNameGeneration() throws {
        let dir = try TempDir.makeUnique()
        let repo = DocumentRepository(documentsDirectory: dir)

        // First URL
        let u1 = repo.newDocumentURL(title: "Report")
        // Simulate existing file
        FileManager.default.createFile(atPath: u1.path, contents: Data())

        // Next URL should add suffix
        let u2 = repo.newDocumentURL(title: "Report")
        XCTAssertNotEqual(u1, u2)
        XCTAssertTrue(u2.lastPathComponent.contains("Report 1"))
    }

    func testFiltersOnlyYianazip() throws {
        let dir = try TempDir.makeUnique()
        let repo = DocumentRepository(documentsDirectory: dir)

        let y1 = dir.appendingPathComponent("A").appendingPathExtension("yianazip")
        let y2 = dir.appendingPathComponent("B").appendingPathExtension("yianazip")
        let other = dir.appendingPathComponent("C").appendingPathExtension("pdf")
        FileManager.default.createFile(atPath: y1.path, contents: Data())
        FileManager.default.createFile(atPath: y2.path, contents: Data())
        FileManager.default.createFile(atPath: other.path, contents: Data())

        let urls = repo.documentURLs()
        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls.contains(y1))
        XCTAssertTrue(urls.contains(y2))
    }
}

