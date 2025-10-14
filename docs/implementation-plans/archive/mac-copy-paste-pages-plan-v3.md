# macOS Copy/Cut/Paste Support Plan v3

**Status:** Ready for implementation
**Estimated Time:** 6-7 hours
**Priority:** High - Feature parity with iOS
**Date:** October 2025

---

## Executive Summary

Enable full page copy/cut/paste functionality in the macOS app to match iOS capabilities. This plan focuses on enhancing the existing macOS DocumentViewModel stub and properly connecting it to NSDocument, rather than building from scratch.

---

## Key Findings from Code Analysis

### Current State

#### ✅ What's Already Working
- **PageClipboard service** - Fully functional, platform-agnostic (Services/PageClipboard.swift)
- **Copy operation** - Works because it only reads PDF data
- **NSDocument layer** - NoteDocument already reads/writes .yianazip format
- **UI components** - PageManagementView has all buttons/shortcuts defined
- **Tests** - PageClipboardTests pass on macOS

#### ❌ What's Not Working
- **DocumentViewModel mutations** - macOS stub (lines 531-587) throws errors for cut/paste
- **Document saving** - No connection between DocumentViewModel and NSDocument
- **State management** - No hasChanges tracking or autosave
- **Undo support** - NSUndoManager not integrated
- **DocumentReadView** - Creates temporary DocumentViewModel disconnected from NSDocument

### Key Issues with Previous Plans

The v2 plan assumed we needed to build everything from scratch, but analysis shows:
1. UI and clipboard service already work perfectly
2. The real problem is DocumentReadView creates a temporary DocumentViewModel
3. We just need to enhance the existing macOS stub, not create complex protocols

---

## Improved v3 Implementation Plan

### Phase 1: Connect DocumentViewModel to NSDocument (2-3 hours)

#### 1.1 Enhance macOS DocumentViewModel Stub

Replace the current stub (lines 531-587 in DocumentViewModel.swift) with:

```swift
#if os(macOS)
@MainActor
final class DocumentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var title: String {
        didSet {
            if title != oldValue {
                document?.metadata.title = title
                hasChanges = true
                scheduleAutosave()
            }
        }
    }
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    @Published var pdfData: Data? {
        didSet {
            if pdfData != oldValue {
                document?.pdfData = pdfData
                hasChanges = true
                scheduleAutosave()
            }
        }
    }

    // MARK: - Private Properties
    private weak var document: NoteDocument?  // Weak to avoid retain cycle
    private var autosaveTask: Task<Void, Never>?
    private let autosaveDelay: TimeInterval = 2.0

    // MARK: - Computed Properties
    var documentID: UUID {
        document?.metadata.id ?? UUID()
    }
    var displayPDFData: Data? {
        pdfData
    }
    var provisionalPageRange: Range<Int>? {
        nil  // No provisional pages on macOS yet
    }
    var isReadOnly: Bool {
        guard let url = document?.fileURL else { return false }
        return !FileManager.default.isWritableFile(atPath: url.path)
    }

    // MARK: - Initialization
    init(document: NoteDocument) {
        self.document = document
        self.title = document.metadata.title
        self.pdfData = document.pdfData
    }

    // For backwards compatibility with tests
    init(pdfData: Data? = nil) {
        self.title = "Untitled"
        self.pdfData = pdfData
    }
}
#endif
```

#### 1.2 Fix DocumentReadView Initialization

Update DocumentReadView.swift to properly connect the view model:

```swift
struct DocumentReadView: View {
    @State private var document: NoteDocument?
    @State private var viewModel: DocumentViewModel?  // Not @StateObject

    private func loadDocument() async {
        isLoading = true
        errorMessage = nil

        do {
            let noteDocument = NoteDocument(fileURL: documentURL)
            try noteDocument.read(from: documentURL)

            self.document = noteDocument
            self.pdfData = noteDocument.pdfData
            self.documentTitle = noteDocument.metadata.title

            // Create proper viewModel connected to document
            await MainActor.run {
                self.viewModel = DocumentViewModel(document: noteDocument)
            }
        } catch {
            // Handle error...
        }

        isLoading = false
    }

    var body: some View {
        // ... existing UI ...
        .sheet(isPresented: $showingPageManagement) {
            if let viewModel = viewModel {
                PageManagementView(
                    pdfData: $viewModel.pdfData,  // Now properly bound
                    viewModel: viewModel,          // Real viewModel with save
                    isPresented: $showingPageManagement,
                    currentPageIndex: 0,
                    displayPDFData: viewModel.displayPDFData,
                    provisionalPageRange: nil
                )
            }
        }
    }
}
```

---

### Phase 2: Implement Cut/Paste Operations (2 hours)

#### 2.1 Add Core Operations to macOS DocumentViewModel

Copy the working iOS implementations and adapt for macOS:

```swift
extension DocumentViewModel {
    func save() async -> Bool {
        guard let document = document, hasChanges else { return true }

        isSaving = true
        defer { isSaving = false }

        // Update metadata
        document.metadata.modified = Date()
        if let pdf = PDFDocument(data: pdfData ?? Data()) {
            document.metadata.pageCount = pdf.pageCount
        }

        // Save through NSDocument
        return await withCheckedContinuation { continuation in
            document.save { error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    continuation.resume(returning: false)
                } else {
                    self.hasChanges = false
                    continuation.resume(returning: true)
                }
            }
        }
    }

    func removePages(at indices: [Int]) async {
        guard let currentData = pdfData,
              let pdf = PDFDocument(data: currentData) else { return }

        let sortedIndices = indices.sorted(by: >)
        for index in sortedIndices where index >= 0 && index < pdf.pageCount {
            pdf.removePage(at: index)
        }

        pdfData = pdf.dataRepresentation()
    }

    func copyPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        guard !indices.isEmpty else {
            throw PageOperationError.noValidPagesSelected
        }

        guard !isReadOnly else {
            throw PageOperationError.documentReadOnly
        }

        return try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .copy
        )
    }

    func cutPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        guard !isReadOnly else {
            throw PageOperationError.documentReadOnly
        }

        let sourceDataBeforeCut = pdfData

        // Create payload before removing
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .cut,
            sourceDataBeforeCut: sourceDataBeforeCut
        )

        // Register undo
        document?.undoManager?.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                target.pdfData = sourceDataBeforeCut
            }
        }
        document?.undoManager?.setActionName("Cut Pages")

        // Remove the pages
        await removePages(at: Array(indices))

        return payload
    }

    func insertPages(from payload: PageClipboardPayload, at insertIndex: Int?) async throws -> Int {
        guard !isReadOnly else {
            throw PageOperationError.documentReadOnly
        }

        guard let currentData = pdfData,
              let targetPDF = PDFDocument(data: currentData),
              let sourcePDF = PDFDocument(data: payload.pdfData) else {
            throw PageOperationError.sourceDocumentUnavailable
        }

        let originalData = currentData
        let insertAt = insertIndex ?? targetPDF.pageCount

        // Register undo
        document?.undoManager?.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                target.pdfData = originalData
            }
        }
        document?.undoManager?.setActionName("Paste Pages")

        // Insert pages
        var insertedCount = 0
        for i in 0..<sourcePDF.pageCount {
            autoreleasepool {
                if let page = sourcePDF.page(at: i),
                   let pageCopy = page.copy() as? PDFPage {
                    targetPDF.insert(pageCopy, at: insertAt + insertedCount)
                    insertedCount += 1
                }
            }
        }

        guard insertedCount > 0 else {
            throw PageOperationError.insertionFailed
        }

        pdfData = targetPDF.dataRepresentation()

        return insertedCount
    }
}
```

#### 2.2 Add Helper Methods

```swift
extension DocumentViewModel {
    func ensureDocumentIsAvailable() throws {
        // Check if document is available for editing
        guard document != nil else {
            throw PageOperationError.sourceDocumentUnavailable
        }

        if isReadOnly {
            throw PageOperationError.documentReadOnly
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()

        guard document?.autosavesInPlace == true else { return }

        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(autosaveDelay * 1_000_000_000))

            guard !Task.isCancelled, hasChanges else { return }
            _ = await save()
        }
    }
}
```

---

### Phase 3: Add Autosave & Visual Feedback (1 hour)

#### 3.1 Update DocumentReadView UI

Add visual feedback for save status and read-only state:

```swift
var body: some View {
    HSplitView {
        ZStack {
            // ... existing content ...

            // Read-only banner
            if viewModel?.isReadOnly == true {
                VStack {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("This document is read-only")
                        Spacer()
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
                    .padding()

                    Spacer()
                }
            }
        }
    }
    .toolbar {
        // Save indicator
        ToolbarItem {
            if viewModel?.hasChanges == true {
                if viewModel?.isSaving == true {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.orange)
                        .help("Unsaved changes")
                }
            }
        }
    }
}
```

#### 3.2 Add Menu Bar Commands

Update the app's main menu commands:

```swift
.commands {
    CommandGroup(after: .pasteboard) {
        Button("Copy Pages") {
            NotificationCenter.default.post(name: .copyPages, object: nil)
        }
        .keyboardShortcut("c", modifiers: [.command, .option])

        Button("Cut Pages") {
            NotificationCenter.default.post(name: .cutPages, object: nil)
        }
        .keyboardShortcut("x", modifiers: [.command, .option])

        Button("Paste Pages") {
            NotificationCenter.default.post(name: .pastePages, object: nil)
        }
        .keyboardShortcut("v", modifiers: [.command, .option])
        .disabled(!PageClipboard.shared.hasPayload)
    }
}
```

---

### Phase 4: Testing & Polish (1 hour)

#### 4.1 Update Tests

Remove the "not supported" tests and add proper macOS tests:

```swift
#if os(macOS)
func testCutPagesOnMacOS() async throws {
    // Given
    let document = NoteDocument(fileURL: testURL)
    let viewModel = DocumentViewModel(document: document)
    viewModel.pdfData = createSamplePDF()
    let indices: Set<Int> = [0, 1]

    // When
    let payload = try await viewModel.cutPages(atZeroBasedIndices: indices)

    // Then
    XCTAssertEqual(payload.operation, .cut)
    XCTAssertEqual(payload.pageCount, 2)
    XCTAssertTrue(viewModel.hasChanges)
}

func testPastePagesOnMacOS() async throws {
    // Given
    let document = NoteDocument(fileURL: testURL)
    let viewModel = DocumentViewModel(document: document)
    viewModel.pdfData = createSamplePDF()

    let payload = PageClipboardPayload(
        sourceDocumentID: UUID(),
        operation: .copy,
        pageCount: 2,
        pdfData: createSamplePDF(pageCount: 2)
    )

    // When
    let inserted = try await viewModel.insertPages(from: payload, at: 0)

    // Then
    XCTAssertEqual(inserted, 2)
    XCTAssertTrue(viewModel.hasChanges)
}

func testSaveIntegrationOnMacOS() async throws {
    // Test that save() properly updates NSDocument
}

func testUndoRedoOnMacOS() async throws {
    // Test NSUndoManager integration
}
#endif
```

#### 4.2 Manual Testing Checklist

- [ ] Copy pages between two documents
- [ ] Cut and restore functionality
- [ ] Save indicator appears/disappears
- [ ] Undo/redo via Edit menu (Cmd+Z/Cmd+Shift+Z)
- [ ] Read-only files show banner and prevent edits
- [ ] iCloud documents sync properly after changes
- [ ] Large documents (100+ pages) perform well
- [ ] Autosave triggers after 2 seconds
- [ ] No memory leaks with repeated operations

---

## Risk Mitigation

### Identified Risks & Solutions

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Weak reference issues** | Medium | Use proper weak/strong patterns for document reference |
| **NSDocument save conflicts** | High | Rely on NSDocument's built-in conflict resolution |
| **Memory with large PDFs** | Medium | Use autoreleasepool for page operations |
| **Undo stack overflow** | Low | Limit undo stack depth if needed |
| **DocumentReadView state** | Low | Ensure proper cleanup on view dismiss |

### Rollback Strategy

If critical issues are found:
1. Revert DocumentViewModel changes
2. Keep UI improvements (they're harmless)
3. Document issues for next iteration

---

## Success Metrics

### Functional Requirements
- ✅ Full copy/cut/paste parity with iOS
- ✅ Undo/redo support via Edit menu
- ✅ Autosave with visual feedback
- ✅ Read-only file handling
- ✅ Multi-window support
- ✅ Changes persist to disk

### Performance Requirements
- Page operations < 1 second for typical documents
- Autosave completes < 2 seconds
- Memory usage comparable to iOS
- No UI freezing during operations

### Quality Metrics
- Zero data loss scenarios
- All existing tests pass
- New macOS tests pass
- No regression in iOS functionality

---

## Key Advantages Over Previous Plans

1. **Simpler Architecture**: Reuses existing iOS logic instead of reimplementing
2. **Focused Scope**: Fixes the actual problem (DocumentReadView disconnect)
3. **Smaller Effort**: 6-7 hours vs 8-10 hours in v2
4. **Lower Risk**: Minimal changes to working components
5. **Better Integration**: Properly leverages NSDocument capabilities
6. **Cleaner Code**: No unnecessary protocols or abstractions

---

## Implementation Order

1. **Start with Phase 1.1**: Enhance DocumentViewModel stub (highest impact)
2. **Then Phase 1.2**: Fix DocumentReadView (enables all other work)
3. **Then Phase 2.1**: Implement operations (core functionality)
4. **Then Phase 3**: Add polish (user experience)
5. **Finally Phase 4**: Testing (validation)

---

## Next Steps After Implementation

1. **Provisional pages support** - Add draft text page support on macOS
2. **Advanced selection** - Multi-select with Shift+Click
3. **Drag & drop** - Between documents
4. **Batch operations** - Select all, invert selection
5. **Performance optimization** - Background processing for large documents

---

## Appendix: File Locations

- `Yiana/Yiana/ViewModels/DocumentViewModel.swift` (lines 531-587 for macOS stub)
- `Yiana/Yiana/Views/DocumentReadView.swift` (needs connection fix)
- `Yiana/Yiana/Views/PageManagementView.swift` (UI already complete)
- `Yiana/Yiana/Models/NoteDocument.swift` (NSDocument implementation)
- `Yiana/Yiana/Services/PageClipboard.swift` (working service)
- `Yiana/YianaTests/DocumentViewModelPageOperationsTests.swift` (needs macOS updates)

This plan is ready for immediate implementation with clear, actionable steps and realistic time estimates.