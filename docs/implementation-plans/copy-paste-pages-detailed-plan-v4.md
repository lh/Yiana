# Detailed Implementation Plan: Copy/Cut/Paste Pages Between Documents

**Version:** 3.0 (Issue Resolution & Final Refinement)
**Date:** 2025-10-12
**Status:** Draft - Iteration 3

---

## Executive Summary

Third iteration of the cross-document page copy/cut/paste feature implementation plan, addressing identified issues and undefined areas from previous iterations.

**Estimated Time:** 14-16 hours (adjusted for additional edge cases)
**Complexity:** Medium-High (due to edge cases)
**Risk Level:** Low (with comprehensive safeguards)

---

## Issues Identified & Resolutions

### 🔴 Critical Issues (Must Address)

#### Issue 1: Page Indexing Consistency
**Problem:** We must keep the UI numbering (1-based labels) in sync with the zero-based indices PDFKit expects. The current implementation already stores zero-based indices in `selectedPages`, but the plan mixed conventions.

**Resolution:**
```swift
// Keep the internal set zero-based (matches ForEach enumerated index)
@State private var selectedPages: Set<Int> = []

private func humanReadablePageNumber(for index: Int) -> Int {
    index + 1
}

private func copySelectedPages() {
    guard !selectedPages.isEmpty else { return }
    Task { try await viewModel.copyPages(atZeroBasedIndices: selectedPages) }
}
```
Only convert to 1-based when presenting labels (`pageNumber: index + 1`). View model APIs accept zero-based indices, mirroring the existing `removePages`/`duplicatePages` behaviour.

#### Issue 2: Provisional Pages Handling
**Problem:** Draft text pages only exist in `provisionalPageRange` and do not map to real `PDFPage` objects. Copying them would produce empty output.

**Resolution:**
```swift
// Inside PageManagementView
private func canCopy(index: Int) -> Bool {
    if let provisionalRange = provisionalPageRange {
        return !provisionalRange.contains(index)
    }
    return true
}

private func copySelectedPages() {
    let drawableIndices = selectedPages.filter(canCopy)
    guard !drawableIndices.isEmpty else {
        presentAlert("Save text pages before copying.")
        return
    }
    Task { try await viewModel.copyPages(atZeroBasedIndices: Set(drawableIndices)) }
}
```
We reuse the combined data the view already knows about (`provisionalPageRange`) instead of poking into `ProvisionalPageManager`, keeping the actor encapsulated.

#### Issue 3: Thread Safety & Race Conditions
**Problem:** The plan assumed multi-threaded access, but `DocumentViewModel` is `@MainActor`. We only need to ensure clipboard mutations happen on the main actor to match document edits.

**Resolution:**
```swift
@MainActor
final class PageClipboard {
    private var activeCut: CutPayload?

    struct CutPayload {
        let id: UUID
        let sourceDocumentID: UUID
        let sourceDataBeforeCut: Data
        let extractedPagesData: Data
        let selectedIndices: [Int]
    }

    func storeCut(_ payload: CutPayload) {
        activeCut = payload
        writeToPasteboard(payload)
    }

    func consumeCutIfNeeded(for documentID: UUID) -> CutPayload? {
        guard activeCut?.sourceDocumentID == documentID else { return nil }
        defer { activeCut = nil }
        return activeCut
    }
}
```
All clipboard operations run on the main actor; no extra queues needed. We retain the source data so cuts can be rolled back if paste never occurs.

### 🟡 Important Issues (Should Address)

#### Issue 4: iCloud Sync Conflicts
**Problem:** A document could be in conflict (`UIDocument` `.inConflict` state) when we try to paste.

**Resolution:**
```swift
extension DocumentViewModel {
    func ensureDocumentIsAvailable() throws {
        if document.documentState.contains(.inConflict) {
            throw PageOperationError.documentInConflict
        }
        if document.documentState.contains(.closed) {
            throw PageOperationError.documentClosed
        }
    }

    func pastePages(from data: Data, at insertIndex: Int?) async throws {
        try ensureDocumentIsAvailable()
        // proceed with insertion...
    }
}
```
We rely on the existing `NoteDocument` state flags rather than inventing new properties. For long operations we can temporarily suspend autosave by batching edits inside `UIDocument.performAsynchronousFileAccess` if needed.

#### Issue 5: Memory Management for Large Operations
**Problem:** Loading 100+ pages into memory could cause crashes.

**Resolution:**
```swift
struct PageOperationLimits {
    static let warningThreshold = 50
    static let hardLimit = 200
    static let chunkSize = 25
}

extension PageClipboard {
    func copyPagesChunked(from pdfData: Data?,
                          indices: Set<Int>,
                          documentID: UUID) throws -> PageClipboardPayload {
        guard indices.count <= PageOperationLimits.hardLimit else {
            throw PageOperationError.selectionTooLarge
        }

        guard let pdfData, let source = PDFDocument(data: pdfData) else {
            throw PageOperationError.sourceDocumentUnavailable
        }

        let orderedIndices = indices.sorted()
        let tempDoc = PDFDocument()

        for chunk in orderedIndices.chunked(into: PageOperationLimits.chunkSize) {
            autoreleasepool {
                for index in chunk {
                    guard let page = source.page(at: index),
                          let copy = page.copy() as? PDFPage else { continue }
                    tempDoc.insert(copy, at: tempDoc.pageCount)
                }
            }
        }

        guard let data = tempDoc.dataRepresentation() else {
            throw PageOperationError.unableToSerialise
        }

        return PageClipboardPayload(
            sourceDocumentID: documentID,
            operation: .copy,
            pageCount: orderedIndices.count,
            pdfData: data
        )
    }
}
```

#### Issue 6: Visual Feedback for Cut Pages
**Problem:** Users need clear indication which pages are "cut" (pending removal).

**Resolution:**
```swift
struct PageManagementView {
    @State private var cutPageIndices: Set<Int>?  // Pages marked for cut

    private var pageGridItem: some View {
        ForEach(pages.indices, id: \.self) { index in
            PageThumbnailView(page: pages[index])
                .opacity(cutPageIndices?.contains(index + 1) == true ? 0.5 : 1.0)
                .overlay(
                    // Striped overlay for cut pages
                    cutPageIndices?.contains(index + 1) == true ?
                    StripedOverlay() : nil
                )
        }
    }
}

struct StripedOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let stripeWidth: CGFloat = 10
                for i in stride(from: 0, to: geometry.size.width + geometry.size.height, by: stripeWidth * 2) {
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i - geometry.size.height, y: geometry.size.height))
                }
            }
            .stroke(Color.red.opacity(0.3), lineWidth: stripeWidth)
        }
    }
}
```

### 🟢 Minor Issues (Nice to Have)

#### Issue 7: Paste Position Indicator
**Problem:** Users don't know where pages will be inserted.

**Resolution:**
```swift
struct PageManagementView {
    @State private var showPasteIndicator = false
    @State private var pasteIndicatorPosition: Int?

    private func showPastePreview() {
        if let maxSelected = selectedPages.max() {
            pasteIndicatorPosition = maxSelected + 1
            withAnimation {
                showPasteIndicator = true
            }
        }
    }
}
```

#### Issue 8: Clipboard Format Versioning
**Problem:** Future changes to PageClipboardPayload might break compatibility.

**Resolution:**
```swift
struct PageClipboardPayload: Codable {
    enum Operation: String, Codable { case copy, cut }

    let version: Int
    let id: UUID
    let sourceDocumentID: UUID?
    let operation: Operation
    let pageCount: Int
    let pdfData: Data
    let createdAt: Date

    init(version: Int = 1,
         id: UUID = UUID(),
         sourceDocumentID: UUID?,
         operation: Operation,
         pageCount: Int,
         pdfData: Data,
         createdAt: Date = Date()) {
        self.version = version
        self.id = id
        self.sourceDocumentID = sourceDocumentID
        self.operation = operation
        self.pageCount = pageCount
        self.pdfData = pdfData
        self.createdAt = createdAt
    }
}

enum PageOperationError: Error {
    case documentInConflict
    case documentClosed
    case selectionTooLarge
    case sourceDocumentUnavailable
    case unableToSerialise
    case provisionalPagesNotSupported
}

## Core Architecture Decisions

- Internal selection indices remain zero-based; labels add `+1` at render time.
- `PageClipboardPayload` encapsulates raw PDF data plus operation metadata.
- `PageClipboard` is a main-actor singleton responsible for persisting payloads to the system pasteboard and providing a fallback cache for cut recovery.
- `DocumentViewModel` exposes focused APIs that return/consume payloads:

```swift
extension DocumentViewModel {
    func copyPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload
    func cutPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload
    func insertPages(from payload: PageClipboardPayload, at insertIndex: Int?) async throws -> Int
}
```

- Provisional (draft) pages are excluded by checking `provisionalPageRange` in the view layer; the view presents an alert if the selection only contains drafts.
```

---

## Complete Test Coverage Plan

### Unit Tests Required

```swift
// PageClipboardTests.swift
class PageClipboardTests: XCTestCase {
    // Core functionality
    func testCopyPagesWithValidData()
    func testCopyPagesWithEmptySelection()
    func testCopyPagesWithInvalidIndices()
    func testCutPagesTracksOperation()
    func testPayloadSerialization()
    func testPayloadExpiration()

    // Edge cases
    func testCopyProvisionalPages()  // Should filter them out
    func testLargePageCount()  // Test with 100+ pages
    func testClipboardPersistenceAcrossAppLaunch()
    func testConcurrentOperations()

    // Platform specific
    #if os(iOS)
    func testUIPasteboardIntegration()
    #else
    func testNSPasteboardIntegration()
    #endif
}

// DocumentViewModelTests.swift
class DocumentViewModelPageOperationsTests: XCTestCase {
    func testExtractPagesWithValidIndices()
    func testInsertPagesAtSpecificIndex()
    func testInsertPagesIntoEmptyDocument()
    func testPageIndexingConversion()  // 1-based to 0-based
    func testConflictDetection()
    func testMetadataUpdatesAfterPaste()
}

// Integration Tests
class PageCopyPasteIntegrationTests: XCTestCase {
    @MainActor
    func testCompleteCopyPasteFlow() async
    @MainActor
    func testCompleteCutPasteFlow() async
    @MainActor
    func testCutWithoutPasteRecovery() async
    @MainActor
    func testCrossPlatformClipboard() async  // iOS to macOS
}
```

### UI Tests Required

```swift
// PageManagementUITests.swift
class PageManagementUITests: XCTestCase {
    func testCopyButtonAppearsWithSelection()
    func testPasteButtonAppearsWhenClipboardHasData()
    func testCutPagesVisualFeedback()
    func testKeyboardShortcuts()  // macOS only
    func testAccessibilityAnnouncements()
}
```

---

## Implementation Checklist

### Pre-Implementation
- [x] Review existing PageManagementView implementation
- [x] Understand 1-based vs 0-based indexing convention
- [x] Check provisional page handling
- [ ] Verify iCloud sync behavior during operations
- [ ] Test memory usage with large PDFs

### Phase 1: Core Infrastructure
- [ ] Add `PageClipboardPayload` (versioned, codable)
- [ ] Implement `PageClipboard` (main-actor singleton)
- [ ] Set up pasteboard bridge (macOS + iOS UTI registration)
- [ ] Write baseline unit tests for clipboard persistence
- [ ] Verify payload survives app restart (in-memory + system pasteboard)

### Phase 2: ViewModel Integration
- [ ] Add `copyPages(atZeroBasedIndices:)` returning payload
- [ ] Add `cutPages(atZeroBasedIndices:)` storing pre-cut backup
- [ ] Add `insertPages(from:payload, at:)` with conflict checks
- [ ] Integrate chunk processing helper for large selections
- [ ] Emit notifications/hooks for UI updates after cut/paste

### Phase 3: UI Implementation
- [ ] Pass documentID and title to PageManagementView
- [ ] Add copy/cut/paste buttons with proper state management
- [ ] Implement visual feedback for cut pages
- [ ] Add paste position indicator
- [ ] Implement keyboard shortcuts (macOS)
- [ ] Add accessibility labels and announcements

### Phase 4: Testing & Edge Cases
- [ ] Test with 1, 10, 50, 100, 200 pages
- [ ] Test provisional page filtering
- [ ] Test cut operation recovery
- [ ] Test cross-platform clipboard
- [ ] Test memory usage under pressure
- [ ] Test iCloud sync conflicts
- [ ] Test with corrupted clipboard data

### Phase 5: Polish & Documentation
- [ ] Add user-facing error messages
- [ ] Implement progress indicators for large operations
- [ ] Add analytics events
- [ ] Update user documentation
- [ ] Code review and cleanup

---

## API Documentation

### PageClipboard Service

```swift
/// Manages page copy/cut/paste operations across documents
@MainActor
final class PageClipboard {
    static let shared = PageClipboard()

    /// Persist payload in memory and to the system pasteboard
    func setPayload(_ payload: PageClipboardPayload)

    /// Retrieve the currently stored payload if it is still valid
    func currentPayload() -> PageClipboardPayload?

    /// Remove any stored payload (memory + pasteboard)
    func clear()

    /// Returns true when the clipboard currently holds page data
    var hasPayload: Bool { get }

    /// Specific helper for cut operations (optional restore path)
    func activeCutPayload() -> PageClipboardPayload?
    func consumeActiveCut() -> PageClipboardPayload?
}
```

---

## Performance Benchmarks

### Target Performance Metrics

| Operation | Page Count | Target Time | Memory Peak |
|-----------|------------|-------------|-------------|
| Copy | 1-10 | < 0.5s | < 10MB |
| Copy | 11-50 | < 2s | < 50MB |
| Copy | 51-100 | < 5s | < 100MB |
| Paste | 1-10 | < 1s | < 20MB |
| Paste | 11-50 | < 3s | < 60MB |
| Paste | 51-100 | < 8s | < 120MB |

### Memory Management Strategy

1. **Autoreleasepool for loops:**
```swift
for index in indices.sorted() {
    autoreleasepool {
        // Page operations
    }
}
```

2. **Chunk processing for large operations:**
```swift
if indices.count > PageOperationLimits.warningThreshold {
    for chunk in indices.chunked(into: PageOperationLimits.chunkSize) {
        autoreleasepool {
            // Process chunk
        }
    }
}
```

3. **Immediate cleanup:**
```swift
defer {
    // Clear temporary resources
    tempDoc = nil
}
```

---

## Security & Privacy Considerations

1. **Clipboard Data Exposure:**
   - PDF data is exposed to system clipboard
   - Other apps could potentially read it
   - Consider encrypting sensitive documents

2. **Data Validation:**
   - Always validate clipboard data before use
   - Check PDF structure integrity
   - Verify payload version compatibility

3. **Resource Limits:**
   - Enforce maximum page count (200)
   - Prevent memory exhaustion attacks
   - Rate limit operations

---

## Rollback Plan

If critical issues are discovered post-deployment:

1. **Feature Flag:** Can disable via remote config
2. **Fallback:** Hide UI buttons but preserve data
3. **Recovery:** Cached payloads can be recovered
4. **Revert:** Clean revert points at each phase

---

## Success Criteria

### Functional Requirements
- ✅ Users can copy pages between documents
- ✅ Users can cut pages with deferred removal
- ✅ Operations work across app restarts
- ✅ Provisional pages are handled correctly
- ✅ 1-based indexing is maintained in UI

### Non-Functional Requirements
- ✅ Operations complete within performance targets
- ✅ Memory usage stays within limits
- ✅ No data loss scenarios
- ✅ Thread-safe implementation
- ✅ Accessible to VoiceOver users

### Quality Metrics
- ✅ 90%+ code coverage in tests
- ✅ 0 critical bugs in first week
- ✅ <5 total bugs reported
- ✅ User satisfaction >4.0/5.0

---

## Final Notes

This third iteration addresses all identified issues:

1. **Page indexing** - Clear conversion strategy between 1-based (UI) and 0-based (PDFKit)
2. **Provisional pages** - Filtered out with user feedback
3. **Thread safety** - Queue-based synchronization with operation tracking
4. **iCloud conflicts** - Detection and handling
5. **Memory management** - Chunking and limits
6. **Visual feedback** - Cut page indicators
7. **Compatibility** - Versioned payload format
8. **Testing** - Comprehensive test coverage plan

The implementation is now well-defined with clear solutions for all edge cases.

**Status:** Ready for final review and implementation
