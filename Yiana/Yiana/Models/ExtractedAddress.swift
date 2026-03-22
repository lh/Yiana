//
//  ExtractedAddress.swift
//  Yiana
//
//  View-facing model for addresses extracted from medical documents.
//  JSON schema types (DocumentAddressFile, AddressPageEntry, etc.) are
//  defined in the YianaExtraction package — imported here.
//

import Foundation
import YianaExtraction

// MARK: - View-Facing Model (flat structure for UI)

struct ExtractedAddress {
    var documentId: String
    var pageNumber: Int?

    // Patient Information
    var fullName: String?
    var surname: String?
    var firstname: String?
    var title: String?
    var dateOfBirth: String?
    var mrn: String?

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
    var nhsGPCandidates: [NHSCandidate]?

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
    var matchAddressType: String?  // Original page type for override matching
    var addressType: String?
    var isPrime: Bool?
    var specialistName: String?
    var isDismissed: Bool?
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
        self.mrn = patient?.mrn
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
        self.gpOdsCode = gp?.odsCode
        self.gpOfficialName = gp?.officialName
        self.nhsGPCandidates = gp?.nhsCandidates

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
        self.matchAddressType = page.addressType ?? "patient"
        self.addressType = override?.addressType ?? page.addressType
        self.isPrime = override?.isPrime ?? page.isPrime
        self.specialistName = override?.specialistName ?? page.specialistName
        self.isDismissed = override?.isDismissed

        // Fields not in the JSON schema
        self.country = nil
        self.rawText = nil
        self.ocrJson = nil

        // Enriched patient data fills gaps in override/page data.
        // Override may have partial patient info (e.g. just a title like "Mrs")
        // so use enriched values when the resolved name looks incomplete.
        if let ep = enriched?.patient {
            let nameIsSubstantive = (self.fullName ?? "").split(separator: " ").count >= 2
            if !nameIsSubstantive, let name = ep.fullName, !name.isEmpty {
                self.fullName = name
            }
            if (self.dateOfBirth == nil || self.dateOfBirth?.isEmpty == true),
               let dob = ep.dateOfBirth, !dob.isEmpty {
                self.dateOfBirth = dob
            }
            if self.surname == nil || self.surname?.isEmpty == true {
                self.surname = ep.surname
            }
            if self.firstname == nil || self.firstname?.isEmpty == true {
                self.firstname = ep.firstname
            }
        }

        // Infer title from fullName if it starts with a known title prefix
        if self.title == nil, let name = self.fullName {
            let knownTitles = ["Mr", "Mrs", "Ms", "Miss", "Dr", "Prof"]
            for t in knownTitles where name.hasPrefix(t + " ") {
                self.title = t
                break
            }
        }

        // Derive surname/firstname from fullName when not already set
        if (self.surname == nil || self.surname?.isEmpty == true),
           (self.firstname == nil || self.firstname?.isEmpty == true),
           let name = self.fullName, !name.isEmpty {
            // Strip title prefix if present
            var nameToParse = name
            if let t = self.title {
                nameToParse = String(name.dropFirst(t.count).drop(while: { $0 == " " }))
            }
            let parts = nameToParse.split(separator: " ").map(String.init)
            if parts.count >= 2 {
                self.firstname = parts.dropLast().joined(separator: " ")
                self.surname = parts.last
            } else if parts.count == 1 {
                self.surname = parts[0]
            }
        }
    }
}

// MARK: - Empty Address Init

extension ExtractedAddress {
    /// Create an empty address for a given document and page (for manual entry)
    init(documentId: String, pageNumber: Int) {
        self.documentId = documentId
        self.pageNumber = pageNumber
    }
}

// MARK: - Manual Address Init

extension ExtractedAddress {
    /// Create from a manual override (page 0, no extraction data)
    init(documentId: String, manualOverride: AddressOverrideEntry) {
        self.documentId = documentId
        self.pageNumber = 0

        let patient = manualOverride.patient
        self.fullName = patient?.fullName
        self.dateOfBirth = patient?.dateOfBirth
        self.mrn = patient?.mrn
        self.phoneHome = patient?.phones?.home
        self.phoneWork = patient?.phones?.work
        self.phoneMobile = patient?.phones?.mobile

        let address = manualOverride.address
        self.addressLine1 = address?.line1
        self.addressLine2 = address?.line2
        self.city = address?.city
        self.county = address?.county
        self.postcode = address?.postcode
        self.postcodeValid = address?.postcodeValid
        self.postcodeDistrict = address?.postcodeDistrict

        let gp = manualOverride.gp
        self.gpName = gp?.name
        self.gpPractice = gp?.practice
        self.gpAddress = gp?.address
        self.gpPostcode = gp?.postcode
        self.gpOdsCode = gp?.odsCode
        self.gpOfficialName = gp?.officialName

        self.matchAddressType = manualOverride.matchAddressType
        self.addressType = manualOverride.addressType ?? manualOverride.matchAddressType
        self.isPrime = manualOverride.isPrime
        self.specialistName = manualOverride.specialistName
        self.isDismissed = manualOverride.isDismissed

        self.extractionConfidence = nil
        self.extractionMethod = nil
        self.extractedAt = nil
        self.country = nil
        self.rawText = nil
        self.ocrJson = nil
        // Infer title/firstname/surname from fullName
        self.surname = nil
        self.firstname = nil
        self.title = nil
        if let name = self.fullName {
            let knownTitles = ["Mr", "Mrs", "Ms", "Miss", "Dr", "Prof"]
            for t in knownTitles where name.hasPrefix(t + " ") || name.hasPrefix(t + ". ") {
                self.title = t
                let afterTitle = String(name.dropFirst(t.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                let parts = afterTitle.components(separatedBy: " ").filter { !$0.isEmpty }
                if parts.count >= 2 {
                    self.firstname = parts.dropLast().joined(separator: " ")
                    self.surname = parts.last
                } else if parts.count == 1 {
                    self.surname = parts[0]
                }
                break
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
    /// Formatted full address for patient (postcode shown separately)
    var formattedPatientAddress: String? {
        let components = [addressLine1, addressLine2, city, county, country]
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
