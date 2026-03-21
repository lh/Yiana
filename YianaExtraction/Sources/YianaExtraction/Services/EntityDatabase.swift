import CryptoKit
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

    // MARK: - Ingestion

    /// Ingest a .addresses/*.json file, resolving entities and creating links.
    public func ingestAddressFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        let hash = Self.contentHash(of: data)
        let doc = try JSONDecoder().decode(DocumentAddressFile.self, from: data)
        try dbQueue.write { db in
            try self.ingestDocument(db, doc: doc, hash: hash)
        }
    }

    // MARK: - Query

    /// All patient records.
    func allPatients() throws -> [PatientRecord] {
        try dbQueue.read { db in try PatientRecord.fetchAll(db) }
    }

    /// All practitioner records.
    func allPractitioners() throws -> [PractitionerRecord] {
        try dbQueue.read { db in try PractitionerRecord.fetchAll(db) }
    }

    // MARK: - Entity Resolution

    func resolvePatient(_ db: Database, name: String, dob: String?) throws -> Int64? {
        let normalized = ExtractionHelpers.normalizeName(name)
        guard !normalized.isEmpty else { return nil }
        let now = Self.iso8601Now()

        var existing: PatientRecord?
        if let dob {
            existing = try PatientRecord
                .filter(Column("full_name_normalized") == normalized)
                .filter(Column("date_of_birth") == dob)
                .fetchOne(db)
        } else {
            let matches = try PatientRecord
                .filter(Column("full_name_normalized") == normalized)
                .fetchAll(db)
            if matches.count == 1 { existing = matches[0] }
        }

        if var patient = existing {
            patient.documentCount += 1
            patient.lastSeenAt = now
            try patient.update(db)
            return patient.id
        }

        let patient = PatientRecord(
            id: nil, fullName: name, fullNameNormalized: normalized,
            dateOfBirth: dob,
            addressLine1: nil, addressLine2: nil, city: nil, county: nil,
            postcode: nil, postcodeDistrict: nil,
            phoneHome: nil, phoneWork: nil, phoneMobile: nil,
            documentCount: 1, firstSeenAt: now, lastSeenAt: now
        )
        try patient.insert(db)
        return db.lastInsertedRowID
    }

    func resolvePractitioner(_ db: Database, name: String, type: String,
                             practiceName: String?, address: String?,
                             postcode: String?, odsCode: String?,
                             officialName: String?) throws -> Int64? {
        let normalized = ExtractionHelpers.normalizeName(name)
        guard !normalized.isEmpty else { return nil }
        let now = Self.iso8601Now()

        if var existing = try PractitionerRecord
            .filter(Column("full_name_normalized") == normalized)
            .filter(Column("type") == type)
            .fetchOne(db) {
            if let v = practiceName { existing.practiceName = v }
            if let v = address { existing.address = v }
            if let v = postcode { existing.postcode = v }
            if let v = odsCode { existing.odsCode = v }
            if let v = officialName { existing.officialName = v }
            existing.documentCount += 1
            existing.lastSeenAt = now
            try existing.update(db)
            return existing.id
        }

        let practitioner = PractitionerRecord(
            id: nil, type: type, fullName: name, fullNameNormalized: normalized,
            practiceName: practiceName, odsCode: odsCode, officialName: officialName,
            address: address, postcode: postcode,
            documentCount: 1, firstSeenAt: now, lastSeenAt: now
        )
        try practitioner.insert(db)
        return db.lastInsertedRowID
    }

    func linkPatientPractitioner(_ db: Database, patientId: Int64,
                                 practitionerId: Int64,
                                 relationshipType: String) throws {
        let now = Self.iso8601Now()
        if var existing = try PatientPractitionerRecord
            .filter(Column("patient_id") == patientId)
            .filter(Column("practitioner_id") == practitionerId)
            .filter(Column("relationship_type") == relationshipType)
            .fetchOne(db) {
            existing.documentCount += 1
            existing.lastSeenAt = now
            try existing.update(db)
        } else {
            let link = PatientPractitionerRecord(
                id: nil, patientId: patientId, practitionerId: practitionerId,
                relationshipType: relationshipType,
                documentCount: 1, firstSeenAt: now, lastSeenAt: now
            )
            try link.insert(db)
        }
    }

    // MARK: - Private Helpers

    private func ingestDocument(_ db: Database, doc: DocumentAddressFile,
                                hash: String) throws {
        let now = Self.iso8601Now()
        let documentId = doc.documentId

        // 1. Document upsert with hash check
        if let existing = try DocumentRecord
            .filter(Column("document_id") == documentId).fetchOne(db) {
            if existing.jsonHash == hash { return }
            try ExtractionRecord
                .filter(Column("document_id") == documentId).deleteAll(db)
            try PatientDocumentRecord
                .filter(Column("document_id") == documentId).deleteAll(db)
            var updated = existing
            updated.jsonHash = hash
            updated.schemaVersion = doc.schemaVersion
            updated.extractedAt = doc.extractedAt
            updated.pageCount = doc.pageCount
            updated.updatedAt = now
            try updated.update(db)
        } else {
            let docRecord = DocumentRecord(
                id: nil, documentId: documentId, jsonHash: hash,
                schemaVersion: doc.schemaVersion, extractedAt: doc.extractedAt,
                pageCount: doc.pageCount, ingestedAt: now, updatedAt: nil
            )
            try docRecord.insert(db)
        }

        // 2. Build override map: (pageNumber:addressType) -> override
        var overrideMap: [String: AddressOverrideEntry] = [:]
        for override in doc.overrides {
            let key = "\(override.pageNumber):\(override.matchAddressType)"
            if let prev = overrideMap[key] {
                if (override.overrideDate ?? "") > (prev.overrideDate ?? "") {
                    overrideMap[key] = override
                }
            } else {
                overrideMap[key] = override
            }
        }

        // 3. Resolve filename patient (document owner)
        let filenamePatient = ExtractionHelpers.parsePatientFilename(documentId)
        var filenamePatientId: Int64?
        if let fp = filenamePatient {
            filenamePatientId = try resolvePatient(
                db, name: fp.fullName, dob: fp.dateOfBirth)
        }

        // 4. Process pages
        var pagePatients: [Int: Set<Int64>] = [:]
        var pagePractitioners: [Int: [(Int64, String)]] = [:]
        var seenPatients = Set<Int64>()
        var seenPractitioners: [(Int64, String)] = []
        var linkedPairs = Set<String>()

        for page in doc.pages {
            let pageNum = page.pageNumber
            let addressType = page.addressType ?? "patient"
            let overrideKey = "\(pageNum):\(addressType)"
            let override = overrideMap[overrideKey]

            let effectivePatient = override?.patient ?? page.patient
            let effectiveAddress = override?.address ?? page.address
            let effectiveGP = override?.gp ?? page.gp
            let effectiveSpecialist = override?.specialistName ?? page.specialistName
            let effectiveAddressType = override?.addressType ?? addressType

            // Patient: filename patient is document owner
            let pagePatientId = filenamePatientId
            if let pid = pagePatientId, effectiveAddressType == "patient" {
                try updatePatientData(db, patientId: pid,
                                      address: effectiveAddress,
                                      phones: effectivePatient?.phones)
            }

            // GP practitioner
            var gpId: Int64?
            if let gpName = effectiveGP?.name, !gpName.isEmpty {
                gpId = try resolvePractitioner(
                    db, name: gpName, type: "GP",
                    practiceName: effectiveGP?.practice,
                    address: effectiveGP?.address,
                    postcode: effectiveGP?.postcode,
                    odsCode: effectiveGP?.odsCode,
                    officialName: effectiveGP?.officialName)
            }

            // Specialist practitioner
            var specialistId: Int64?
            if effectiveAddressType == "specialist",
               let specName = effectiveSpecialist, !specName.isEmpty {
                specialistId = try resolvePractitioner(
                    db, name: specName, type: "Consultant",
                    practiceName: nil, address: nil, postcode: nil,
                    odsCode: nil, officialName: nil)
            }

            // Extraction record
            let extraction = ExtractionRecord(
                id: nil, documentId: documentId, pageNumber: pageNum,
                addressType: effectiveAddressType, isPrime: page.isPrime,
                patientId: pagePatientId, practitionerId: gpId ?? specialistId,
                patientFullName: effectivePatient?.fullName,
                patientDateOfBirth: effectivePatient?.dateOfBirth,
                patientPhoneHome: effectivePatient?.phones?.home,
                patientPhoneWork: effectivePatient?.phones?.work,
                patientPhoneMobile: effectivePatient?.phones?.mobile,
                addressLine1: effectiveAddress?.line1,
                addressLine2: effectiveAddress?.line2,
                addressCity: effectiveAddress?.city,
                addressCounty: effectiveAddress?.county,
                addressPostcode: effectiveAddress?.postcode,
                addressPostcodeValid: effectiveAddress?.postcodeValid,
                addressPostcodeDistrict: effectiveAddress?.postcodeDistrict,
                gpName: effectiveGP?.name,
                gpPractice: effectiveGP?.practice,
                gpAddress: effectiveGP?.address,
                gpPostcode: effectiveGP?.postcode,
                extractionMethod: page.extraction?.method,
                extractionConfidence: page.extraction?.confidence,
                specialistName: effectiveSpecialist,
                hasOverride: override != nil,
                overrideReason: override?.overrideReason,
                overrideDate: override?.overrideDate
            )
            try extraction.insert(db)

            // Track for cross-row linking
            if let pid = pagePatientId {
                pagePatients[pageNum, default: []].insert(pid)
                seenPatients.insert(pid)
            }
            if let gid = gpId {
                pagePractitioners[pageNum, default: []].append((gid, "GP"))
                seenPractitioners.append((gid, "GP"))
            }
            if let sid = specialistId {
                pagePractitioners[pageNum, default: []].append((sid, "Consultant"))
                seenPractitioners.append((sid, "Consultant"))
            }
        }

        // 5. Cross-row linking
        // Strategy 1: same-page
        for (pageNum, patientIds) in pagePatients {
            for patientId in patientIds {
                for (practId, relType) in pagePractitioners[pageNum] ?? [] {
                    let key = "\(patientId):\(practId):\(relType)"
                    if linkedPairs.insert(key).inserted {
                        try linkPatientPractitioner(
                            db, patientId: patientId,
                            practitionerId: practId,
                            relationshipType: relType)
                    }
                }
            }
        }
        // Strategy 2: single-patient document
        if seenPatients.count == 1, let sole = seenPatients.first {
            for (practId, relType) in seenPractitioners {
                let key = "\(sole):\(practId):\(relType)"
                if linkedPairs.insert(key).inserted {
                    try linkPatientPractitioner(
                        db, patientId: sole,
                        practitionerId: practId,
                        relationshipType: relType)
                }
            }
        }

        // 6. Patient-document links
        for pid in seenPatients {
            let link = PatientDocumentRecord(
                id: nil, patientId: pid, documentId: documentId)
            try link.insert(db)
        }
    }

    private func updatePatientData(_ db: Database, patientId: Int64,
                                   address: AddressInfo?,
                                   phones: PhoneInfo?) throws {
        guard var patient = try PatientRecord.fetchOne(db, key: patientId)
        else { return }
        var changed = false
        if let addr = address {
            if let v = addr.line1 { patient.addressLine1 = v; changed = true }
            if let v = addr.line2 { patient.addressLine2 = v; changed = true }
            if let v = addr.city { patient.city = v; changed = true }
            if let v = addr.county { patient.county = v; changed = true }
            if let v = addr.postcode { patient.postcode = v; changed = true }
            if let v = addr.postcodeDistrict {
                patient.postcodeDistrict = v; changed = true
            }
        }
        if let ph = phones {
            if let v = ph.home { patient.phoneHome = v; changed = true }
            if let v = ph.work { patient.phoneWork = v; changed = true }
            if let v = ph.mobile { patient.phoneMobile = v; changed = true }
        }
        if changed { try patient.update(db) }
    }

    // MARK: - Utilities

    static func contentHash(of data: Data) -> String {
        if var dict = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any] {
            dict.removeValue(forKey: "enriched")
            if let normalized = try? JSONSerialization.data(
                withJSONObject: dict, options: [.sortedKeys]) {
                let digest = SHA256.hash(data: normalized)
                return digest.map { String(format: "%02x", $0) }.joined()
            }
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
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
