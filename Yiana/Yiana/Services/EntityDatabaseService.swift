import Foundation
import os
import YianaExtraction

/// Manages the local entity resolution database — a derived cache
/// stored in Caches/ that deduplicates patients and practitioners
/// across documents.
///
/// Not synced via iCloud (SQLite doesn't survive iCloud sync).
/// Rebuildable from `.addresses/*.json` at any time via `ingestAll()`.
final class EntityDatabaseService {
    static let shared = EntityDatabaseService()

    private let logger = Logger(subsystem: "com.vitygas.Yiana", category: "EntityDatabase")
    private var database: EntityDatabase?

    /// Cached iCloud addresses directory URL (set from main thread in init)
    private let addressesDirectoryURL: URL?

    private init() {
        // Cache iCloud URL on main thread — returns nil from Task.detached
        if let iCloudURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana"
        ) {
            addressesDirectoryURL = iCloudURL
                .appendingPathComponent("Documents")
                .appendingPathComponent(".addresses")
        } else {
            addressesDirectoryURL = nil
        }

        let fileManager = FileManager.default
        guard let cachesDir = fileManager.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first else {
            logger.error("Could not find Caches directory")
            database = nil
            return
        }

        let entityDir = cachesDir.appendingPathComponent("EntityDatabase", isDirectory: true)
        try? fileManager.createDirectory(at: entityDir, withIntermediateDirectories: true)

        let dbPath = entityDir.appendingPathComponent("entities.db").path
        do {
            database = try EntityDatabase(path: dbPath)
            logger.info("Entity database ready at \(dbPath)")
        } catch {
            logger.error("Failed to initialise entity database: \(error)")
            database = nil
        }
    }

    /// Ingest a single document's address file. Idempotent via content hash.
    func ingestDocument(_ documentId: String) {
        guard let db = database, let dirURL = addressesDirectoryURL else { return }

        let fileURL = dirURL.appendingPathComponent("\(documentId).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            try db.ingestAddressFile(at: fileURL)
        } catch {
            logger.error("Ingestion failed for \(documentId): \(error)")
        }
    }

    /// Ingest all .addresses/*.json files (boss instance full rebuild).
    func ingestAll() {
        guard let db = database, let dirURL = addressesDirectoryURL else { return }

        // options: [] — iCloud marks synced files as hidden
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dirURL, includingPropertiesForKeys: nil, options: []
        ).filter({ $0.pathExtension == "json" && !$0.lastPathComponent.contains(".overrides.") })
        else {
            logger.warning("Could not list .addresses/ directory")
            return
        }

        var ingested = 0
        for fileURL in files {
            do {
                try db.ingestAddressFile(at: fileURL)
                ingested += 1
            } catch {
                logger.error("Ingestion failed for \(fileURL.lastPathComponent): \(error)")
            }
        }
        logger.info("Ingested \(ingested)/\(files.count) address files")
    }

    /// Entity database statistics for diagnostics.
    func statistics() -> EntityStatistics? {
        guard let db = database else { return nil }
        return try? db.statistics()
    }

    /// Patient linked to a document.
    func patientForDocument(_ documentId: String) -> PatientRecord? {
        guard let db = database else { return nil }
        return try? db.patientForDocument(documentId)
    }

    /// Practitioners linked to a document's patient.
    func practitionersForDocument(_ documentId: String) -> [PractitionerRecord] {
        guard let db = database else { return [] }
        return (try? db.practitionersForDocument(documentId).map(\.practitioner)) ?? []
    }

    /// Search patients by name or DOB substring.
    func searchPatients(query: String, limit: Int = 20) -> [PatientRecord] {
        guard let db = database else { return [] }
        return (try? db.searchPatients(query: query, limit: limit)) ?? []
    }

    /// Search practitioners by name or practice name substring.
    func searchPractitioners(query: String, limit: Int = 20) -> [PractitionerRecord] {
        guard let db = database else { return [] }
        return (try? db.searchPractitioners(query: query, limit: limit)) ?? []
    }
}
