//
//  AddressSchema.swift
//  YianaExtraction
//
//  JSON schema types matching .addresses/*.json format.
//  These are the canonical definitions — the Yiana app imports them from this package.
//

import Foundation

// MARK: - Address Type

public enum AddressType: String, Codable, Sendable {
    case patient
    case gp
    case optician
    case specialist
}

// MARK: - Top-Level File Schema

/// Top-level structure of a document address JSON file (.addresses/{documentId}.json)
public struct DocumentAddressFile: Codable, Sendable {
    public var schemaVersion: Int
    public var documentId: String
    public var extractedAt: String
    public var pageCount: Int
    public var pages: [AddressPageEntry]
    public var overrides: [AddressOverrideEntry]
    public var enriched: EnrichedData?

    public init(
        schemaVersion: Int = 1,
        documentId: String,
        extractedAt: String,
        pageCount: Int,
        pages: [AddressPageEntry],
        overrides: [AddressOverrideEntry] = [],
        enriched: EnrichedData? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.documentId = documentId
        self.extractedAt = extractedAt
        self.pageCount = pageCount
        self.pages = pages
        self.overrides = overrides
        self.enriched = enriched
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case documentId = "document_id"
        case extractedAt = "extracted_at"
        case pageCount = "page_count"
        case pages
        case overrides
        case enriched
    }
}

// MARK: - Page Entry

/// One entry in the pages[] array
public struct AddressPageEntry: Codable, Sendable {
    public var pageNumber: Int
    public var patient: PatientInfo?
    public var address: AddressInfo?
    public var gp: GPInfo?
    public var extraction: ExtractionInfo?
    public var addressType: String?
    public var isPrime: Bool?
    public var specialistName: String?

    public init(
        pageNumber: Int,
        patient: PatientInfo? = nil,
        address: AddressInfo? = nil,
        gp: GPInfo? = nil,
        extraction: ExtractionInfo? = nil,
        addressType: String? = "patient",
        isPrime: Bool? = nil,
        specialistName: String? = nil
    ) {
        self.pageNumber = pageNumber
        self.patient = patient
        self.address = address
        self.gp = gp
        self.extraction = extraction
        self.addressType = addressType
        self.isPrime = isPrime
        self.specialistName = specialistName
    }

    private enum CodingKeys: String, CodingKey {
        case pageNumber = "page_number"
        case patient
        case address
        case gp
        case extraction
        case addressType = "address_type"
        case isPrime = "is_prime"
        case specialistName = "specialist_name"
    }
}

// MARK: - Nested Objects

/// Patient information
public struct PatientInfo: Codable, Sendable {
    public var fullName: String?
    public var dateOfBirth: String?
    public var phones: PhoneInfo?
    public var mrn: String?

    public init(fullName: String? = nil, dateOfBirth: String? = nil, phones: PhoneInfo? = nil, mrn: String? = nil) {
        self.fullName = fullName
        self.dateOfBirth = dateOfBirth
        self.phones = phones
        self.mrn = mrn
    }

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case phones
        case mrn
    }
}

/// Phone numbers
public struct PhoneInfo: Codable, Sendable {
    public var home: String?
    public var work: String?
    public var mobile: String?

    public init(home: String? = nil, work: String? = nil, mobile: String? = nil) {
        self.home = home
        self.work = work
        self.mobile = mobile
    }
}

/// Address fields
public struct AddressInfo: Codable, Sendable {
    public var line1: String?
    public var line2: String?
    public var city: String?
    public var county: String?
    public var postcode: String?
    public var postcodeValid: Bool?
    public var postcodeDistrict: String?

    public init(
        line1: String? = nil, line2: String? = nil, city: String? = nil,
        county: String? = nil, postcode: String? = nil,
        postcodeValid: Bool? = nil, postcodeDistrict: String? = nil
    ) {
        self.line1 = line1
        self.line2 = line2
        self.city = city
        self.county = county
        self.postcode = postcode
        self.postcodeValid = postcodeValid
        self.postcodeDistrict = postcodeDistrict
    }

    private enum CodingKeys: String, CodingKey {
        case line1 = "line_1"
        case line2 = "line_2"
        case city
        case county
        case postcode
        case postcodeValid = "postcode_valid"
        case postcodeDistrict = "postcode_district"
    }
}

/// GP information
public struct GPInfo: Codable, Sendable {
    public var name: String?
    public var practice: String?
    public var address: String?
    public var postcode: String?
    public var odsCode: String?
    public var officialName: String?
    public var nhsCandidates: [NHSCandidate]?

    public init(
        name: String? = nil, practice: String? = nil, address: String? = nil,
        postcode: String? = nil, odsCode: String? = nil, officialName: String? = nil,
        nhsCandidates: [NHSCandidate]? = nil
    ) {
        self.name = name
        self.practice = practice
        self.address = address
        self.postcode = postcode
        self.odsCode = odsCode
        self.officialName = officialName
        self.nhsCandidates = nhsCandidates
    }

    public enum CodingKeys: String, CodingKey {
        case name, practice, address, postcode
        case odsCode = "ods_code"
        case officialName = "official_name"
        case nhsCandidates = "nhs_candidates"
    }
}

/// NHS candidate match from postcode lookup
public struct NHSCandidate: Codable, Sendable {
    public var source: String?
    public var odsCode: String?
    public var name: String?
    public var addressLine1: String?
    public var town: String?
    public var postcode: String?

    public init(
        source: String? = nil, odsCode: String? = nil, name: String? = nil,
        addressLine1: String? = nil, town: String? = nil, postcode: String? = nil
    ) {
        self.source = source
        self.odsCode = odsCode
        self.name = name
        self.addressLine1 = addressLine1
        self.town = town
        self.postcode = postcode
    }

    public enum CodingKeys: String, CodingKey {
        case source
        case odsCode = "ods_code"
        case name
        case addressLine1 = "address_line1"
        case town
        case postcode
    }
}

/// Extraction metadata
public struct ExtractionInfo: Codable, Sendable {
    public var method: String?
    public var confidence: Double?

    public init(method: String? = nil, confidence: Double? = nil) {
        self.method = method
        self.confidence = confidence
    }
}

// MARK: - Override Entry

/// One entry in the overrides[] array (user corrections from the app)
public struct AddressOverrideEntry: Codable, Sendable {
    public var pageNumber: Int
    public var matchAddressType: String
    public var patient: PatientInfo?
    public var address: AddressInfo?
    public var gp: GPInfo?
    public var addressType: String?
    public var isPrime: Bool?
    public var specialistName: String?
    public var overrideReason: String?
    public var overrideDate: String?
    public var isDismissed: Bool?

    public init(
        pageNumber: Int, matchAddressType: String,
        patient: PatientInfo? = nil, address: AddressInfo? = nil, gp: GPInfo? = nil,
        addressType: String? = nil, isPrime: Bool? = nil, specialistName: String? = nil,
        overrideReason: String? = nil, overrideDate: String? = nil, isDismissed: Bool? = nil
    ) {
        self.pageNumber = pageNumber
        self.matchAddressType = matchAddressType
        self.patient = patient
        self.address = address
        self.gp = gp
        self.addressType = addressType
        self.isPrime = isPrime
        self.specialistName = specialistName
        self.overrideReason = overrideReason
        self.overrideDate = overrideDate
        self.isDismissed = isDismissed
    }

    private enum CodingKeys: String, CodingKey {
        case pageNumber = "page_number"
        case matchAddressType = "match_address_type"
        case patient
        case address
        case gp
        case addressType = "address_type"
        case isPrime = "is_prime"
        case specialistName = "specialist_name"
        case overrideReason = "override_reason"
        case overrideDate = "override_date"
        case isDismissed = "is_dismissed"
    }
}

// MARK: - Enriched Data (backend DB write-back)

public struct EnrichedPatientInfo: Codable, Sendable {
    public var fullName: String?
    public var surname: String?
    public var firstname: String?
    public var dateOfBirth: String?
    public var source: String?
    public var documentCount: Int?

    public init(
        fullName: String? = nil, surname: String? = nil, firstname: String? = nil,
        dateOfBirth: String? = nil, source: String? = nil, documentCount: Int? = nil
    ) {
        self.fullName = fullName
        self.surname = surname
        self.firstname = firstname
        self.dateOfBirth = dateOfBirth
        self.source = source
        self.documentCount = documentCount
    }

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case surname
        case firstname
        case dateOfBirth = "date_of_birth"
        case source
        case documentCount = "document_count"
    }
}

public struct EnrichedPractitionerInfo: Codable, Sendable {
    public var name: String?
    public var type: String?
    public var practice: String?
    public var documentCount: Int?

    public init(name: String? = nil, type: String? = nil, practice: String? = nil, documentCount: Int? = nil) {
        self.name = name
        self.type = type
        self.practice = practice
        self.documentCount = documentCount
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case practice
        case documentCount = "document_count"
    }
}

public struct EnrichedData: Codable, Sendable {
    public var enrichedAt: String?
    public var patient: EnrichedPatientInfo?
    public var practitioners: [EnrichedPractitionerInfo]?

    public init(enrichedAt: String? = nil, patient: EnrichedPatientInfo? = nil, practitioners: [EnrichedPractitionerInfo]? = nil) {
        self.enrichedAt = enrichedAt
        self.patient = patient
        self.practitioners = practitioners
    }

    private enum CodingKeys: String, CodingKey {
        case enrichedAt = "enriched_at"
        case patient
        case practitioners
    }
}
