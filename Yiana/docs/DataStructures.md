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

## Future Considerations

1. **Versioning**: Add version field for format migration
2. **Compression**: Consider PDF compression options
3. **Thumbnails**: Add preview images for faster browsing
4. **Encryption**: Support for sensitive documents
5. **Annotations**: Separate layer for user annotations (read-only PDF)