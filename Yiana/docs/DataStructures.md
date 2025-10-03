# Yiana Data Structures Documentation

## Overview
Yiana uses a custom `.yianazip` package format to store PDF documents with associated metadata. This document describes the data structures and file formats used.

## File Format: .yianazip

### Current Implementation (Temporary)
The current implementation uses a simple separator-based format:
```
[JSON-encoded metadata][0xFF 0xFF 0xFF 0xFF][PDF data]
```

### Planned Implementation
Will be a proper ZIP archive containing:
```
document.yianazip/
├── metadata.json
└── document.pdf
```

## Core Data Structures

### DocumentMetadata
Stores all metadata associated with a PDF document.

```swift
struct DocumentMetadata: Codable, Equatable {
    let id: UUID                    // Unique identifier
    var title: String              // Document title
    let created: Date              // Creation date
    var modified: Date             // Last modification date
    var pageCount: Int             // Number of pages in PDF
    var tags: [String]             // User-defined tags
    var ocrCompleted: Bool         // OCR processing status
    var fullText: String?          // Extracted text (nil until OCR completes)
}
```

#### Field Descriptions:
- **id**: Immutable UUID generated on document creation
- **title**: Initially derived from filename, user-editable
- **created**: Set once on document import/scan
- **modified**: Updated on any metadata or PDF change
- **pageCount**: Extracted from PDF on import
- **tags**: User-defined, used for organization/search
- **ocrCompleted**: False initially, true after Mac mini processing
- **fullText**: Populated by OCR server, used for full-text search

### NoteDocument (iOS)
UIDocument subclass that handles the .yianazip format.

```swift
class NoteDocument: UIDocument {
    var pdfData: Data?             // The actual PDF content
    var metadata: DocumentMetadata // Associated metadata
}
```

## JSON Schema

### metadata.json
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Meeting Notes",
  "created": "2025-01-15T10:30:00Z",
  "modified": "2025-01-15T14:45:00Z", 
  "pageCount": 3,
  "tags": ["meeting", "project-x", "2025"],
  "ocrCompleted": true,
  "fullText": "Full extracted text content..."
}
```

## Usage Examples

### Creating a New Document
```swift
let metadata = DocumentMetadata(
    id: UUID(),
    title: "My Document",
    created: Date(),
    modified: Date(),
    pageCount: 0,
    tags: [],
    ocrCompleted: false,
    fullText: nil
)

let document = NoteDocument(fileURL: url)
document.metadata = metadata
document.pdfData = pdfData
```

### Loading a Document
```swift
let document = NoteDocument(fileURL: url)
document.open { success in
    if success {
        // Access document.metadata and document.pdfData
    }
}
```

## Design Decisions

1. **Why .yianazip?**
   - Allows bundling PDF with metadata
   - Future-proof for additional assets (thumbnails, annotations)
   - Standard ZIP format is widely supported

2. **Why separate metadata?**
   - Can be read without loading entire PDF
   - Enables efficient searching/filtering
   - Allows metadata updates without touching PDF

3. **Why immutable ID and created date?**
   - Ensures document identity persistence
   - Critical for sync conflict resolution
   - Audit trail for document lifecycle

4. **Why optional fullText?**
   - OCR is async and happens on Mac mini
   - Allows documents to exist before OCR
   - Saves space if OCR not needed

## Platform Differences

### iOS/iPadOS
- Uses UIDocument for iCloud sync
- Implements full document lifecycle
- Primary platform for scanning/viewing

### macOS
- Will use NSDocument (not yet implemented)
- Shares same file format
- Focus on OCR processing and management

## Search Index Architecture

### Technology: GRDB.swift
The search index uses **GRDB.swift** (v7.7+), a mature Swift wrapper over SQLite that provides:
- Type-safe database operations
- Automatic Swift String ↔ C string conversion
- Built-in migration support
- Thread-safe database access
- FTS5 (Full-Text Search) integration

### Why GRDB vs Raw SQLite?
Raw SQLite C API in Swift is error-prone:
- Manual string conversion required (`(str as NSString).utf8String`)
- No compile-time type checking
- Easy to create memory leaks
- Verbose boilerplate code

GRDB eliminates these issues while adding zero runtime overhead.

### Database Schema
**Location:** `~/Library/Caches/SearchIndex/search_index.db`
(Excluded from iCloud backup to prevent sync conflicts)

**Tables:**
1. `documents_fts` - FTS5 virtual table for full-text search
   - `document_id` (UUID, not indexed)
   - `title` (searchable, 100x BM25 weight)
   - `full_text` (searchable from OCR)
   - `tags` (searchable)

2. `documents_metadata` - Non-searchable metadata
   - `document_id` (UUID, primary key)
   - `url` (file path)
   - `created_date`, `modified_date` (timestamps)
   - `page_count`, `ocr_completed` (integers)
   - `indexed_date` (timestamp)

### Indexing Process
1. Background indexing starts on app launch
2. Checks which documents need indexing
3. Extracts metadata (including embedded `fullText` from `.yianazip`)
4. Inserts into FTS table with BM25 ranking
5. Optimizes index after bulk operations

### Search Query Flow
```swift
// User types "diabetes"
// → Sanitized to "diabetes*" (prefix matching)
// → FTS5 MATCH query with BM25 ranking
// → Results sorted by relevance (titles weighted 100x)
```

## Future Considerations

1. **Versioning**: Add version field for format migration
2. **Compression**: Consider PDF compression options
3. **Thumbnails**: Add preview images for faster browsing
4. **Encryption**: Support for sensitive documents
5. **Annotations**: Separate layer for user annotations (read-only PDF)