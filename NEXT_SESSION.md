# Next Session Tasks - Yiana Project

## Immediate Priority: Debug Test Execution Hang

### Current State
- All compilation errors have been fixed (commit 963bd7c)
- Build succeeds for iOS target
- Test execution hangs indefinitely when running full suite
- Individual test classes (e.g., DocumentMetadataTests) run successfully in isolation

### Debugging Steps Required
1. Identify which test class(es) cause the hang by running each individually:
   - DocumentMetadataTests ✅ (confirmed working)
   - NoteDocumentTests
   - DocumentRepositoryTests
   - DocumentListViewModelTests
   - DocumentViewModelTests
   - ImportServiceTests
   - ScanningServiceTests
   - BackupManagerTests
   - PDFFlattenerTests
   - OCRSearchTests
   - Others...

2. Once hanging test(s) identified:
   - Check for async/await deadlocks
   - Look for UI tests that might be waiting for simulator interaction
   - Check for file system operations that might be blocking
   - Review any network or iCloud operations that could timeout

3. Fix the hanging tests and verify full suite runs

## Secondary Priority: Improve PDF Markup System

### Current State
- Basic macOS PDF markup system implemented but "crude" (per git history)
- Non-functional implementation merged in commit 61e69de
- Multiple markup-related files and proposals exist in project

### Required Improvements
1. Review current implementation in:
   - Yiana/Yiana/Markup/ directory
   - Yiana/Yiana/Views/MacPDFMarkupView.swift
   - Related ViewModels and Services

2. Identify specific deficiencies in current implementation

3. Refine markup functionality based on existing proposals:
   - MARKUP-SOLUTION-PROPOSAL.md
   - MARKUP_IMPLEMENTATION_PLAN.md
   - gemini-markup-solution-proposal.md
   - gpt-markup-solution-proposal.md

## Technical Context
- Serena MCP tools are now configured and working
- Project follows TDD methodology
- Must maintain iOS/macOS compatibility
- 1-based page indexing convention throughout
- No Core Data - using UIDocument/NSDocument architecture

## Build/Test Commands
```bash
# Build
xcodebuild build -project Yiana.xcodeproj -scheme Yiana -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16'

# Test individual class (replace TestClassName)
xcodebuild test -project Yiana.xcodeproj -scheme Yiana -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16' -only-testing:YianaTests/TestClassName

# Full test suite (currently hangs)
xcodebuild test -project Yiana.xcodeproj -scheme Yiana -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16'
```

## Notes
- Tests must actually pass before claiming success
- Maintain technical precision and accuracy in all communications
- Follow CLAUDE.md guidelines for using Serena MCP tools