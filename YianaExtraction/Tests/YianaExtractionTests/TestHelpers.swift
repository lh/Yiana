import Foundation
import Testing
@testable import YianaExtraction

/// Load an OCR fixture and return ExtractionInput for a specific page.
func loadOCRFixture(_ documentId: String, page pageNumber: Int) throws -> ExtractionInput {
    guard let url = Bundle.module.url(
        forResource: documentId,
        withExtension: "json",
        subdirectory: "Fixtures/input_ocr"
    ) else {
        throw FixtureError.fileNotFound("input_ocr/\(documentId).json")
    }

    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let pages = json["pages"] as! [[String: Any]]

    guard let ocrPage = pages.first(where: { ($0["pageNumber"] as? Int) == pageNumber }) else {
        throw FixtureError.pageNotFound(documentId, pageNumber)
    }

    let text = ocrPage["text"] as? String ?? ""
    let confidence = ocrPage["confidence"] as? Double ?? 0.85

    return ExtractionInput(
        documentId: documentId,
        pageNumber: pageNumber,
        text: text,
        confidence: confidence
    )
}

/// Load expected address output for a document.
func loadExpectedAddresses(_ documentId: String) throws -> DocumentAddressFile {
    guard let url = Bundle.module.url(
        forResource: documentId,
        withExtension: "json",
        subdirectory: "Fixtures/expected_addresses"
    ) else {
        throw FixtureError.fileNotFound("expected_addresses/\(documentId).json")
    }

    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(DocumentAddressFile.self, from: data)
}

/// Get the expected page entry for a specific page number.
func loadExpectedPage(_ documentId: String, page pageNumber: Int) throws -> AddressPageEntry {
    let file = try loadExpectedAddresses(documentId)
    guard let page = file.pages.first(where: { $0.pageNumber == pageNumber }) else {
        throw FixtureError.pageNotFound(documentId, pageNumber)
    }
    return page
}

enum FixtureError: Error {
    case fileNotFound(String)
    case pageNotFound(String, Int)
}
