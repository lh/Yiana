# Yiana Project Structure

## Repository Layout
```
Yiana/                          # Root
├── Yiana/                      # Xcode project (iOS/macOS app)
│   ├── Yiana.xcodeproj/
│   ├── Yiana/                  # App source
│   │   ├── Models/             # 12 files — DocumentMetadata, ExtractedAddress, LetterDraft, etc.
│   │   ├── Views/              # 26 files — SwiftUI views (cross-platform)
│   │   ├── ViewModels/         # 5 files — DocumentListVM, DocumentVM, ComposeVM, etc.
│   │   ├── Services/           # 32 files — Repos, import/export, OCR, rendering, sync
│   │   ├── Extensions/         # 5 files — PDFDocument+PageIndexing, String+TitleCase
│   │   ├── Utilities/          # 12 files — Formatting, dev tools, typography
│   │   ├── Accessibility/      # VoiceOver support
│   │   └── Markup/             # PencilKit PDF markup
│   ├── YianaTests/             # 25 test files
│   └── YianaUITests/           # 3 UI test files
├── YianaExtraction/            # Swift Package — address extraction, entity DB, NHS lookup
├── YianaRenderer/              # Swift Package — Typst rendering via Rust FFI
├── YianaDocumentArchive/       # Swift Package — .yianazip format (ZIPFoundation)
├── YianaOCRService/            # Swift Package — legacy server OCR (retired)
├── AddressExtractor/           # Python backend (retired, legacy reference)
├── scripts/                    # Dashboard, watchdog, postcode generator
├── docs/                       # Architecture, plans, roadmap
└── .claude/                    # Skills (/deploy, /testflight, /check), hooks
```

## Swift Packages (4)
| Package | Purpose | Dependencies |
|---------|---------|-------------|
| YianaExtraction | Extraction, entity DB, NHS lookup | GRDB.swift |
| YianaRenderer | Typst letter/envelope PDF rendering | CYianaTypstBridge (Rust) |
| YianaDocumentArchive | .yianazip package format | ZIPFoundation |
| YianaOCRService | Server OCR (retired) | swift-argument-parser, swift-log |

## Xcode Schemes
- **Yiana** — main app (iOS + macOS)
- **yiana-extract** — CLI extraction tool
- **YianaRenderer**, **YianaDocumentArchive**, **YianaExtraction** — package schemes

## Single Branch
- `main` only (14 stale branches cleaned up 2026-03-27)
- 10 consolidation phase tags for historical reference
