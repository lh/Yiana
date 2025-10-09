# Developer Getting Started Guide

**Purpose**: Get new developers productive with Yiana in under 1 hour
**Audience**: Developers new to the Yiana codebase
**Last Updated**: 2025-10-08

---

## Prerequisites

- **Xcode 15.0+** (for iOS/iPadOS/macOS development)
- **Swift 5.9+** (bundled with Xcode)
- **macOS 14.0+** (Sonoma or later)
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
open Yiana.xcodeproj
```

### 3. Build and Run (Simulator)

1. Select scheme: **Yiana** (top-left)
2. Select destination: **iPhone 15** (or any iOS simulator)
3. Press **⌘R** to build and run

The app should launch in the simulator within 30-60 seconds.

### 4. Verify Build (Tests)

```bash
# Run iOS unit tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'

# Run macOS unit tests
xcodebuild test -scheme Yiana -destination 'platform=macOS'
```

**Expected**: All tests pass (or failing tests are documented in GitHub issues).

## Project Structure Overview (10 minutes)

```
Yiana/
├── Yiana/                    # Main app target (iOS/iPadOS/macOS)
│   ├── YianaApp.swift       # SwiftUI app entry point
│   ├── Models/              # Data structures (DocumentMetadata, NoteDocument)
│   ├── ViewModels/          # State management (DocumentListViewModel, etc.)
│   ├── Views/               # SwiftUI views (DocumentListView, PDFViewer, etc.)
│   ├── Services/            # Core functionality (DocumentRepository, etc.)
│   ├── Extensions/          # API wrappers (PDFDocument+PageIndexing, etc.)
│   └── Utilities/           # Helper functions
│
├── YianaTests/              # Unit tests
├── YianaUITests/            # UI tests
│
├── YianaOCRService/         # OCR backend (Swift Package, Mac mini)
│   └── Sources/YianaOCR/   # OCR processing logic
│
├── AddressExtractor/        # Python utilities
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

- **Format**: `.yianazip` packages = `[metadata JSON][separator][PDF bytes]`
- **Storage**: iCloud Drive (`iCloud.com.vitygas.Yiana/Documents/`)
- **Models**:
  - `NoteDocument` (iOS/iPadOS) extends `UIDocument`
  - `YianaDocument` (macOS) extends `NSDocument`
  - Both use `DocumentMetadata` struct

### Page Numbering Convention (CRITICAL)

**Always use 1-based page numbers** except at PDFKit API boundaries.

```swift
// ✅ GOOD - using wrapper (1-based)
let page = pdfDocument.getPage(number: 1)  // First page

// ❌ BAD - direct PDFKit call (0-based, error-prone)
let page = pdfDocument.page(at: 0)  // First page
```

See: `Extensions/PDFDocument+PageIndexing.swift` for wrapper implementations.

### OCR Processing

- **Backend service**: `YianaOCRService` (Swift CLI, runs on Mac mini)
- **Flow**: Document created → `ocrCompleted = false` → Service processes → Writes `.ocr_results/` JSON → Updates metadata
- **App integration**: `OCRProcessor` reads `.ocr_results/` for search

### Platform Specifics

Yiana has **separate iOS and macOS** implementations, not cross-platform abstractions:

- **iOS/iPadOS**: UIDocument, UIKit wrappers (PDFView via UIViewRepresentable)
- **macOS**: NSDocument, AppKit (PDFView via NSViewRepresentable)
- **Shared**: DocumentMetadata format, .yianazip package structure

## Core Workflows (15 minutes)

### Creating a Document

1. User taps "New Document" → `DocumentListView`
2. Enters title (required) → `DocumentListViewModel.createDocument()`
3. `DocumentRepository.createNewDocument()` → Creates `NoteDocument`
4. `NoteDocument.save()` → Writes `.yianazip` to iCloud Drive

**Code path**: `DocumentListView.swift` → `DocumentListViewModel.swift` → `DocumentRepository.swift` → `NoteDocument.swift`

### Scanning Pages

1. User taps scan button → `DocumentEditView` → `ScannerView`
2. VisionKit's `VNDocumentCameraViewController` (automatic edge detection)
3. Captured images → `ScanningService.convertToPDF()`
4. `DocumentViewModel.appendScannedPages()` → Appends to existing PDF
5. `NoteDocument.save()` → Updates `.yianazip`

**Code path**: `DocumentEditView.swift` → `ScannerView.swift` → `ScanningService.swift` → `DocumentViewModel.swift`

### Creating Text Pages

1. User taps "Text" scan button → `TextPageEditorView`
2. Types markdown → `TextPageEditorViewModel` schedules live render
3. `TextPagePDFRenderer` converts markdown → PDF
4. `ProvisionalPageManager` combines saved PDF + draft (in-memory)
5. Preview shown in `PDFViewer` with "DRAFT" indicator
6. User taps "Done" → Finalized, draft appended to document

**Code path**: `TextPageEditorView.swift` → `TextPageEditorViewModel.swift` → `TextPagePDFRenderer.swift` → `ProvisionalPageManager.swift` → `DocumentViewModel.swift`

### Search

1. User types search term → `DocumentListView`
2. `DocumentListViewModel.performSearch()` → Searches titles + OCR text
3. `OCRProcessor.getOCRResults()` → Reads `.ocr_results/` JSON
4. Results with page numbers (1-based) → Display in list
5. User taps result → Navigate to document + page

**Code path**: `DocumentListView.swift` → `DocumentListViewModel.swift` → `OCRProcessor.swift`

## Development Workflow (10 minutes)

### Test-Driven Development (TDD) Mandate

**ALWAYS follow TDD**:

1. Write failing test first (`YianaTests/`)
2. Implement minimal code to make test pass
3. Refactor while keeping tests green
4. Commit after each test/implementation pair

Example:
```bash
# 1. Write test
# YianaTests/DocumentRepositoryTests.swift
func testCreateNewDocument() { ... }

# 2. Run test (fails)
xcodebuild test -scheme Yiana ...

# 3. Implement feature
# Yiana/Services/DocumentRepository.swift
func createNewDocument() { ... }

# 4. Run test (passes)
xcodebuild test -scheme Yiana ...

# 5. Commit
git add .
git commit -m "Add document creation with title validation"
```

### Coding Style

**Key principles**:
- 1-based page indexing (except PDFKit boundaries)
- Use wrapper extensions for external APIs
- Avoid state mutation during SwiftUI view updates
- Platform-specific code is preferred over cross-platform abstractions

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
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'

# Run all macOS tests
xcodebuild test -scheme Yiana -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentRepositoryTests/testCreateNewDocument
```

## Common Tasks (10 minutes)

### Adding a New Feature

1. **Check PLAN.md or Roadmap** - Is it planned?
2. **Write ADR** (if architectural) - `docs/decisions/`
3. **Write tests first** (TDD)
4. **Implement feature**
5. **Update documentation** - Feature docs, API reference
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

### Building for Device

1. Connect iPhone/iPad via USB
2. Select device in Xcode (top-left)
3. Xcode may prompt to register device with Apple Developer account
4. Press **⌘R** to build and run

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
3. [`Architecture.md`](Architecture.md) - System architecture
4. [`docs/decisions/`](../decisions/) - Key architectural decisions (ADRs)

**Feature-specific** (as needed):

5. [`docs/dev/features/TextPages.md`](features/TextPages.md) - Text page editor
6. [`SearchArchitecture.md`](SearchArchitecture.md) - Search implementation
7. [`Importing.md`](Importing.md) - PDF import flows

**Diagrams** (visual overview):

8. [`docs/diagrams/system-architecture.md`](diagrams/system-architecture.md)
9. [`docs/diagrams/data-flow.md`](diagrams/data-flow.md)
10. [`docs/diagrams/pdf-rendering-pipeline.md`](diagrams/pdf-rendering-pipeline.md)

## Troubleshooting

### Build Errors

**Issue**: "Unable to load contents of file list"
- **Fix**: Clean build folder (`⌘⇧K`), then rebuild

**Issue**: "No such module 'PDFKit'"
- **Fix**: Verify target is set to iOS/macOS (not watchOS/tvOS)

**Issue**: Code signing error
- **Fix**: Update provisioning profiles in Xcode → Signing & Capabilities

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
- ✅ Build and run Yiana on simulator and device
- ✅ Run tests and verify they pass
- ✅ Navigate the codebase structure
- ✅ Understand core workflows (document creation, scanning, text pages, search)
- ✅ Follow TDD workflow
- ✅ Commit changes following project conventions

**Ready to contribute?** See:
- [`Contributing.md`](Contributing.md) - Contribution guidelines and PR process
- [`CodeReview.md`](CodeReview.md) - Code review checklist
- [`Roadmap.md`](Roadmap.md) - Current priorities and planned features

## Getting Help

- **Documentation**: Check `docs/` directory first
- **Issues**: Search GitHub issues for known problems
- **Code Review**: Create draft PR and ask for feedback
- **Architecture**: Review ADRs in `docs/decisions/`

**Welcome to the Yiana project! 🎉**
