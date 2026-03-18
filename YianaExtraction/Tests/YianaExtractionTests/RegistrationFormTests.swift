import Testing
@testable import YianaExtraction

/// Tests for RegistrationFormExtractor against 12 clearwater_form fixture documents.
/// All tests should be RED until Session 2 implements the extractor.
struct RegistrationFormTests {

    let extractor = RegistrationFormExtractor()

    // MARK: - Detection

    @Test func detectsClearwaterFormText() throws {
        let input = try loadOCRFixture("Cooper_Peter_010962", page: 1)
        let result = extractor.extract(from: input)
        #expect(result != nil, "Should detect registration form")
        #expect(result?.extraction?.method == "clearwater_form")
    }

    @Test func rejectsNonFormText() throws {
        let input = try loadOCRFixture("Anderson_Noah_090976", page: 5)
        let result = extractor.extract(from: input)
        #expect(result == nil, "Should reject non-registration-form text")
    }

    // MARK: - Patient Fields

    @Test func extractsPatientName() throws {
        let input = try loadOCRFixture("Cooper_Peter_010962", page: 1)
        let expected = try loadExpectedPage("Cooper_Peter_010962", page: 1)
        let result = extractor.extract(from: input)
        #expect(result?.patient?.fullName?.lowercased() == expected.patient?.fullName?.lowercased())
    }

    @Test func extractsDOB() throws {
        let input = try loadOCRFixture("Cooper_Peter_010962", page: 1)
        let expected = try loadExpectedPage("Cooper_Peter_010962", page: 1)
        let result = extractor.extract(from: input)
        #expect(result?.patient?.dateOfBirth == expected.patient?.dateOfBirth)
    }

    @Test func extractsMRN() throws {
        let input = try loadOCRFixture("Cooper_Peter_010962", page: 1)
        let expected = try loadExpectedPage("Cooper_Peter_010962", page: 1)
        let result = extractor.extract(from: input)
        #expect(result?.patient?.mrn == expected.patient?.mrn)
    }

    @Test func extractsPostcode() throws {
        let input = try loadOCRFixture("Cooper_Peter_010962", page: 1)
        let expected = try loadExpectedPage("Cooper_Peter_010962", page: 1)
        let result = extractor.extract(from: input)
        let expectedPC = expected.address?.postcode?.replacingOccurrences(of: " ", with: "").uppercased()
        let actualPC = result?.address?.postcode?.replacingOccurrences(of: " ", with: "").uppercased()
        #expect(actualPC == expectedPC)
    }

    // MARK: - GP Fields

    @Test func extractsGPName() throws {
        let input = try loadOCRFixture("Cooper_Peter_010962", page: 1)
        let expected = try loadExpectedPage("Cooper_Peter_010962", page: 1)
        let result = extractor.extract(from: input)
        #expect(result?.gp?.name?.lowercased() == expected.gp?.name?.lowercased())
    }

    // MARK: - All Documents

    @Test(arguments: [
        "Clarke_Clara_100767",
        "Cooper_Grace_130882",
        "Cooper_Mary_120492",
        "Cooper_Peter_010962",
        "Davis_Derek_130441",
        "Dixon_Carol_130591",
        "Harris_Tara_281262",
        "Nelson_Opal_241267",
        "Palmer_James_250542",
        "Taylor_Opal_111252",
        "Walker_David_050562",
        "Walker_Zach_190991",
    ])
    func registrationFormProducesResult(documentId: String) throws {
        let input = try loadOCRFixture(documentId, page: 1)
        let result = extractor.extract(from: input)
        #expect(result != nil, "Registration form should extract from \(documentId)")
        #expect(result?.extraction?.method == "clearwater_form")
        #expect(result?.extraction?.confidence == 0.9)
    }
}
