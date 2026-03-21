import Foundation
import Testing
@testable import YianaExtraction

/// Tests for ExtractionHelpers.parsePatientFilename.
struct FilenameParserTests {

    // MARK: - Standard Filenames

    @Test func parsesNameAndDOB() {
        let result = ExtractionHelpers.parsePatientFilename("Kelly_Sidney_010575")
        #expect(result != nil)
        #expect(result?.surname == "Kelly")
        #expect(result?.firstname == "Sidney")
        #expect(result?.fullName == "Sidney Kelly")
        #expect(result?.dateOfBirth == "01/05/1975")
    }

    @Test func centuryPivot1900s() {
        // yy >= 26 → 1900s
        let result = ExtractionHelpers.parsePatientFilename("Smith_Jane_150348")
        #expect(result?.dateOfBirth == "15/03/1948")
    }

    @Test func centuryPivot2000s() {
        // yy < 26 → 2000s
        let result = ExtractionHelpers.parsePatientFilename("Smith_Jane_150305")
        #expect(result?.dateOfBirth == "15/03/2005")
    }

    @Test func centuryPivotBoundary() {
        // yy == 26 → 1926
        let result = ExtractionHelpers.parsePatientFilename("Smith_Jane_010126")
        #expect(result?.dateOfBirth == "01/01/1926")
    }

    @Test func centuryPivotJustBelow() {
        // yy == 25 → 2025
        let result = ExtractionHelpers.parsePatientFilename("Smith_Jane_010125")
        #expect(result?.dateOfBirth == "01/01/2025")
    }

    // MARK: - Hyphenated Names

    @Test func hyphenatedSurname() {
        let result = ExtractionHelpers.parsePatientFilename("O'Brien-Smith_Mary_220660")
        #expect(result != nil)
        #expect(result?.surname == "O'Brien-Smith")
        #expect(result?.fullName == "Mary O'Brien-Smith")
    }

    @Test func hyphenatedFirstname() {
        let result = ExtractionHelpers.parsePatientFilename("Jones_Mary-Jane_100380")
        #expect(result != nil)
        #expect(result?.firstname == "Mary-Jane")
    }

    // MARK: - Apostrophes

    @Test func straightApostrophe() {
        let result = ExtractionHelpers.parsePatientFilename("O'Neill_Sean_050555")
        #expect(result != nil)
        #expect(result?.surname == "O'Neill")
    }

    @Test func curlyApostrophe() {
        let result = ExtractionHelpers.parsePatientFilename("O\u{2019}Neill_Sean_050555")
        #expect(result != nil)
        #expect(result?.surname == "O'Neill")
    }

    // MARK: - Trailing Text After DOB

    @Test func trailingTextIgnored() {
        let result = ExtractionHelpers.parsePatientFilename("Kelly_Sidney_010575_copy2")
        #expect(result != nil)
        #expect(result?.fullName == "Sidney Kelly")
        #expect(result?.dateOfBirth == "01/05/1975")
    }

    @Test func trailingDNA() {
        let result = ExtractionHelpers.parsePatientFilename("Brady_Michael_280348_DNA")
        #expect(result != nil)
        #expect(result?.dateOfBirth == "28/03/1948")
    }

    // MARK: - Spacing / Double Underscores

    @Test func doubleUnderscore() {
        let result = ExtractionHelpers.parsePatientFilename("Gaby__Shirley_120545")
        #expect(result != nil)
        #expect(result?.fullName == "Shirley Gaby")
    }

    @Test func spacesAroundParts() {
        // e.g. "Brady_Michael _280348" — space in part gets trimmed
        let result = ExtractionHelpers.parsePatientFilename("Brady_Michael _280348")
        #expect(result != nil)
        #expect(result?.firstname == "Michael")
    }

    // MARK: - Invalid Filenames

    @Test func tooFewParts() {
        #expect(ExtractionHelpers.parsePatientFilename("Kelly_Sidney") == nil)
    }

    @Test func singlePart() {
        #expect(ExtractionHelpers.parsePatientFilename("document") == nil)
    }

    @Test func emptyString() {
        #expect(ExtractionHelpers.parsePatientFilename("") == nil)
    }

    @Test func numericSurname() {
        #expect(ExtractionHelpers.parsePatientFilename("123_Sidney_010575") == nil)
    }

    @Test func numericFirstname() {
        #expect(ExtractionHelpers.parsePatientFilename("Kelly_456_010575") == nil)
    }

    @Test func noDOBDigits() {
        #expect(ExtractionHelpers.parsePatientFilename("Kelly_Sidney_nodob") == nil)
    }

    @Test func invalidDay() {
        #expect(ExtractionHelpers.parsePatientFilename("Kelly_Sidney_320575") == nil)
    }

    @Test func invalidMonth() {
        #expect(ExtractionHelpers.parsePatientFilename("Kelly_Sidney_011375") == nil)
    }

    @Test func dayZero() {
        #expect(ExtractionHelpers.parsePatientFilename("Kelly_Sidney_000575") == nil)
    }

    @Test func monthZero() {
        #expect(ExtractionHelpers.parsePatientFilename("Kelly_Sidney_010075") == nil)
    }
}

// MARK: - Cascade Integration

struct FilenameCascadeTests {

    let cascade = ExtractionCascade()

    @Test func filenameOverridesOCRName() {
        let input = ExtractionInput(
            documentId: "Kelly_Sidney_010575",
            pageNumber: 1,
            text: "Patient name: John Smith\nAddress: 10 High Street\nLondon\nSW1A 1AA"
        )
        let result = cascade.extractDocument(
            documentId: "Kelly_Sidney_010575",
            pages: [input]
        )
        #expect(result.pages.count == 1)
        #expect(result.pages[0].patient?.fullName == "Sidney Kelly")
    }

    @Test func filenameDOBOverridesOCR() {
        let input = ExtractionInput(
            documentId: "Kelly_Sidney_010575",
            pageNumber: 1,
            text: "Patient name: John Smith\nDate of birth: 15/03/1980\nAddress: 10 High Street\nLondon\nSW1A 1AA"
        )
        let result = cascade.extractDocument(
            documentId: "Kelly_Sidney_010575",
            pages: [input]
        )
        // Filename DOB is canonical
        #expect(result.pages[0].patient?.dateOfBirth == "01/05/1975")
    }

    @Test func nonConventionFilenameNoOverride() {
        let input = ExtractionInput(
            documentId: "scan_20260320",
            pageNumber: 1,
            text: "Patient name: John Smith\nAddress: 10 High Street\nLondon\nSW1A 1AA"
        )
        let result = cascade.extractDocument(
            documentId: "scan_20260320",
            pages: [input]
        )
        // OCR name preserved when filename doesn't match convention
        #expect(result.pages[0].patient?.fullName?.lowercased() == "john smith")
    }
}
