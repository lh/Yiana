//
//  AddressRepository.swift
//  Yiana
//
//  Provides access to extracted address database
//

import Foundation
import GRDB
import Combine

/// Repository for accessing extracted address data
@MainActor
final class AddressRepository: ObservableObject {
    private let dbQueue: DatabaseQueue?
    private let logger = Logger(subsystem: "com.vitygas.Yiana", category: "AddressRepository")

    /// Database file URL in iCloud container
    private static var databaseURL: URL? {
        guard let iCloudURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana"
        ) else {
            return nil
        }
        return iCloudURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("addresses.db")
    }

    init() {
        guard let dbURL = Self.databaseURL else {
            logger.error("Failed to locate iCloud container")
            self.dbQueue = nil
            return
        }

        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            logger.warning("addresses.db does not exist at \(dbURL.path)")
            self.dbQueue = nil
            return
        }

        do {
            // Open database in read-write mode for Phase 2 (user editing)
            var config = Configuration()
            config.label = "AddressRepository"

            self.dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)
            logger.info("Opened addresses.db at \(dbURL.path)")
        } catch {
            logger.error("Failed to open database: \(error)")
            self.dbQueue = nil
        }
    }

    /// Fetch all addresses for a specific document
    /// - Parameter documentId: The document ID (filename without extension)
    /// - Returns: Array of extracted addresses, or empty array if none found
    func addresses(forDocument documentId: String) async throws -> [ExtractedAddress] {
        guard let dbQueue else {
            return []
        }

        return try await dbQueue.read { db in
            // Query with LEFT JOIN to get user overrides when present
            // Use subquery to get only the most recent override for each address
            try ExtractedAddress.fetchAll(db, sql: """
                SELECT
                    ea.id,
                    COALESCE(ao.document_id, ea.document_id) as document_id,
                    COALESCE(ao.page_number, ea.page_number) as page_number,
                    COALESCE(ao.full_name, ea.full_name) as full_name,
                    COALESCE(ao.date_of_birth, ea.date_of_birth) as date_of_birth,
                    COALESCE(ao.address_line_1, ea.address_line_1) as address_line_1,
                    COALESCE(ao.address_line_2, ea.address_line_2) as address_line_2,
                    COALESCE(ao.city, ea.city) as city,
                    COALESCE(ao.county, ea.county) as county,
                    COALESCE(ao.postcode, ea.postcode) as postcode,
                    COALESCE(ao.country, ea.country) as country,
                    COALESCE(ao.phone_home, ea.phone_home) as phone_home,
                    COALESCE(ao.phone_work, ea.phone_work) as phone_work,
                    COALESCE(ao.phone_mobile, ea.phone_mobile) as phone_mobile,
                    COALESCE(ao.gp_name, ea.gp_name) as gp_name,
                    COALESCE(ao.gp_practice, ea.gp_practice) as gp_practice,
                    COALESCE(ao.gp_address, ea.gp_address) as gp_address,
                    COALESCE(ao.gp_postcode, ea.gp_postcode) as gp_postcode,
                    ea.gp_ods_code,
                    ea.gp_official_name,
                    ea.extraction_confidence,
                    ea.extraction_method,
                    ea.extracted_at,
                    ea.postcode_valid,
                    ea.postcode_district,
                    ea.raw_text,
                    ea.ocr_json
                FROM extracted_addresses ea
                LEFT JOIN address_overrides ao ON ea.id = ao.original_extraction_id
                    AND (ao.override_reason IS NULL OR ao.override_reason != 'removed')
                    AND ao.id = (
                        SELECT id FROM address_overrides
                        WHERE original_extraction_id = ea.id
                        AND (override_reason IS NULL OR override_reason != 'removed')
                        ORDER BY overridden_at DESC
                        LIMIT 1
                    )
                WHERE ea.document_id = ?
                ORDER BY ea.page_number ASC
                """, arguments: [documentId])
        }
    }

    /// Fetch all addresses from all documents
    /// - Returns: Array of all extracted addresses
    func allAddresses() async throws -> [ExtractedAddress] {
        guard let dbQueue else {
            return []
        }

        return try await dbQueue.read { db in
            try ExtractedAddress
                .order(ExtractedAddress.Columns.extractedAt.desc)
                .fetchAll(db)
        }
    }

    /// Check if database is available
    var isDatabaseAvailable: Bool {
        dbQueue != nil
    }

    /// Get statistics about the address database
    func statistics() async throws -> DatabaseStatistics {
        guard let dbQueue else {
            return DatabaseStatistics(
                totalAddresses: 0,
                documentsWithAddresses: 0,
                patientsFound: 0,
                gpsFound: 0
            )
        }

        return try await dbQueue.read { db in
            let total = try ExtractedAddress.fetchCount(db)
            let docsWithAddresses = try Int.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT document_id) FROM extracted_addresses
                """) ?? 0
            let patientsFound = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM extracted_addresses WHERE full_name IS NOT NULL
                """) ?? 0
            let gpsFound = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM extracted_addresses WHERE gp_name IS NOT NULL OR gp_practice IS NOT NULL
                """) ?? 0

            return DatabaseStatistics(
                totalAddresses: total,
                documentsWithAddresses: docsWithAddresses,
                patientsFound: patientsFound,
                gpsFound: gpsFound
            )
        }
    }

    /// Save user correction as an override
    /// - Parameters:
    ///   - originalId: The ID of the original extracted address
    ///   - updatedAddress: The corrected address data
    ///   - reason: Reason for override ("corrected", "added", "removed", "false_positive")
    func saveOverride(originalId: Int64, updatedAddress: ExtractedAddress, reason: String) async throws {
        guard let dbQueue else {
            throw NSError(domain: "AddressRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Database not available"
            ])
        }

        try await dbQueue.write { db in
            // Insert override record
            try db.execute(sql: """
                INSERT INTO address_overrides (
                    document_id,
                    page_number,
                    original_extraction_id,
                    full_name,
                    date_of_birth,
                    address_line_1,
                    address_line_2,
                    city,
                    county,
                    postcode,
                    country,
                    phone_home,
                    phone_work,
                    phone_mobile,
                    gp_name,
                    gp_practice,
                    gp_address,
                    gp_postcode,
                    override_reason,
                    is_training_candidate,
                    training_used
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0)
                """,
                arguments: [
                    updatedAddress.documentId,
                    updatedAddress.pageNumber,
                    originalId,
                    updatedAddress.fullName,
                    updatedAddress.dateOfBirth,
                    updatedAddress.addressLine1,
                    updatedAddress.addressLine2,
                    updatedAddress.city,
                    updatedAddress.county,
                    updatedAddress.postcode,
                    updatedAddress.country,
                    updatedAddress.phoneHome,
                    updatedAddress.phoneWork,
                    updatedAddress.phoneMobile,
                    updatedAddress.gpName,
                    updatedAddress.gpPractice,
                    updatedAddress.gpAddress,
                    updatedAddress.gpPostcode,
                    reason
                ]
            )
        }

        logger.info("Saved override for address ID \(originalId) with reason '\(reason)'")
    }
}

// MARK: - Statistics
struct DatabaseStatistics {
    let totalAddresses: Int
    let documentsWithAddresses: Int
    let patientsFound: Int
    let gpsFound: Int
}

// MARK: - Logger Placeholder
// Simple logger implementation (replace with OSLog if needed)
private struct Logger {
    let subsystem: String
    let category: String

    func info(_ message: String) {
        print("[\(category)] INFO: \(message)")
    }

    func warning(_ message: String) {
        print("[\(category)] WARNING: \(message)")
    }

    func error(_ message: String) {
        print("[\(category)] ERROR: \(message)")
    }
}
