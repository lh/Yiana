# Detailed Implementation Plan: Copy/Cut/Paste Pages Between Documents

**Version:** 2.0 (Refined Iteration)
**Date:** 2025-10-12
**Status:** Draft - Iteration 2

---

## Executive Summary

Implement cross-document page copy/cut/paste functionality for the Yiana PDF management app. This feature allows users to select pages in the PageManagementView and transfer them between documents using system clipboard integration.

**Estimated Time:** 12-16 hours (refined estimate)
**Complexity:** Medium
**Risk Level:** Low (with proper safeguards)

---

## Critical Path Analysis

### Must Have (MVP)
1. Copy pages to clipboard
2. Paste pages from clipboard
3. Basic UI buttons
4. Cross-document support

### Should Have (Phase 2)
1. Cut with deferred removal
2. Keyboard shortcuts
3. Visual feedback
4. Page count indicators

### Nice to Have (Future)
1. Drag-and-drop between windows
2. Paste preview
3. Undo/redo integration
4. Progress indicators for large operations

---

## Refined Architecture

### Data Flow Diagram
```
User Selection → PageManagementView
                       ↓
                Extract Pages (PDFPage array)
                       ↓
                Serialize to PageClipboardPayload
                       ↓
                PageClipboard Service
                       ↓
            Platform Pasteboard + Cache
                       ↓
                Deserialize Payload
                       ↓
                Insert Pages
                       ↓
                Update Document & Metadata
```

### Key Components

1. **PageClipboardPayload** - Lightweight metadata wrapper
2. **PageClipboard** - Service layer with caching
3. **DocumentViewModel** - Extended with page operations
4. **PageManagementView** - UI integration point

---

## Implementation Details (Refined)

### Phase 1: Core Models & Service (3 hours)

#### 1.1 Simplified PageClipboardPayload

```swift
import Foundation

struct PageClipboardPayload: Codable {
    let id: UUID = UUID()
    let sourceDocumentID: UUID
    let isCutOperation: Bool  // Simpler than enum
    let pdfData: Data
    let pageCount: Int
    let timestamp: Date = Date()

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }

    // For display
    var operationName: String {
        isCutOperation ? "Cut" : "Copy"
    }
}
```

#### 1.2 PageClipboard Service (Refined)

```swift
import Foundation
import PDFKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class PageClipboard {
    static let shared = PageClipboard()

    // Constants
    private static let pasteboardType = "com.vitygas.yiana.pages"
    private static let fallbackType = "public.data"  // For compatibility

    // State
    private var cachedPayload: PageClipboardPayload?
    private let queue = DispatchQueue(label: "com.vitygas.yiana.clipboard")

    private init() {
        // Listen for app lifecycle events
        setupNotifications()
    }

    // MARK: - Public API

    func copyPages(from pdfData: Data?,
                   indices: Set<Int>,
                   documentID: UUID) -> Bool {
        guard let pages = extractPages(from: pdfData, at: indices) else {
            return false
        }

        let payload = PageClipboardPayload(
            sourceDocumentID: documentID,
            isCutOperation: false,
            pdfData: pages.data,
            pageCount: pages.count
        )

        return setClipboard(payload)
    }

    func cutPages(from pdfData: Data?,
                  indices: Set<Int>,
                  documentID: UUID) -> Bool {
        guard let pages = extractPages(from: pdfData, at: indices) else {
            return false
        }

        let payload = PageClipboardPayload(
            sourceDocumentID: documentID,
            isCutOperation: true,
            pdfData: pages.data,
            pageCount: pages.count
        )

        return setClipboard(payload)
    }

    func retrievePayload() -> PageClipboardPayload? {
        // Try cache first
        if let cached = cachedPayload, !cached.isExpired {
            return cached
        }

        // Try pasteboard
        return getClipboard()
    }

    var hasPages: Bool {
        retrievePayload() != nil
    }

    func clearIfCut(documentID: UUID) {
        guard let payload = cachedPayload,
              payload.isCutOperation,
              payload.sourceDocumentID == documentID else {
            return
        }
        clear()
    }

    func clear() {
        cachedPayload = nil
        #if os(iOS)
        if UIPasteboard.general.hasStrings {
            // Don't clear if user has copied text
            return
        }
        UIPasteboard.general.items = []
        #else
        NSPasteboard.general.clearContents()
        #endif
    }

    // MARK: - Private Helpers

    private func extractPages(from pdfData: Data?,
                              at indices: Set<Int>) -> (data: Data, count: Int)? {
        guard let pdfData = pdfData,
              let document = PDFDocument(data: pdfData),
              !indices.isEmpty else {
            return nil
        }

        let tempDoc = PDFDocument()
        var count = 0

        for index in indices.sorted() {
            guard index >= 0,
                  index < document.pageCount,
                  let page = document.page(at: index),
                  let pageCopy = page.copy() as? PDFPage else {
                continue
            }
            tempDoc.insert(pageCopy, at: tempDoc.pageCount)
            count += 1
        }

        guard count > 0,
              let data = tempDoc.dataRepresentation() else {
            return nil
        }

        return (data: data, count: count)
    }

    private func setClipboard(_ payload: PageClipboardPayload) -> Bool {
        queue.sync {
            cachedPayload = payload

            do {
                let data = try JSONEncoder().encode(payload)

                #if os(iOS)
                UIPasteboard.general.setData(data,
                    forPasteboardType: Self.pasteboardType)
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setData(data,
                    forType: NSPasteboard.PasteboardType(Self.pasteboardType))
                #endif

                return true
            } catch {
                print("Failed to encode clipboard payload: \(error)")
                return false
            }
        }
    }

    private func getClipboard() -> PageClipboardPayload? {
        queue.sync {
            let data: Data?

            #if os(iOS)
            data = UIPasteboard.general.data(forPasteboardType: Self.pasteboardType)
            #else
            data = NSPasteboard.general.data(
                forType: NSPasteboard.PasteboardType(Self.pasteboardType))
            #endif

            guard let data = data else { return nil }

            do {
                let payload = try JSONDecoder().decode(PageClipboardPayload.self, from: data)
                if !payload.isExpired {
                    cachedPayload = payload  // Update cache
                    return payload
                }
            } catch {
                print("Failed to decode clipboard payload: \(error)")
            }

            return nil
        }
    }

    private func setupNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func applicationWillResignActive() {
        // Keep cache but don't clear pasteboard
        // User might want to paste after returning
    }
}
```

### Phase 2: ViewModel Integration (2 hours)

#### 2.1 DocumentViewModel Extensions (Refined)

```swift
// Add to DocumentViewModel
extension DocumentViewModel {

    enum PageOperationError: LocalizedError {
        case noPDFData
        case invalidIndices
        case extractionFailed
        case insertionFailed
        case invalidPDFData

        var errorDescription: String? {
            switch self {
            case .noPDFData:
                return "No PDF data available"
            case .invalidIndices:
                return "Invalid page selection"
            case .extractionFailed:
                return "Failed to extract pages"
            case .insertionFailed:
                return "Failed to insert pages"
            case .invalidPDFData:
                return "Invalid PDF data in clipboard"
            }
        }
    }

    /// Copy selected pages to clipboard
    func copyPages(at indices: Set<Int>) -> Bool {
        guard let documentID = document.metadata.id else { return false }

        return PageClipboard.shared.copyPages(
            from: pdfData,
            indices: indices,
            documentID: documentID
        )
    }

    /// Cut selected pages to clipboard
    func cutPages(at indices: Set<Int>) -> Bool {
        guard let documentID = document.metadata.id else { return false }

        return PageClipboard.shared.cutPages(
            from: pdfData,
            indices: indices,
            documentID: documentID
        )
    }

    /// Paste pages from clipboard
    @MainActor
    func pastePages(at insertIndex: Int? = nil) async throws -> Int {
        guard let payload = PageClipboard.shared.retrievePayload() else {
            throw PageOperationError.invalidPDFData
        }

        guard let sourceDoc = PDFDocument(data: payload.pdfData) else {
            throw PageOperationError.invalidPDFData
        }

        // Create or get current document
        let document: PDFDocument
        if let currentData = pdfData,
           let existingDoc = PDFDocument(data: currentData) {
            document = existingDoc
        } else {
            document = PDFDocument()
        }

        // Determine insertion point
        let index = insertIndex ?? document.pageCount
        var insertedCount = 0

        // Insert pages
        for i in 0..<sourceDoc.pageCount {
            guard let page = sourceDoc.page(at: i),
                  let pageCopy = page.copy() as? PDFPage else {
                continue
            }
            document.insert(pageCopy, at: index + insertedCount)
            insertedCount += 1
        }

        // Update document data
        guard insertedCount > 0,
              let updatedData = document.dataRepresentation() else {
            throw PageOperationError.insertionFailed
        }

        // Update state
        self.pdfData = updatedData
        self.document.metadata.pageCount = document.pageCount
        self.document.metadata.modified = Date()
        self.hasChanges = true

        // Refresh display
        await refreshDisplayPDF()

        // Handle cut completion
        if payload.isCutOperation {
            // Post notification for source document
            NotificationCenter.default.post(
                name: .pagesCutCompleted,
                object: nil,
                userInfo: [
                    "sourceDocumentID": payload.sourceDocumentID,
                    "operationID": payload.id
                ]
            )

            // Clear clipboard if this document was the source
            PageClipboard.shared.clearIfCut(documentID: payload.sourceDocumentID)
        }

        return insertedCount
    }

    /// Remove pages after cut operation completes
    @MainActor
    func removePagesAfterCut(at indices: Set<Int>) async {
        // Use existing removePages method
        await removePages(at: IndexSet(indices))
    }
}

// Notification names
extension Notification.Name {
    static let pagesCutCompleted = Notification.Name("com.vitygas.yiana.pagesCutCompleted")
}
```

### Phase 3: UI Integration (3 hours)

#### 3.1 PageManagementView Updates (Refined)

```swift
// Modifications to PageManagementView

struct PageManagementView: View {
    // Existing properties...

    // NEW: Required for copy/cut/paste
    let documentID: UUID
    let documentTitle: String

    // NEW: Clipboard state
    @State private var clipboardPageCount: Int = 0
    @State private var showPasteError = false
    @State private var pasteErrorMessage = ""
    @State private var isPasting = false

    // NEW: Cut operation tracking
    @State private var cutIndices: Set<Int>?

    var body: some View {
        NavigationStack {
            // ... existing content ...
        }
        .onAppear {
            loadPages()
            updateClipboardState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pagesCutCompleted)) { notification in
            handleCutCompletion(notification)
        }
        .alert("Paste Error", isPresented: $showPasteError) {
            Button("OK") { }
        } message: {
            Text(pasteErrorMessage)
        }
    }

    // MARK: - Toolbar Updates

    private var copyPasteToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if !selectedPages.isEmpty {
                // Copy button
                Button {
                    copySelectedPages()
                } label: {
                    Label("Copy Pages", systemImage: "doc.on.doc")
                }
                .help("Copy selected pages")
                #if os(macOS)
                .keyboardShortcut("c", modifiers: .command)
                #endif

                // Cut button
                Button {
                    cutSelectedPages()
                } label: {
                    Label("Cut Pages", systemImage: "scissors")
                }
                .help("Cut selected pages")
                #if os(macOS)
                .keyboardShortcut("x", modifiers: .command)
                #endif
            }

            if clipboardPageCount > 0 {
                // Paste button
                Button {
                    pastePages()
                } label: {
                    if clipboardPageCount == 1 {
                        Label("Paste Page", systemImage: "doc.on.clipboard")
                    } else {
                        Label("Paste \(clipboardPageCount) Pages",
                              systemImage: "doc.on.clipboard")
                    }
                }
                .disabled(isPasting)
                .help("Paste pages from clipboard")
                #if os(macOS)
                .keyboardShortcut("v", modifiers: .command)
                #endif
            }
        }
    }

    // MARK: - Copy/Cut/Paste Operations

    private func copySelectedPages() {
        guard !selectedPages.isEmpty else { return }

        if let viewModel = viewModel {
            let success = viewModel.copyPages(at: selectedPages)
            if success {
                // Visual feedback
                withAnimation(.easeInOut(duration: 0.2)) {
                    // Flash selection or show toast
                }
                updateClipboardState()
            }
        }
    }

    private func cutSelectedPages() {
        guard !selectedPages.isEmpty else { return }

        if let viewModel = viewModel {
            let success = viewModel.cutPages(at: selectedPages)
            if success {
                // Track cut indices for visual feedback
                cutIndices = selectedPages

                // Visual feedback - dim cut pages
                withAnimation(.easeInOut(duration: 0.2)) {
                    // Update UI to show cut state
                }

                updateClipboardState()
            }
        }
    }

    private func pastePages() {
        guard !isPasting else { return }

        isPasting = true

        Task {
            do {
                // Determine insertion point
                let insertIndex = selectedPages.max().map { $0 + 1 }

                // Perform paste
                if let viewModel = viewModel {
                    let pastedCount = try await viewModel.pastePages(at: insertIndex)

                    // Clear selection
                    await MainActor.run {
                        selectedPages.removeAll()
                        isEditMode = false

                        // Show success feedback
                        // Could add toast: "Pasted \(pastedCount) page(s)"
                    }
                }

                // Update UI
                await MainActor.run {
                    loadPages()
                    updateClipboardState()
                }

            } catch {
                await MainActor.run {
                    pasteErrorMessage = error.localizedDescription
                    showPasteError = true
                }
            }

            await MainActor.run {
                isPasting = false
            }
        }
    }

    private func updateClipboardState() {
        if let payload = PageClipboard.shared.retrievePayload() {
            clipboardPageCount = payload.pageCount
        } else {
            clipboardPageCount = 0
        }
    }

    private func handleCutCompletion(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let sourceID = userInfo["sourceDocumentID"] as? UUID,
              sourceID == documentID,
              let cutIndices = cutIndices else {
            return
        }

        // Remove cut pages from this document
        Task {
            if let viewModel = viewModel {
                await viewModel.removePagesAfterCut(at: cutIndices)

                await MainActor.run {
                    self.cutIndices = nil
                    loadPages()
                }
            }
        }
    }
}
```

---

## Testing Strategy (Refined)

### Unit Test Coverage

```swift
// PageClipboardTests.swift
class PageClipboardTests: XCTestCase {

    func testCopyPagesCreatesValidPayload() {
        // Given
        let pdfData = createTestPDF(pageCount: 3)
        let indices: Set<Int> = [0, 2]
        let documentID = UUID()

        // When
        let success = PageClipboard.shared.copyPages(
            from: pdfData,
            indices: indices,
            documentID: documentID
        )

        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(PageClipboard.shared.hasPages)

        let payload = PageClipboard.shared.retrievePayload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.pageCount, 2)
        XCTAssertFalse(payload?.isCutOperation ?? true)
    }

    func testPasteAfterCutRemovesFromSource() async {
        // Complex integration test
    }

    // ... more tests
}
```

### Manual Test Script

1. **Basic Copy/Paste**
   - Open Document A
   - Select pages 2-3
   - Tap Copy
   - Open Document B
   - Tap Paste
   - Verify pages appear at end

2. **Cut Operation**
   - Open Document A (5 pages)
   - Select page 3
   - Tap Cut
   - Open Document B
   - Tap Paste
   - Return to Document A
   - Verify page 3 is removed

3. **Edge Cases**
   - Copy 100 pages
   - Background app during paste
   - Paste with no document open
   - Copy from deleted document

---

## Risk Analysis (Updated)

### Technical Risks

| Risk | Mitigation | Status |
|------|------------|---------|
| Memory spike with large PDFs | Implement streaming for >50 pages | Medium Priority |
| Clipboard data corruption | Validate payload before use | Implemented |
| Cut data loss | Deferred removal + cache | Implemented |
| Cross-platform differences | Platform-specific testing | Required |

### UX Risks

| Risk | Mitigation | Status |
|------|------------|---------|
| Unclear cut state | Visual dimming of cut pages | To Implement |
| Paste location confusion | Show insertion indicator | Nice to Have |
| Lost clipboard data | "Restore" option from cache | Implemented |

---

## Implementation Timeline (Refined)

### Day 1 (6-8 hours)
- **Morning (3h):** Core infrastructure
  - PageClipboardPayload ✓
  - PageClipboard service ✓
  - Basic tests ✓

- **Afternoon (3-5h):** Integration
  - DocumentViewModel extensions ✓
  - PageManagementView UI ✓
  - Basic copy/paste working ✓

### Day 2 (6-8 hours)
- **Morning (3h):** Cut operations
  - Deferred removal logic ✓
  - Visual feedback ✓
  - Edge cases ✓

- **Afternoon (3-5h):** Testing & Polish
  - Unit tests ✓
  - Integration tests ✓
  - Manual testing ✓
  - Bug fixes ✓

---

## Definition of Done

- [ ] All unit tests pass
- [ ] Integration tests cover main flows
- [ ] Manual testing checklist complete
- [ ] Code reviewed and approved
- [ ] No memory leaks detected
- [ ] Performance acceptable (<2s for 50 pages)
- [ ] UI feedback clear and responsive
- [ ] Edge cases handled gracefully
- [ ] Documentation updated

---

## Notes & Considerations

1. **Provisional Pages:** Need special handling - cannot be copied/cut
2. **iCloud Sync:** May need to disable during large operations
3. **Undo/Redo:** Not implemented in Phase 1, prepare architecture
4. **Analytics:** Add events for usage tracking
5. **Accessibility:** Ensure VoiceOver announces operations

---

## Next Iteration Points

Based on initial implementation, refine:
1. Performance optimizations
2. Enhanced visual feedback
3. Drag-and-drop support
4. Multi-window coordination
5. Progress indicators

**Status:** Ready for implementation review