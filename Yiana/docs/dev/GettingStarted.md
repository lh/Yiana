# Developer Getting Started Guide

**Purpose**: Get new developers productive with Yiana in under 1 hour
**Audience**: Developers new to the Yiana codebase
**Last Updated**: 2026-02-25

---

## Prerequisites

- **Xcode 16.0+** (for iOS/iPadOS/macOS development)
- **Swift 5.9+** (bundled with Xcode)
- **macOS 15.0+** (Sequoia or later)
- **Apple Developer Account** (for device testing, optional for simulator)
- **Git** (for version control)

## Quick Start (15 minutes)

### 1. Clone the Repository

```bash
cd ~/Code  # or your preferred workspace
git clone https://github.com/lh/Yiana.git
cd Yiana
```

### 2. Open in Xcode

```bash
open Yiana/Yiana.xcodeproj
```

### 3. Build and Run (Simulator)

1. Select scheme: **Yiana** (top-left)
2. Select destination: **iPhone 16** (or any iOS simulator)
3. Press **Cmd+R** to build and run

The app should launch in the simulator within 30-60 seconds.

### 4. Verify Build (Tests)

```bash
# Run iOS unit tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'

# Run macOS unit tests
xcodebuild test -scheme Yiana -destination 'platform=macOS'
```

**Expected**: All tests pass (or failing tests are documented in GitHub issues).

## Project Structure Overview (10 minutes)

```
Yiana/
├── Yiana/                    # Main app target (iOS/iPadOS/macOS)
│   ├── YianaApp.swift       # SwiftUI app entry point
│   ├── Models/              # Data structures (DocumentMetadata, NoteDocument, etc.)
│   ├── ViewModels/          # State management (DocumentListViewModel, etc.)
│   ├── Views/               # SwiftUI views (DocumentListView, PDFViewer, etc.)
│   ├── Services/            # Core functionality (DocumentRepository, SearchIndexService, etc.)
│   ├── Extensions/          # API wrappers (PDFDocument+PageIndexing, etc.)
│   ├── Accessibility/       # VoiceOver and accessibility support
│   ├── Markup/              # PDF markup/annotation code
│   └── Utilities/           # Helper functions
│
├── YianaTests/              # Unit tests
├── YianaUITests/            # UI tests
│
├── YianaDocumentArchive/    # Swift Package for .yianazip format (ZIPFoundation)
│
├── YianaOCRService/         # OCR backend (Swift Package, Mac mini)
│   └── Sources/YianaOCR/   # OCR processing logic
│
├── AddressExtractor/        # Python utilities (address extraction, entity linking)
│
├── docs/                    # Documentation
│   ├── user/               # User-facing documentation
│   ├── dev/                # Developer documentation
│   └── decisions/          # Architecture Decision Records (ADRs)
│
└── comments/                # Code review notes and analyses
```

## Architecture Essentials (15 minutes)

### Document Storage Model

**Key concept**: Yiana uses UIDocument (iOS) and NSDocument (macOS), **NOT Core Data**.

- **Format**: `.yianazip` packages -- ZIP archives containing `metadata.json`, `content.pdf`, and `format.json`
- **Package**: `YianaDocumentArchive` Swift Package handles reading/writing using ZIPFoundation
- **Storage**: iCloud Drive (`iCloud.com.vitygas.Yiana/Documents/`)
- **Models**:
  - `NoteDocument` (iOS/iPadOS) extends `UIDocument`
  - `YianaDocument` (macOS) extends `NSDocument`
  - Both use `DocumentMetadata` struct

### Page Numbering Convention (CRITICAL)

**Always use 1-based page numbers** except at PDFKit API boundaries.

```swift
// GOOD - using wrapper (1-based)
let page = pdfDocument.getPage(number: 1)  // First page

// BAD - direct PDFKit call (0-based, error-prone)
let page = pdfDocument.page(at: 0)  // First page
```

See: `Extensions/PDFDocument+PageIndexing.swift` for wrapper implementations.

### Search Index

- **GRDB v7.7** with SQLite FTS5 for full-text search
- BM25 ranking (title weighted 100x over content)
- Porter stemming + Unicode61 tokenizer
- `ValueObservation` for reactive SwiftUI list binding
- Database in `~/Library/Caches/SearchIndex/` (not synced via iCloud)

### OCR Processing

- **On-device**: `OnDeviceOCRService` uses Apple's Vision framework (`VNRecognizeTextRequest`) for immediate text recognition when documents are scanned or opened
- **Server**: `YianaOCRService` (Swift CLI, runs on Mac mini) processes documents in the background and writes `.ocr_results/` JSON
- Metadata tracks source via `ocrSource` enum: `.onDevice`, `.service`, or `.embedded`

### Key Dependencies

- **GRDB.swift** (v7.7) -- Type-safe SQLite wrapper powering the FTS5 search index
- **ZIPFoundation** -- ZIP archive handling for `.yianazip` format (via `YianaDocumentArchive` package)

### Platform Specifics

Yiana has **separate iOS and macOS** implementations, not cross-platform abstractions:

- **iOS/iPadOS**: UIDocument, UIKit wrappers (PDFView via UIViewRepresentable)
- **macOS**: NSDocument, AppKit (PDFView via NSViewRepresentable)
- **Shared**: DocumentMetadata format, .yianazip package structure, search index

## Core Workflows (15 minutes)

### Creating a Document

1. User taps "New Document" in `DocumentListView`
2. Enters title (required) via `DocumentListViewModel.createDocument()`
3. `DocumentRepository.createNewDocument()` creates `NoteDocument`
4. `NoteDocument.save()` writes `.yianazip` to iCloud Drive

**Code path**: `DocumentListView.swift` -> `DocumentListViewModel.swift` -> `DocumentRepository.swift` -> `NoteDocument.swift`

### Scanning Pages

1. User taps scan button in `DocumentEditView` -> `ScannerView`
2. VisionKit's `VNDocumentCameraViewController` (automatic edge detection)
3. Captured images -> `ScanningService.convertToPDF()`
4. `DocumentViewModel.appendScannedPages()` appends to existing PDF
5. `NoteDocument.save()` updates `.yianazip`
6. On-device OCR runs automatically via `OnDeviceOCRService`

**Code path**: `DocumentEditView.swift` -> `ScannerView.swift` -> `ScanningService.swift` -> `DocumentViewModel.swift`

### Bulk Import (macOS)

1. Drag PDFs into app, use File > Import, or Import from Folder
2. `BulkImportService` validates, deduplicates (SHA256), and imports
3. Progress tracking with per-file timeout (30s)
4. Batch search indexing in groups of 50

**Code path**: `DocumentListView.swift` -> `BulkImportView.swift` -> `BulkImportService.swift`

### Search

1. User types search term in `DocumentListView`
2. `SearchIndexService.search()` runs FTS5 MATCH query with BM25 ranking
3. Results include snippets with `<mark>` tags around matches
4. User taps result to navigate to document + page

**Code path**: `DocumentListView.swift` -> `DocumentListViewModel.swift` -> `SearchIndexService.swift`

## Development Workflow (10 minutes)

### Test-Driven Development (TDD) Mandate

**ALWAYS follow TDD**:

1. Write failing test first (`YianaTests/`)
2. Implement minimal code to make test pass
3. Refactor while keeping tests green
4. Commit after each test/implementation pair

### Coding Style

**Key principles**:
- 1-based page indexing (except PDFKit boundaries)
- Use wrapper extensions for external APIs
- Avoid state mutation during SwiftUI view updates
- Platform-specific code is preferred over cross-platform abstractions
- Never read `@State`/`@Published` inside `Task {}` bodies; capture to local first

See: [`CODING_STYLE.md`](../../CODING_STYLE.md) for detailed conventions.

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, commit frequently
git add .
git commit -m "Brief description of change"

# Push to GitHub
git push origin feature/your-feature-name

# Create PR on GitHub
```

**Commit conventions**:
- No emojis
- No attributions (e.g., "Fixed by Claude")
- Clear, concise descriptions
- Small, focused commits

### Running Tests

```bash
# Run all iOS tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all macOS tests
xcodebuild test -scheme Yiana -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentRepositoryTests/testCreateNewDocument
```

## Common Tasks (10 minutes)

### Adding a New Feature

1. **Check Roadmap** - Is it planned? (`docs/dev/Roadmap.md`)
2. **Write ADR** (if architectural) - `docs/decisions/`
3. **Write tests first** (TDD)
4. **Implement feature**
5. **Build both platforms** - iOS and macOS
6. **Manual testing** - Multiple devices, edge cases
7. **Create PR** with description of changes

### Debugging Tips

**Page Navigation Issues**:
```swift
// Add logging to verify 1-based indexing
print("Navigating to page \(pageNum) (1-based)")
```

**State Update Issues** ("Modifying state during view update"):
```swift
// Use DispatchQueue.main.async to defer state changes
DispatchQueue.main.async {
    self.totalPages = document.pageCount
}
```

**OCR/Search Issues**:
- Check `.ocr_results/` directory exists
- Verify OCR JSON format (1-based page numbers)
- Check `ocrCompleted` flag in metadata
- Check search index stats via Developer Tools in Settings

### Building for Device

1. Connect iPhone/iPad via USB
2. Select device in Xcode (top-left)
3. Xcode may prompt to register device with Apple Developer account
4. Press **Cmd+R** to build and run

### Building OCR Service

```bash
cd YianaOCRService
swift build
swift run yiana-ocr --help
```

**Note**: OCR service requires macOS and is intended for Mac mini backend.

## Essential Documentation (5 minutes)

**Must read** (in order):

1. [`CLAUDE.md`](../../CLAUDE.md) - Project overview, core rules, architecture
2. [`CODING_STYLE.md`](../../CODING_STYLE.md) - Code conventions
3. [`Architecture.md`](../Architecture.md) - System architecture
4. [`docs/decisions/`](../decisions/) - Key architectural decisions (ADRs)

**Feature-specific** (as needed):

5. [`docs/dev/features/TextPages.md`](features/TextPages.md) - Text page editor
6. [`SearchArchitecture.md`](../SearchArchitecture.md) - Search implementation
7. [`Importing.md`](../Importing.md) - PDF import flows
8. [`AddressExtraction.md`](AddressExtraction.md) - Backend extraction pipeline and domain adaptation

**Diagrams** (visual overview):

8. [`docs/diagrams/system-architecture.md`](../diagrams/system-architecture.md)
9. [`docs/diagrams/data-flow.md`](../diagrams/data-flow.md)
10. [`docs/diagrams/pdf-rendering-pipeline.md`](../diagrams/pdf-rendering-pipeline.md)

## Troubleshooting

### Build Errors

**Issue**: "Unable to load contents of file list"
- **Fix**: Clean build folder (Cmd+Shift+K), then rebuild

**Issue**: "No such module 'PDFKit'"
- **Fix**: Verify target is set to iOS/macOS (not watchOS/tvOS)

**Issue**: Code signing error
- **Fix**: Update provisioning profiles in Xcode -> Signing & Capabilities

### Test Failures

**Issue**: Tests fail on CI but pass locally
- **Check**: Ensure tests don't depend on local file paths or iCloud state

**Issue**: UI tests time out
- **Fix**: Increase timeout in test configuration

### Runtime Issues

**Issue**: App crashes on launch
- **Check**: Console logs for stack trace
- **Check**: iCloud Drive enabled in Settings

**Issue**: Documents not syncing
- **Check**: iCloud Drive connected
- **Check**: Network connectivity

## Next Steps

**After completing this guide, you should be able to**:
- Build and run Yiana on simulator and device
- Run tests and verify they pass
- Navigate the codebase structure
- Understand core workflows (document creation, scanning, search, import)
- Follow TDD workflow
- Commit changes following project conventions

**Ready to contribute?** See:
- [`Roadmap.md`](Roadmap.md) - Current priorities and planned features
- [`docs/decisions/`](../decisions/) - Architectural context

## Getting Help

- **Documentation**: Check `docs/` directory first
- **Issues**: Search GitHub issues for known problems
- **Code Review**: Create draft PR and ask for feedback
- **Architecture**: Review ADRs in `docs/decisions/`

Welcome to the Yiana project.
