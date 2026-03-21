import Foundation
import GRDB

// MARK: - Records

struct DocumentRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "documents"

    var id: Int64?
    var documentId: String
    var jsonHash: String
    var schemaVersion: Int?
    var extractedAt: String?
    var pageCount: Int?
    var ingestedAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, documentId = "document_id", jsonHash = "json_hash"
        case schemaVersion = "schema_version", extractedAt = "extracted_at"
        case pageCount = "page_count", ingestedAt = "ingested_at"
        case updatedAt = "updated_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct PatientRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "patients"

    var id: Int64?
    var fullName: String
    var fullNameNormalized: String
    var dateOfBirth: String?

    var addressLine1: String?
    var addressLine2: String?
    var city: String?
    var county: String?
    var postcode: String?
    var postcodeDistrict: String?

    var phoneHome: String?
    var phoneWork: String?
    var phoneMobile: String?

    var documentCount: Int
    var firstSeenAt: String
    var lastSeenAt: String

    enum CodingKeys: String, CodingKey {
        case id, fullName = "full_name", fullNameNormalized = "full_name_normalized"
        case dateOfBirth = "date_of_birth"
        case addressLine1 = "address_line_1", addressLine2 = "address_line_2"
        case city, county, postcode, postcodeDistrict = "postcode_district"
        case phoneHome = "phone_home", phoneWork = "phone_work", phoneMobile = "phone_mobile"
        case documentCount = "document_count"
        case firstSeenAt = "first_seen_at", lastSeenAt = "last_seen_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct PractitionerRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "practitioners"

    var id: Int64?
    var type: String
    var fullName: String?
    var fullNameNormalized: String?
    var practiceName: String?
    var odsCode: String?
    var officialName: String?
    var address: String?
    var postcode: String?

    var documentCount: Int
    var firstSeenAt: String
    var lastSeenAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, fullName = "full_name", fullNameNormalized = "full_name_normalized"
        case practiceName = "practice_name", odsCode = "ods_code"
        case officialName = "official_name", address, postcode
        case documentCount = "document_count"
        case firstSeenAt = "first_seen_at", lastSeenAt = "last_seen_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct ExtractionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "extractions"

    var id: Int64?
    var documentId: String
    var pageNumber: Int
    var addressType: String?
    var isPrime: Bool?

    var patientId: Int64?
    var practitionerId: Int64?

    var patientFullName: String?
    var patientDateOfBirth: String?
    var patientPhoneHome: String?
    var patientPhoneWork: String?
    var patientPhoneMobile: String?

    var addressLine1: String?
    var addressLine2: String?
    var addressCity: String?
    var addressCounty: String?
    var addressPostcode: String?
    var addressPostcodeValid: Bool?
    var addressPostcodeDistrict: String?

    var gpName: String?
    var gpPractice: String?
    var gpAddress: String?
    var gpPostcode: String?

    var extractionMethod: String?
    var extractionConfidence: Double?
    var specialistName: String?

    var hasOverride: Bool
    var overrideReason: String?
    var overrideDate: String?

    enum CodingKeys: String, CodingKey {
        case id, documentId = "document_id", pageNumber = "page_number"
        case addressType = "address_type", isPrime = "is_prime"
        case patientId = "patient_id", practitionerId = "practitioner_id"
        case patientFullName = "patient_full_name"
        case patientDateOfBirth = "patient_date_of_birth"
        case patientPhoneHome = "patient_phone_home"
        case patientPhoneWork = "patient_phone_work"
        case patientPhoneMobile = "patient_phone_mobile"
        case addressLine1 = "address_line_1", addressLine2 = "address_line_2"
        case addressCity = "address_city", addressCounty = "address_county"
        case addressPostcode = "address_postcode"
        case addressPostcodeValid = "address_postcode_valid"
        case addressPostcodeDistrict = "address_postcode_district"
        case gpName = "gp_name", gpPractice = "gp_practice"
        case gpAddress = "gp_address", gpPostcode = "gp_postcode"
        case extractionMethod = "extraction_method"
        case extractionConfidence = "extraction_confidence"
        case specialistName = "specialist_name"
        case hasOverride = "has_override", overrideReason = "override_reason"
        case overrideDate = "override_date"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct PatientDocumentRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "patient_documents"

    var id: Int64?
    var patientId: Int64
    var documentId: String

    enum CodingKeys: String, CodingKey {
        case id, patientId = "patient_id", documentId = "document_id"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct PatientPractitionerRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "patient_practitioners"

    var id: Int64?
    var patientId: Int64
    var practitionerId: Int64
    var relationshipType: String?
    var documentCount: Int
    var firstSeenAt: String
    var lastSeenAt: String

    enum CodingKeys: String, CodingKey {
        case id, patientId = "patient_id", practitionerId = "practitioner_id"
        case relationshipType = "relationship_type"
        case documentCount = "document_count"
        case firstSeenAt = "first_seen_at", lastSeenAt = "last_seen_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Statistics

public struct EntityStatistics: Sendable {
    public let documentCount: Int
    public let patientCount: Int
    public let practitionerCount: Int
    public let linkCount: Int
    public let extractionCount: Int
}

// MARK: - Entity Database

/// Entity resolution database — a derived cache built from `.addresses/*.json` files.
///
/// Deduplicates patients and practitioners across documents, tracks cross-document
/// links, and writes enriched data back to iCloud JSON files.
///
/// This database is rebuildable: delete it and re-ingest from JSON to get the same result.
public final class EntityDatabase: Sendable {
    private let dbQueue: DatabaseQueue

    /// Open or create an entity database at the given path.
    public init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try migrator.migrate(dbQueue)
    }

    /// Create an in-memory entity database (for testing).
    public init() throws {
        dbQueue = try DatabaseQueue()
        try migrator.migrate(dbQueue)
    }

    /// Get statistics about the entity database.
    public func statistics() throws -> EntityStatistics {
        try dbQueue.read { db in
            EntityStatistics(
                documentCount: try DocumentRecord.fetchCount(db),
                patientCount: try PatientRecord.fetchCount(db),
                practitionerCount: try PractitionerRecord.fetchCount(db),
                linkCount: try PatientPractitionerRecord.fetchCount(db),
                extractionCount: try ExtractionRecord.fetchCount(db)
            )
        }
    }

    // MARK: - Schema Migration

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            try db.create(table: "documents") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("document_id", .text).notNull().unique()
                t.column("json_hash", .text).notNull()
                t.column("schema_version", .integer)
                t.column("extracted_at", .text)
                t.column("page_count", .integer)
                t.column("ingested_at", .text).notNull()
                t.column("updated_at", .text)
            }

            try db.create(table: "patients") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("full_name", .text).notNull()
                t.column("full_name_normalized", .text).notNull()
                t.column("date_of_birth", .text)
                t.column("address_line_1", .text)
                t.column("address_line_2", .text)
                t.column("city", .text)
                t.column("county", .text)
                t.column("postcode", .text)
                t.column("postcode_district", .text)
                t.column("phone_home", .text)
                t.column("phone_work", .text)
                t.column("phone_mobile", .text)
                t.column("document_count", .integer).notNull().defaults(to: 1)
                t.column("first_seen_at", .text).notNull()
                t.column("last_seen_at", .text).notNull()
            }
            try db.create(index: "idx_patients_normalized",
                          on: "patients", columns: ["full_name_normalized", "date_of_birth"])
            try db.create(index: "idx_patients_name", on: "patients", columns: ["full_name"])

            try db.create(table: "practitioners") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("type", .text).notNull()
                t.column("full_name", .text)
                t.column("full_name_normalized", .text)
                t.column("practice_name", .text)
                t.column("ods_code", .text)
                t.column("official_name", .text)
                t.column("address", .text)
                t.column("postcode", .text)
                t.column("document_count", .integer).notNull().defaults(to: 1)
                t.column("first_seen_at", .text).notNull()
                t.column("last_seen_at", .text).notNull()
            }
            try db.create(index: "idx_practitioners_normalized",
                          on: "practitioners", columns: ["full_name_normalized", "type"])
            try db.create(index: "idx_practitioners_ods",
                          on: "practitioners", columns: ["ods_code"])

            try db.create(table: "extractions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("document_id", .text).notNull()
                    .references("documents", column: "document_id")
                t.column("page_number", .integer).notNull()
                t.column("address_type", .text)
                t.column("is_prime", .boolean)
                t.column("patient_id", .integer).references("patients")
                t.column("practitioner_id", .integer).references("practitioners")
                t.column("patient_full_name", .text)
                t.column("patient_date_of_birth", .text)
                t.column("patient_phone_home", .text)
                t.column("patient_phone_work", .text)
                t.column("patient_phone_mobile", .text)
                t.column("address_line_1", .text)
                t.column("address_line_2", .text)
                t.column("address_city", .text)
                t.column("address_county", .text)
                t.column("address_postcode", .text)
                t.column("address_postcode_valid", .boolean)
                t.column("address_postcode_district", .text)
                t.column("gp_name", .text)
                t.column("gp_practice", .text)
                t.column("gp_address", .text)
                t.column("gp_postcode", .text)
                t.column("extraction_method", .text)
                t.column("extraction_confidence", .double)
                t.column("specialist_name", .text)
                t.column("has_override", .boolean).notNull().defaults(to: false)
                t.column("override_reason", .text)
                t.column("override_date", .text)
                t.uniqueKey(["document_id", "page_number", "address_type"])
            }
            try db.create(index: "idx_extractions_document",
                          on: "extractions", columns: ["document_id"])
            try db.create(index: "idx_extractions_patient",
                          on: "extractions", columns: ["patient_id"])
            try db.create(index: "idx_extractions_practitioner",
                          on: "extractions", columns: ["practitioner_id"])

            try db.create(table: "patient_documents") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull().references("patients")
                t.column("document_id", .text).notNull()
                    .references("documents", column: "document_id")
                t.uniqueKey(["patient_id", "document_id"])
            }
            try db.create(index: "idx_patient_documents_patient",
                          on: "patient_documents", columns: ["patient_id"])
            try db.create(index: "idx_patient_documents_document",
                          on: "patient_documents", columns: ["document_id"])

            try db.create(table: "patient_practitioners") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull().references("patients")
                t.column("practitioner_id", .integer).notNull().references("practitioners")
                t.column("relationship_type", .text)
                t.column("document_count", .integer).notNull().defaults(to: 1)
                t.column("first_seen_at", .text).notNull()
                t.column("last_seen_at", .text).notNull()
                t.uniqueKey(["patient_id", "practitioner_id", "relationship_type"])
            }
            try db.create(index: "idx_pp_patient",
                          on: "patient_practitioners", columns: ["patient_id"])
            try db.create(index: "idx_pp_practitioner",
                          on: "patient_practitioners", columns: ["practitioner_id"])

            // Placeholder tables — schema only, no logic yet
            try db.create(table: "corrections") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("extraction_id", .integer).references("extractions")
                t.column("document_id", .text).notNull()
                t.column("page_number", .integer).notNull()
                t.column("field_name", .text).notNull()
                t.column("original_value", .text)
                t.column("corrected_value", .text)
                t.column("override_reason", .text)
                t.column("override_date", .text)
                t.column("reviewed", .boolean).notNull().defaults(to: false)
                t.column("applied_to_rules", .boolean).notNull().defaults(to: false)
                t.column("created_at", .text).notNull()
            }
            try db.create(index: "idx_corrections_document",
                          on: "corrections", columns: ["document_id"])
            try db.create(index: "idx_corrections_field",
                          on: "corrections", columns: ["field_name"])

            try db.create(table: "name_aliases") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("alias", .text).notNull()
                t.column("canonical", .text).notNull()
                t.column("entity_type", .text).notNull()
                t.column("source", .text)
                t.column("confidence", .double).defaults(to: 1.0)
                t.column("created_at", .text).notNull()
                t.uniqueKey(["alias", "entity_type"])
            }
            try db.create(index: "idx_name_aliases_alias",
                          on: "name_aliases", columns: ["alias", "entity_type"])
        }

        return migrator
    }
}
