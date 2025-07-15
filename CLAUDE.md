# Yiana - Project Context for Claude

## CORE RULES (MUST FOLLOW)
1. **Development must follow TDD (Test-Driven Development) methodology**
2. **All implementation must strictly follow the steps outlined in PLAN.md**
3. **Primary tech stack is [SwiftUI, UIDocument, PDFKit, VisionKit]. Do not introduce other libraries unless specified in the plan**
4. **Every code change must be small, focused, and verifiable**
5. **Update memory-bank/activeContext.md after each significant change**

## Project Overview
Yiana (Yiana is another notes app) - A document scanning and PDF management app for iOS/iPadOS/macOS.

## Architecture Decisions
- **Document Storage**: UIDocument with iCloud sync (NOT Core Data)
- **Package Format**: `.yianazip` containing PDF + metadata.json
- **PDF Handling**: PDFKit for read-only viewing (no annotations to avoid memory issues)
- **Scanning**: VisionKit for document capture
- **OCR Processing**: Handled by Mac mini server, NOT on device

## Key Implementation Notes
- The Xcode project was created with Core Data but we need to replace it with UIDocument
- Multiplatform app targeting iOS, iPadOS, and macOS
- Bundle ID: com.vitygas.Yiana

## Current Status
- ✅ Xcode project created and building
- ✅ GitHub repository: https://github.com/lh/Yiana
- 🔄 Next: Implement UIDocument architecture

## Testing Commands
```bash
# Run tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for all platforms
xcodebuild -scheme Yiana -destination 'generic/platform=iOS'
xcodebuild -scheme Yiana -destination 'platform=macOS'
```

## Important Files & Locations
- Spec: /Users/rose/Downloads/ios-note-app-spec.md
- Project: /Users/rose/Code/Yiana/

## Design Principles
1. LEGO approach - use proven Apple frameworks
2. Simplicity over feature bloat
3. Read-only PDF viewing (no annotations)
4. Mac mini handles heavy processing (OCR)