# Search Architecture Documentation

## Overview
Yiana implements full-text search using SQLite FTS5 (Full-Text Search version 5) via the GRDB.swift wrapper library. This document explains the architecture, design decisions, and implementation details.

## Technology Stack

### GRDB.swift
**Version:** 7.7.1+
**Repository:** https://github.com/groue/GRDB.swift
**License:** MIT
**Maturity:** 10+ years in production, widely used in iOS community

### Why GRDB Instead of Raw SQLite?

#### Problems with Raw SQLite C API in Swift:
1. **String Conversion Hell**
   ```swift
   // ❌ This silently stores empty strings!
   sqlite3_bind_text(stmt, 1, title, -1, nil)

   // ✅ Required incantation
   sqlite3_bind_text(stmt, 1, (title as NSString).utf8String, -1, nil)
   ```

2. **No Type Safety**
   - SQL queries are strings, no compile-time checking
   - Easy to bind wrong types to parameters
   - Column names are magic strings

3. **Memory Management**
   - Manual statement finalization
   - Potential leaks with early returns
   - No automatic cleanup on errors

4. **Boilerplate**
   - ~500 lines for basic CRUD operations
   - Manual transaction management
   - Repetitive error handling

#### Benefits of GRDB:
1. **Automatic String Conversion** - No more NSString casts
2. **Type Safety** - Swift types map directly to SQL
3. **Memory Safety** - Automatic cleanup via defer/deinit
4. **Less Code** - ~70% reduction in boilerplate
5. **Better Errors** - Clear error messages with context
6. **Migrations** - Built-in schema versioning
7. **Zero Runtime Overhead** - Thin wrapper, same performance

## Database Architecture

### Location
```
~/Library/Caches/SearchIndex/search_index.db
```

**Why Caches directory?**
- Excluded from iCloud backup (prevents sync conflicts)
- Can be regenerated from source documents
- iOS won't delete it unless storage is critically low

### Schema

#### FTS5 Table: `documents_fts`
```sql
CREATE VIRTUAL TABLE documents_fts USING fts5(
    document_id UNINDEXED,  -- UUID, not searchable
    title,                   -- Primary search field
    full_text,              -- OCR text content
    tags,                   -- User tags
    tokenize='porter unicode61 remove_diacritics 2'
);
```

**Tokenizer Options:**
- `porter` - English word stemming (searching → search)
- `unicode61` - Unicode normalization
- `remove_diacritics 2` - Treat "café" as "cafe"

#### Metadata Table: `documents_metadata`
```sql
CREATE TABLE documents_metadata (
    document_id TEXT PRIMARY KEY,
    url TEXT NOT NULL,
    created_date REAL NOT NULL,
    modified_date REAL NOT NULL,
    page_count INTEGER NOT NULL,
    ocr_completed INTEGER NOT NULL,
    indexed_date REAL NOT NULL
);
```

### GRDB Record Types

```swift
struct DocumentFTSRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "documents_fts"

    let documentId: String
    let title: String
    let fullText: String
    let tags: String
}

struct DocumentMetadataRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "documents_metadata"

    let documentId: String
    let url: String
    let createdDate: Date
    let modifiedDate: Date
    let pageCount: Int
    let ocrCompleted: Bool
    let indexedDate: Date
}
```

## Indexing Flow

### 1. App Launch
```
BackgroundIndexer.indexAllDocuments()
  ↓
Get all documents from DocumentRepository
  ↓
For each document:
  - Extract metadata from .yianazip
  - Check if already indexed (by UUID)
  - If not indexed, add to queue
  ↓
Index in batches of 10
  ↓
Optimize FTS index
```

### 2. Document Creation
```
User imports/scans PDF
  ↓
NoteDocument.save() completes
  ↓
SearchIndexService.indexDocument()
  ↓
Immediate indexing (no batch)
```

### 3. Document Modification
```
User edits metadata or OCR completes
  ↓
NoteDocument.save() completes
  ↓
SearchIndexService.indexDocument()
  - INSERT OR REPLACE (updates existing)
```

### 4. Document Deletion
```
User deletes document
  ↓
DocumentRepository.deleteDocument()
  ↓
SearchIndexService.removeDocument(id: UUID)
  ↓
Remove from both FTS and metadata tables
```

## Search Flow

### Query Processing
```
User types: "diabetes patient"
  ↓
Sanitize query:
  - Trim whitespace
  - Add prefix matching: "diabetes* patient*"
  ↓
FTS5 MATCH query:
  SELECT * FROM documents_fts
  WHERE documents_fts MATCH 'diabetes* patient*'
  ORDER BY bm25(documents_fts, 100.0, 1.0, 1.0)
  ↓
BM25 Ranking:
  - Title matches: 100x weight
  - Full text matches: 1x weight
  - Tag matches: 1x weight
  ↓
Join with metadata for additional fields
  ↓
Return sorted results
```

### BM25 Relevance Scoring
BM25 is an industry-standard ranking algorithm that considers:
- **Term Frequency** - How often search term appears
- **Document Length** - Shorter docs rank higher for same frequency
- **Term Rarity** - Rare words matter more than common words

The weights `(100.0, 1.0, 1.0)` mean:
- Title matches are 100x more relevant than content
- Content and tags have equal weight

## GRDB Usage Examples

### Indexing a Document
```swift
try await dbQueue.write { db in
    // Insert FTS record
    try DocumentFTSRecord(
        documentId: id.uuidString,
        title: title,
        fullText: fullText,
        tags: tags.joined(separator: " ")
    ).insert(db)

    // Insert metadata record
    try DocumentMetadataRecord(
        documentId: id.uuidString,
        url: url.path,
        createdDate: metadata.created,
        modifiedDate: metadata.modified,
        pageCount: metadata.pageCount,
        ocrCompleted: metadata.ocrCompleted,
        indexedDate: Date()
    ).insert(db)
}
```

### Searching
```swift
try await dbQueue.read { db in
    let sql = """
        SELECT
            fts.document_id,
            fts.title,
            snippet(documents_fts, 1, '<mark>', '</mark>', '...', 50) as snippet,
            bm25(documents_fts, 100.0, 1.0, 1.0) as rank,
            m.url, m.page_count, m.modified_date
        FROM documents_fts fts
        JOIN documents_metadata m ON fts.document_id = m.document_id
        WHERE documents_fts MATCH ?
        ORDER BY rank
        LIMIT ?
    """

    return try Row.fetchAll(db, sql: sql, arguments: [query, limit])
}
```

### Checking if Indexed
```swift
try await dbQueue.read { db in
    return try DocumentMetadataRecord
        .filter(Column("documentId") == id.uuidString)
        .fetchOne(db) != nil
}
```

## Performance Characteristics

### Indexing Speed
- **Single document:** <10ms
- **500 documents:** ~5 seconds
- **Bottleneck:** Reading .yianazip files, not database

### Search Speed
- **Simple query:** <50ms
- **Complex multi-term:** <100ms
- **Full text length:** No impact (FTS5 is optimized)

### Database Size
- **Overhead per document:** ~2KB (FTS index)
- **500 documents with OCR:** ~10MB total
- **No impact on app size:** Database is user data

## Error Handling

### Database Corruption
If corruption detected:
1. Log error with details
2. Delete database file
3. Reinitialize empty database
4. Trigger full reindex from documents

### Missing Documents
If document in index but file deleted:
- Remove from index on next search
- Background indexer will clean up orphans

### OCR Failures
If document has no fullText:
- Index with empty fullText (title still searchable)
- Will be reindexed when OCR completes

## Migration Strategy

### Schema Changes
GRDB provides built-in migrations:
```swift
var migrator = DatabaseMigrator()

// v1: Initial schema
migrator.registerMigration("v1") { db in
    try db.create(table: "documents_fts") { ... }
    try db.create(table: "documents_metadata") { ... }
}

// v2: Add new column (example)
migrator.registerMigration("v2") { db in
    try db.alter(table: "documents_metadata") { t in
        t.add(column: "favorite", .boolean).notNull().defaults(to: false)
    }
}

try migrator.migrate(dbQueue)
```

### Version Tracking
GRDB automatically tracks schema version in `grdb_migrations` table.

## Testing Strategy

### Unit Tests
- Mock DatabaseWriter for fast tests
- Test record encoding/decoding
- Test query building logic

### Integration Tests
- Use in-memory database (`:memory:`)
- Test full indexing flow
- Test search ranking

### Manual Testing
- Dev Tools → Inspect Database Contents
- Dev Tools → Reset Search Index
- Verify search results match expectations

## Future Enhancements

1. **Faceted Search** - Filter by tags, date ranges, page count
2. **Search Suggestions** - Autocomplete based on indexed content
3. **Highlighting** - Show search terms in context
4. **Relevance Tuning** - Adjust BM25 weights based on user feedback
5. **Analytics** - Track popular search terms
6. **Synonyms** - Expand queries with related terms

## References

- [GRDB Documentation](https://github.com/groue/GRDB.swift)
- [SQLite FTS5](https://www.sqlite.org/fts5.html)
- [BM25 Algorithm](https://en.wikipedia.org/wiki/Okapi_BM25)
- [Full-Text Search Best Practices](https://www.sqlite.org/fts5.html#full_text_query_syntax)
