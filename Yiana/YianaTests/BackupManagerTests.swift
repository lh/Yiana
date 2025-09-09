import XCTest
@testable import Yiana

final class BackupManagerTests: XCTestCase {

    private var backupManager: BackupManager!
    private var tempDirectory: URL!
    private var documentURL: URL!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 1. Create a temporary directory for the test
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 2. Create a dummy document in the temp directory
        documentURL = tempDirectory.appendingPathComponent("TestDocument.pdf")
        let dummyData = "Initial Content".data(using: .utf8)!
        try dummyData.write(to: documentURL)
        
        // 3. Initialize the BackupManager with a short retention period for testing
        let config = BackupConfig(retentionDays: 2)
        backupManager = BackupManager(config: config)
    }

    override func tearDownWithError() throws {
        // Clean up the temporary directory
        try fileManager.removeItem(at: tempDirectory)
        backupManager = nil
        tempDirectory = nil
        documentURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests

    func test_ensureDailyBackup_createsBackupSuccessfully() throws {
        // Given: No backup exists
        XCTAssertFalse(backupManager.hasTodayBackup(for: documentURL, bookmark: nil))

        // When: A backup is ensured
        try backupManager.ensureDailyBackup(for: documentURL, bookmark: nil)

        // Then: A backup for today should exist
        XCTAssertTrue(backupManager.hasTodayBackup(for: documentURL, bookmark: nil))
    }

    func test_ensureDailyBackup_doesNotCreateDuplicateBackup() throws {
        // Given: A backup already exists
        try backupManager.ensureDailyBackup(for: documentURL, bookmark: nil)
        let backupDir = try backupManager.backupDirectory(for: documentURL)
        let initialBackupCount = try fileManager.contentsOfDirectory(atPath: backupDir.path).count

        // When: ensureDailyBackup is called again
        try backupManager.ensureDailyBackup(for: documentURL, bookmark: nil)

        // Then: No new backup file should be created
        let finalBackupCount = try fileManager.contentsOfDirectory(atPath: backupDir.path).count
        XCTAssertEqual(initialBackupCount, finalBackupCount, "Should not create a duplicate backup for the same day")
    }

    func test_revertToStartOfDay_restoresDocumentContent() throws {
        // Given: A backup is made, and the document is then modified
        try backupManager.ensureDailyBackup(for: documentURL, bookmark: nil)
        let modifiedContent = "Modified Content".data(using: .utf8)!
        try modifiedContent.write(to: documentURL)

        // When: The document is reverted
        try backupManager.revertToStartOfDay(documentURL: documentURL, bookmark: nil)

        // Then: The document content should be restored to its initial state
        let revertedContent = try Data(contentsOf: documentURL)
        XCTAssertEqual(revertedContent, "Initial Content".data(using: .utf8)!, "Document content should be reverted to the backup state")
    }

    func test_revertToStartOfDay_throwsErrorIfNoBackupExists() {
        // Given: No backup exists
        
        // When/Then: Attempting to revert should throw a noBackupFound error
        XCTAssertThrowsError(try backupManager.revertToStartOfDay(documentURL: documentURL, bookmark: nil)) { error in
            XCTAssertEqual(error as? BackupError, .noBackupFound)
        }
    }

    func test_pruneOldBackups_removesOutdatedFiles() throws {
        // Given: Multiple backups from different days, some older than the retention period
        let backupDir = try backupManager.backupDirectory(for: documentURL)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Create a recent backup (should be kept)
        let today = Calendar.current.startOfDay(for: Date())
        let recentBackupURL = backupManager.backupURL(in: backupDir, for: documentURL, date: today)
        try fileManager.copyItem(at: documentURL, to: recentBackupURL)

        // Create an old backup (should be pruned)
        let oldDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let oldBackupURL = backupManager.backupURL(in: backupDir, for: documentURL, date: oldDate)
        try fileManager.copyItem(at: documentURL, to: oldBackupURL)

        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: backupDir.path).count, 2)

        // When: Pruning is performed
        try backupManager.pruneOldBackups(for: documentURL, bookmark: nil)

        // Then: Only the recent backup should remain
        let remainingFiles = try fileManager.contentsOfDirectory(atPath: backupDir.path)
        XCTAssertEqual(remainingFiles.count, 1)
        XCTAssertTrue(remainingFiles.first?.contains(ISO8601DateFormatter.string(from: today, timeZone: .current, formatOptions: .withFullDate)) ?? false)
    }
    
    func test_documentId_isStable() {
        // Given two different URLs pointing to the same file path
        let url1 = URL(fileURLWithPath: "/Users/rose/Code/Yiana/file.pdf")
        let url2 = URL(fileURLWithPath: "/Users/rose/Code/Yiana/file.pdf")
        
        // When their IDs are generated
        let id1 = backupManager.documentId(for: url1)
        let id2 = backupManager.documentId(for: url2)
        
        // Then the IDs should be identical
        XCTAssertEqual(id1, id2)
    }
    
    func test_documentId_isUnique() {
        // Given two different URLs
        let url1 = URL(fileURLWithPath: "/Users/rose/Code/Yiana/file1.pdf")
        let url2 = URL(fileURLWithPath: "/Users/rose/Code/Yiana/file2.pdf")
        
        // When their IDs are generated
        let id1 = backupManager.documentId(for: url1)
        let id2 = backupManager.documentId(for: url2)
        
        // Then the IDs should be different
        XCTAssertNotEqual(id1, id2)
    }
}


