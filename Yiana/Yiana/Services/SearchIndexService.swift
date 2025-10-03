//
//  SearchIndexService.swift
//  Yiana
//
//  GRDB-based full-text search index for document content
//

import Foundation
import GRDB

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

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case url = "url"
            case createdDate = "created_date"
            case modifiedDate = "modified_date"
            case pageCount = "page_count"
            case ocrCompleted = "ocr_completed"
            case indexedDate = "indexed_date"
        }

        enum Columns {
            static let documentId = Column("document_id")
            static let url = Column("url")
            static let createdDate = Column("created_date")
            static let modifiedDate = Column("modified_date")
            static let pageCount = Column("page_count")
            static let ocrCompleted = Column("ocr_completed")
            static let indexedDate = Column("indexed_date")
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
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA journal_mode = WAL")
            }

            self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)

            // Run migrations
            try dbQueue.write { db in
                try self.createSchema(db)
            }

            print("✓ Search index database initialized at \(databaseURL.path)")
        } catch {
            fatalError("Failed to initialize search database: \(error)")
        }
    }

    // MARK: - Schema Management

    private func createSchema(_ db: Database) throws {
        // Create FTS5 virtual table for full-text search
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
                document_id UNINDEXED,
                title,
                full_text,
                tags,
                tokenize='porter unicode61 remove_diacritics 2'
            )
            """)

        // Create metadata table for non-searchable fields
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS documents_metadata (
                document_id TEXT PRIMARY KEY,
                url TEXT NOT NULL,
                created_date REAL NOT NULL,
                modified_date REAL NOT NULL,
                page_count INTEGER NOT NULL,
                ocr_completed INTEGER NOT NULL,
                indexed_date REAL NOT NULL
            )
            """)

        // Create index on URL for fast lookups
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_url ON documents_metadata(url)
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
        metadata: DocumentMetadata
    ) async throws {
        try await dbQueue.write { db in
            // Insert FTS record
            let ftsRecord = DocumentFTSRecord(
                documentId: id.uuidString,
                title: title,
                fullText: fullText,
                tags: tags.joined(separator: " ")
            )
            try ftsRecord.insert(db, onConflict: .replace)

            // Insert metadata record
            let metadataRecord = DocumentMetadataRecord(
                documentId: id.uuidString,
                url: url.path,
                createdDate: metadata.created.timeIntervalSince1970,
                modifiedDate: metadata.modified.timeIntervalSince1970,
                pageCount: metadata.pageCount,
                ocrCompleted: metadata.ocrCompleted,
                indexedDate: Date().timeIntervalSince1970
            )
            try metadataRecord.insert(db, onConflict: .replace)
        }
    }

    /// Remove a document from the search index
    func removeDocument(id: UUID) async throws {
        try await dbQueue.write { db in
            let idString = id.uuidString

            // Delete from FTS table
            try db.execute(
                sql: "DELETE FROM documents_fts WHERE document_id = ?",
                arguments: [idString]
            )

            // Delete from metadata table
            try db.execute(
                sql: "DELETE FROM documents_metadata WHERE document_id = ?",
                arguments: [idString]
            )
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
    }

    /// Perform full-text search with relevance ranking
    func search(query: String, limit: Int = 50) async throws -> [IndexedSearchResult] {
        return try await dbQueue.read { db in
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
                    m.modified_date
                FROM documents_fts fts
                JOIN documents_metadata m ON fts.document_id = m.document_id
                WHERE documents_fts MATCH ?
                ORDER BY rank
                LIMIT ?
                """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [sanitizedQuery, limit])

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
                    modifiedDate: Date(timeIntervalSince1970: modifiedTimestamp)
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
        return try await dbQueue.read { db in
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents_metadata") ?? 0
        }
    }

    /// Check if a document is indexed
    func isDocumentIndexed(id: UUID) async throws -> Bool {
        return try await dbQueue.read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM documents_metadata WHERE document_id = ?",
                arguments: [id.uuidString]
            ) ?? 0
            return count > 0
        }
    }

    /// Optimize the FTS index (should be called periodically)
    func optimize() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "INSERT INTO documents_fts(documents_fts) VALUES('optimize')")
            print("✓ Search index optimized")
        }
    }

    /// Rebuild entire index (for migrations or corruption recovery)
    func rebuildIndex() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM documents_fts")
            try db.execute(sql: "DELETE FROM documents_metadata")
            print("✓ Search index cleared")
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
        print("✓ Deleted corrupted database file")

        // Recreate database queue
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)

        try await dbQueue.write { db in
            try self.createSchema(db)
        }

        print("✓ Database reset complete")
    }
}
