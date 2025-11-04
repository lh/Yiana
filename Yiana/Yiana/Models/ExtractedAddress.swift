//
//  ExtractedAddress.swift
//  Yiana
//
//  Model for addresses extracted from medical documents
//

import Foundation
import GRDB

/// Type of address extracted
enum AddressType: String, Codable {
    case patient
    case gp
    case optician
    case specialist
}

/// Address information extracted from a medical document
struct ExtractedAddress: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
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
    var addressType: String? // 'patient', 'gp', 'optician', 'specialist'
    var isPrime: Bool?
    var specialistName: String? // Only used when addressType is 'specialist'

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let documentId = Column(CodingKeys.documentId)
        static let pageNumber = Column(CodingKeys.pageNumber)
        static let fullName = Column(CodingKeys.fullName)
        static let dateOfBirth = Column(CodingKeys.dateOfBirth)
        static let addressLine1 = Column(CodingKeys.addressLine1)
        static let addressLine2 = Column(CodingKeys.addressLine2)
        static let city = Column(CodingKeys.city)
        static let county = Column(CodingKeys.county)
        static let postcode = Column(CodingKeys.postcode)
        static let country = Column(CodingKeys.country)
        static let phoneHome = Column(CodingKeys.phoneHome)
        static let phoneWork = Column(CodingKeys.phoneWork)
        static let phoneMobile = Column(CodingKeys.phoneMobile)
        static let gpName = Column(CodingKeys.gpName)
        static let gpPractice = Column(CodingKeys.gpPractice)
        static let gpAddress = Column(CodingKeys.gpAddress)
        static let gpPostcode = Column(CodingKeys.gpPostcode)
        static let gpOdsCode = Column(CodingKeys.gpOdsCode)
        static let gpOfficialName = Column(CodingKeys.gpOfficialName)
        static let extractionConfidence = Column(CodingKeys.extractionConfidence)
        static let extractionMethod = Column(CodingKeys.extractionMethod)
        static let extractedAt = Column(CodingKeys.extractedAt)
        static let postcodeValid = Column(CodingKeys.postcodeValid)
        static let postcodeDistrict = Column(CodingKeys.postcodeDistrict)
        static let rawText = Column(CodingKeys.rawText)
        static let ocrJson = Column(CodingKeys.ocrJson)
        static let addressType = Column(CodingKeys.addressType)
        static let isPrime = Column(CodingKeys.isPrime)
        static let specialistName = Column(CodingKeys.specialistName)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case documentId = "document_id"
        case pageNumber = "page_number"
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case city
        case county
        case postcode
        case country
        case phoneHome = "phone_home"
        case phoneWork = "phone_work"
        case phoneMobile = "phone_mobile"
        case gpName = "gp_name"
        case gpPractice = "gp_practice"
        case gpAddress = "gp_address"
        case gpPostcode = "gp_postcode"
        case gpOdsCode = "gp_ods_code"
        case gpOfficialName = "gp_official_name"
        case extractionConfidence = "extraction_confidence"
        case extractionMethod = "extraction_method"
        case extractedAt = "extracted_at"
        case postcodeValid = "postcode_valid"
        case postcodeDistrict = "postcode_district"
        case rawText = "raw_text"
        case ocrJson = "ocr_json"
        case addressType = "address_type"
        case isPrime = "is_prime"
        case specialistName = "specialist_name"
    }
}

// MARK: - Table Name
extension ExtractedAddress {
    static let databaseTableName = "extracted_addresses"
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
