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
**Problem:** The app uses 1-based indexing everywhere except PDFKit (0-based). Current plan uses 0-based indices in Set<Int>.

**Resolution:**
```swift
// CRITICAL: Convert between UI (1-based) and PDFKit (0-based)
struct PageManagementView {
    @State private var selectedPages: Set<Int>  // 1-based for UI

    private func copySelectedPages() {
        // Convert to 0-based for PDFKit operations
        let zeroBasedIndices = selectedPages.map { $0 - 1 }
        viewModel.copyPages(at: Set(zeroBasedIndices))
    }
}
```

#### Issue 2: Provisional Pages Handling
**Problem:** Text pages (provisional pages) cannot be represented as PDFPage objects.

**Resolution:**
```swift
extension DocumentViewModel {
    func copyPages(at indices: Set<Int>) -> Bool {
        // Filter out provisional pages
        let validIndices = indices.filter { index in
            // Check if page at index is a real PDF page
            if let provisionalManager = self.provisionalPageManager {
                return !provisionalManager.isProvisionalPage(at: index - 1) // Convert to 0-based
            }
            return true
        }

        guard !validIndices.isEmpty else {
            // Show error: "Text pages cannot be copied. Please save them first."
            return false
        }

        // Continue with valid indices only
        return PageClipboard.shared.copyPages(
            from: pdfData,
            indices: validIndices,
            documentID: documentID
        )
    }
}
```

#### Issue 3: Thread Safety & Race Conditions
**Problem:** Cut operation removal could race with document saves.

**Resolution:**
```swift
class PageClipboard {
    // Add operation tracking
    private var activeCutOperation: CutOperation?

    struct CutOperation {
        let id: UUID
        let sourceDocumentID: UUID
        let pageIndices: Set<Int>  // Store original indices
        let timestamp: Date
        var isCompleted: Bool = false
    }

    func markCutAsCompleted(operationID: UUID) -> Set<Int>? {
        queue.sync {
            guard let operation = activeCutOperation,
                  operation.id == operationID,
                  !operation.isCompleted else {
                return nil
            }

            activeCutOperation?.isCompleted = true
            return operation.pageIndices
        }
    }
}
```

### 🟡 Important Issues (Should Address)

#### Issue 4: iCloud Sync Conflicts
**Problem:** Document might be modified on another device during cut/paste.

**Resolution:**
```swift
extension DocumentViewModel {
    func pastePages(at insertIndex: Int? = nil) async throws -> Int {
        // Check for conflicts before paste
        if document.hasConflicts {
            throw PageOperationError.documentHasConflicts
        }

        // Disable iCloud sync temporarily for large operations
        if let payload = PageClipboard.shared.retrievePayload(),
           payload.pageCount > 50 {
            document.isAutoSavingEnabled = false
            defer { document.isAutoSavingEnabled = true }
        }

        // ... perform paste operation ...
    }
}
```

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
                          documentID: UUID) async -> Bool {
        guard indices.count <= PageOperationLimits.hardLimit else {
            // Reject operation
            return false
        }

        if indices.count > PageOperationLimits.warningThreshold {
            // Process in chunks
            return await processInChunks(indices: indices, chunkSize: PageOperationLimits.chunkSize)
        }

        // Regular processing for small operations
        return copyPages(from: pdfData, indices: indices, documentID: documentID)
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
    let version: Int = 1  // Add version field
    let id: UUID
    // ... other fields ...

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1

        switch version {
        case 1:
            // Current decoding
            self.version = version
            self.id = try container.decode(UUID.self, forKey: .id)
            // ...
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported clipboard format version: \(version)"
                )
            )
        }
    }
}
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
- [ ] Create PageClipboardPayload.swift with versioning
- [ ] Implement PageClipboard.swift with thread safety
- [ ] Add index conversion utilities
- [ ] Write basic unit tests
- [ ] Test pasteboard integration on both platforms

### Phase 2: ViewModel Integration
- [ ] Add copyPages method with provisional page filtering
- [ ] Add cutPages method with operation tracking
- [ ] Add pastePages method with conflict detection
- [ ] Implement chunk processing for large operations
- [ ] Add notification handling for cut completion

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
final class PageClipboard {
    /// Singleton instance
    static let shared: PageClipboard

    /// Copy pages from a document to clipboard
    /// - Parameters:
    ///   - pdfData: Source PDF data
    ///   - indices: Set of 0-based page indices to copy
    ///   - documentID: Source document UUID
    /// - Returns: Success status
    func copyPages(from pdfData: Data?, indices: Set<Int>, documentID: UUID) -> Bool

    /// Cut pages from a document (deferred removal)
    /// - Parameters:
    ///   - pdfData: Source PDF data
    ///   - indices: Set of 0-based page indices to cut
    ///   - documentID: Source document UUID
    /// - Returns: Success status
    func cutPages(from pdfData: Data?, indices: Set<Int>, documentID: UUID) -> Bool

    /// Retrieve the current clipboard payload
    /// - Returns: PageClipboardPayload if available and valid
    func retrievePayload() -> PageClipboardPayload?

    /// Check if clipboard contains pages
    var hasPages: Bool { get }

    /// Mark a cut operation as completed
    /// - Parameter operationID: The operation UUID
    /// - Returns: Original page indices if operation is valid
    func markCutAsCompleted(operationID: UUID) -> Set<Int>?

    /// Clear clipboard if it contains a cut from the specified document
    /// - Parameter documentID: Document UUID to check
    func clearIfCut(documentID: UUID)

    /// Clear all clipboard data
    func clear()
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