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
- 🔄 Writing failing tests for DocumentMetadata struct

## Next Immediate Steps
1. Create DocumentMetadataTests.swift with failing tests
2. Implement DocumentMetadata struct to pass tests
3. Continue with NoteDocument UIDocument subclass

## Important Context
- The app is called "Yiana" (Yiana is another notes app)
- Focus on document scanning and PDF management
- Mac mini will handle OCR processing (not on-device)
- Must maintain iOS/iPadOS/macOS compatibility
- Document packages will use `.yianazip` extension (not `.notedoc`)