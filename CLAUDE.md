# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CORE RULES (MUST FOLLOW)
1. **ALWAYS USE SERENA MCP TOOLS for code exploration and editing** - Use mcp__serena__ tools instead of basic Read/Edit
2. **Development must follow TDD (Test-Driven Development) methodology**
3. **All implementation must strictly follow the steps outlined in PLAN.md**
4. **Primary tech stack is [SwiftUI, UIDocument, PDFKit, VisionKit]. Additional dependencies require justification (see Dependency Management below)**
5. **Every code change must be small, focused, and verifiable**
6. **Update memory-bank/activeContext.md after each significant change**
7. **Commit to git regularly - after each significant feature or fix is completed and tested. Testing includes always asking for user feedback before claiming success**
8. **Keep commits clean - no emojis, no attributions**
9. **Follow dependency management philosophy (see below)**
10. **Keep code clean - remove any attributions you come accross and do not add any new attributions**

## Dependency Management Philosophy

### When TO Add Dependencies ✅
- **Complex subsystems** - Databases, networking protocols, file format parsers
- **Bug prevention** - Libraries that eliminate entire classes of errors (memory safety, type safety)
- **Time savings** - When development/debugging time exceeds integration effort by 10x+
- **Maturity** - Well-maintained projects with 5+ years of production use
- **Safety-critical** - C interop, concurrency, cryptography where errors have serious consequences

### When NOT to Add Dependencies ❌
- **Trivial features** - Anything implementable in <50 lines of straightforward code
- **Duplicate functionality** - Features already provided by Apple frameworks
- **Unmaintained projects** - Libraries without updates in 2+ years or single-maintainer projects
- **Vendor lock-in** - Libraries that make future migration difficult
- **Feature bloat** - Heavy frameworks when only 10% of features are needed

### Approved Dependencies
- **GRDB.swift** (v7.7+) - Type-safe SQLite wrapper; prevents C interop bugs, ~10 years production use
## SERENA TOOLS USAGE (MANDATORY)
**ALWAYS use Serena MCP tools for this project:**
- `mcp__serena__get_symbols_overview` - First look at any code file
- `mcp__serena__find_symbol` - Find functions/classes
- `mcp__serena__search_for_pattern` - Search code
- `mcp__serena__list_dir` - Explore directories
- `mcp__serena__replace_symbol_body` - Replace entire functions
- `mcp__serena__insert_before_symbol` / `insert_after_symbol` - Add code
- `mcp__serena__write_memory` / `read_memory` - Track project state
- Only use basic Read/Edit for non-code files or tiny edits

## Project Overview

Yiana is a document scanning and PDF management app for iOS/iPadOS/macOS. It stores documents as `.yianazip` packages (metadata JSON + PDF data), syncs via iCloud Drive, and offloads OCR processing to a Mac mini backend service.

## Build & Test Commands

```bash
# Run tests (iOS)
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests (macOS)
xcodebuild test -scheme Yiana -destination 'platform=macOS'

# Build app for iOS
xcodebuild -scheme Yiana -destination 'generic/platform=iOS'

# Build app for macOS
xcodebuild -scheme Yiana -destination 'platform=macOS'

# Build OCR service
cd YianaOCRService && swift build

# Run OCR service
cd YianaOCRService && swift run yiana-ocr --help

# Python tools setup
cd AddressExtractor && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

## Architecture & Key Decisions

### Document Storage Architecture
- **UIDocument-based** (iOS/iPadOS) and **NSDocument-based** (macOS) - NOT Core Data
- Documents stored in iCloud container: `iCloud.com.vitygas.Yiana/Documents`
- Package format: `.yianazip` with structure: `[metadata JSON][0xFF 0xFF 0xFF 0xFF separator][raw PDF bytes]`
- Bundle ID: com.vitygas.Yiana

### Platform Strategy
- iOS/iPadOS and macOS share data format but NOT implementation
- Each platform uses native document classes directly (UIDocument vs NSDocument)
- No shared protocols or complex abstractions - platform-specific code is preferred

### PDF Handling
- **PDFKit** for read-only viewing (no annotations to avoid memory issues)
- **1-based page indexing** everywhere in the app (convert only at PDFKit API boundaries)
- Wrapper extensions in `Extensions/PDFDocument+PageIndexing.swift` handle conversions

### OCR Processing
- OCR handled by `YianaOCRService` (Mac mini backend), NOT on device
- Service watches documents folder and processes PDFs with `ocrCompleted = false`
- Results stored in `.ocr_results/` as JSON/XML/hOCR

## Repository Structure

```
Yiana/                  # SwiftUI app (iOS/iPadOS/macOS)
├── Models/            # DocumentMetadata, NoteDocument (UIDocument)
├── ViewModels/        # DocumentListViewModel, DocumentViewModel
├── Views/             # SwiftUI views (DocumentListView, PDFViewer, etc.)
├── Services/          # DocumentRepository, ImportService, ScanningService
├── Extensions/        # PDFDocument+PageIndexing, other wrappers
└── Tests/             # Unit and UI tests

YianaOCRService/       # Swift Package executable for OCR processing
AddressExtractor/      # Python utilities for data processing
docs/                  # Technical documentation
memory-bank/           # Project state tracking
```

## Development Workflow

### TDD (Test-Driven Development) Required
1. Write failing tests first in `Tests/` folder
2. Implement minimal code to make tests pass
3. Refactor while keeping tests green
4. Commit after each test/implementation pair

### State Management Patterns
- Avoid modifying state during SwiftUI view updates (use `DispatchQueue.main.async`)
- Use `@State` sparingly - prefer bindings and coordinator patterns
- Let PDFKit manage its own state

### Error Prevention
- Always use 1-based page numbers except at PDFKit boundaries
- Check for OCR JSON existence before reading
- Use atomic writes for `.yianazip` files to ensure iCloud sync signals

## Current Implementation Status

### Completed (✅)
- Basic project structure and Xcode configuration
- Document models (DocumentMetadata, NoteDocument)
- Document repository with iCloud support
- PDF viewing with 1-based page indexing
- Import system (new documents and append to existing)
- OCR service foundation
- Search functionality with OCR text
- GitHub repository: https://github.com/lh/Yiana

### In Progress (🔄)
- PDF markup/annotation system for macOS
- Backup and restore system
- Implementing UIDocument architecture (replacing Core Data)

### Planned (📋)
See `PLAN.md` for detailed implementation phases

## Code Style & Conventions

### Page Numbering (CRITICAL)
- **Always 1-based** in UI, metadata, OCR JSON, search results
- Use wrapper methods: `pdfDocument.getPage(number: 1)` not `pdfDocument.page(at: 0)`
- Document with comments like `// 1-based page number`

### Platform-Specific Code
```swift
#if os(iOS)
    // iOS-specific implementation
#elseif os(macOS)
    // macOS-specific implementation
#endif
```

### OCR JSON Structure
```json
{
  "pages": [
    {
      "pageNumber": 1,  // Always 1-based
      "text": "...",
      "textBlocks": [...]
    }
  ]
}
```

## Common Issues & Solutions

### "Modifying state during view update"
- Move state changes to `.task` or `.onAppear`
- Use `DispatchQueue.main.async` for deferred updates

### Page Navigation Issues
- Verify 1-based indexing throughout
- Check wrapper method usage
- Add debug logging: `print("Navigating to page \(pageNum) (1-based)")`

### OCR/Search Issues
- Verify OCR JSON exists in `.ocr_results/`
- Check DocumentNavigationData is passed correctly
- Ensure page numbers match 1-based convention

## Design Principles
1. LEGO approach - use proven Apple frameworks
2. Simplicity over feature bloat
3. Read-only PDF viewing (no annotations)
4. Mac mini handles heavy processing (OCR)

## Important Files & Locations
- Spec: /Users/rose/Downloads/ios-note-app-spec.md
- Project: /Users/rose/Code/Yiana/
- Current plan: PLAN.md
- Coding style: CODING_STYLE.md
- Architecture details: docs/Architecture.md
