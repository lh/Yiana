# Detailed Implementation Plan: Copy/Cut/Paste Pages Between Documents

**Version:** 1.0
**Date:** 2025-10-12
**Status:** Draft - Iteration 1

---

## Executive Summary

Implement a feature to copy/cut pages from one document's page sorter and paste them into another document. The solution uses a custom payload format with metadata, platform-specific pasteboard APIs, and deferred removal for cut operations to ensure data safety.

**Estimated Time:** 14-18 hours (2-2.5 days)
**Complexity:** Medium
**Risk Level:** Low-Medium (data loss prevention via deferred removal)

---

## Architecture Overview

### Component Diagram
```
┌─────────────────────────────────────────────────┐
│              PageManagementView                  │
│  - Selection UI                                  │
│  - Copy/Cut/Paste Buttons                       │
└──────────────────┬──────────────────────────────┘
                   │
        ┌──────────▼──────────┐
        │   PageClipboard     │
        │   (Shared Service)  │
        │   - Payload Cache   │
        │   - Cut Tracking    │
        └──────────┬──────────┘
                   │
    ┌──────────────┴──────────────┐
    │                             │
┌───▼────────┐          ┌─────────▼────────┐
│UIPasteboard│          │   NSPasteboard   │
│   (iOS)    │          │     (macOS)      │
└────────────┘          └──────────────────┘
```

---

## Phase 1: Core Infrastructure (4-5 hours)

### 1.1 PageClipboardPayload Model

**File:** `Yiana/Yiana/Models/PageClipboardPayload.swift`

```swift
import Foundation

struct PageClipboardPayload: Codable {
    enum Operation: String, Codable {
        case copy
        case cut
    }

    let id: UUID = UUID()  // Unique payload ID
    let sourceDocumentID: UUID?
    let sourceDocumentTitle: String?
    let operation: Operation
    let pdfData: Data
    let pageCount: Int
    let pageNumbers: [Int]?  // Original page numbers for reference
    let createdAt: Date
    let appVersion: String  // For compatibility checking

    // Computed properties
    var isCutOperation: Bool { operation == .cut }
    var isExpired: Bool {
        // Consider payload expired after 1 hour
        Date().timeIntervalSince(createdAt) > 3600
    }
}
```

### 1.2 PageClipboard Service

**File:** `Yiana/Yiana/Services/PageClipboard.swift`

```swift
import Foundation
import PDFKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class PageClipboard {
    static let shared = PageClipboard()

    // Custom UTI
    static let pasteboardType = "com.vitygas.yiana.pages"

    // Cache for recovery
    private var cachedPayload: PageClipboardPayload?
    private var pendingCutPayload: PageClipboardPayload?

    private init() {}

    // Core operations
    func copyPages(_ pages: [PDFPage], from document: DocumentMetadata) -> Bool
    func cutPages(_ pages: [PDFPage], from document: DocumentMetadata) -> Bool
    func retrievePages() -> PageClipboardPayload?
    func clearClipboard()

    // Status checks
    var hasPages: Bool
    var canPaste: Bool
    var hasPendingCut: Bool
    var pendingCutDocumentID: UUID?

    // Recovery
    func restoreCutPages() -> PageClipboardPayload?
    func markCutAsConsumed()
}
```

### 1.3 DocumentViewModel Extensions

**File:** `Yiana/Yiana/ViewModels/DocumentViewModel.swift`

Add these methods to the existing DocumentViewModel:

```swift
extension DocumentViewModel {
    /// Extract selected pages as PDF data
    func extractPages(at indices: [Int]) throws -> (data: Data, pageCount: Int) {
        guard let pdfData = self.pdfData,
              let document = PDFDocument(data: pdfData) else {
            throw PageOperationError.noPDFData
        }

        let tempDoc = PDFDocument()
        var extractedCount = 0

        for index in indices.sorted() {
            guard index >= 0, index < document.pageCount,
                  let page = document.page(at: index),
                  let pageCopy = page.copy() as? PDFPage else {
                continue
            }
            tempDoc.insert(pageCopy, at: tempDoc.pageCount)
            extractedCount += 1
        }

        guard extractedCount > 0,
              let data = tempDoc.dataRepresentation() else {
            throw PageOperationError.extractionFailed
        }

        return (data: data, pageCount: extractedCount)
    }

    /// Insert pages from PDF data
    func insertPages(from data: Data, at insertIndex: Int? = nil) async throws {
        guard let sourceDoc = PDFDocument(data: data) else {
            throw PageOperationError.invalidPDFData
        }

        guard let currentData = self.pdfData,
              let document = PDFDocument(data: currentData) else {
            // If no existing document, use the pasted data directly
            self.pdfData = data
            self.hasChanges = true
            return
        }

        let index = insertIndex ?? document.pageCount

        for i in 0..<sourceDoc.pageCount {
            guard let page = sourceDoc.page(at: i),
                  let pageCopy = page.copy() as? PDFPage else {
                continue
            }
            document.insert(pageCopy, at: index + i)
        }

        guard let updatedData = document.dataRepresentation() else {
            throw PageOperationError.insertionFailed
        }

        self.pdfData = updatedData
        self.document.metadata.pageCount = document.pageCount
        self.document.metadata.modified = Date()
        self.hasChanges = true

        await refreshDisplayPDF()
    }
}
```

---

## Phase 2: UI Integration (3-4 hours)

### 2.1 PageManagementView Updates

**Modifications Required:**

1. **Add document ID property:**
```swift
struct PageManagementView: View {
    @Binding var pdfData: Data?
    @Binding var isPresented: Bool
    var documentID: UUID  // NEW: Pass from parent
    var documentTitle: String  // NEW: For display in paste confirmations
    // ... existing properties
}
```

2. **Add clipboard state:**
```swift
@State private var clipboardHasPages = false
@State private var showPasteConfirmation = false
@State private var pastePageCount = 0
@State private var showCutWarning = false
```

3. **Add toolbar buttons:**
```swift
// In toolbar
ToolbarItemGroup(placement: .automatic) {
    if !selectedPages.isEmpty {
        Button {
            copySelectedPages()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("c", modifiers: .command)

        Button {
            cutSelectedPages()
        } label: {
            Label("Cut", systemImage: "scissors")
        }
        .keyboardShortcut("x", modifiers: .command)
    }

    if clipboardHasPages {
        Button {
            pastePages()
        } label: {
            Label("Paste \(pastePageCount > 0 ? "(\(pastePageCount))" : "")",
                  systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut("v", modifiers: .command)
    }
}
```

### 2.2 DocumentEditView Updates

Pass document ID to PageManagementView:

```swift
PageManagementView(
    pdfData: Binding(...),
    isPresented: Binding(...),
    documentID: document.metadata.id,  // NEW
    documentTitle: document.metadata.title,  // NEW
    currentPageIndex: currentViewedPage,
    // ... other parameters
)
```

---

## Phase 3: Cut Operation Handling (2-3 hours)

### 3.1 Deferred Removal Strategy

```swift
class PageClipboard {
    // Track cut operation state
    private struct CutOperation {
        let payload: PageClipboardPayload
        let pageIndices: [Int]
        var isConsumed: Bool = false
    }

    private var activeCut: CutOperation?

    func performDeferredRemoval(from documentID: UUID) async -> Bool {
        guard let cut = activeCut,
              cut.payload.sourceDocumentID == documentID,
              !cut.isConsumed else {
            return false
        }

        // Notify source document to remove pages
        NotificationCenter.default.post(
            name: .pagesCutCompleted,
            object: nil,
            userInfo: [
                "documentID": documentID,
                "indices": cut.pageIndices
            ]
        )

        activeCut?.isConsumed = true
        return true
    }
}
```

### 3.2 Paste Completion Flow

```swift
// In PageManagementView
func pastePages() {
    guard let payload = PageClipboard.shared.retrievePages() else { return }

    Task {
        do {
            // Insert pages
            let insertIndex = selectedPages.max().map { $0 + 1 }
            try await viewModel.insertPages(from: payload.pdfData, at: insertIndex)

            // If this was a cut, trigger removal from source
            if payload.isCutOperation {
                await PageClipboard.shared.performDeferredRemoval(
                    from: payload.sourceDocumentID
                )
            }

            // Clear selection and update UI
            selectedPages.removeAll()
            saveChanges()

        } catch {
            // Show error alert
        }
    }
}
```

---

## Phase 4: Testing Strategy (3-4 hours)

### 4.1 Unit Tests

**File:** `YianaTests/PageClipboardTests.swift`

```swift
class PageClipboardTests: XCTestCase {
    func testPayloadSerialization()
    func testCopyOperation()
    func testCutOperation()
    func testPasteboardIntegration()
    func testPayloadExpiration()
    func testCutRecovery()
    func testCrossDocumentCoordination()
}
```

### 4.2 Integration Tests

**File:** `YianaTests/PageManagementIntegrationTests.swift`

```swift
class PageManagementIntegrationTests: XCTestCase {
    func testCopyPasteWithinDocument()
    func testCopyPasteBetweenDocuments()
    func testCutPasteWithDeferredRemoval()
    func testLargePageSelection()
    func testClipboardOverwrite()
    func testProvisionalPageHandling()
}
```

### 4.3 Manual Testing Checklist

- [ ] Copy single page, paste in same document
- [ ] Copy multiple pages, paste in different document
- [ ] Cut pages, verify deferred removal
- [ ] Cut pages, don't paste, verify recovery
- [ ] Copy 50+ pages, verify performance
- [ ] Background app with clipboard data
- [ ] Switch between documents rapidly
- [ ] Paste when source document is closed
- [ ] Clipboard interference from other apps
- [ ] Keyboard shortcuts on both platforms

---

## Phase 5: Edge Cases & Error Handling (2 hours)

### 5.1 Error Scenarios

| Scenario | Handling | User Feedback |
|----------|----------|---------------|
| Invalid clipboard data | Graceful failure | "Unable to paste. Clipboard data is invalid." |
| Source document deleted | Allow paste to proceed | Pages paste normally |
| Paste fails (memory) | Rollback changes | "Unable to paste due to memory constraints." |
| Cut without paste | Restore option | "Restore Cut Pages" button |
| Expired payload | Clear clipboard | "Clipboard data has expired." |
| Document save fails | Retry with exponential backoff | "Saving changes..." with retry |

### 5.2 Performance Considerations

```swift
// For large operations
struct PageOperationLimits {
    static let warningThreshold = 50  // Show warning
    static let chunkSize = 25  // Process in chunks
    static let maxPages = 200  // Hard limit
}

func shouldWarnForLargeOperation(pageCount: Int) -> Bool {
    return pageCount > PageOperationLimits.warningThreshold
}
```

### 5.3 Memory Management

```swift
// Monitor memory during operations
class MemoryMonitor {
    static func availableMemory() -> Int64
    static func canHandlePageCount(_ count: Int) -> Bool
    static func suggestedChunkSize(for pageCount: Int) -> Int
}
```

---

## Design Decisions & Rationale

### Decision 1: Custom Payload vs Raw PDF
**Choice:** Custom PageClipboardPayload
**Rationale:**
- Enables metadata tracking (source document, operation type)
- Supports cut operation with deferred removal
- Allows version compatibility checking
- Provides expiration handling

### Decision 2: Cut Operation Safety
**Choice:** Deferred removal (pages remain until paste completes)
**Rationale:**
- Prevents data loss if paste fails
- Allows recovery if user changes mind
- Maintains document integrity during operation
- Provides clear user feedback

### Decision 3: Clipboard Cache
**Choice:** In-memory cache with 1-hour expiration
**Rationale:**
- Enables recovery from clipboard overwrites
- Supports "Restore Cut Pages" feature
- Balances memory usage with usability
- Prevents stale data issues

### Decision 4: Insertion Point
**Choice:** After last selected page or at document end
**Rationale:**
- Intuitive for users
- Consistent with other apps
- Allows precise placement control
- Works with drag-and-drop mental model

---

## Implementation Order

1. **Foundation (Day 1 Morning)**
   - PageClipboardPayload model
   - PageClipboard service skeleton
   - Basic pasteboard integration

2. **Core Logic (Day 1 Afternoon)**
   - DocumentViewModel extensions
   - Page extraction/insertion
   - Metadata updates

3. **UI Integration (Day 1 Evening)**
   - PageManagementView buttons
   - Keyboard shortcuts
   - Visual feedback

4. **Cut Operations (Day 2 Morning)**
   - Deferred removal logic
   - Recovery mechanisms
   - Cross-document coordination

5. **Testing & Polish (Day 2 Afternoon)**
   - Unit tests
   - Integration tests
   - Edge case handling
   - Performance optimization

---

## Open Questions

1. **UI/UX Decisions:**
   - Should we show source document name in paste tooltip?
   - Visual indication for cut pages (dimmed/striped)?
   - Paste position indicator in grid?
   - Undo/redo integration?

2. **Technical Decisions:**
   - Maximum page count for single operation?
   - Chunking strategy for large operations?
   - Background processing for 100+ pages?
   - iCloud sync behavior during operations?

3. **Product Decisions:**
   - Analytics events to track?
   - A/B testing considerations?
   - Feature flag for gradual rollout?
   - Help documentation needed?

---

## Success Metrics

- **Functional:** All test cases pass
- **Performance:** < 2s for 50-page operation
- **Reliability:** No data loss scenarios
- **Usability:** Intuitive without documentation
- **Quality:** < 3 bugs in first week after release

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss during cut | Low | High | Deferred removal + recovery |
| Memory issues with large PDFs | Medium | Medium | Chunking + limits |
| Clipboard conflicts | Low | Low | Custom UTI + validation |
| iCloud sync issues | Low | Medium | Conflict resolution |
| Cross-platform differences | Medium | Low | Platform-specific testing |

---

## Next Steps

1. Review plan with team
2. Address open questions
3. Create feature branch
4. Implement Phase 1
5. Daily progress updates

**Ready to implement:** Pending review and approval