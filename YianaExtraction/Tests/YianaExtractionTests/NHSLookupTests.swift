import Foundation
import Testing
@testable import YianaExtraction

// MARK: - Test Case Model

private struct NHSTestCase: Codable {
    var id: Int
    var type: String
    var description: String
    var input: Input
    var expected: Expected

    struct Input: Codable {
        var postcode: String
        var nameHint: String?
        var addressHint: String?

        enum CodingKeys: String, CodingKey {
            case postcode
            case nameHint = "name_hint"
            case addressHint = "address_hint"
        }
    }

    struct Expected: Codable {
        var matchCount: Int?
        var matches: [Match]?
        var firstMatchName: String?
        var district: String?
        var districtPracticeCount: Int?
        var shouldReturnResults: Bool?
        var notes: String?

        enum CodingKeys: String, CodingKey {
            case matchCount = "match_count"
            case matches
            case firstMatchName = "first_match_name"
            case district
            case districtPracticeCount = "district_practice_count"
            case shouldReturnResults = "should_return_results"
            case notes
        }
    }

    struct Match: Codable {
        var odsCode: String
        var name: String
        var addressLine1: String
        var addressLine2: String?
        var town: String
        var county: String?
        var postcode: String

        enum CodingKeys: String, CodingKey {
            case odsCode = "ods_code"
            case name
            case addressLine1 = "address_line1"
            case addressLine2 = "address_line2"
            case town, county, postcode
        }
    }
}

private struct NHSTestFixture: Codable {
    var cases: [NHSTestCase]
}

// MARK: - Helpers

private func loadNHSTestCases() throws -> [NHSTestCase] {
    guard let url = Bundle.module.url(
        forResource: "test_cases",
        withExtension: "json",
        subdirectory: "Fixtures/nhs_lookup"
    ) else {
        throw FixtureError.fileNotFound("Fixtures/nhs_lookup/test_cases.json")
    }
    let data = try Data(contentsOf: url)
    let fixture = try JSONDecoder().decode(NHSTestFixture.self, from: data)
    return fixture.cases
}

private func loadNHSTestCase(_ id: Int) throws -> NHSTestCase {
    let cases = try loadNHSTestCases()
    guard let testCase = cases.first(where: { $0.id == id }) else {
        throw FixtureError.fileNotFound("NHS test case \(id)")
    }
    return testCase
}

private func makeService() throws -> NHSLookupService {
    guard let url = Bundle.module.url(
        forResource: "nhs_lookup",
        withExtension: "db",
        subdirectory: "Fixtures/nhs_lookup"
    ) else {
        throw FixtureError.fileNotFound("Fixtures/nhs_lookup/nhs_lookup.db")
    }
    return try NHSLookupService(databasePath: url.path)
}

// MARK: - Tests

@Suite("NHS Lookup")
struct NHSLookupTests {

    // MARK: - Cases 1-15: exact match, single practice

    @Test("Exact match single practice", arguments: 1...15)
    func exactMatchSinglePractice(caseId: Int) throws {
        let service = try makeService()
        let testCase = try loadNHSTestCase(caseId)
        let results = try service.lookupGP(
            postcode: testCase.input.postcode,
            nameHint: testCase.input.nameHint,
            addressHint: testCase.input.addressHint
        )

        #expect(results.count == testCase.expected.matchCount)
        guard let expectedMatch = testCase.expected.matches?.first,
              let result = results.first else {
            Issue.record("Expected 1 match for case \(caseId)")
            return
        }

        #expect(result.odsCode == expectedMatch.odsCode)
        #expect(result.name == expectedMatch.name)
        #expect(result.addressLine1 == expectedMatch.addressLine1)
        #expect(result.town == expectedMatch.town)
        #expect(result.postcode == expectedMatch.postcode)
        #expect(result.source == "gp")
    }

    // MARK: - Cases 16-18: exact match, multiple practices

    @Test("Exact match multiple practices", arguments: 16...18)
    func exactMatchMultiplePractices(caseId: Int) throws {
        let service = try makeService()
        let testCase = try loadNHSTestCase(caseId)
        let results = try service.lookupGP(
            postcode: testCase.input.postcode,
            nameHint: testCase.input.nameHint,
            addressHint: testCase.input.addressHint
        )

        #expect(results.count == testCase.expected.matchCount)

        // Verify all expected practices are present (order may vary)
        let expectedMatches = testCase.expected.matches ?? []
        let resultODSCodes = Set(results.compactMap(\.odsCode))
        let expectedODSCodes = Set(expectedMatches.map(\.odsCode))
        #expect(resultODSCodes == expectedODSCodes,
                "ODS codes mismatch for case \(caseId)")
    }

    // MARK: - Cases 19-20: exact match with hint reordering

    @Test("Exact match with hint reorders", arguments: 19...20)
    func exactMatchWithHintReorders(caseId: Int) throws {
        let service = try makeService()
        let testCase = try loadNHSTestCase(caseId)
        let results = try service.lookupGP(
            postcode: testCase.input.postcode,
            nameHint: testCase.input.nameHint,
            addressHint: testCase.input.addressHint
        )

        #expect(results.count == testCase.expected.matchCount)
        let firstName = results.first?.name
        let expectedName = testCase.expected.firstMatchName
        #expect(firstName == expectedName)
    }

    // MARK: - Cases 21-22: district fallback with hint

    @Test("District fallback with hint", arguments: 21...22)
    func districtFallbackWithHint(caseId: Int) throws {
        let service = try makeService()
        let testCase = try loadNHSTestCase(caseId)
        let results = try service.lookupGP(
            postcode: testCase.input.postcode,
            nameHint: testCase.input.nameHint,
            addressHint: testCase.input.addressHint
        )

        #expect(testCase.expected.shouldReturnResults == true)
        #expect(!results.isEmpty,
                "Case \(caseId): district fallback with hint should return results")
        #expect(results.allSatisfy { $0.source == "gp" })
    }

    // MARK: - Cases 23-24: district fallback without hint

    @Test("District fallback no hint returns empty", arguments: 23...24)
    func districtFallbackNoHintReturnsEmpty(caseId: Int) throws {
        let service = try makeService()
        let testCase = try loadNHSTestCase(caseId)
        let results = try service.lookupGP(
            postcode: testCase.input.postcode,
            nameHint: testCase.input.nameHint,
            addressHint: testCase.input.addressHint
        )

        #expect(testCase.expected.shouldReturnResults == false)
        #expect(results.isEmpty,
                "Case \(caseId): district fallback without hint should return empty")
    }

    // MARK: - Case 25: invalid postcode

    @Test("Invalid postcode returns empty")
    func invalidPostcodeReturnsEmpty() throws {
        let service = try makeService()
        let testCase = try loadNHSTestCase(25)
        let results = try service.lookupGP(
            postcode: testCase.input.postcode,
            nameHint: testCase.input.nameHint,
            addressHint: testCase.input.addressHint
        )

        #expect(results.isEmpty)
    }
}
