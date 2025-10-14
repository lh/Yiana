# macOS Copy/Cut/Paste Support Plan v2

**Status:** Ready for implementation
**Estimated Time:** 8-10 hours
**Priority:** High - Feature parity with iOS

---

## Executive Summary

Enable full page copy/cut/paste functionality in the macOS app to match iOS capabilities. The macOS version currently supports copy-only operations due to its read-only DocumentViewModel. This plan leverages lessons learned from the iOS implementation to create a robust macOS solution.

---

## 1. Current State Analysis

### What Works Today
- ✅ **PageClipboard service** - Fully functional, platform-agnostic
- ✅ **Copy operation** - Works because it only reads PDF data
- ✅ **NSDocument layer** - `NoteDocument` already reads/writes .yianazip format
- ✅ **UI components** - PageManagementView has all buttons/shortcuts defined
- ✅ **Tests** - PageClipboardTests pass on macOS

### What's Missing
- ❌ **DocumentViewModel mutations** - Stub throws errors for cut/paste
- ❌ **Document saving** - No connection between ViewModel and NSDocument
- ❌ **State management** - No `hasChanges` tracking or autosave
- ❌ **Undo support** - NSUndoManager not integrated
- ❌ **Read-only detection** - No handling for locked files

### Lessons from iOS Implementation
1. **Visual feedback is critical** - Cut pages need dimming/overlay
2. **Restore functionality essential** - Users need to undo cuts
3. **Conflict detection needs logging** - Monitor but don't block
4. **Performance matters** - Cache clipboard availability checks
5. **Error handling must be user-friendly** - Clear, actionable messages

---

## 2. Technical Architecture

### 2.1 DocumentViewModel for macOS

Replace the stub with a full implementation that mirrors iOS functionality:

```swift
#if os(macOS)
@MainActor
final class DocumentViewModel: ObservableObject {
    // MARK: - Published Properties (match iOS)
    @Published var title: String
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    @Published var pdfData: Data? {
        didSet {
            if pdfData != oldValue {
                hasChanges = true
                scheduleAutosave()
            }
        }
    }

    // Display data (for preview during edits)
    @Published private(set) var displayPDFData: Data?

    // No provisional pages on macOS yet
    var provisionalPageRange: Range<Int>? { nil }

    // MARK: - Private Properties
    private let document: NoteDocument
    private var autosaveTask: Task<Void, Never>?
    private let autosaveDelay: TimeInterval = 2.0

    // MARK: - Computed Properties
    var documentID: UUID { document.metadata.id }
    var isReadOnly: Bool {
        // Check file permissions
        !FileManager.default.isWritableFile(atPath: document.fileURL?.path ?? "")
    }

    // MARK: - Initialization
    init(document: NoteDocument) {
        self.document = document
        self.title = document.metadata.title
        self.pdfData = document.pdfData
        self.displayPDFData = document.pdfData
    }
}
#endif
```

### 2.2 Core Operations

Implement the same three operations as iOS:

```swift
extension DocumentViewModel {
    func copyPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        // Same as iOS - already works
    }

    func cutPages(atZeroBasedIndices indices: Set<Int>) async throws -> PageClipboardPayload {
        guard !isReadOnly else {
            throw PageOperationError.documentReadOnly
        }

        let sourceDataBeforeCut = pdfData
        let payload = try PageClipboard.shared.createPayload(
            from: pdfData,
            indices: indices,
            documentID: documentID,
            operation: .cut,
            sourceDataBeforeCut: sourceDataBeforeCut
        )

        // Register undo
        document.undoManager?.registerUndo(withTarget: self) { target in
            target.pdfData = sourceDataBeforeCut
        }
        document.undoManager?.setActionName("Cut Pages")

        await removePages(at: Array(indices))
        return payload
    }

    func insertPages(from payload: PageClipboardPayload, at insertIndex: Int?) async throws -> Int {
        guard !isReadOnly else {
            throw PageOperationError.documentReadOnly
        }

        // Implementation matches iOS
        // Register undo for the insertion
        // Update pdfData, which triggers autosave
    }
}
```

### 2.3 Document Saving

Implement save through NSDocument:

```swift
func save() async -> Bool {
    guard hasChanges, !isReadOnly else { return true }

    isSaving = true
    defer { isSaving = false }

    do {
        // Update document with current data
        document.pdfData = pdfData
        document.metadata = DocumentMetadata(
            id: document.metadata.id,
            title: title,
            created: document.metadata.created,
            modified: Date(),
            pageCount: PDFDocument(data: pdfData ?? Data())?.pageCount ?? 0,
            tags: document.metadata.tags,
            ocrCompleted: document.metadata.ocrCompleted,
            plainText: document.metadata.plainText
        )

        // Save through NSDocument
        try await withCheckedThrowingContinuation { continuation in
            document.save { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        hasChanges = false
        return true
    } catch {
        errorMessage = error.localizedDescription
        return false
    }
}
```

### 2.4 Autosave Implementation

```swift
private func scheduleAutosave() {
    autosaveTask?.cancel()

    guard document.autosavesInPlace else { return }

    autosaveTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(autosaveDelay * 1_000_000_000))

        guard !Task.isCancelled, hasChanges else { return }
        _ = await save()
    }
}
```

---

## 3. UI Integration

### 3.1 DocumentReadView Updates

Transform from read-only viewer to editable document:

```swift
struct DocumentReadView: View {
    @StateObject private var viewModel: DocumentViewModel
    @State private var showingPageManagement = false

    init(documentURL: URL, searchResult: SearchResult? = nil) {
        // Create document and view model
        let document = NoteDocument(fileURL: documentURL)
        self._viewModel = StateObject(wrappedValue: DocumentViewModel(document: document))
    }

    var body: some View {
        // Main PDF viewer
        PDFKitView(pdfDocument: $viewModel.displayPDFData)
            .toolbar {
                ToolbarItem {
                    Button("Manage Pages") {
                        showingPageManagement = true
                    }
                    .disabled(viewModel.isReadOnly)
                }

                ToolbarItem {
                    if viewModel.hasChanges {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .sheet(isPresented: $showingPageManagement) {
                PageManagementView(
                    pdfData: $viewModel.pdfData,
                    viewModel: viewModel,
                    isPresented: $showingPageManagement,
                    currentPageIndex: 0,
                    displayPDFData: viewModel.displayPDFData,
                    provisionalPageRange: nil
                )
            }
    }
}
```

### 3.2 Menu Bar Integration

Add Edit menu items:

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

### 3.3 Read-Only Handling

Show banner when document is read-only:

```swift
if viewModel.isReadOnly {
    HStack {
        Image(systemName: "lock.fill")
        Text("This document is read-only")
        Spacer()
    }
    .padding()
    .background(Color.yellow.opacity(0.2))
}
```

---

## 4. Implementation Steps

### Phase 1: Core Infrastructure (3-4 hours)
1. **Extract shared logic** from iOS DocumentViewModel
   - Create `DocumentViewModelCore` protocol
   - Move common operations to extensions

2. **Implement macOS DocumentViewModel**
   - Full property set matching iOS
   - Connection to NSDocument
   - Save and autosave methods

3. **Add read-only detection**
   - File permission checks
   - UI state management
   - Error messaging

### Phase 2: Operations (2-3 hours)
1. **Implement cut/paste methods**
   - Reuse PageClipboard service
   - Add NSUndoManager integration
   - Handle edge cases

2. **Add helper methods**
   - removePages (already exists)
   - duplicatePages (already exists)
   - refreshDisplayPDF

3. **Error handling**
   - New error case: documentReadOnly
   - User-friendly messages
   - Logging for debugging

### Phase 3: UI Integration (2-3 hours)
1. **Update DocumentReadView**
   - Create and manage DocumentViewModel
   - Add page management sheet
   - Show save status

2. **Add menu commands**
   - Edit menu integration
   - Keyboard shortcuts
   - Enable/disable logic

3. **Visual feedback**
   - Read-only banner
   - Save progress indicator
   - Error alerts

### Phase 4: Testing & Polish (1-2 hours)
1. **Unit tests**
   - macOS DocumentViewModel operations
   - Save/autosave functionality
   - Undo/redo behavior

2. **Integration tests**
   - Full copy/paste workflow
   - Multi-window scenarios
   - iCloud sync behavior

3. **Edge cases**
   - Large documents
   - Permission changes
   - Concurrent edits

---

## 5. Risk Mitigation

### Identified Risks & Solutions

| Risk | Impact | Mitigation |
|------|--------|------------|
| **NSDocument conflicts** | High | Use NSDocument's built-in versioning; show conflict UI |
| **Undo complexity** | Medium | Start simple with single-level undo; enhance later |
| **Performance with large PDFs** | Medium | Reuse iOS chunking/autoreleasepool patterns |
| **Read-only detection timing** | Low | Check permissions on each operation attempt |
| **Autosave flooding** | Low | Debounce with 2-second delay |

### Rollback Strategy
- Feature flag: `UserDefaults.standard.bool(forKey: "EnableMacOSPageEditing")`
- Fallback: Revert to read-only mode if critical issues found
- Gradual rollout: Start with beta users

---

## 6. Testing Strategy

### Unit Tests
```swift
class MacDocumentViewModelTests: XCTestCase {
    func testCutPagesOnMacOS() async throws
    func testPastePagesOnMacOS() async throws
    func testSaveIntegration() async throws
    func testReadOnlyDetection() throws
    func testUndoRedo() throws
    func testAutosaveDebouncing() async throws
}
```

### UI Tests
```swift
class MacPageManagementUITests: XCTestCase {
    func testCompleteCopyPasteFlow()
    func testMenuBarCommands()
    func testReadOnlyBanner()
    func testMultiWindowEditing()
}
```

### Manual Testing Checklist
- [ ] Copy pages between two documents
- [ ] Cut and restore functionality
- [ ] Save indicator appears/disappears
- [ ] Undo/redo via Edit menu
- [ ] Read-only files show banner
- [ ] iCloud documents sync properly
- [ ] Large documents (100+ pages) perform well

---

## 7. Success Metrics

### Functional Requirements
- ✅ Full copy/cut/paste parity with iOS
- ✅ Undo/redo support via Edit menu
- ✅ Autosave with visual feedback
- ✅ Read-only file handling
- ✅ Multi-window support

### Performance Requirements
- Page operations < 1 second for typical documents
- Autosave completes < 2 seconds
- Memory usage comparable to iOS
- No UI freezing during operations

### Quality Metrics
- Zero data loss scenarios
- < 5 bugs in first release
- Test coverage > 80%
- User satisfaction > 4.5/5

---

## 8. Documentation Updates

### User-Facing
- Release notes: "Page editing now available on macOS!"
- Help documentation: How to manage pages
- Keyboard shortcuts guide

### Developer-Facing
- Architecture decision record
- Code comments for platform differences
- Test documentation

---

## 9. Future Enhancements

After MVP ships:
1. **Provisional pages** - Support for draft text pages
2. **Advanced undo** - Multi-level undo stack
3. **Batch operations** - Select all, invert selection
4. **Drag & drop** - Between windows
5. **Performance** - Background processing for large documents

---

## Appendix: Key Differences from v1

### Improvements in v2
1. **Concrete code examples** - Real Swift code, not pseudocode
2. **NSUndoManager integration** - Proper macOS undo support
3. **Autosave implementation** - Matches iOS behavior
4. **Read-only handling** - Complete solution with UI
5. **Testing strategy** - Specific test cases defined
6. **Risk mitigation** - Feature flags and rollback plan
7. **Success metrics** - Measurable goals
8. **Lessons incorporated** - Visual feedback, restore functionality, performance optimization

### Technical Decisions
- Use NSDocument's save method instead of custom file writing
- Integrate with NSUndoManager for native undo/redo
- Match iOS property names exactly for consistency
- Reuse all PageClipboard code without modification
- Add read-only detection as primary safety mechanism

This plan is ready for implementation with clear phases, concrete code examples, and comprehensive testing strategy.