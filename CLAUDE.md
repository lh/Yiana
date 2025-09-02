# Yiana - Project Context for Claude

## CORE RULES (MUST FOLLOW)
1. **ALWAYS USE SERENA MCP TOOLS for code exploration and editing** - Use mcp__serena__ tools instead of basic Read/Edit
2. **Development must follow TDD (Test-Driven Development) methodology**
3. **All implementation must strictly follow the steps outlined in PLAN.md**
4. **Primary tech stack is [SwiftUI, UIDocument, PDFKit, VisionKit]. Do not introduce other libraries unless specified in the plan**
5. **Every code change must be small, focused, and verifiable**
6. **Update memory-bank/activeContext.md after each significant change**
7. **Commit to git regularly - after each significant feature or fix is completed and tested**
8. **Keep commits clean - no emojis, minimal "Co-authored-by" attributions**

## Project Overview
Yiana (Yiana is another notes app) - A document scanning and PDF management app for iOS/iPadOS/macOS.

## Architecture Decisions
- **Document Storage**: UIDocument with iCloud sync (NOT Core Data)
- **Package Format**: `.yianazip` containing PDF + metadata.json
- **PDF Handling**: PDFKit for read-only viewing (no annotations to avoid memory issues)
- **Scanning**: VisionKit for document capture
- **OCR Processing**: Handled by Mac mini server, NOT on device
- **Multiplatform Strategy**: iOS/iPadOS and macOS apps share data format but NOT implementation. Each platform uses its native document class (UIDocument vs NSDocument) directly. No shared protocols or complex abstractions needed.

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