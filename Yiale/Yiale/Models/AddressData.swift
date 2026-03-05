import Foundation

// MARK: - JSON File Schema (matches .addresses/*.json)

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

struct PhoneInfo: Codable {
    var home: String?
    var work: String?
    var mobile: String?
}

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

struct GPInfo: Codable {
    var name: String?
    var practice: String?
    var address: String?
    var postcode: String?
}

struct ExtractionInfo: Codable {
    var method: String?
    var confidence: Double?
}

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

// MARK: - Resolved Patient (flattened view model for compose UI)

/// Flattened patient data after resolving overrides and enrichment.
/// Used for patient search results and compose form population.
struct ResolvedPatient: Identifiable {
    let id: String  // documentId
    let documentId: String

    // Patient
    var fullName: String
    var dateOfBirth: String?
    var mrn: String?
    var address: [String]
    var phones: [String]

    // GP
    var gpName: String?
    var gpPractice: String?
    var gpAddress: String?
    var gpPostcode: String?

    /// The yianazip filename stem, used as yiana_target for the letter draft.
    var yianaTarget: String { documentId }

    /// Build from a DocumentAddressFile, resolving overrides and enrichment.
    /// Takes the prime patient page (or first page) and applies override chain.
    init(from file: DocumentAddressFile) {
        self.documentId = file.documentId
        self.id = file.documentId

        // Find the prime patient page, falling back to the first page
        let primePage = file.pages.first(where: { $0.isPrime == true && ($0.addressType ?? "patient") == "patient" })
            ?? file.pages.first

        // Find matching override (most recent)
        let pageNumber = primePage?.pageNumber ?? 1
        let override = file.overrides
            .filter { $0.pageNumber == pageNumber && $0.matchAddressType == (primePage?.addressType ?? "patient") }
            .sorted { ($0.overrideDate ?? "") > ($1.overrideDate ?? "") }
            .first

        // Resolve patient info: override > enriched > page
        let patient = override?.patient ?? primePage?.patient
        let addr = override?.address ?? primePage?.address
        let gp = override?.gp ?? primePage?.gp

        var name = patient?.fullName ?? ""
        var dob = patient?.dateOfBirth

        // Enriched name/DOB (from backend DB) replaces OCR data, unless user overrode
        if let ep = file.enriched?.patient, override?.patient == nil {
            if let enrichedName = ep.fullName, !enrichedName.isEmpty {
                name = enrichedName
            }
            if let enrichedDob = ep.dateOfBirth, !enrichedDob.isEmpty {
                dob = enrichedDob
            }
        }

        self.fullName = name
        self.dateOfBirth = dob

        // Parse MRN from documentId (Surname_First_MRN convention)
        let parts = file.documentId.split(separator: "_")
        if parts.count >= 3 {
            self.mrn = String(parts.last!)
        } else {
            self.mrn = nil
        }

        // Build address lines
        var addressLines: [String] = []
        if let line1 = addr?.line1, !line1.isEmpty { addressLines.append(line1) }
        if let line2 = addr?.line2, !line2.isEmpty { addressLines.append(line2) }
        if let city = addr?.city, !city.isEmpty { addressLines.append(city) }
        if let county = addr?.county, !county.isEmpty { addressLines.append(county) }
        if let postcode = addr?.postcode, !postcode.isEmpty { addressLines.append(postcode) }
        self.address = addressLines

        // Build phone list
        var phoneList: [String] = []
        if let home = patient?.phones?.home, !home.isEmpty { phoneList.append(home) }
        if let work = patient?.phones?.work, !work.isEmpty { phoneList.append(work) }
        if let mobile = patient?.phones?.mobile, !mobile.isEmpty { phoneList.append(mobile) }
        self.phones = phoneList

        // GP info
        self.gpName = gp?.name
        self.gpPractice = gp?.practice
        self.gpAddress = gp?.address
        self.gpPostcode = gp?.postcode
    }
}
