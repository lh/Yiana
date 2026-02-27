# Architecture

This doc explains how Yiana is structured across app(s), services, and files, and how data moves through the system.

## Quick Reference

For detailed diagrams and flows, see:
- [System Architecture](diagrams/system-architecture.md) - Component relationships and responsibilities
- [Data Flow](diagrams/data-flow.md) - Sequence diagrams for major operations
- [PDF Rendering Pipeline](diagrams/pdf-rendering-pipeline.md) - PDF viewing, scanning, and text page rendering
- [OCR Processing Flow](diagrams/ocr-processing-flow.md) - Backend OCR service architecture

## System Overview
```mermaid
flowchart LR
  subgraph Mobile
    A[iOS/iPadOS App (SwiftUI)]
    M[macOS App (SwiftUI)]
  end
  subgraph Storage
    I[iCloud Drive\nDocuments/]
  end
  subgraph Backend
    O[OCR Service\n(YianaOCRService)]
    E[Address Extraction\n(AddressExtractor)]
  end

  A <-->.yianazip / sync --> I
  M <-->.yianazip / sync --> I
  O <--> I
  E <--> I
  O --> R[[.ocr_results JSON/XML/hOCR]]
  E --> S[[.addresses JSON]]
```

## Components & Responsibilities

- **App** (`Yiana/`)
  - SwiftUI views for listing, viewing, organizing, and (on iOS) scanning documents
  - Importing PDFs (new, append, or bulk import on macOS)
  - On-device OCR via Vision framework (`OnDeviceOCRService`)
  - GRDB/FTS5 search index (`SearchIndexService`) for full-text search with BM25 ranking
  - Folders with nesting, rename, and drag-and-drop
  - Page copy/cut/paste between documents (`PageClipboard`)
  - Duplicate detection (`DuplicateScanner`, macOS)
  - Address viewing and editing (`AddressesView`, `AddressRepository`)
  - 1-based page indexing helpers wrap PDFKit quirks
- **Document archive** (`YianaDocumentArchive/`)
  - Swift Package using ZIPFoundation for reading/writing `.yianazip` files
  - Atomic writes with staging directory for iCloud sync safety
- **OCR service** (`YianaOCRService/`)
  - Watches the documents directory (iCloud or local fallback)
  - OCRs PDFs lacking text; embeds text layer; saves `.ocr_results/*.json|.xml|.hocr`
- **Address extraction** (`AddressExtractor/`)
  - Python service running on Mac mini
  - Extracts patient, GP, and specialist data from OCR results
  - Writes `.addresses/*.json` files synced via iCloud

## Data Model & Format

- **DocumentMetadata** (selected fields):
  - `id: UUID`, `title: String`, `created: Date`, `modified: Date`
  - `pageCount: Int`, `ocrCompleted: Bool`, `fullText: String?`
  - `pdfHash: String?` (SHA256 for duplicate detection)
  - `ocrSource: OCRSource?` (`.onDevice`, `.service`, or `.embedded`)
  - `ocrConfidence: Double?`, `ocrProcessedAt: Date?`
  - `pageProcessingStates: [Int: PageProcessingState]?`
- **Document format** (`.yianazip`):
  - ZIP archive containing:
    - `metadata.json` — document metadata
    - `content.pdf` — PDF binary data
    - `format.json` — format version (currently `2`)
  - Created via `YianaDocumentArchive` package (ZIPFoundation, no compression)

## Search Index

- **GRDB v7.7** with SQLite FTS5 virtual table
- Tokenizer: Porter stemming + Unicode61 with diacritic removal
- BM25 ranking weights title 100x over content
- Snippet generation with `<mark>` tags for highlighting
- `ValueObservation` for reactive SwiftUI list updates
- Database stored in `~/Library/Caches/SearchIndex/` (excluded from iCloud backup)
- Placeholder entries for iCloud files not yet downloaded

## Storage & Sync
- Documents live in `iCloud.com.vitygas.Yiana/Documents` with subfolders
- Local fallback: user Documents directory when iCloud unavailable
- OCR service and address extraction read/write directly in the same directory tree
- OCR results in `.ocr_results/`, address data in `.addresses/`

## Key Conventions
- 1-based page numbers in UI and metadata (convert at PDFKit boundaries)
- Read-only PDF viewing; editing limited to page-level operations (reorder, delete, copy/cut/paste)
- Platform-specific code is preferred over heavy cross-platform abstractions
- Atomic writes for `.yianazip` to ensure iCloud sync signals

## Import Flow

### iOS/iPadOS
1. System share/open hands a PDF file URL to the app
2. `ImportService` either creates a new `.yianazip` or merges pages into an existing one
3. On-device OCR runs immediately via `OnDeviceOCRService`
4. `ocrCompleted = false` triggers server OCR pickup for additional processing

### macOS
1. Drag PDFs into app window, use File > Import, or Import from Folder
2. `BulkImportService` handles multi-file import with:
   - SHA256 duplicate detection against existing library
   - Progress tracking with per-file timeout protection
   - Batch search indexing (50-file groups)
3. On-device OCR runs on each imported document

## Error & State Patterns
- Avoid state changes during SwiftUI view updates (dispatch to main async)
- Save small, focused changes; rely on UIDocument semantics on iOS
- Atomic writes for `.yianazip` to ensure sync signals
- Never read `@State`/`@Published` inside `Task {}` bodies; capture to local first
