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
