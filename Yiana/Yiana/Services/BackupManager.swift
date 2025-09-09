import Foundation
import CryptoKit

public struct BackupConfig {
    public var retentionDays: Int

    public init(retentionDays: Int = 7) {
        self.retentionDays = retentionDays
    }
}

public enum BackupError: Error, Equatable {
    case permissionDenied
    case noBackupFound
    case ioFailure(Error)
    case lockTimeout
    case failedToGetBackupLocation
    case bookmarkIsStale
    case bookmarkResolutionFailed

    public static func == (lhs: BackupError, rhs: BackupError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied):
            return true
        case (.noBackupFound, .noBackupFound):
            return true
        case (.lockTimeout, .lockTimeout):
            return true
        case (.failedToGetBackupLocation, .failedToGetBackupLocation):
            return true
        case (.bookmarkIsStale, .bookmarkIsStale):
            return true
        case (.bookmarkResolutionFailed, .bookmarkResolutionFailed):
            return true
        case (.ioFailure(let lhsError), .ioFailure(let rhsError)):
            return (lhsError as NSError).domain == (rhsError as NSError).domain && (lhsError as NSError).code == (rhsError as NSError).code
        default:
            return false
        }
    }
}

public final class BackupManager {
    private let config: BackupConfig
    private let fileManager = FileManager.default
    private let calendar = Calendar.current

    public init(config: BackupConfig = BackupConfig()) {
        self.config = config
    }

    // MARK: - Public API

    public func ensureDailyBackup(for documentURL: URL, bookmark: Data?) throws {
        try withResolvedURL(for: documentURL, bookmark: bookmark) { resolvedURL in
            try withDocumentLock(resolvedURL) {
                let backupDir = try backupDirectory(for: resolvedURL)
                let today = startOfDay(for: Date())
                let backupURL = backupURL(in: backupDir, for: resolvedURL, date: today)

                if !fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
                    try fileManager.copyItem(at: resolvedURL, to: backupURL)
                }
            }
        }
    }

    public func revertToStartOfDay(documentURL: URL, bookmark: Data?) throws {
        try withResolvedURL(for: documentURL, bookmark: bookmark) { resolvedURL in
            try withDocumentLock(resolvedURL) {
                let backupDir = try backupDirectory(for: resolvedURL)
                let today = startOfDay(for: Date())
                let backupURL = backupURL(in: backupDir, for: resolvedURL, date: today)

                guard fileManager.fileExists(atPath: backupURL.path) else {
                    throw BackupError.noBackupFound
                }

                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinationError: NSError?
                var ioError: Error?

                coordinator.coordinate(writingItemAt: resolvedURL, options: .forReplacing, error: &coordinationError) { (newURL) in
                    do {
                        _ = try? self.fileManager.removeItem(at: newURL)
                        try self.fileManager.copyItem(at: backupURL, to: newURL)
                    } catch {
                        ioError = error
                    }
                }

                if let error = coordinationError { throw BackupError.ioFailure(error) }
                if let error = ioError { throw BackupError.ioFailure(error) }
            }
        }
    }

    public func pruneOldBackups(for documentURL: URL, bookmark: Data?) throws {
        try withResolvedURL(for: documentURL, bookmark: bookmark) { resolvedURL in
            try withDocumentLock(resolvedURL) {
                let backupDir = try backupDirectory(for: resolvedURL)
                guard fileManager.fileExists(atPath: backupDir.path) else { return }
                
                let retentionDate = calendar.date(byAdding: .day, value: -config.retentionDays, to: Date())!
                let startOfRetentionDay = startOfDay(for: retentionDate)

                let backupFiles = try fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey])

                for fileURL in backupFiles {
                    if let modificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       startOfDay(for: modificationDate) < startOfRetentionDay {
                        try fileManager.removeItem(at: fileURL)
                    }
                }
            }
        }
    }

    public func hasTodayBackup(for documentURL: URL, bookmark: Data?) -> Bool {
        do {
            var hasBackup = false
            try withResolvedURL(for: documentURL, bookmark: bookmark) { resolvedURL in
                let backupDir = try backupDirectory(for: resolvedURL)
                let today = startOfDay(for: Date())
                let backupURL = backupURL(in: backupDir, for: resolvedURL, date: today)
                hasBackup = fileManager.fileExists(atPath: backupURL.path)
            }
            return hasBackup
        } catch {
            return false
        }
    }

    // MARK: - Locking

    public func withDocumentLock(_ url: URL, _ action: () throws -> Void) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var actionError: Error?

        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { writeURL in
            do {
                try action()
            } catch {
                actionError = error
            }
        }

        if let error = coordinationError { throw BackupError.ioFailure(error) }
        if let error = actionError { throw error }
    }

    // MARK: - Helpers

    internal func backupDirectory(for documentURL: URL) throws -> URL {
        let adjacentDir = documentURL.deletingLastPathComponent().appendingPathComponent(".yiana-backups", isDirectory: true)
        let documentID = self.documentId(for: documentURL)

        do {
            try fileManager.createDirectory(at: adjacentDir, withIntermediateDirectories: true)
            if fileManager.isWritableFile(atPath: adjacentDir.path) {
                return adjacentDir.appendingPathComponent(documentID, isDirectory: true)
            }
        } catch {
            // If creating the adjacent directory fails, fall back to app support.
            // This handles cases like read-only volumes.
        }

        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BackupError.failedToGetBackupLocation
        }

        let fallbackDir = appSupportDir.appendingPathComponent("com.yiana.backups").appendingPathComponent(documentID)
        try fileManager.createDirectory(at: fallbackDir, withIntermediateDirectories: true, attributes: nil)
        return fallbackDir
    }

    internal func backupURL(in backupDirectory: URL, for documentURL: URL, date: Date) -> URL {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: date)
        let originalFileName = documentURL.lastPathComponent
        return backupDirectory.appendingPathComponent("\(dateString)_\(originalFileName)")
    }

    internal func documentId(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    internal func startOfDay(for date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    internal func withResolvedURL(for documentURL: URL, bookmark: Data?, perform action: (URL) throws -> Void) throws {
        guard let bookmark = bookmark else {
            // If no bookmark, assume direct access is possible
            try action(documentURL)
            return
        }

        var isStale = false
        do {
            let resolvedURL = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // In a real app, you would need to create a new bookmark and persist it.
                // For now, we'll just throw an error.
                throw BackupError.bookmarkIsStale
            }
            
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                throw BackupError.permissionDenied
            }
            
            defer { resolvedURL.stopAccessingSecurityScopedResource() }
            
            try action(resolvedURL)
            
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.bookmarkResolutionFailed
        }
    }
}