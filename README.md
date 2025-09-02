# Yiana

Yiana is a document scanning and PDF management app for iOS, iPadOS, and macOS. It stores documents as simple packages with metadata and a PDF, syncs via iCloud Drive, and offloads OCR to a Mac mini backend.

## Repo Layout
- `Yiana/`: SwiftUI app (iOS/iPadOS/macOS). Views, ViewModels, Services, Extensions, and tests.
- `YianaOCRService/`: Swift Package executable (`yiana-ocr`) that watches the documents folder and performs OCR.
- `AddressExtractor/`: Python utilities for letter generation and data processing.
- `Yiana/docs/`: Technical docs (architecture, APIs, importing, plans).

## Quick Start
- Requirements: Xcode 15+, iOS 17+/macOS 14+, Swift 5.9+
- Build app: `open Yiana/Yiana.xcodeproj` → select device/simulator → Cmd+R
- Tests (CLI): `xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'`
- OCR service: `cd YianaOCRService && swift build && swift run yiana-ocr --help`
- Python tools: `cd AddressExtractor && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`

## Import PDFs
- iOS/iPadOS: Share → “Copy to Yiana” or “Open in Yiana”. Choose:
  - New Document: creates a `.yianazip` with your PDF
  - Append to Existing: merges pages into a selected document
- macOS: Open from Files or drag a PDF into the app (append options coming).
- OCR: Imports mark `ocrCompleted = false`; the Mac mini watcher processes and embeds text, saving results in `.ocr_results`.

## Design Principles
- Simplicity over abstraction; platform‑specific code is OK
- 1‑based page indexing in all app code (PDFKit conversions hidden in extensions)
- Read‑only PDF viewing (no heavy annotation model)
- Server‑side OCR; mobile stays responsive

## Learn More
- Architecture: `Yiana/docs/Architecture.md`
- Importing PDFs: `Yiana/docs/Importing.md`
- Coding style: `CODING_STYLE.md`
- API & data structures: `Yiana/docs/API.md`, `Yiana/docs/DataStructures.md`
- Plan & roadmap: `PLAN.md`
