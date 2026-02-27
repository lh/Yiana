# Yiana

Yiana is a document scanning and PDF management app for iOS, iPadOS, and macOS. It stores documents as `.yianazip` packages (ZIP archives containing metadata and a PDF), syncs via iCloud Drive, and processes OCR both on-device and via a Mac mini backend.

## Repo Layout
- `Yiana/`: SwiftUI app (iOS/iPadOS/macOS). Views, ViewModels, Services, Extensions, and tests.
- `YianaDocumentArchive/`: Swift Package that reads and writes the `.yianazip` format (ZIPFoundation-based).
- `YianaOCRService/`: Swift Package executable (`yiana-ocr`) that watches the documents folder and performs server-side OCR.
- `AddressExtractor/`: Python utilities for address extraction, entity linking, and data processing.
- `Yiana/docs/`: Technical docs (architecture, developer guides, user guides).

## Quick Start
- Requirements: Xcode 16+, iOS 18+/macOS 15+, Swift 5.9+
- Build app: `open Yiana/Yiana.xcodeproj` then select device/simulator and Cmd+R
- Tests (CLI): `xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'`
- OCR service: `cd YianaOCRService && swift build && swift run yiana-ocr --help`
- Python tools: `cd AddressExtractor && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`

## Key Features
- **Document scanning** (iOS/iPadOS) with VisionKit auto-detection
- **On-device OCR** using Apple's Vision framework for immediate text recognition
- **Server OCR** via Mac mini backend for batch processing
- **Full-text search** powered by GRDB/FTS5 with BM25 ranking
- **Folders** with nesting, rename, and drag-and-drop organization
- **Bulk import/export** (macOS) with duplicate detection and folder structure preservation
- **Page copy/cut/paste** between documents on both platforms
- **Print** (macOS Cmd+P, iOS via share sheet)
- **Address extraction** with in-app viewing, editing, and override of extracted data
- **iCloud sync** across all devices

## Import PDFs
- **iOS/iPadOS**: Share a PDF to "Copy to Yiana" or "Open in Yiana". Choose New Document or Append to Existing.
- **macOS**: Drag PDFs into the app window, use File > Import, or Import from Folder for bulk import.
- OCR: On-device OCR runs automatically. The Mac mini server also processes documents in the background.

## Design Principles
- Simplicity over abstraction; platform-specific code is OK
- 1-based page indexing in all app code (PDFKit conversions hidden in extensions)
- Read-only PDF viewing (no heavy annotation model)
- Dual OCR: on-device for immediacy, server for batch processing

## Learn More
- Architecture: `Yiana/docs/Architecture.md`
- Developer guide: `Yiana/docs/dev/GettingStarted.md`
- User guide: `Yiana/docs/user/README.md`
- Roadmap: `Yiana/docs/dev/Roadmap.md`
- Coding style: `CODING_STYLE.md`
