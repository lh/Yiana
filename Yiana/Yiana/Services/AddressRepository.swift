//
//  AddressRepository.swift
//  Yiana
//
//  Provides access to extracted address data from .addresses/ JSON files
//

import Foundation
import Combine
import os
import YianaExtraction

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

    /// Address confirmation status for indicator strip
    enum AddressStatus {
        case noAddresses      // no file or empty pages — green
        case unconfirmed      // has addresses but not fully primed — red
        case confirmed        // patient and GP both primed — blue
    }

    /// Lightweight check of address status without full resolution.
    /// Safe to call from any context (no @MainActor requirement on the static helper).
    static func addressStatus(forDocumentId documentId: String) -> AddressStatus {
        guard let dirURL = addressesDirectoryURL else { return .noAddresses }
        let fileURL = dirURL.appendingPathComponent("\(documentId).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .noAddresses }

        do {
            let data = try Data(contentsOf: fileURL)
            var file = try JSONDecoder().decode(DocumentAddressFile.self, from: data)

            // Merge overrides from separate file
            let separateOverrides = readOverridesFileStatic(forDocument: documentId)
            if !separateOverrides.isEmpty {
                file.overrides = separateOverrides
            }

            // No pages and no manual overrides = no addresses
            if file.pages.isEmpty && file.overrides.isEmpty { return .noAddresses }

            // Resolve effective isPrime for each page by checking overrides
            var hasPatientPrime = false
            var hasGPPrime = false

            for page in file.pages {
                let override = file.overrides
                    .filter { $0.pageNumber == page.pageNumber && $0.matchAddressType == (page.addressType ?? "patient") }
                    .sorted { ($0.overrideDate ?? "") > ($1.overrideDate ?? "") }
                    .first

                let effectivePrime = override?.isPrime ?? page.isPrime ?? false
                let effectiveType = override?.addressType ?? page.addressType ?? "patient"

                if effectivePrime {
                    switch effectiveType {
                    case "patient": hasPatientPrime = true
                    case "gp": hasGPPrime = true
                    default: break
                    }
                }
            }

            // Check manual addresses (page 0 overrides not matched to any page)
            for override in file.overrides where override.pageNumber == 0 {
                let effectiveType = override.addressType ?? override.matchAddressType
                if override.isPrime == true {
                    switch effectiveType {
                    case "patient": hasPatientPrime = true
                    case "gp": hasGPPrime = true
                    default: break
                    }
                }
            }

            if hasPatientPrime && hasGPPrime {
                return .confirmed
            }
            return .unconfirmed

        } catch {
            return .noAddresses
        }
    }

    init() {
        if Self.addressesDirectoryURL == nil {
            logger.error("Failed to locate iCloud container")
        }
    }

    /// One-time migration: extract overrides from main .json files into separate .overrides.json files.
    /// Idempotent — skips files that already have a .overrides.json or have no overrides.
    private static func migrateOverridesToSeparateFiles(dirURL: URL) {
        let logger = Logger(subsystem: "com.vitygas.Yiana", category: "AddressRepository")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dirURL, includingPropertiesForKeys: nil, options: [])
            .filter({ $0.pathExtension == "json" && !$0.lastPathComponent.contains(".overrides.") })
        else { return }

        var migrated = 0
        for fileURL in files {
            let stem = fileURL.deletingPathExtension().lastPathComponent
            let overridesURL = dirURL.appendingPathComponent("\(stem).overrides.json")

            // Skip if overrides file already exists
            if FileManager.default.fileExists(atPath: overridesURL.path) { continue }

            guard let data = try? Data(contentsOf: fileURL),
                  let file = try? JSONDecoder().decode(DocumentAddressFile.self, from: data),
                  !file.overrides.isEmpty else { continue }

            // Write overrides to separate file
            let overridesFile = OverridesFile(documentId: file.documentId, overrides: file.overrides)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let overridesData = try? encoder.encode(overridesFile) else { continue }

            do {
                try overridesData.write(to: overridesURL, options: .atomic)
                migrated += 1
            } catch {
                logger.error("Failed to migrate overrides for \(stem): \(error)")
            }
        }

        if migrated > 0 {
            logger.info("Migrated overrides from \(migrated) files to separate .overrides.json files")
        }
    }

    // MARK: - Read Methods

    /// Fetch all addresses for a specific document
    func addresses(forDocument documentId: String) async throws -> [ExtractedAddress] {
        guard let dirURL = Self.addressesDirectoryURL else { return [] }

        let mainExists = FileManager.default.fileExists(
            atPath: dirURL.appendingPathComponent("\(documentId).json").path)
        let overridesExist = FileManager.default.fileExists(
            atPath: dirURL.appendingPathComponent("\(documentId).overrides.json").path)

        guard mainExists || overridesExist else { return [] }

        let file = try readOrCreateFile(forDocument: documentId)
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
                let docId = fileURL.deletingPathExtension().lastPathComponent
                let file = try readOrCreateFile(forDocument: docId)
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
        let resolvedType = updatedAddress.addressType ?? "patient"

        // Only create sub-objects the current type owns
        let patient: PatientInfo? = (resolvedType == "patient" || resolvedType == "optician" || resolvedType == "specialist") ? PatientInfo(
            fullName: updatedAddress.fullName,
            dateOfBirth: updatedAddress.dateOfBirth,
            phones: PhoneInfo(
                home: updatedAddress.phoneHome,
                work: updatedAddress.phoneWork,
                mobile: updatedAddress.phoneMobile
            ),
            mrn: updatedAddress.mrn
        ) : nil

        let addressInfo: AddressInfo? = resolvedType != "gp" ? AddressInfo(
            line1: updatedAddress.addressLine1,
            line2: updatedAddress.addressLine2,
            city: updatedAddress.city,
            county: updatedAddress.county,
            postcode: updatedAddress.postcode,
            postcodeValid: updatedAddress.postcodeValid,
            postcodeDistrict: updatedAddress.postcodeDistrict
        ) : nil

        let gp: GPInfo? = resolvedType == "gp" ? GPInfo(
            name: updatedAddress.gpName,
            practice: updatedAddress.gpPractice,
            address: updatedAddress.gpAddress,
            postcode: updatedAddress.gpPostcode
        ) : nil

        let override = AddressOverrideEntry(
            pageNumber: pageNumber,
            matchAddressType: matchAddressType,
            patient: patient,
            address: addressInfo,
            gp: gp,
            addressType: updatedAddress.addressType,
            isPrime: updatedAddress.isPrime,
            specialistName: updatedAddress.specialistName,
            overrideReason: reason,
            overrideDate: ISO8601DateFormatter().string(from: Date()),
            recipientRole: updatedAddress.recipientRole
        )

        var overrides = try readOverridesFile(forDocument: documentId)
        overrides.append(override)
        try atomicWriteOverrides(documentId: documentId, overrides: overrides)

        logger.info("Saved override for \(documentId) page \(pageNumber) type \(matchAddressType)")
    }

    /// Save recipient role (To/CC/None) — updates existing override or appends a minimal one
    func saveRecipientRole(documentId: String, pageNumber: Int, matchAddressType: String, recipientRole: String) async throws {
        var overrides = try readOverridesFile(forDocument: documentId)

        // Find the most recent override for this page+type and update it
        if let idx = overrides.lastIndex(where: { $0.pageNumber == pageNumber && $0.matchAddressType == matchAddressType }) {
            overrides[idx].recipientRole = recipientRole
        } else {
            // No existing override — append a minimal one
            overrides.append(AddressOverrideEntry(
                pageNumber: pageNumber,
                matchAddressType: matchAddressType,
                recipientRole: recipientRole
            ))
        }

        try atomicWriteOverrides(documentId: documentId, overrides: overrides)
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

        try atomicWriteOverrides(documentId: documentId, overrides: file.overrides)
        logger.info("Toggled prime for \(documentId) page \(pageNumber) type \(addressType) to \(makePrime)")
    }

    /// Update the address type for an address
    func updateAddressType(documentId: String, pageNumber: Int, currentAddressType: String,
                           newType: String, specialistName: String?) async throws {
        var overrides = try readOverridesFile(forDocument: documentId)

        let existingIdx = overrides.lastIndex {
            $0.pageNumber == pageNumber && $0.matchAddressType == currentAddressType
        }

        if let idx = existingIdx {
            overrides[idx].addressType = newType
            overrides[idx].specialistName = specialistName
            overrides[idx].overrideDate = ISO8601DateFormatter().string(from: Date())
        } else {
            let override = AddressOverrideEntry(
                pageNumber: pageNumber,
                matchAddressType: currentAddressType,
                addressType: newType,
                specialistName: specialistName,
                overrideReason: "type_changed",
                overrideDate: ISO8601DateFormatter().string(from: Date())
            )
            overrides.append(override)
        }

        try atomicWriteOverrides(documentId: documentId, overrides: overrides)
        logger.info("Updated address type for \(documentId) page \(pageNumber) to \(newType)")
    }

    /// Add a manual address (not from extraction) on virtual page 0
    func addManualAddress(documentId: String, addressType: String) async throws {
        var overrides = try readOverridesFile(forDocument: documentId)

        let override = AddressOverrideEntry(
            pageNumber: 0,
            matchAddressType: addressType,
            addressType: addressType,
            overrideReason: "manual",
            overrideDate: ISO8601DateFormatter().string(from: Date())
        )
        overrides.append(override)

        try atomicWriteOverrides(documentId: documentId, overrides: overrides)
        logger.info("Added manual \(addressType) address for \(documentId)")
    }

    /// Dismiss an extracted address (hide from UI without deleting)
    func dismissAddress(documentId: String, pageNumber: Int, addressType: String) async throws {
        var overrides = try readOverridesFile(forDocument: documentId)

        let override = AddressOverrideEntry(
            pageNumber: pageNumber,
            matchAddressType: addressType,
            overrideReason: "dismissed",
            overrideDate: ISO8601DateFormatter().string(from: Date()),
            isDismissed: true
        )
        overrides.append(override)

        try atomicWriteOverrides(documentId: documentId, overrides: overrides)
        logger.info("Dismissed \(addressType) on page \(pageNumber) for \(documentId)")
    }

    /// Delete all page-0 overrides for a given address type
    func deleteManualAddress(documentId: String, addressType: String) async throws {
        var overrides = try readOverridesFile(forDocument: documentId)
        overrides.removeAll { $0.pageNumber == 0 && $0.matchAddressType == addressType }
        try atomicWriteOverrides(documentId: documentId, overrides: overrides)
        logger.info("Deleted manual \(addressType) address for \(documentId)")
    }

    // MARK: - Private Helpers

    /// Read and decode an address JSON file
    private func readAddressFile(at url: URL) throws -> DocumentAddressFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DocumentAddressFile.self, from: data)
    }

    /// Read the separate overrides file, or return empty array
    private func readOverridesFile(forDocument documentId: String) throws -> [AddressOverrideEntry] {
        guard let dirURL = Self.addressesDirectoryURL else { return [] }
        let url = dirURL.appendingPathComponent("\(documentId).overrides.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(OverridesFile.self, from: data)
        return file.overrides
    }

    /// Read the separate overrides file, or return empty array (static, for addressStatus)
    private static func readOverridesFileStatic(forDocument documentId: String) -> [AddressOverrideEntry] {
        guard let dirURL = addressesDirectoryURL else { return [] }
        let url = dirURL.appendingPathComponent("\(documentId).overrides.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(OverridesFile.self, from: data) else {
            return []
        }
        return file.overrides
    }

    /// Read existing main file + overrides, merged into a DocumentAddressFile
    private func readOrCreateFile(forDocument documentId: String) throws -> DocumentAddressFile {
        guard let dirURL = Self.addressesDirectoryURL else {
            throw NSError(domain: "AddressRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "iCloud container not available"])
        }

        let fileURL = dirURL.appendingPathComponent("\(documentId).json")
        var file: DocumentAddressFile
        if FileManager.default.fileExists(atPath: fileURL.path) {
            file = try readAddressFile(at: fileURL)
        } else {
            file = DocumentAddressFile(
                schemaVersion: 1,
                documentId: documentId,
                extractedAt: ISO8601DateFormatter().string(from: Date()),
                pageCount: 0,
                pages: [],
                overrides: []
            )
        }

        // Merge overrides from separate file
        let separateOverrides = try readOverridesFile(forDocument: documentId)
        if !separateOverrides.isEmpty {
            file.overrides = separateOverrides
        }

        return file
    }

    /// Resolve pages + overrides into flat ExtractedAddress array
    private func resolveAddresses(from file: DocumentAddressFile) -> [ExtractedAddress] {
        // Track which overrides are consumed by page entries
        var matchedOverrides = Set<Int>()

        let pageAddresses = file.pages.map { page in
            // Find the most recent override matching this page
            let overrideWithIndex = file.overrides.enumerated()
                .filter { $0.element.pageNumber == page.pageNumber && $0.element.matchAddressType == (page.addressType ?? "patient") }
                .sorted { ($0.element.overrideDate ?? "") > ($1.element.overrideDate ?? "") }
                .first

            if let match = overrideWithIndex {
                matchedOverrides.insert(match.offset)
            }

            return ExtractedAddress(
                documentId: file.documentId,
                page: page,
                override: overrideWithIndex?.element,
                extractedAt: file.extractedAt,
                enriched: file.enriched
            )
        }

        // Include manual addresses (unmatched overrides on page 0)
        // Deduplicate by matchAddressType, keeping the most recent
        var manualByType: [String: AddressOverrideEntry] = [:]
        for (idx, override) in file.overrides.enumerated() {
            guard !matchedOverrides.contains(idx), override.pageNumber == 0 else { continue }
            let key = override.matchAddressType
            if let existing = manualByType[key] {
                if (override.overrideDate ?? "") > (existing.overrideDate ?? "") {
                    manualByType[key] = override
                }
            } else {
                manualByType[key] = override
            }
        }
        let manualAddresses = manualByType.values.map { override in
            ExtractedAddress(
                documentId: file.documentId,
                manualOverride: override
            )
        }

        return (pageAddresses + manualAddresses).filter { $0.isDismissed != true }
    }

    /// Atomic write of overrides to the separate `.overrides.json` file.
    private func atomicWriteOverrides(documentId: String, overrides: [AddressOverrideEntry]) throws {
        guard let dirURL = Self.addressesDirectoryURL else {
            throw NSError(domain: "AddressRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "iCloud container not available"])
        }

        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let overridesFile = OverridesFile(documentId: documentId, overrides: overrides)
        let finalURL = dirURL.appendingPathComponent("\(documentId).overrides.json")
        let tmpURL = dirURL.appendingPathComponent("\(documentId).overrides.json.tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(overridesFile)
        try data.write(to: tmpURL, options: .atomic)

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
