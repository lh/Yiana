# Architecture

This doc explains how Yiana is structured across app(s), services, and files, and how data moves through the system.

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
  end

  A <-->.yianazip / sync --> I
  M <-->.yianazip / sync --> I
  O <--> I
  O --> R[[.ocr_results JSON/XML/hOCR]]
```

## Components & Responsibilities
- App (`Yiana/`)
  - SwiftUI views for listing, viewing, and (on iOS) editing documents
  - Importing PDFs (new or append) via ImportService
  - 1‑based page indexing helpers wrap PDFKit quirks
- OCR service (`YianaOCRService/`)
  - Watches the documents directory (iCloud or local fallback)
  - OCRs PDFs lacking text; embeds text layer; saves `.ocr_results/*.json|.xml|.hocr`
- Python tools (`AddressExtractor/`)
  - Separate utilities for letters/data processing

## Data Model & Format
- DocumentMetadata (selected fields):
  - `id: UUID`, `title: String`, `created: Date`, `modified: Date`
  - `pageCount: Int`, `ocrCompleted: Bool`, `fullText: String?`
- Document format (`.yianazip`):
  - `[metadata JSON][0xFF 0xFF 0xFF 0xFF separator][raw PDF bytes]`

## Storage & Sync
- Documents live in `iCloud.com.vitygas.Yiana/Documents` with optional subfolders
- Local fallback: user Documents directory when iCloud unavailable
- OCR service reads/writes directly in the same directory tree

## Key Conventions
- 1‑based page numbers in UI and metadata (convert at PDFKit boundaries)
- Read‑only PDF viewing; editing limited to page-level merges/appends
- Platform-specific code is preferred over heavy cross‑platform abstractions

## Import Flow (iOS)
1) System share/open hands a PDF file URL to the app
2) ImportService either:
   - Creates a new `.yianazip`, or
   - Merges pages into an existing one
3) `ocrCompleted = false` → OCR service picks it up and updates metadata

## Error & State Patterns
- Avoid state changes during SwiftUI view updates (dispatch to main async)
- Save small, focused changes; rely on UIDocument semantics on iOS
- Defensive IO: atomic writes for `.yianazip` to ensure sync signals

## Extensibility Notes
- Add insertion-at-position on append by reusing PDFKit page APIs
- Surface OCR status in list/read views from metadata and `.ocr_results`
- macOS save path can mirror iOS NoteDocument format for symmetry

