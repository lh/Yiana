//
//  ExtractedAddress.swift
//  Yiana
//
//  Model for addresses extracted from medical documents
//

import Foundation

// MARK: - Address Type

enum AddressType: String, Codable {
    case patient
    case gp
    case optician
    case specialist
}

// MARK: - JSON File Schema (matches .addresses/*.json)

/// Top-level structure of a document address JSON file
struct DocumentAddressFile: Codable {
    var schemaVersion: Int
    var documentId: String
    var extractedAt: String
    var pageCount: Int
    var pages: [AddressPageEntry]
    var overrides: [AddressOverrideEntry]
    var enriched: EnrichedData?

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

/// Patient information nested object
struct PatientInfo: Codable {
    var fullName: String?
    var dateOfBirth: String?
    var phones: PhoneInfo?

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case phones
    }
}

/// Phone numbers nested object
struct PhoneInfo: Codable {
    var home: String?
    var work: String?
    var mobile: String?
}

/// Address nested object
struct AddressInfo: Codable {
    var line1: String?
    var line2: String?
    var city: String?
    var county: String?
    var postcode: String?
    var postcodeValid: Bool?
    var postcodeDistrict: String?

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

/// GP information nested object
struct GPInfo: Codable {
    var name: String?
    var practice: String?
    var address: String?
    var postcode: String?
}

/// Extraction metadata nested object
struct ExtractionInfo: Codable {
    var method: String?
    var confidence: Double?
}

/// One entry in the pages[] array
struct AddressPageEntry: Codable {
    var pageNumber: Int
    var patient: PatientInfo?
    var address: AddressInfo?
    var gp: GPInfo?
    var extraction: ExtractionInfo?
    var addressType: String?
    var isPrime: Bool?
    var specialistName: String?

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

/// One entry in the overrides[] array
struct AddressOverrideEntry: Codable {
    var pageNumber: Int
    var matchAddressType: String
    var patient: PatientInfo?
    var address: AddressInfo?
    var gp: GPInfo?
    var addressType: String?
    var isPrime: Bool?
    var specialistName: String?
    var overrideReason: String?
    var overrideDate: String?

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
    }
}

// MARK: - Enriched Data (backend DB write-back)

struct EnrichedPatientInfo: Codable {
    var fullName: String?
    var dateOfBirth: String?
    var source: String?
    var documentCount: Int?

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case source
        case documentCount = "document_count"
    }
}

struct EnrichedPractitionerInfo: Codable {
    var name: String?
    var type: String?
    var practice: String?
    var documentCount: Int?

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case practice
        case documentCount = "document_count"
    }
}

struct EnrichedData: Codable {
    var enrichedAt: String?
    var patient: EnrichedPatientInfo?
    var practitioners: [EnrichedPractitionerInfo]?

    private enum CodingKeys: String, CodingKey {
        case enrichedAt = "enriched_at"
        case patient
        case practitioners
    }
}

// MARK: - View-Facing Model (flat structure for UI)

struct ExtractedAddress {
    var documentId: String
    var pageNumber: Int?

    // Patient Information
    var fullName: String?
    var dateOfBirth: String?

    // Address
    var addressLine1: String?
    var addressLine2: String?
    var city: String?
    var county: String?
    var postcode: String?
    var country: String?

    // Contact Details
    var phoneHome: String?
    var phoneWork: String?
    var phoneMobile: String?

    // GP Information
    var gpName: String?
    var gpPractice: String?
    var gpAddress: String?
    var gpPostcode: String?
    var gpOdsCode: String?
    var gpOfficialName: String?

    // Metadata
    var extractionConfidence: Double?
    var extractionMethod: String?
    var extractedAt: Date?

    // Validation
    var postcodeValid: Bool?
    var postcodeDistrict: String?

    // Raw Data (not displayed in UI by default)
    var rawText: String?
    var ocrJson: String?

    // Prime Address System
    var addressType: String?
    var isPrime: Bool?
    var specialistName: String?
}

// MARK: - Conversion from JSON structs to view model

extension ExtractedAddress {
    /// Create a flat ExtractedAddress from a page entry, optionally applying an override and enriched data.
    /// Priority: override > page > enriched (enriched only fills nil/empty gaps).
    init(documentId: String, page: AddressPageEntry, override: AddressOverrideEntry? = nil, extractedAt: String? = nil, enriched: EnrichedData? = nil) {
        self.documentId = documentId
        self.pageNumber = page.pageNumber

        // Start with page data
        let patient = override?.patient ?? page.patient
        let address = override?.address ?? page.address
        let gp = override?.gp ?? page.gp

        self.fullName = patient?.fullName
        self.dateOfBirth = patient?.dateOfBirth
        self.phoneHome = patient?.phones?.home
        self.phoneWork = patient?.phones?.work
        self.phoneMobile = patient?.phones?.mobile

        self.addressLine1 = address?.line1
        self.addressLine2 = address?.line2
        self.city = address?.city
        self.county = address?.county
        self.postcode = address?.postcode
        self.postcodeValid = address?.postcodeValid
        self.postcodeDistrict = address?.postcodeDistrict

        self.gpName = gp?.name
        self.gpPractice = gp?.practice
        self.gpAddress = gp?.address
        self.gpPostcode = gp?.postcode

        self.extractionConfidence = page.extraction?.confidence
        self.extractionMethod = page.extraction?.method

        // Parse extracted_at date
        if let dateStr = extractedAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.extractedAt = formatter.date(from: dateStr)
            if self.extractedAt == nil {
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                self.extractedAt = formatter.date(from: dateStr)
            }
        }

        // Override fields take precedence
        self.addressType = override?.addressType ?? page.addressType
        self.isPrime = override?.isPrime ?? page.isPrime
        self.specialistName = override?.specialistName ?? page.specialistName

        // Fields not in the JSON schema
        self.country = nil
        self.gpOdsCode = nil
        self.gpOfficialName = nil
        self.rawText = nil
        self.ocrJson = nil

        // Enriched patient name/DOB: override > enriched > page.
        // Filename-derived names are more reliable than OCR, so enriched
        // replaces OCR data — but never overwrites user corrections.
        if let ep = enriched?.patient, override?.patient == nil {
            if let name = ep.fullName, !name.isEmpty {
                self.fullName = name
            }
            if let dob = ep.dateOfBirth, !dob.isEmpty {
                self.dateOfBirth = dob
            }
        }
    }
}

// MARK: - Identifiable

extension ExtractedAddress {
    /// Stable identifier for SwiftUI ForEach (composite of documentId + pageNumber + addressType)
    var stableId: String {
        "\(documentId)_\(pageNumber ?? 0)_\(addressType ?? "patient")"
    }
}

// MARK: - Computed Properties

extension ExtractedAddress {
    /// Formatted full address for patient
    var formattedPatientAddress: String? {
        let components = [addressLine1, addressLine2, city, county, postcode, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return components.isEmpty ? nil : components.joined(separator: "\n")
    }

    /// Formatted patient contact info
    var formattedPhones: String? {
        let phones = [phoneHome, phoneWork, phoneMobile]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return phones.isEmpty ? nil : phones.joined(separator: ", ")
    }

    /// Whether this record contains GP information
    var hasGPInfo: Bool {
        gpName != nil || gpPractice != nil || gpAddress != nil
    }

    /// Whether this record contains patient information
    var hasPatientInfo: Bool {
        fullName != nil || addressLine1 != nil
    }

    /// Get the typed address type (with fallback to 'patient')
    var typedAddressType: AddressType {
        guard let typeString = addressType,
              let type = AddressType(rawValue: typeString) else {
            return .patient
        }
        return type
    }

    /// Icon name for this address type
    var typeIcon: String {
        switch typedAddressType {
        case .patient:
            return "person.fill"
        case .gp:
            return "cross.fill"
        case .optician:
            return "eye.fill"
        case .specialist:
            return "stethoscope"
        }
    }

    /// Sort order for address type (lower is higher priority)
    var typeSortOrder: Int {
        switch typedAddressType {
        case .patient: return 0
        case .gp: return 1
        case .optician: return 2
        case .specialist: return 3
        }
    }
}
