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

/// Load the first OCR page from a fixture that matches a given extraction method.
func loadFirstOCRFixtureByMethod(_ documentId: String, method: String) throws -> ExtractionInput {
    let expected = try loadExpectedAddresses(documentId)
    guard let page = expected.pages.first(where: { $0.extraction?.method == method }) else {
        throw FixtureError.methodNotFound(documentId, method)
    }
    return try loadOCRFixture(documentId, page: page.pageNumber)
}

/// Load the first expected page matching a given extraction method.
func loadExpectedPageByMethod(_ documentId: String, method: String) throws -> AddressPageEntry {
    let expected = try loadExpectedAddresses(documentId)
    guard let page = expected.pages.first(where: { $0.extraction?.method == method }) else {
        throw FixtureError.methodNotFound(documentId, method)
    }
    return page
}

/// Load all OCR pages from a fixture as ExtractionInput array.
func loadAllOCRPages(_ documentId: String) throws -> [ExtractionInput] {
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

    return pages.map { ocrPage in
        let pageNumber = ocrPage["pageNumber"] as? Int ?? 1
        let text = ocrPage["text"] as? String ?? ""
        let confidence = ocrPage["confidence"] as? Double ?? 0.85
        return ExtractionInput(
            documentId: documentId,
            pageNumber: pageNumber,
            text: text,
            confidence: confidence
        )
    }
}

enum FixtureError: Error {
    case fileNotFound(String)
    case pageNotFound(String, Int)
    case methodNotFound(String, String)
}
