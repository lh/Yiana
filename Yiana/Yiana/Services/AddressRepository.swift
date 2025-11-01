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
            try ExtractedAddress
                .filter(ExtractedAddress.Columns.documentId == documentId)
                .order(ExtractedAddress.Columns.pageNumber.asc)
                .fetchAll(db)
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
