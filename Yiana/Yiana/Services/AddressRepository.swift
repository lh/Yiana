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
            // Use CASE to prefer override values even if they're empty strings
            try ExtractedAddress.fetchAll(db, sql: """
                SELECT
                    ea.id,
                    CASE WHEN ao.id IS NOT NULL THEN ao.document_id ELSE ea.document_id END as document_id,
                    CASE WHEN ao.id IS NOT NULL THEN ao.page_number ELSE ea.page_number END as page_number,
                    CASE WHEN ao.id IS NOT NULL THEN ao.full_name ELSE ea.full_name END as full_name,
                    CASE WHEN ao.id IS NOT NULL THEN ao.date_of_birth ELSE ea.date_of_birth END as date_of_birth,
                    CASE WHEN ao.id IS NOT NULL THEN ao.address_line_1 ELSE ea.address_line_1 END as address_line_1,
                    CASE WHEN ao.id IS NOT NULL THEN ao.address_line_2 ELSE ea.address_line_2 END as address_line_2,
                    CASE WHEN ao.id IS NOT NULL THEN ao.city ELSE ea.city END as city,
                    CASE WHEN ao.id IS NOT NULL THEN ao.county ELSE ea.county END as county,
                    CASE WHEN ao.id IS NOT NULL THEN ao.postcode ELSE ea.postcode END as postcode,
                    CASE WHEN ao.id IS NOT NULL THEN ao.country ELSE ea.country END as country,
                    CASE WHEN ao.id IS NOT NULL THEN ao.phone_home ELSE ea.phone_home END as phone_home,
                    CASE WHEN ao.id IS NOT NULL THEN ao.phone_work ELSE ea.phone_work END as phone_work,
                    CASE WHEN ao.id IS NOT NULL THEN ao.phone_mobile ELSE ea.phone_mobile END as phone_mobile,
                    CASE WHEN ao.id IS NOT NULL THEN ao.gp_name ELSE ea.gp_name END as gp_name,
                    CASE WHEN ao.id IS NOT NULL THEN ao.gp_practice ELSE ea.gp_practice END as gp_practice,
                    CASE WHEN ao.id IS NOT NULL THEN ao.gp_address ELSE ea.gp_address END as gp_address,
                    CASE WHEN ao.id IS NOT NULL THEN ao.gp_postcode ELSE ea.gp_postcode END as gp_postcode,
                    ea.gp_ods_code,
                    ea.gp_official_name,
                    ea.extraction_confidence,
                    ea.extraction_method,
                    ea.extracted_at,
                    ea.postcode_valid,
                    ea.postcode_district,
                    ea.raw_text,
                    ea.ocr_json,
                    CASE WHEN ao.id IS NOT NULL THEN ao.address_type ELSE ea.address_type END as address_type,
                    CASE WHEN ao.id IS NOT NULL THEN ao.is_prime ELSE ea.is_prime END as is_prime,
                    CASE WHEN ao.id IS NOT NULL THEN ao.specialist_name ELSE ea.specialist_name END as specialist_name
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
                    address_type,
                    is_prime,
                    specialist_name,
                    override_reason,
                    is_training_candidate,
                    training_used
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0)
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
                    updatedAddress.addressType,
                    updatedAddress.isPrime,
                    updatedAddress.specialistName,
                    reason
                ]
            )
        }

        logger.info("Saved override for address ID \(originalId) with reason '\(reason)'")
    }

    /// Toggle the prime status of an address
    /// Ensures only one address of the same type (except specialists) is marked as prime per document
    /// - Parameters:
    ///   - addressId: The ID of the address to toggle
    ///   - documentId: The document ID
    ///   - addressType: The type of the address
    ///   - makePrime: Whether to make this address prime (true) or non-prime (false)
    func togglePrime(addressId: Int64, documentId: String, addressType: String, makePrime: Bool) async throws {
        guard let dbQueue else {
            throw NSError(domain: "AddressRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Database not available"
            ])
        }

        try await dbQueue.write { db in
            if makePrime && addressType != "specialist" {
                // First, unset prime for all other addresses of this type in the document
                try db.execute(sql: """
                    UPDATE extracted_addresses
                    SET is_prime = 0
                    WHERE document_id = ? AND address_type = ? AND id != ?
                    """, arguments: [documentId, addressType, addressId])

                try db.execute(sql: """
                    UPDATE address_overrides
                    SET is_prime = 0
                    WHERE document_id = ? AND address_type = ? AND original_extraction_id != ?
                    """, arguments: [documentId, addressType, addressId])
            }

            // Now toggle the target address
            try db.execute(sql: """
                UPDATE extracted_addresses
                SET is_prime = ?
                WHERE id = ?
                """, arguments: [makePrime ? 1 : 0, addressId])

            // Also update any override for this address
            try db.execute(sql: """
                UPDATE address_overrides
                SET is_prime = ?
                WHERE original_extraction_id = ?
                AND (override_reason IS NULL OR override_reason != 'removed')
                """, arguments: [makePrime ? 1 : 0, addressId])
        }

        logger.info("Toggled prime status for address ID \(addressId) to \(makePrime)")
    }

    /// Update the address type for an address
    /// - Parameters:
    ///   - addressId: The ID of the address
    ///   - newType: The new address type
    ///   - specialistName: The specialist name (if type is specialist)
    func updateAddressType(addressId: Int64, newType: String, specialistName: String?) async throws {
        guard let dbQueue else {
            throw NSError(domain: "AddressRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Database not available"
            ])
        }

        try await dbQueue.write { db in
            try db.execute(sql: """
                UPDATE extracted_addresses
                SET address_type = ?, specialist_name = ?
                WHERE id = ?
                """, arguments: [newType, specialistName, addressId])

            // Also update any override for this address
            try db.execute(sql: """
                UPDATE address_overrides
                SET address_type = ?, specialist_name = ?
                WHERE original_extraction_id = ?
                AND (override_reason IS NULL OR override_reason != 'removed')
                """, arguments: [newType, specialistName, addressId])
        }

        logger.info("Updated address type for ID \(addressId) to \(newType)")
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
