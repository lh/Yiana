import Testing
@testable import YianaExtraction

/// Tests for label-based extraction (name on first line, address block, postcode).
/// All tests should be RED until Session 3 implements NLPExtractor.
struct LabelExtractorTests {

    @Test(arguments: [
        "Anderson_Noah_090976",
        "Ashworth_Mira_090581",
        "Ashworth_Opal_161283",
        "Baker_Iona_101170",
        "Chase_Iris_080886",
        "Clarke_Finn_101049",
        "Clarke_Karen_200582",
        "Davis_Tessa_210256",
        "Dixon_Xavier_011293",
        "Edwards_Neel_111158",
        "Green_Sean_250481",
        "Keane_Iris_231068",
        "Morgan_Bob_200771",
        "Nelson_Xena_100250",
        "Palmer_Paul_180248",
        "Palmer_Tessa_280472",
        "Parker_Brent_080596",
        "Reed_Hugo_280491",
        "Turner_Mary_161175",
        "Turner_Opal_280763",
        "Underwood_Quinn_151275",
    ])
    func labelExtractionProducesResult(documentId: String) throws {
        let cascade = ExtractionCascade()
        let input = try loadFirstOCRFixtureByMethod(documentId, method: "label")
        let expected = try loadExpectedPageByMethod(documentId, method: "label")
        let result = cascade.extract(from: input)
        #expect(result != nil, "Label extraction should succeed for \(documentId)")
        #expect(result?.extraction?.method == "label")

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
