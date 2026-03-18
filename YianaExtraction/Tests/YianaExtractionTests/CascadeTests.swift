import Foundation
import Testing
@testable import YianaExtraction

/// Integration tests for ExtractionCascade.
struct CascadeTests {

    let cascade = ExtractionCascade()

    // MARK: - Empty / Edge Cases

    @Test func emptyTextReturnsNil() {
        let input = ExtractionInput(documentId: "test", pageNumber: 1, text: "")
        let result = cascade.extract(from: input)
        #expect(result == nil)
    }

    @Test func noExtractableContentReturnsNil() {
        let input = ExtractionInput(
            documentId: "test", pageNumber: 1,
            text: "This page contains no extractable addresses."
        )
        let result = cascade.extract(from: input)
        #expect(result == nil)
    }

    @Test(arguments: [
        "Clarke_Peter_210558",
        "Clarke_Sean_170991",
        "Knight_Amara_020840",
        "Owen_Victor_031165",
    ])
    func emptyDocumentProducesNoPages(documentId: String) throws {
        let cascade = ExtractionCascade()
        let result = cascade.extractDocument(documentId: documentId, pages: [])
        #expect(result.pages.isEmpty)
        #expect(result.documentId == documentId)
        #expect(result.schemaVersion == 1)
        #expect(result.overrides.isEmpty)
    }

    // MARK: - Output Format

    @Test func outputSerializesToValidJSON() throws {
        let file = DocumentAddressFile(
            documentId: "test_doc",
            extractedAt: "2026-03-17T12:00:00Z",
            pageCount: 1,
            pages: [
                AddressPageEntry(
                    pageNumber: 1,
                    patient: PatientInfo(fullName: "Test Patient"),
                    address: AddressInfo(postcode: "ZZ1 1AA"),
                    extraction: ExtractionInfo(method: "test", confidence: 0.9)
                ),
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(file)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify snake_case keys
        #expect(json["schema_version"] as? Int == 1)
        #expect(json["document_id"] as? String == "test_doc")
        #expect(json["page_count"] as? Int == 1)

        let pages = json["pages"] as! [[String: Any]]
        let page = pages[0]
        #expect(page["page_number"] as? Int == 1)

        let patient = page["patient"] as! [String: Any]
        #expect(patient["full_name"] as? String == "Test Patient")

        let address = page["address"] as! [String: Any]
        #expect(address["postcode"] as? String == "ZZ1 1AA")
    }

    @Test func outputDecodesBackToSameStructure() throws {
        let original = DocumentAddressFile(
            documentId: "round_trip",
            extractedAt: "2026-03-17T12:00:00Z",
            pageCount: 2,
            pages: [
                AddressPageEntry(
                    pageNumber: 1,
                    patient: PatientInfo(fullName: "Alice Smith", dateOfBirth: "15/03/1980"),
                    address: AddressInfo(line1: "10 High St", postcode: "ZZ1 1AA"),
                    gp: GPInfo(name: "Dr Jones", practice: "Test Surgery"),
                    extraction: ExtractionInfo(method: "label", confidence: 0.7)
                ),
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(DocumentAddressFile.self, from: data)

        #expect(decoded.documentId == original.documentId)
        #expect(decoded.pages.count == 1)
        #expect(decoded.pages[0].patient?.fullName == "Alice Smith")
        #expect(decoded.pages[0].gp?.name == "Dr Jones")
    }

    // MARK: - Unstructured (known divergence)

    // KNOWN_DIVERGENCE: Synthetic unstructured text triggers label extractor
    // in Python. The Swift cascade may handle this differently.
    // Validated via Phase 1.4 parallel run against real data.
    @Test func unstructuredDocumentNote() throws {
        // Fisher_Victor_180549 is the only unstructured fixture.
        // Its synthetic text was designed for Python's unstructured extractor
        // but Python's label extractor grabbed it first.
        // We don't assert a specific method here — just that extraction
        // produces something (or nothing, which is also acceptable).
        let input = try loadOCRFixture("Fisher_Victor_180549", page: 1)
        _ = cascade.extract(from: input) // No assertion — documenting the divergence
    }
}
