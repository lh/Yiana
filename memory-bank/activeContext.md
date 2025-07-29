# Active Context

## Current State
- ✅ Xcode project created with multiplatform support
- ✅ Git repository initialized and pushed to GitHub
- ✅ Project builds successfully
- ✅ Memory-bank structure created
- ✅ Phase 1 of PLAN.md completed!
- ✅ Refactored to protocol-based architecture for better maintainability
- ⚠️ Project currently uses Core Data (needs to be replaced with UIDocument)

## What We're Doing Now
Completed Phase 1 - Project Structure & Core Models:
- ✅ Created folder structure (Models, ViewModels, Views, Services, Utilities, Tests)
- ✅ Created DocumentMetadataTests.swift with comprehensive tests
- ✅ Implemented DocumentMetadata struct - all tests passing!
- ✅ Created NoteDocumentTests.swift with failing tests
- ✅ Implemented simple NoteDocument class extending UIDocument (iOS only)
- ✅ Wrapped NoteDocument in #if os(iOS) for platform-specific compilation
- ✅ Both iOS and macOS targets now build successfully

Completed Phase 2 - Remove Core Data & Setup Document Repository:
- ✅ Removed Core Data references from YianaApp.swift and ContentView.swift
- ✅ Created DocumentRepositoryTests.swift with comprehensive tests
- ✅ Implemented DocumentRepository - simple URL manager for .yianazip files
- ✅ Added integration test between NoteDocument and DocumentRepository
- ✅ Repository provides: list URLs, generate unique URLs, delete files
- ✅ No iCloud yet - just local file management (simpler!)

Completed Phase 3 - ViewModels with TDD:
- ✅ Created DocumentListViewModelTests with comprehensive test coverage
- ✅ Implemented DocumentListViewModel - manages document URLs from repository
- ✅ Created DocumentViewModelTests for single document editing (iOS only)
- ✅ Implemented DocumentViewModel - wraps NoteDocument for UI editing
- ✅ Added auto-save support with debouncing
- ✅ Platform-specific: iOS gets full editing, macOS gets placeholder

Ready for Phase 4 - Basic UI Implementation

## Next Immediate Steps
Phase 2 Tasks:
1. Delete Core Data files (Persistence.swift, Yiana.xcdatamodeld)
2. Remove Core Data references from YianaApp.swift
3. Write failing tests for DocumentRepository
4. Implement DocumentRepository to manage documents in iCloud

## Recent Technical Decisions
- ABANDONED protocol-based architecture after realizing it was overengineered
- Decided to keep iOS and macOS implementations separate
- They will share data format but not code
- Each platform uses native document patterns (UIDocument vs NSDocument)
- Simpler, cleaner, more maintainable

## Important Context
- The app is called "Yiana" (Yiana is another notes app)
- Focus on document scanning and PDF management
- Mac mini will handle OCR processing (not on-device)
- Must maintain iOS/iPadOS/macOS compatibility
- Document packages will use `.yianazip` extension
- Using TDD methodology throughout development