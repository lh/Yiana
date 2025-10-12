# Copy/Cut/Paste Pages Between Documents - Implementation Plan
**Date:** 2025-10-12
**Feature Request:** Enable copying/cutting pages from one document and pasting into another

---

## Use Case

**User Story:**
> "I can select one or several page(s) in the sorter (PageManagementView), copy or cut, and then paste into a new document via its sorter."

**Workflow:**
1. User opens Document A's page sorter
2. Selects one or more pages
3. Taps "Copy" or "Cut" button
4. Opens Document B's page sorter
5. Taps "Paste" button
6. Selected pages appear in Document B (and removed from Document A if cut)

---

## Analysis: Can This Be Done Without Major Refactor?

**Answer: YES ✅**

The existing architecture supports this feature cleanly:

### What We Have (Architecture Strengths):

1. **PDFPage Copying Already Works**
   - `PDFPage.copy()` is used extensively in the codebase
   - Found in: DocumentViewModel.swift:236, TextPageRenderService.swift:77, ProvisionalPageManager.swift:70
   - Pages can be copied and inserted into different PDFDocuments

2. **Page Selection Infrastructure Exists**
   - `selectedPages: Set<Int>` tracks selected page indices
   - Selection mode toggles between navigation and edit mode
   - Works on both iOS and macOS

3. **Pasteboard APIs Available**
   - iOS: `UIPasteboard.general`
   - macOS: `NSPasteboard.general`
   - Currently used for text copying (DocumentInfoPanel.swift:162-163)

4. **Clean Document Architecture**
   - Each document is independent (UIDocument/NSDocument)
   - No shared state between documents
   - Changes are saved atomically via `pdfData` binding

### What We Need to Add:

1. **Pasteboard Page Serialization**
   - Serialize PDFPage(s) to Data for clipboard
   - Deserialize from clipboard back to PDFPage(s)

2. **Copy/Cut/Paste UI Buttons**
   - Add toolbar buttons in PageManagementView
   - Enable/disable based on selection and clipboard state

3. **Pasteboard Manager Service**
   - Handle cross-document page transfer
   - Track cut vs copy state
   - Clean up clipboard on app lifecycle events

---

## Implementation Approach

### Approach 1: PDF Data Serialization (RECOMMENDED ✅)

**How it works:**
- Serialize selected PDFPages by creating a temporary PDFDocument containing only those pages
- Store the resulting PDF data on the pasteboard
- When pasting, read PDF data and extract pages

**Advantages:**
- Uses standard PDF format (portable, well-tested)
- No custom serialization needed
- Works with existing PDFDocument/PDFPage APIs
- Preserves all page content (text, images, annotations)
- Could potentially paste from other apps in the future

**Implementation:**
```swift
// Copy pages to clipboard
let tempDoc = PDFDocument()
for index in selectedPageIndices.sorted() {
    if let page = pages[index].copy() as? PDFPage {
        tempDoc.insert(page, at: tempDoc.pageCount)
    }
}
if let pdfData = tempDoc.dataRepresentation() {
    #if os(iOS)
    UIPasteboard.general.setData(pdfData, forPasteboardType: "com.adobe.pdf")
    #else
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setData(pdfData, forType: .pdf)
    #endif
}

// Paste pages from clipboard
#if os(iOS)
if let pdfData = UIPasteboard.general.data(forPasteboardType: "com.adobe.pdf"),
   let sourceDoc = PDFDocument(data: pdfData) {
    for i in 0..<sourceDoc.pageCount {
        if let page = sourceDoc.page(at: i),
           let copy = page.copy() as? PDFPage {
            pages.insert(copy, at: insertIndex + i)
        }
    }
    saveChanges()
}
#else
if let pdfData = NSPasteboard.general.data(forType: .pdf),
   let sourceDoc = PDFDocument(data: pdfData) {
    // Same as iOS
}
#endif
```

### Approach 2: Custom UTI with Metadata (Alternative)

**How it works:**
- Create custom pasteboard type (e.g., "com.vitygas.yiana.pages")
- Store both PDF data AND metadata (page numbers, source document ID, cut vs copy)

**Advantages:**
- Can track cut vs copy state
- Can prevent pasting back into same document after cut
- Could add more metadata (thumbnails, page titles, etc.)

**Disadvantages:**
- More complex
- Requires custom serialization/deserialization
- Not shareable with other apps

**Verdict:** Approach 1 is simpler and sufficient. We can track cut state separately.

---

## Detailed Implementation Plan

### Phase 1: Pasteboard Service

**Create:** `Yiana/Yiana/Services/PagePasteboardManager.swift`

```swift
import PDFKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Manages copying, cutting, and pasting PDF pages via system pasteboard
class PagePasteboardManager {
    static let shared = PagePasteboardManager()

    private init() {}

    enum PasteboardType {
        case copy
        case cut(documentID: UUID)
    }

    // Track whether last operation was cut (for UI feedback)
    private(set) var lastOperation: PasteboardType?

    /// Copy selected pages to clipboard
    func copyPages(_ pages: [PDFPage]) -> Bool {
        guard !pages.isEmpty else { return false }

        let tempDoc = PDFDocument()
        for (index, page) in pages.enumerated() {
            if let pageCopy = page.copy() as? PDFPage {
                tempDoc.insert(pageCopy, at: index)
            }
        }

        guard let pdfData = tempDoc.dataRepresentation() else {
            return false
        }

        #if os(iOS)
        UIPasteboard.general.setData(pdfData, forPasteboardType: "com.adobe.pdf")
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(pdfData, forType: .pdf)
        #endif

        lastOperation = .copy
        return true
    }

    /// Cut selected pages (same as copy, but tracks cut state)
    func cutPages(_ pages: [PDFPage], from documentID: UUID) -> Bool {
        let result = copyPages(pages)
        if result {
            lastOperation = .cut(documentID: documentID)
        }
        return result
    }

    /// Check if clipboard has PDF page data
    func hasPagesInClipboard() -> Bool {
        #if os(iOS)
        return UIPasteboard.general.contains(pasteboardTypes: ["com.adobe.pdf"])
        #else
        return NSPasteboard.general.availableType(from: [.pdf]) != nil
        #endif
    }

    /// Retrieve pages from clipboard
    func retrievePages() -> [PDFPage]? {
        let pdfData: Data?

        #if os(iOS)
        pdfData = UIPasteboard.general.data(forPasteboardType: "com.adobe.pdf")
        #else
        pdfData = NSPasteboard.general.data(forType: .pdf)
        #endif

        guard let data = pdfData,
              let sourceDoc = PDFDocument(data: data) else {
            return nil
        }

        var pages: [PDFPage] = []
        for i in 0..<sourceDoc.pageCount {
            if let page = sourceDoc.page(at: i),
               let pageCopy = page.copy() as? PDFPage {
                pages.append(pageCopy)
            }
        }

        return pages.isEmpty ? nil : pages
    }

    /// Clear clipboard (call after cut operation completes)
    func clearClipboard() {
        #if os(iOS)
        UIPasteboard.general.items = []
        #else
        NSPasteboard.general.clearContents()
        #endif
        lastOperation = nil
    }

    /// Check if last operation was cut from specific document
    func wasCutFrom(documentID: UUID) -> Bool {
        if case .cut(let cutDocumentID) = lastOperation {
            return cutDocumentID == documentID
        }
        return false
    }
}
```

### Phase 2: Update PageManagementView

**Modify:** `Yiana/Yiana/Views/PageManagementView.swift`

**Changes needed:**

1. **Add state variables:**
```swift
@State private var showPasteButton = false
@State private var cutInProgress = false  // Track if we did a cut
private let pasteboardManager = PagePasteboardManager.shared
```

2. **Add toolbar buttons:**
```swift
ToolbarItemGroup {
    if !selectedPages.isEmpty {
        Button {
            copySelectedPages()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        Button {
            cutSelectedPages()
        } label: {
            Label("Cut", systemImage: "scissors")
        }
    }

    if pasteboardManager.hasPagesInClipboard() {
        Button {
            pastePages()
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
    }
}
```

3. **Add methods:**
```swift
private func copySelectedPages() {
    let pagesToCopy = selectedPages.sorted().compactMap { index in
        index < pages.count ? pages[index] : nil
    }

    if pasteboardManager.copyPages(pagesToCopy) {
        // Optional: Show toast or brief feedback
        selectedPages.removeAll()
        isEditMode = false
    }
}

private func cutSelectedPages() {
    let pagesToCut = selectedPages.sorted().compactMap { index in
        index < pages.count ? pages[index] : nil
    }

    // Get document ID from parent (need to pass this in as binding)
    // For now, use a temporary UUID (will fix in integration)
    if pasteboardManager.cutPages(pagesToCut, from: UUID()) {
        cutInProgress = true
        // Don't remove pages yet - wait for paste elsewhere
        selectedPages.removeAll()
        isEditMode = false
    }
}

private func pastePages() {
    guard let pagesToPaste = pasteboardManager.retrievePages() else {
        return
    }

    // Insert at end for now (can make this configurable later)
    let insertIndex = pages.count

    for (offset, page) in pagesToPaste.enumerated() {
        if let pageCopy = page.copy() as? PDFPage {
            pages.insert(pageCopy, at: insertIndex + offset)
        }
    }

    saveChanges()

    // If this was a cut operation, we need to tell the source document to delete
    // For MVP, we'll just clear the clipboard
    // TODO: Implement cross-document cut coordination
    pasteboardManager.clearClipboard()
}
```

4. **Update onAppear to check clipboard:**
```swift
.onAppear {
    loadPages()
    showPasteButton = pasteboardManager.hasPagesInClipboard()
}
```

### Phase 3: Handle Cut Operations

**Challenge:** When pages are cut from Document A and pasted into Document B, we need to remove them from Document A.

**Two implementation options:**

#### Option A: Optimistic Cut (RECOMMENDED for MVP)

- Cut operation marks pages as "pending removal"
- Pages stay in Document A until paste happens
- When paste completes, Document A's PageManagementView checks if it was the cut source
- If yes, automatically removes the cut pages

**Implementation:**
- Add notification when paste completes
- PageManagementView listens for paste notification
- If it was the cut source, remove the originally selected pages

#### Option B: Immediate Cut

- Cut operation immediately removes pages from Document A
- Pages stored in clipboard
- If user doesn't paste (or cancels), pages are lost
- More dangerous UX

**Verdict:** Option A is safer for MVP

### Phase 4: Pass Document ID

**Modify PageManagementView initializer to accept document ID:**

```swift
struct PageManagementView: View {
    @Binding var pdfData: Data?
    @Binding var isPresented: Bool
    var documentID: UUID  // ADD THIS
    var currentPageIndex: Int = 0
    // ... rest of properties
```

**Update callers to pass document ID:**
- DocumentViewModel needs to track and pass its document ID
- This already exists in `metadata.id`

---

## Testing Plan

### Unit Tests
1. **PagePasteboardManager Tests**
   - Test copying single page
   - Test copying multiple pages
   - Test cut operation tracking
   - Test clipboard state checking
   - Test retrieving pages from clipboard
   - Test clearing clipboard

2. **PageManagementView Tests**
   - Test copy button appears when pages selected
   - Test paste button appears when clipboard has data
   - Test cut button appears when pages selected
   - Test paste inserts pages correctly

### Integration Tests
1. **Cross-Document Copy**
   - Open Document A
   - Select and copy pages
   - Open Document B
   - Paste pages
   - Verify pages appear in Document B
   - Verify Document A unchanged

2. **Cross-Document Cut**
   - Open Document A, select and cut pages
   - Open Document B, paste pages
   - Verify pages appear in Document B
   - Verify pages removed from Document A (manual verification for MVP)

3. **Edge Cases**
   - Copy/paste within same document
   - Cut/paste within same document
   - Multiple copy operations (clipboard overwrite)
   - App backgrounding with clipboard data

---

## Risks & Mitigations

### Risk 1: Large Page Counts
**Problem:** Copying 100+ pages might use too much memory

**Mitigation:**
- Add warning if > 50 pages selected
- Consider chunking or streaming for very large operations
- Monitor memory usage in testing

### Risk 2: Cut Without Paste
**Problem:** User cuts pages but never pastes (loses data)

**Mitigation:**
- Option A implementation keeps pages in source until paste
- Add "Restore Cut Pages" option if clipboard still has data

### Risk 3: Clipboard Interference
**Problem:** Other apps or operations overwrite clipboard

**Mitigation:**
- Check clipboard validity before showing paste button
- Handle gracefully if clipboard data is invalid
- Use `.onChange` to detect clipboard changes

### Risk 4: OCR Metadata Loss
**Problem:** Copied pages lose their OCR text

**Mitigation:**
- OCR is document-level, not page-level
- Pasted pages will need re-OCR in destination document
- This is acceptable (OCR service will detect and process)
- Document in user guide

---

## Implementation Estimate

### Time Breakdown:
1. **PagePasteboardManager service:** 2-3 hours
2. **PageManagementView updates:** 2-3 hours
3. **Document ID plumbing:** 1 hour
4. **Testing & debugging:** 3-4 hours
5. **Edge case handling:** 2 hours

**Total: 10-13 hours** (1.5-2 days)

### Complexity: **MEDIUM** 🟡

**Why not HIGH:**
- Existing architecture supports it well
- PDFPage copying already works
- No database or sync changes needed
- Pasteboard APIs are straightforward

**Why not LOW:**
- Cross-document coordination needed
- Cut operation state tracking
- UI updates across views
- Testing cross-document behavior

---

## MVP Feature Set

**Phase 1 (Minimal Viable):**
- ✅ Copy selected pages to clipboard
- ✅ Paste pages from clipboard (at end of document)
- ✅ Visual feedback (buttons appear/disappear)
- ✅ Works between documents

**Phase 2 (Enhanced):**
- Cut pages (with optimistic removal)
- Paste at specific insertion point (not just end)
- Keyboard shortcuts (Cmd+C, Cmd+V on macOS)
- Undo support

**Phase 3 (Polish):**
- Visual feedback during paste (progress indicator)
- Drag-and-drop between document windows (macOS)
- Page count indicator in paste button
- Warnings for large page counts

---

## Alternative Considered: Drag & Drop Between Documents

**Why not implemented:**
- Requires multiple document windows open simultaneously
- More complex on iOS (split-screen coordination)
- Copy/paste is more universal and familiar
- Can add later as enhancement

---

## Recommendation

**Proceed with Approach 1 (PDF Data Serialization) for MVP**

**Reasons:**
1. Clean implementation using existing APIs
2. No major refactoring required
3. Works with existing document architecture
4. Reasonable implementation time (1.5-2 days)
5. Natural UX (copy/paste familiar to users)

**Next Steps:**
1. Create PagePasteboardManager service
2. Update PageManagementView with copy/paste buttons
3. Add document ID passing
4. Test cross-document operations
5. Handle edge cases (large selections, clipboard clearing)

---

**Status:** Ready to implement
**Estimated Time:** 10-13 hours
**Risk Level:** Medium
**Architecture Impact:** Minimal (additive only)
