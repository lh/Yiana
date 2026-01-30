//
//  SearchIndexService.swift
//  Yiana
//
//  GRDB-based full-text search index for document content

import Foundation
import GRDB

/// Sort column for document list queries
enum SortColumn: String {
    case title
    case dateModified = "modified_date"
    case dateCreated = "created_date"
    case fileSize = "file_size"
}

/// Service for managing full-text search index using GRDB + SQLite FTS5
/// Provides fast, type-safe search across thousands of documents
class SearchIndexService {
    static let shared = SearchIndexService()

    private var dbQueue: DatabaseQueue
    private let databaseURL: URL

    enum SearchIndexError: Error {
        case databaseError(String)
        case initializationFailed
        case queryFailed(String)
    }

    // MARK: - Record Types

    /// FTS5 record for full-text search
    struct DocumentFTSRecord: Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "documents_fts"

        let documentId: String
        let title: String
        let fullText: String
        let tags: String

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case title = "title"
            case fullText = "full_text"
            case tags = "tags"
        }

        enum Columns {
            static let documentId = Column("document_id")
            static let title = Column("title")
            static let fullText = Column("full_text")
            static let tags = Column("tags")
        }
    }

    /// Metadata record for non-searchable fields
    struct DocumentMetadataRecord: Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "documents_metadata"

        let documentId: String
        let url: String
        let createdDate: Double
        let modifiedDate: Double
        let pageCount: Int
        let ocrCompleted: Bool
        let indexedDate: Double
        let title: String
        let folderPath: String
        let fileSize: Int64
        let hasPendingTextPage: Bool
        let tagsCsv: String
        let isPlaceholder: Bool

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case url = "url"
            case createdDate = "created_date"
            case modifiedDate = "modified_date"
            case pageCount = "page_count"
            case ocrCompleted = "ocr_completed"
            case indexedDate = "indexed_date"
            case title = "title"
            case folderPath = "folder_path"
            case fileSize = "file_size"
            case hasPendingTextPage = "has_pending_text_page"
            case tagsCsv = "tags_csv"
            case isPlaceholder = "is_placeholder"
        }

        enum Columns {
            static let documentId = Column("document_id")
            static let url = Column("url")
            static let createdDate = Column("created_date")
            static let modifiedDate = Column("modified_date")
            static let pageCount = Column("page_count")
            static let ocrCompleted = Column("ocr_completed")
            static let indexedDate = Column("indexed_date")
            static let title = Column("title")
            static let folderPath = Column("folder_path")
            static let fileSize = Column("file_size")
            static let hasPendingTextPage = Column("has_pending_text_page")
            static let tagsCsv = Column("tags_csv")
            static let isPlaceholder = Column("is_placeholder")
        }
    }

    private init() {
        // Store database in Caches directory (excluded from iCloud backup)
        // This prevents SQLite corruption from iCloud sync conflicts
        let fileManager = FileManager.default
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Could not find Caches directory")
        }

        let yianaDir = cachesDir.appendingPathComponent("SearchIndex", isDirectory: true)
        try? fileManager.createDirectory(at: yianaDir, withIntermediateDirectories: true)

        self.databaseURL = yianaDir.appendingPathComponent("search_index.db")

        do {
            // Create database queue with WAL mode for better concurrency
            var config = Configuration()
            config.prepareDatabase { database in
                try database.execute(sql: "PRAGMA journal_mode = WAL")
            }

            self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)

            // Run migrations
            try dbQueue.write { database in
                try self.createSchema(database)
            }

#if DEBUG
        print("Search index database initialized at \(databaseURL.path)")
#endif
        } catch {
            fatalError("Failed to initialize search database: \(error)")
        }
    }

    // MARK: - Schema Management

    private func createSchema(_ database: Database) throws {
        // Create FTS5 virtual table for full-text search
        try database.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
                document_id UNINDEXED,
                title,
                full_text,
                tags,
                tokenize='porter unicode61 remove_diacritics 2'
            )
            """)

        // Create metadata table for non-searchable fields
        try database.execute(sql: """
            CREATE TABLE IF NOT EXISTS documents_metadata (
                document_id TEXT PRIMARY KEY,
                url TEXT NOT NULL,
                created_date REAL NOT NULL,
                modified_date REAL NOT NULL,
                page_count INTEGER NOT NULL,
                ocr_completed INTEGER NOT NULL,
                indexed_date REAL NOT NULL,
                title TEXT NOT NULL DEFAULT '',
                folder_path TEXT NOT NULL DEFAULT '',
                file_size INTEGER NOT NULL DEFAULT 0,
                has_pending_text_page INTEGER NOT NULL DEFAULT 0,
                tags_csv TEXT NOT NULL DEFAULT '',
                is_placeholder INTEGER NOT NULL DEFAULT 0
            )
            """)

        // Create index on URL for fast lookups
        try database.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_url ON documents_metadata(url)
            """)

        // Migrate existing rows: add columns if they don't exist yet
        // (CREATE TABLE IF NOT EXISTS handles fresh installs; ALTER TABLE handles upgrades)
        let columns = try Row.fetchAll(database, sql: "PRAGMA table_info(documents_metadata)")
        let columnNames = Set(columns.compactMap { $0["name"] as String? })

        if !columnNames.contains("title") {
            try database.execute(sql: "ALTER TABLE documents_metadata ADD COLUMN title TEXT NOT NULL DEFAULT ''")
        }
        if !columnNames.contains("folder_path") {
            try database.execute(sql: "ALTER TABLE documents_metadata ADD COLUMN folder_path TEXT NOT NULL DEFAULT ''")
        }
        if !columnNames.contains("file_size") {
            try database.execute(sql: "ALTER TABLE documents_metadata ADD COLUMN file_size INTEGER NOT NULL DEFAULT 0")
        }
        if !columnNames.contains("has_pending_text_page") {
            try database.execute(sql: "ALTER TABLE documents_metadata ADD COLUMN has_pending_text_page INTEGER NOT NULL DEFAULT 0")
        }
        if !columnNames.contains("tags_csv") {
            try database.execute(sql: "ALTER TABLE documents_metadata ADD COLUMN tags_csv TEXT NOT NULL DEFAULT ''")
        }
        if !columnNames.contains("is_placeholder") {
            try database.execute(sql: "ALTER TABLE documents_metadata ADD COLUMN is_placeholder INTEGER NOT NULL DEFAULT 0")
        }

        // Create index on folder_path (after migrations ensure the column exists)
        try database.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_folder_path ON documents_metadata(folder_path)
            """)
    }

    // MARK: - Indexing Operations

    /// Index a document in the search database
    func indexDocument(
        id: UUID,
        url: URL,
        title: String,
        fullText: String,
        tags: [String],
        metadata: DocumentMetadata,
        folderPath: String = "",
        fileSize: Int64 = 0
    ) async throws {
        try await dbQueue.write { database in
            // Remove any placeholder row for this URL before inserting the real entry
            let placeholderIds = try String.fetchAll(
                database,
                sql: "SELECT document_id FROM documents_metadata WHERE url = ? AND is_placeholder = 1",
                arguments: [url.path]
            )
            for placeholderId in placeholderIds {
                try database.execute(
                    sql: "DELETE FROM documents_fts WHERE document_id = ?",
                    arguments: [placeholderId]
                )
                try database.execute(
                    sql: "DELETE FROM documents_metadata WHERE document_id = ?",
                    arguments: [placeholderId]
                )
            }

            // Insert FTS record
            let ftsRecord = DocumentFTSRecord(
                documentId: id.uuidString,
                title: title,
                fullText: fullText,
                tags: tags.joined(separator: " ")
            )
            try ftsRecord.insert(database, onConflict: .replace)

            // Insert metadata record
            let metadataRecord = DocumentMetadataRecord(
                documentId: id.uuidString,
                url: url.path,
                createdDate: metadata.created.timeIntervalSince1970,
                modifiedDate: metadata.modified.timeIntervalSince1970,
                pageCount: metadata.pageCount,
                ocrCompleted: metadata.ocrCompleted,
                indexedDate: Date().timeIntervalSince1970,
                title: title,
                folderPath: folderPath,
                fileSize: fileSize,
                hasPendingTextPage: metadata.hasPendingTextPage,
                tagsCsv: tags.joined(separator: ","),
                isPlaceholder: false
            )
            try metadataRecord.insert(database, onConflict: .replace)
        }
    }

    /// Batch index multiple documents in a single database transaction.
    /// Much faster than calling indexDocument() individually for each document.
    func indexDocumentsBatch(_ documents: [(url: URL, metadata: DocumentMetadata, folderPath: String, fileSize: Int64)]) async throws {
        guard !documents.isEmpty else { return }
        try await dbQueue.write { database in
            for doc in documents {
                let ftsRecord = DocumentFTSRecord(
                    documentId: doc.metadata.id.uuidString,
                    title: doc.metadata.title,
                    fullText: "",
                    tags: doc.metadata.tags.joined(separator: " ")
                )
                try ftsRecord.insert(database, onConflict: .replace)

                // Remove any placeholder row for this URL
                let placeholderIds = try String.fetchAll(
                    database,
                    sql: "SELECT document_id FROM documents_metadata WHERE url = ? AND is_placeholder = 1",
                    arguments: [doc.url.path]
                )
                for placeholderId in placeholderIds {
                    try database.execute(
                        sql: "DELETE FROM documents_fts WHERE document_id = ?",
                        arguments: [placeholderId]
                    )
                    try database.execute(
                        sql: "DELETE FROM documents_metadata WHERE document_id = ?",
                        arguments: [placeholderId]
                    )
                }

                let metadataRecord = DocumentMetadataRecord(
                    documentId: doc.metadata.id.uuidString,
                    url: doc.url.path,
                    createdDate: doc.metadata.created.timeIntervalSince1970,
                    modifiedDate: doc.metadata.modified.timeIntervalSince1970,
                    pageCount: doc.metadata.pageCount,
                    ocrCompleted: doc.metadata.ocrCompleted,
                    indexedDate: Date().timeIntervalSince1970,
                    title: doc.metadata.title,
                    folderPath: doc.folderPath,
                    fileSize: doc.fileSize,
                    hasPendingTextPage: doc.metadata.hasPendingTextPage,
                    tagsCsv: doc.metadata.tags.joined(separator: ","),
                    isPlaceholder: false
                )
                try metadataRecord.insert(database, onConflict: .replace)
            }
        }
    }

    /// Remove a document from the search index
    func removeDocument(id: UUID) async throws {
        try await dbQueue.write { database in
            let idString = id.uuidString

            // Delete from FTS table
            try database.execute(
                sql: "DELETE FROM documents_fts WHERE document_id = ?",
                arguments: [idString]
            )

            // Delete from metadata table
            try database.execute(
                sql: "DELETE FROM documents_metadata WHERE document_id = ?",
                arguments: [idString]
            )
        }
    }

    /// Remove documents whose URLs are not in the valid set (cache pruning)
    func removeStaleDocuments(validPaths: Set<String>) async throws {
        try await dbQueue.write { database in
            let allRows = try Row.fetchAll(database, sql: "SELECT document_id, url FROM documents_metadata")
            var staleIds: [String] = []
            for row in allRows {
                guard let docId: String = row["document_id"],
                      let urlPath: String = row["url"] else { continue }
                if !validPaths.contains(urlPath) {
                    staleIds.append(docId)
                }
            }

            guard !staleIds.isEmpty else { return }

            for docId in staleIds {
                try database.execute(
                    sql: "DELETE FROM documents_fts WHERE document_id = ?",
                    arguments: [docId]
                )
                try database.execute(
                    sql: "DELETE FROM documents_metadata WHERE document_id = ?",
                    arguments: [docId]
                )
            }

            #if DEBUG
            print("Pruned \(staleIds.count) stale documents from search index")
            #endif
        }
    }

    /// Index a placeholder document (iCloud file not yet downloaded).
    /// Uses INSERT OR IGNORE so it won't overwrite a fully-indexed entry.
    func indexPlaceholderDocument(id: UUID, url: URL, title: String, folderPath: String) async throws {
        try await dbQueue.write { database in
            // Only insert if no row exists for this URL (placeholder or real)
            let existingCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM documents_metadata WHERE url = ?",
                arguments: [url.path]
            ) ?? 0

            guard existingCount == 0 else { return }

            let ftsRecord = DocumentFTSRecord(
                documentId: id.uuidString,
                title: title,
                fullText: "",
                tags: ""
            )
            try ftsRecord.insert(database, onConflict: .ignore)

            let metadataRecord = DocumentMetadataRecord(
                documentId: id.uuidString,
                url: url.path,
                createdDate: Date().timeIntervalSince1970,
                modifiedDate: Date().timeIntervalSince1970,
                pageCount: 0,
                ocrCompleted: false,
                indexedDate: Date().timeIntervalSince1970,
                title: title,
                folderPath: folderPath,
                fileSize: 0,
                hasPendingTextPage: false,
                tagsCsv: "",
                isPlaceholder: true
            )
            try metadataRecord.insert(database, onConflict: .ignore)
        }
    }

    /// Remove a document from the search index by its URL
    func removeDocumentByURL(_ url: URL) async throws {
        try await dbQueue.write { database in
            let docIds = try String.fetchAll(
                database,
                sql: "SELECT document_id FROM documents_metadata WHERE url = ?",
                arguments: [url.path]
            )

            for docId in docIds {
                try database.execute(
                    sql: "DELETE FROM documents_fts WHERE document_id = ?",
                    arguments: [docId]
                )
                try database.execute(
                    sql: "DELETE FROM documents_metadata WHERE document_id = ?",
                    arguments: [docId]
                )
            }
        }
    }

    /// Count placeholder documents in a folder
    func placeholderCount(folderPath: String) async throws -> Int {
        return try await dbQueue.read { database in
            return try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM documents_metadata WHERE folder_path = ? AND is_placeholder = 1",
                arguments: [folderPath]
            ) ?? 0
        }
    }

    // MARK: - Document List Queries

    /// Query documents in a folder, sorted by the given column
    func documentsInFolder(
        folderPath: String,
        sortBy: SortColumn = .title,
        ascending: Bool = true
    ) async throws -> [DocumentMetadataRecord] {
        return try await dbQueue.read { database in
            let orderDirection = ascending ? "ASC" : "DESC"
            let orderColumn: String
            switch sortBy {
            case .title:
                orderColumn = "title"
            case .dateModified:
                orderColumn = "modified_date"
            case .dateCreated:
                orderColumn = "created_date"
            case .fileSize:
                orderColumn = "file_size"
            }

            let sql = """
                SELECT * FROM documents_metadata
                WHERE folder_path = ?
                ORDER BY \(orderColumn) \(orderDirection)
                """
            return try DocumentMetadataRecord.fetchAll(database, sql: sql, arguments: [folderPath])
        }
    }

    /// Get all documents (across all folders) for global search
    func allDocuments() async throws -> [DocumentMetadataRecord] {
        return try await dbQueue.read { database in
            return try DocumentMetadataRecord.fetchAll(database, sql: "SELECT * FROM documents_metadata")
        }
    }

    // MARK: - Search Operations

    /// Search result with relevance score
    struct IndexedSearchResult {
        let documentId: UUID
        let url: URL
        let title: String
        let snippet: String
        let rank: Double
        let pageCount: Int
        let modifiedDate: Date
        let folderPath: String
        let createdDate: Date
        let fileSize: Int64
        let ocrCompleted: Bool
        let hasPendingTextPage: Bool
        let tagsCsv: String
    }

    /// Perform full-text search with relevance ranking
    func search(query: String, limit: Int = 50) async throws -> [IndexedSearchResult] {
        return try await dbQueue.read { database in
            let sanitizedQuery = self.sanitizeFTSQuery(query)

            // FTS5 query with BM25 ranking
            // Give heavy weight to title column (100x vs 1x for content)
            let sql = """
                SELECT
                    fts.document_id,
                    m.url,
                    fts.title,
                    snippet(documents_fts, 2, '<mark>', '</mark>', '...', 50) as snippet,
                    bm25(documents_fts, 100.0, 1.0, 1.0) as rank,
                    m.page_count,
                    m.modified_date,
                    m.folder_path,
                    m.created_date,
                    m.file_size,
                    m.ocr_completed,
                    m.has_pending_text_page,
                    m.tags_csv
                FROM documents_fts fts
                JOIN documents_metadata m ON fts.document_id = m.document_id
                WHERE documents_fts MATCH ?
                ORDER BY rank
                LIMIT ?
                """

            let rows = try Row.fetchAll(database, sql: sql, arguments: [sanitizedQuery, limit])

            return rows.compactMap { row in
                guard let idString: String = row["document_id"],
                      let id = UUID(uuidString: idString),
                      let urlString: String = row["url"],
                      let title: String = row["title"],
                      let snippet: String = row["snippet"],
                      let rank: Double = row["rank"],
                      let pageCount: Int = row["page_count"],
                      let modifiedTimestamp: Double = row["modified_date"] else {
                    return nil
                }

                return IndexedSearchResult(
                    documentId: id,
                    url: URL(fileURLWithPath: urlString),
                    title: title,
                    snippet: snippet,
                    rank: rank,
                    pageCount: pageCount,
                    modifiedDate: Date(timeIntervalSince1970: modifiedTimestamp),
                    folderPath: row["folder_path"] ?? "",
                    createdDate: Date(timeIntervalSince1970: row["created_date"] ?? 0),
                    fileSize: row["file_size"] ?? 0,
                    ocrCompleted: row["ocr_completed"] ?? false,
                    hasPendingTextPage: row["has_pending_text_page"] ?? false,
                    tagsCsv: row["tags_csv"] ?? ""
                )
            }
        }
    }

    /// Sanitize user query for FTS5 (prevent injection and syntax errors)
    private func sanitizeFTSQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // If query contains quotes, treat as phrase search
        if trimmed.contains("\"") {
            return trimmed
        }

        // Otherwise, split into terms and add prefix matching
        let terms = trimmed.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { term in
                // Escape special characters
                let escaped = term.replacingOccurrences(of: "\"", with: "")
                return "\(escaped)*"
            }

        return terms.joined(separator: " ")
    }

    // MARK: - Utility Methods

    /// Get count of indexed documents
    func getIndexedDocumentCount() async throws -> Int {
        return try await dbQueue.read { database in
            return try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM documents_metadata") ?? 0
        }
    }

    /// Check if a document is indexed
    func isDocumentIndexed(id: UUID) async throws -> Bool {
        return try await dbQueue.read { database in
            let count = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM documents_metadata WHERE document_id = ?",
                arguments: [id.uuidString]
            ) ?? 0
            return count > 0
        }
    }

    /// Optimize the FTS index (should be called periodically)
    func optimize() async throws {
        try await dbQueue.write { database in
            try database.execute(sql: "INSERT INTO documents_fts(documents_fts) VALUES('optimize')")
            print("Search index optimized")
        }
    }

    /// Rebuild entire index (for migrations or corruption recovery)
    func rebuildIndex() async throws {
        try await dbQueue.write { database in
            try database.execute(sql: "DELETE FROM documents_fts")
            try database.execute(sql: "DELETE FROM documents_metadata")
            print("Search index cleared")
        }
    }

    /// Delete and recreate the database from scratch (for corruption recovery)
    func resetDatabase() async throws {
        // Close current queue
        try dbQueue.close()

        // Delete database files (including WAL and SHM)
        let fileManager = FileManager.default
        let paths = [
            databaseURL.path,
            databaseURL.path + "-wal",
            databaseURL.path + "-shm"
        ]

        for path in paths {
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(atPath: path)
            }
        }
        print("Deleted corrupted database file")

        // Recreate database queue
        var config = Configuration()
        config.prepareDatabase { database in
            try database.execute(sql: "PRAGMA journal_mode = WAL")
        }

        self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)

        try await dbQueue.write { database in
            try self.createSchema(database)
        }

        print("Database reset complete")
    }
}
