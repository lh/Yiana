import Foundation
import Testing
@testable import YianaExtraction

// MARK: - Name Normalisation Tests

struct NormalizeNameTests {

    @Test func lowercases() {
        #expect(ExtractionHelpers.normalizeName("John Smith") == "john smith")
    }

    @Test func stripsDr() {
        #expect(ExtractionHelpers.normalizeName("Dr John Smith") == "john smith")
    }

    @Test func stripsDrWithPeriod() {
        #expect(ExtractionHelpers.normalizeName("Dr. John Smith") == "john smith")
    }

    @Test func stripsMrs() {
        #expect(ExtractionHelpers.normalizeName("Mrs Jane Doe") == "jane doe")
    }

    @Test func stripsMr() {
        #expect(ExtractionHelpers.normalizeName("Mr Tom Archer") == "tom archer")
    }

    @Test func stripsProf() {
        #expect(ExtractionHelpers.normalizeName("Prof. Alan Turing") == "alan turing")
    }

    @Test func stripsProfessor() {
        #expect(ExtractionHelpers.normalizeName("Professor Jane Doe") == "jane doe")
    }

    @Test func preservesHyphens() {
        #expect(ExtractionHelpers.normalizeName("Mary Smith-Jones") == "mary smith-jones")
    }

    @Test func preservesApostrophes() {
        #expect(ExtractionHelpers.normalizeName("Sean O'Brien") == "sean o'brien")
    }

    @Test func normalizesCurlyApostrophes() {
        #expect(ExtractionHelpers.normalizeName("Sean O\u{2019}Brien") == "sean o'brien")
    }

    @Test func collapsesWhitespace() {
        #expect(ExtractionHelpers.normalizeName("  John   Smith  ") == "john smith")
    }

    @Test func removesNonAlpha() {
        #expect(ExtractionHelpers.normalizeName("John (Jr.) Smith") == "john jr smith")
    }

    @Test func allUppercase() {
        #expect(ExtractionHelpers.normalizeName("ROSA LANE") == "rosa lane")
    }

    @Test func emptyString() {
        #expect(ExtractionHelpers.normalizeName("") == "")
    }

    @Test func titleOnly() {
        // Bare title with no following name — title regex requires trailing space
        #expect(ExtractionHelpers.normalizeName("Dr") == "dr")
    }

    @Test func titleWithPeriodOnly() {
        #expect(ExtractionHelpers.normalizeName("Dr.") == "dr")
    }

    @Test func doesNotStripDoctor() {
        // "doctor" written out is NOT in the title list
        #expect(ExtractionHelpers.normalizeName("Doctor Smith") == "doctor smith")
    }

    @Test func stripsReverend() {
        #expect(ExtractionHelpers.normalizeName("Rev. David Brown") == "david brown")
    }

    @Test func titleMidNameNotStripped() {
        // Only strip title at start of name
        #expect(ExtractionHelpers.normalizeName("John Dr Smith") == "john dr smith")
    }
}

// MARK: - Entity Database Schema Tests

struct EntityDatabaseSchemaTests {

    @Test func createsInMemoryDatabase() throws {
        let db = try EntityDatabase()
        let stats = try db.statistics()
        #expect(stats.documentCount == 0)
        #expect(stats.patientCount == 0)
        #expect(stats.practitionerCount == 0)
        #expect(stats.linkCount == 0)
        #expect(stats.extractionCount == 0)
    }

    @Test func createsFileDatabase() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let dbPath = tmpDir.appendingPathComponent("test_entity_\(UUID().uuidString).db").path
        defer { try? FileManager.default.removeItem(atPath: dbPath) }

        let db = try EntityDatabase(path: dbPath)
        let stats = try db.statistics()
        #expect(stats.documentCount == 0)
    }
}

// MARK: - Entity Corpus Validation

struct EntityCorpusTests {

    private static var fixturesPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // YianaExtractionTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // YianaExtraction/
            .deletingLastPathComponent() // Yiana repo root
            .appendingPathComponent("migration/fixtures/entity")
            .path
    }

    private struct ExpectedScenario: Codable {
        let id: Int
        let name: String
        let files: [String]
        let expectedPatients: Int
        let expectedPatientNames: [String]?
        let expectedPatientDocCount: [String: Int]?
        let expectedPractitioners: Int
        let expectedPractitionerNames: [String]?
        let expectedLinks: Int
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case id, name, files, notes
            case expectedPatients = "expected_patients"
            case expectedPatientNames = "expected_patient_names"
            case expectedPatientDocCount = "expected_patient_doc_count"
            case expectedPractitioners = "expected_practitioners"
            case expectedPractitionerNames = "expected_practitioner_names"
            case expectedLinks = "expected_links"
        }
    }

    private struct ExpectedCorpus: Codable {
        let scenarios: [ExpectedScenario]
    }

    @Test("All 30 scenarios match expected outcomes")
    func allScenariosPass() throws {
        let expectedURL = URL(fileURLWithPath: Self.fixturesPath + "/expected.json")
        let corpus = try JSONDecoder().decode(
            ExpectedCorpus.self, from: Data(contentsOf: expectedURL))

        for scenario in corpus.scenarios {
            let db = try EntityDatabase()

            for filename in scenario.files {
                let fileURL = URL(fileURLWithPath:
                    Self.fixturesPath + "/addresses/" + filename)
                try db.ingestAddressFile(at: fileURL)
            }

            let stats = try db.statistics()
            let tag = "Scenario \(scenario.id) (\(scenario.name))"

            #expect(stats.patientCount == scenario.expectedPatients,
                    "\(tag): expected \(scenario.expectedPatients) patients, got \(stats.patientCount)")
            #expect(stats.practitionerCount == scenario.expectedPractitioners,
                    "\(tag): expected \(scenario.expectedPractitioners) practitioners, got \(stats.practitionerCount)")
            #expect(stats.linkCount == scenario.expectedLinks,
                    "\(tag): expected \(scenario.expectedLinks) links, got \(stats.linkCount)")

            // Verify patient names
            if let expectedNames = scenario.expectedPatientNames {
                let patients = try db.allPatients()
                let actualNames = patients.map(\.fullNameNormalized).sorted()
                let sortedExpected = expectedNames.sorted()
                #expect(actualNames == sortedExpected,
                        "\(tag): patient names \(actualNames) != \(sortedExpected)")
            }

            // Verify practitioner names
            if let expectedNames = scenario.expectedPractitionerNames {
                let practitioners = try db.allPractitioners()
                let actualNames = practitioners.compactMap(\.fullNameNormalized).sorted()
                let sortedExpected = expectedNames.sorted()
                #expect(actualNames == sortedExpected,
                        "\(tag): practitioner names \(actualNames) != \(sortedExpected)")
            }

            // Verify patient document counts
            if let expectedDocCounts = scenario.expectedPatientDocCount {
                let patients = try db.allPatients()
                for patient in patients {
                    if let expected = expectedDocCounts[patient.fullNameNormalized] {
                        #expect(patient.documentCount == expected,
                                "\(tag): \(patient.fullNameNormalized) doc count \(patient.documentCount) != \(expected)")
                    }
                }
            }
        }
    }
}

// MARK: - Ingestion Edge Cases

struct IngestionEdgeCaseTests {

    private static var fixturesPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("migration/fixtures/entity")
            .path
    }

    @Test func idempotentIngestion() throws {
        let db = try EntityDatabase()
        let fileURL = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Archer_Tom_150380.json")

        try db.ingestAddressFile(at: fileURL)
        let stats1 = try db.statistics()

        // Second ingest of same file — hash matches, should be a no-op
        try db.ingestAddressFile(at: fileURL)
        let stats2 = try db.statistics()

        #expect(stats1.patientCount == stats2.patientCount)
        #expect(stats1.practitionerCount == stats2.practitionerCount)
        #expect(stats1.linkCount == stats2.linkCount)
        #expect(stats1.extractionCount == stats2.extractionCount)
    }

    @Test func contentHashExcludesEnriched() throws {
        let base: [String: Any] = [
            "schema_version": 1,
            "document_id": "test",
            "pages": [] as [Any]
        ]
        var withEnriched = base
        withEnriched["enriched"] = ["patient": ["name": "Test"]]

        let baseData = try JSONSerialization.data(withJSONObject: base)
        let enrichedData = try JSONSerialization.data(withJSONObject: withEnriched)

        let hash1 = EntityDatabase.contentHash(of: baseData)
        let hash2 = EntityDatabase.contentHash(of: enrichedData)
        #expect(hash1 == hash2)
    }

    @Test func missingDobCreatesNoPatient() throws {
        let db = try EntityDatabase()
        let fileURL = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Irvine_Meg.json")
        try db.ingestAddressFile(at: fileURL)

        let stats = try db.statistics()
        #expect(stats.patientCount == 0)
        #expect(stats.practitionerCount == 1)
        #expect(stats.linkCount == 0)
    }

    @Test func malformedFilenameCreatesNoPatient() throws {
        let db = try EntityDatabase()
        let fileURL = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/JohnSmith.json")
        try db.ingestAddressFile(at: fileURL)

        let stats = try db.statistics()
        #expect(stats.patientCount == 0)
        #expect(stats.practitionerCount == 1)
    }

    @Test func sameNameDifferentDobCreatesTwoPatients() throws {
        let db = try EntityDatabase()
        let url1 = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Nash_Kate_120590.json")
        let url2 = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Nash_Kate_040302.json")
        try db.ingestAddressFile(at: url1)
        try db.ingestAddressFile(at: url2)

        let stats = try db.statistics()
        #expect(stats.patientCount == 2)
        let patients = try db.allPatients()
        #expect(patients.allSatisfy { $0.fullNameNormalized == "kate nash" })
    }

    @Test func practitionerTypePreventsmerge() throws {
        let db = try EntityDatabase()
        // Dr Finch (GP) in Yates file, Mr Finch (Consultant) in Zane file
        let url1 = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Yates_Eve_170883.json")
        let url2 = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Zane_Max_050777.json")
        try db.ingestAddressFile(at: url1)
        try db.ingestAddressFile(at: url2)

        let practitioners = try db.allPractitioners()
        #expect(practitioners.count == 2)
        let types = Set(practitioners.map(\.type))
        #expect(types == ["GP", "Consultant"])
    }

    @Test func emptyPagesWithValidFilenameCreatesPatient() throws {
        let db = try EntityDatabase()
        let fileURL = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Lowe_Ned_010101.json")
        try db.ingestAddressFile(at: fileURL)

        let stats = try db.statistics()
        #expect(stats.patientCount == 1)
        #expect(stats.practitionerCount == 0)
        #expect(stats.linkCount == 0)
    }

    @Test func specialistCreatesConsultantPractitioner() throws {
        let db = try EntityDatabase()
        let url1 = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Grant_Noah_250855.json")
        let url2 = URL(fileURLWithPath:
            Self.fixturesPath + "/addresses/Grant_Noah_250855_ref.json")
        try db.ingestAddressFile(at: url1)
        try db.ingestAddressFile(at: url2)

        let practitioners = try db.allPractitioners()
        #expect(practitioners.count == 2)

        let gps = practitioners.filter { $0.type == "GP" }
        let consultants = practitioners.filter { $0.type == "Consultant" }
        #expect(gps.count == 1)
        #expect(consultants.count == 1)
        #expect(gps[0].fullNameNormalized == "wei")
        #expect(consultants[0].fullNameNormalized == "bennett")

        let stats = try db.statistics()
        #expect(stats.linkCount == 2)
    }
}

// MARK: - Patient Search Tests

struct PatientSearchTests {

    private func makeDB() throws -> EntityDatabase {
        let db = try EntityDatabase()
        // Insert synthetic patients directly via ingestion
        let json = """
        {
            "document_id": "Smith_John_010190",
            "schema_version": 2,
            "extracted_at": "2026-01-01T00:00:00Z",
            "page_count": 1,
            "pages": [{
                "page_number": 1,
                "address_type": "patient",
                "patient": { "full_name": "John Smith", "date_of_birth": "1990-01-01" },
                "address": { "postcode": "SW1A 1AA" },
                "gp": { "name": "Dr Alice Green", "practice": "Riverside Surgery" }
            }],
            "overrides": []
        }
        """
        let json2 = """
        {
            "document_id": "Jones_Mary_150285",
            "schema_version": 2,
            "extracted_at": "2026-01-01T00:00:00Z",
            "page_count": 1,
            "pages": [{
                "page_number": 1,
                "address_type": "patient",
                "patient": { "full_name": "Mary Jones", "date_of_birth": "1985-02-15" },
                "address": { "postcode": "EC1A 1BB" },
                "gp": { "name": "Dr Bob White", "practice": "Hilltop Medical Centre" }
            }],
            "overrides": []
        }
        """
        // Ingest Smith twice to give higher document count
        let json3 = """
        {
            "document_id": "Smith_John_010190_letter",
            "schema_version": 2,
            "extracted_at": "2026-01-01T00:00:00Z",
            "page_count": 1,
            "pages": [{
                "page_number": 1,
                "address_type": "patient",
                "patient": { "full_name": "John Smith", "date_of_birth": "1990-01-01" },
                "address": {}
            }],
            "overrides": []
        }
        """
        for jsonStr in [json, json2, json3] {
            let data = jsonStr.data(using: .utf8)!
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".json")
            try data.write(to: tempURL)
            try db.ingestAddressFile(at: tempURL)
            try FileManager.default.removeItem(at: tempURL)
        }
        return db
    }

    @Test func emptyQueryReturnsEmpty() throws {
        let db = try makeDB()
        let results = try db.searchPatients(query: "")
        #expect(results.isEmpty)
    }

    @Test func whitespaceOnlyReturnsEmpty() throws {
        let db = try makeDB()
        let results = try db.searchPatients(query: "   ")
        #expect(results.isEmpty)
    }

    @Test func partialNameMatch() throws {
        let db = try makeDB()
        let results = try db.searchPatients(query: "smith")
        #expect(results.count == 1)
        #expect(results[0].fullNameNormalized == "john smith")
    }

    @Test func caseInsensitiveMatch() throws {
        let db = try makeDB()
        let results = try db.searchPatients(query: "JONES")
        #expect(results.count == 1)
        #expect(results[0].fullNameNormalized == "mary jones")
    }

    @Test func dobMatch() throws {
        let db = try makeDB()
        // DOB stored as DD/MM/YYYY from filename parsing
        let results = try db.searchPatients(query: "01/01/1990")
        #expect(results.count == 1)
        #expect(results[0].fullNameNormalized == "john smith")
    }

    @Test func noMatchReturnsEmpty() throws {
        let db = try makeDB()
        let results = try db.searchPatients(query: "zzzznotaname")
        #expect(results.isEmpty)
    }

    @Test func orderedByDocumentCount() throws {
        let db = try makeDB()
        // "john smith" has 2 docs, "mary jones" has 1
        let results = try db.searchPatients(query: "o") // matches both (john, jones)
        #expect(results.count == 2)
        #expect(results[0].fullNameNormalized == "john smith") // higher doc count
    }

    @Test func limitResults() throws {
        let db = try makeDB()
        let results = try db.searchPatients(query: "o", limit: 1)
        #expect(results.count == 1)
    }
}

// MARK: - Practitioner Search Tests

struct PractitionerSearchTests {

    private func makeDB() throws -> EntityDatabase {
        let db = try EntityDatabase()
        let json = """
        {
            "document_id": "Test_Doc_010190",
            "schema_version": 2,
            "extracted_at": "2026-01-01T00:00:00Z",
            "page_count": 1,
            "pages": [{
                "page_number": 1,
                "address_type": "patient",
                "patient": { "full_name": "Test Patient" },
                "gp": { "name": "Dr Sarah Palmer", "practice": "Oak Tree Surgery" }
            }],
            "overrides": []
        }
        """
        let data = json.data(using: .utf8)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try data.write(to: tempURL)
        try db.ingestAddressFile(at: tempURL)
        try FileManager.default.removeItem(at: tempURL)
        return db
    }

    @Test func emptyQueryReturnsEmpty() throws {
        let db = try makeDB()
        let results = try db.searchPractitioners(query: "")
        #expect(results.isEmpty)
    }

    @Test func searchByName() throws {
        let db = try makeDB()
        let results = try db.searchPractitioners(query: "palmer")
        #expect(results.count == 1)
        #expect(results[0].fullNameNormalized == "sarah palmer")
    }

    @Test func searchByPracticeName() throws {
        let db = try makeDB()
        let results = try db.searchPractitioners(query: "oak tree")
        #expect(results.count == 1)
        #expect(results[0].practiceName == "Oak Tree Surgery")
    }

    @Test func noMatchReturnsEmpty() throws {
        let db = try makeDB()
        let results = try db.searchPractitioners(query: "zznotapractice")
        #expect(results.isEmpty)
    }
}
