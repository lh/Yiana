//
//  AddressRepository.swift
//  Yiana
//
//  Provides access to extracted address data from .addresses/ JSON files
//

import Foundation
import Combine
import os

/// Repository for accessing extracted address data from iCloud-synced JSON files
@MainActor
final class AddressRepository: ObservableObject {
    private let logger = Logger(subsystem: "com.vitygas.Yiana", category: "AddressRepository")

    /// Directory URL for .addresses/ in iCloud container
    private static var addressesDirectoryURL: URL? {
        guard let iCloudURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana"
        ) else {
            return nil
        }
        return iCloudURL
            .appendingPathComponent("Documents")
            .appendingPathComponent(".addresses")
    }

    /// Check if the addresses directory exists and contains files
    static var isDatabaseAvailable: Bool {
        guard let dirURL = addressesDirectoryURL else { return false }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir),
              isDir.boolValue else {
            return false
        }
        // Check that there's at least one .json file
        let contents = try? FileManager.default.contentsOfDirectory(
            at: dirURL, includingPropertiesForKeys: nil)
        return contents?.contains(where: { $0.pathExtension == "json" }) ?? false
    }

    /// Check if repository is available (instance method)
    var isDatabaseAvailable: Bool {
        Self.isDatabaseAvailable
    }

    init() {
        if let dirURL = Self.addressesDirectoryURL {
            logger.info("Addresses directory: \(dirURL.path)")
        } else {
            logger.error("Failed to locate iCloud container")
        }
    }

    // MARK: - Read Methods

    /// Fetch all addresses for a specific document
    func addresses(forDocument documentId: String) async throws -> [ExtractedAddress] {
        guard let dirURL = Self.addressesDirectoryURL else { return [] }

        let fileURL = dirURL.appendingPathComponent("\(documentId).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        let file = try readAddressFile(at: fileURL)
        return resolveAddresses(from: file)
    }

    /// Fetch all addresses from all documents
    func allAddresses() async throws -> [ExtractedAddress] {
        guard let dirURL = Self.addressesDirectoryURL else { return [] }
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return [] }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: dirURL, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" }

        var allResults: [ExtractedAddress] = []
        for fileURL in fileURLs {
            do {
                let file = try readAddressFile(at: fileURL)
                allResults.append(contentsOf: resolveAddresses(from: file))
            } catch {
                logger.warning("Failed to read \(fileURL.lastPathComponent): \(error)")
            }
        }

        // Sort by extraction date, most recent first
        allResults.sort { ($0.extractedAt ?? .distantPast) > ($1.extractedAt ?? .distantPast) }
        return allResults
    }

    /// Get statistics about the address data
    func statistics() async throws -> DatabaseStatistics {
        guard let dirURL = Self.addressesDirectoryURL else {
            return DatabaseStatistics(totalAddresses: 0, documentsWithAddresses: 0, patientsFound: 0, gpsFound: 0)
        }
        guard FileManager.default.fileExists(atPath: dirURL.path) else {
            return DatabaseStatistics(totalAddresses: 0, documentsWithAddresses: 0, patientsFound: 0, gpsFound: 0)
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        var totalAddresses = 0
        var patientsFound = 0
        var gpsFound = 0

        for fileURL in fileURLs {
            do {
                let file = try readAddressFile(at: fileURL)
                let addresses = resolveAddresses(from: file)
                totalAddresses += addresses.count
                patientsFound += addresses.filter { $0.fullName != nil }.count
                gpsFound += addresses.filter { $0.gpName != nil || $0.gpPractice != nil }.count
            } catch {
                continue
            }
        }

        return DatabaseStatistics(
            totalAddresses: totalAddresses,
            documentsWithAddresses: fileURLs.count,
            patientsFound: patientsFound,
            gpsFound: gpsFound
        )
    }

    // MARK: - Write Methods (all use atomic writes)

    /// Save user correction as an override
    func saveOverride(documentId: String, pageNumber: Int, matchAddressType: String,
                      updatedAddress: ExtractedAddress, reason: String) async throws {
        let file = try readOrCreateFile(forDocument: documentId)

        let override = AddressOverrideEntry(
            pageNumber: pageNumber,
            matchAddressType: matchAddressType,
            patient: PatientInfo(
                fullName: updatedAddress.fullName,
                dateOfBirth: updatedAddress.dateOfBirth,
                phones: PhoneInfo(
                    home: updatedAddress.phoneHome,
                    work: updatedAddress.phoneWork,
                    mobile: updatedAddress.phoneMobile
                )
            ),
            address: AddressInfo(
                line1: updatedAddress.addressLine1,
                line2: updatedAddress.addressLine2,
                city: updatedAddress.city,
                county: updatedAddress.county,
                postcode: updatedAddress.postcode,
                postcodeValid: updatedAddress.postcodeValid,
                postcodeDistrict: updatedAddress.postcodeDistrict
            ),
            gp: GPInfo(
                name: updatedAddress.gpName,
                practice: updatedAddress.gpPractice,
                address: updatedAddress.gpAddress,
                postcode: updatedAddress.gpPostcode
            ),
            addressType: updatedAddress.addressType,
            isPrime: updatedAddress.isPrime,
            specialistName: updatedAddress.specialistName,
            overrideReason: reason,
            overrideDate: ISO8601DateFormatter().string(from: Date())
        )

        var updated = file
        updated.overrides.append(override)
        try atomicWrite(file: updated)

        logger.info("Saved override for \(documentId) page \(pageNumber) type \(matchAddressType)")
    }

    /// Toggle the prime status of an address
    func togglePrime(documentId: String, pageNumber: Int, addressType: String, makePrime: Bool) async throws {
        var file = try readOrCreateFile(forDocument: documentId)

        if makePrime && addressType != "specialist" {
            // Remove prime from other addresses of same type in this document
            for i in file.overrides.indices {
                if file.overrides[i].addressType == addressType && file.overrides[i].isPrime == true {
                    if file.overrides[i].pageNumber != pageNumber || file.overrides[i].matchAddressType != addressType {
                        file.overrides[i].isPrime = false
                    }
                }
            }
            // Also check pages that don't have overrides
            for page in file.pages {
                if page.addressType == addressType && page.isPrime == true {
                    let hasOverride = file.overrides.contains {
                        $0.pageNumber == page.pageNumber && $0.matchAddressType == (page.addressType ?? "patient")
                    }
                    if !hasOverride && (page.pageNumber != pageNumber || page.addressType != addressType) {
                        // Create an override to unset prime
                        let unprime = AddressOverrideEntry(
                            pageNumber: page.pageNumber,
                            matchAddressType: page.addressType ?? "patient",
                            addressType: page.addressType,
                            isPrime: false,
                            overrideReason: "prime_toggled",
                            overrideDate: ISO8601DateFormatter().string(from: Date())
                        )
                        file.overrides.append(unprime)
                    }
                }
            }
        }

        // Find or create override for the target address
        let existingIdx = file.overrides.lastIndex {
            $0.pageNumber == pageNumber && $0.matchAddressType == addressType
        }

        if let idx = existingIdx {
            file.overrides[idx].isPrime = makePrime
            file.overrides[idx].overrideDate = ISO8601DateFormatter().string(from: Date())
        } else {
            let override = AddressOverrideEntry(
                pageNumber: pageNumber,
                matchAddressType: addressType,
                addressType: addressType,
                isPrime: makePrime,
                overrideReason: "prime_toggled",
                overrideDate: ISO8601DateFormatter().string(from: Date())
            )
            file.overrides.append(override)
        }

        try atomicWrite(file: file)
        logger.info("Toggled prime for \(documentId) page \(pageNumber) type \(addressType) to \(makePrime)")
    }

    /// Update the address type for an address
    func updateAddressType(documentId: String, pageNumber: Int, currentAddressType: String,
                           newType: String, specialistName: String?) async throws {
        var file = try readOrCreateFile(forDocument: documentId)

        let existingIdx = file.overrides.lastIndex {
            $0.pageNumber == pageNumber && $0.matchAddressType == currentAddressType
        }

        if let idx = existingIdx {
            file.overrides[idx].addressType = newType
            file.overrides[idx].specialistName = specialistName
            file.overrides[idx].overrideDate = ISO8601DateFormatter().string(from: Date())
        } else {
            let override = AddressOverrideEntry(
                pageNumber: pageNumber,
                matchAddressType: currentAddressType,
                addressType: newType,
                specialistName: specialistName,
                overrideReason: "type_changed",
                overrideDate: ISO8601DateFormatter().string(from: Date())
            )
            file.overrides.append(override)
        }

        try atomicWrite(file: file)
        logger.info("Updated address type for \(documentId) page \(pageNumber) to \(newType)")
    }

    // MARK: - Private Helpers

    /// Read and decode an address JSON file
    private func readAddressFile(at url: URL) throws -> DocumentAddressFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DocumentAddressFile.self, from: data)
    }

    /// Read existing file or create an empty one for the document
    private func readOrCreateFile(forDocument documentId: String) throws -> DocumentAddressFile {
        guard let dirURL = Self.addressesDirectoryURL else {
            throw NSError(domain: "AddressRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "iCloud container not available"])
        }

        let fileURL = dirURL.appendingPathComponent("\(documentId).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try readAddressFile(at: fileURL)
        }

        // Create empty file
        return DocumentAddressFile(
            schemaVersion: 1,
            documentId: documentId,
            extractedAt: ISO8601DateFormatter().string(from: Date()),
            pageCount: 0,
            pages: [],
            overrides: []
        )
    }

    /// Resolve pages + overrides into flat ExtractedAddress array
    private func resolveAddresses(from file: DocumentAddressFile) -> [ExtractedAddress] {
        file.pages.map { page in
            // Find the most recent override matching this page
            let override = file.overrides
                .filter { $0.pageNumber == page.pageNumber && $0.matchAddressType == (page.addressType ?? "patient") }
                .sorted { ($0.overrideDate ?? "") > ($1.overrideDate ?? "") }
                .first

            return ExtractedAddress(
                documentId: file.documentId,
                page: page,
                override: override,
                extractedAt: file.extractedAt,
                enriched: file.enriched
            )
        }
    }

    /// Atomic write: encode to temp file, then replace
    private func atomicWrite(file: DocumentAddressFile) throws {
        guard let dirURL = Self.addressesDirectoryURL else {
            throw NSError(domain: "AddressRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "iCloud container not available"])
        }

        // Ensure directory exists
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let finalURL = dirURL.appendingPathComponent("\(file.documentId).json")
        let tmpURL = dirURL.appendingPathComponent("\(file.documentId).json.tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: tmpURL, options: .atomic)

        // Use FileManager replaceItemAt for atomic replacement
        if FileManager.default.fileExists(atPath: finalURL.path) {
            _ = try FileManager.default.replaceItemAt(finalURL, withItemAt: tmpURL)
        } else {
            try FileManager.default.moveItem(at: tmpURL, to: finalURL)
        }
    }
}

// MARK: - Statistics

struct DatabaseStatistics {
    let totalAddresses: Int
    let documentsWithAddresses: Int
    let patientsFound: Int
    let gpsFound: Int
}
