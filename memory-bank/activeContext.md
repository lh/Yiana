# Active Context

## Current State
- ✅ Xcode project created with multiplatform support
- ✅ Git repository initialized and pushed to GitHub
- ✅ Project builds successfully
- ✅ Memory-bank structure created
- ⚠️ Project currently uses Core Data (needs to be replaced with UIDocument)

## What We're Doing Now
Following PLAN.md Phase 1 - Project Structure & Core Models:
- ✅ Created folder structure (Models, ViewModels, Views, Services, Utilities, Tests)
- ✅ Created DocumentMetadataTests.swift with comprehensive tests
- ✅ Implemented DocumentMetadata struct - all tests passing!
- 🔄 Next: Create NoteDocumentTests for UIDocument subclass

## Next Immediate Steps
1. Write failing tests for NoteDocument (UIDocument subclass)
2. Implement NoteDocument to make tests pass
3. Continue with removing Core Data in Phase 2

## Important Context
- The app is called "Yiana" (Yiana is another notes app)
- Focus on document scanning and PDF management
- Mac mini will handle OCR processing (not on-device)
- Must maintain iOS/iPadOS/macOS compatibility
- Document packages will use `.yianazip` extension (not `.notedoc`)