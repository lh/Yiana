import XCTest
import YianaDocumentArchive
@testable import Yiana

@MainActor
final class OCRSearchTests: XCTestCase {
    func testOCRSearchFindsMatchAndReportsOneBasedPage() async throws {
        let docsDir = try TempDir.makeUnique()
        let repo = DocumentRepository(documentsDirectory: docsDir)
        let vm = DocumentListViewModel(repository: repo)

        // Create a document file (minimal yianazip with empty PDF payload)
        let docURL = docsDir.appendingPathComponent("Clinic Note").appendingPathExtension("yianazip")
        let meta = DocumentMetadata(id: UUID(), title: "Clinic Note", created: Date(), modified: Date(), pageCount: 2, tags: [], ocrCompleted: false, fullText: nil)
        try DocumentArchive.write(
            metadata: JSONEncoder().encode(meta),
            pdf: nil,
            to: docURL,
            formatVersion: DocumentArchive.currentFormatVersion
        )

        // Create OCR JSON under .ocr_results
        let relPath = "" // root
        let ocrDir = docsDir.appendingPathComponent(".ocr_results").appendingPathComponent(relPath)
        try FileManager.default.createDirectory(at: ocrDir, withIntermediateDirectories: true)
        let baseName = docURL.deletingPathExtension().lastPathComponent
        let ocrJSON = [
            "pages": [
                ["pageNumber": 1, "text": "Patient seen by Dr Smith"],
                ["pageNumber": 2, "text": "Follow up appointment"],
            ]
        ] as [String : Any]
        let jsonData = try JSONSerialization.data(withJSONObject: ocrJSON)
        try jsonData.write(to: ocrDir.appendingPathComponent("\(baseName).json"))

        // Load and search
        await vm.loadDocuments()
        await vm.filterDocuments(searchText: "Dr Smith")

        // Assert a search result exists with pageNumber 1
        let match = vm.searchResults.first { $0.documentURL == docURL }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.pageNumber, 1)
        XCTAssertEqual(match?.matchType == .content || match?.matchType == .both, true)
    }
}
