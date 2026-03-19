import Testing
@testable import YianaExtraction

/// Tests for form-based extraction (field labels like "Patient name:", "Address:").
/// All tests should be RED until Session 3 implements NLPExtractor.
struct FormExtractorTests {

    @Test(arguments: [
        "Blake_Karen_220855",
        "Cooper_Mary_200889",
        "Dixon_Peter_040770",
        "Ellis_Rachel_260787",
        "Ingram_Jay_231245",
        "Jones_Clara_080749",
        "Keane_Yvonne_060555",
        "Mason_Carol_091171",
        "Quinn_Rachel_081167",
        "Turner_Jay_190592",
        "Turner_Rosa_030868",
        "Turner_Will_190680",
        "Vaughan_Iris_250760",
        "Ward_Bob_020885",
        "Ward_Elena_210890",
    ])
    func formExtractionProducesResult(documentId: String) throws {
        let cascade = ExtractionCascade()
        let input = try loadFirstOCRFixtureByMethod(documentId, method: "form")
        let expected = try loadExpectedPageByMethod(documentId, method: "form")
        let result = cascade.extract(from: input)
        #expect(result != nil, "Form extraction should succeed for \(documentId)")
        #expect(result?.extraction?.method == "form")

        // Check key fields
        if let expectedName = expected.patient?.fullName {
            #expect(
                result?.patient?.fullName?.lowercased() == expectedName.lowercased(),
                "Name mismatch for \(documentId)"
            )
        }
        if let expectedPC = expected.address?.postcode {
            let actualPC = result?.address?.postcode?.replacingOccurrences(of: " ", with: "").uppercased()
            let expPC = expectedPC.replacingOccurrences(of: " ", with: "").uppercased()
            #expect(actualPC == expPC, "Postcode mismatch for \(documentId)")
        }
    }
}
