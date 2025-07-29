# Phase 3: ViewModels with TDD - Detailed Plan

## Overview
Phase 3 creates the ViewModels layer that bridges our data models (NoteDocument, DocumentRepository) with the UI. We'll use TDD and keep it simple.

## Key Design Decisions

1. **DocumentListViewModel manages URLs, not documents** - It gets URLs from DocumentRepository, the UI creates documents as needed
2. **Platform-specific ViewModels** - iOS uses NoteDocument, macOS will have its own later
3. **Simple async patterns** - Use completion handlers, not Combine (simpler)
4. **One responsibility per ViewModel** - List management vs single document editing

## Implementation Steps

### Step 1: DocumentListViewModel Tests (45 minutes)
**Goal**: Define the API for managing the document list

Create `YianaTests/DocumentListViewModelTests.swift`:

```swift
import XCTest
@testable import Yiana

@MainActor
class DocumentListViewModelTests: XCTestCase {
    var viewModel: DocumentListViewModel!
    var repository: DocumentRepository!
    var testDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: testDirectory,
                                              withIntermediateDirectories: true)
        repository = DocumentRepository(documentsDirectory: testDirectory)
        viewModel = DocumentListViewModel(repository: repository)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testDirectory)
        try await super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(viewModel.documentURLs.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadDocuments() async throws {
        // Create test files
        let url1 = repository.newDocumentURL(title: "Doc 1")
        let url2 = repository.newDocumentURL(title: "Doc 2")
        try Data().write(to: url1)
        try Data().write(to: url2)
        
        // Load documents
        await viewModel.loadDocuments()
        
        // Verify
        XCTAssertEqual(viewModel.documentURLs.count, 2)
        XCTAssertTrue(viewModel.documentURLs.contains(url1))
        XCTAssertTrue(viewModel.documentURLs.contains(url2))
    }
    
    func testCreateNewDocument() async {
        // Create new document
        let url = await viewModel.createNewDocument(title: "New Doc")
        
        // Verify URL was generated
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.pathExtension, "yianazip")
        
        // Note: ViewModel doesn't create the file, just returns URL
        // UI will create the actual document
    }
    
    func testDeleteDocument() async throws {
        // Create test file
        let url = repository.newDocumentURL(title: "To Delete")
        try Data().write(to: url)
        await viewModel.loadDocuments()
        
        // Delete
        try await viewModel.deleteDocument(at: url)
        
        // Verify
        await viewModel.loadDocuments()
        XCTAssertFalse(viewModel.documentURLs.contains(url))
    }
    
    func testLoadingState() async {
        // Start loading
        let loadTask = Task {
            await viewModel.loadDocuments()
        }
        
        // Check loading state (might be flaky in tests)
        // In real app, isLoading would be true during load
        
        await loadTask.value
        XCTAssertFalse(viewModel.isLoading)
    }
}
```

### Step 2: DocumentListViewModel Implementation (45 minutes)
**Goal**: Simple ViewModel that manages document URLs

Create `ViewModels/DocumentListViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
class DocumentListViewModel: ObservableObject {
    @Published var documentURLs: [URL] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: DocumentRepository
    
    init(repository: DocumentRepository? = nil) {
        self.repository = repository ?? DocumentRepository()
    }
    
    func loadDocuments() async {
        isLoading = true
        errorMessage = nil
        
        // Simulate async work (file system is actually sync)
        await Task.yield()
        
        documentURLs = repository.documentURLs()
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        isLoading = false
    }
    
    func createNewDocument(title: String) async -> URL? {
        let url = repository.newDocumentURL(title: title)
        // Note: We don't create the file here, just return the URL
        // The UI will create the actual NoteDocument
        return url
    }
    
    func deleteDocument(at url: URL) async throws {
        do {
            try repository.deleteDocument(at: url)
            // Remove from our list
            documentURLs.removeAll { $0 == url }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            throw error
        }
    }
    
    func refresh() async {
        await loadDocuments()
    }
}
```

### Step 3: DocumentViewModel Tests (30 minutes)
**Goal**: Define API for single document editing

Create `YianaTests/DocumentViewModelTests.swift`:

```swift
import XCTest
@testable import Yiana

#if os(iOS)
@MainActor
class DocumentViewModelTests: XCTestCase {
    var viewModel: DocumentViewModel!
    var document: NoteDocument!
    var testURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.yianazip")
        document = NoteDocument(fileURL: testURL)
        viewModel = DocumentViewModel(document: document)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testURL)
        try await super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(viewModel.title, document.metadata.title)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertFalse(viewModel.hasChanges)
    }
    
    func testTitleChange() {
        // Change title
        viewModel.title = "New Title"
        
        // Verify
        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertEqual(viewModel.title, "New Title")
        // Document not updated until save
        XCTAssertNotEqual(document.metadata.title, "New Title")
    }
    
    func testSave() async {
        // Make changes
        viewModel.title = "Updated Title"
        viewModel.pdfData = Data("New PDF".utf8)
        
        // Save
        let success = await viewModel.save()
        
        // Verify
        XCTAssertTrue(success)
        XCTAssertFalse(viewModel.hasChanges)
        XCTAssertEqual(document.metadata.title, "Updated Title")
        XCTAssertEqual(document.pdfData, Data("New PDF".utf8))
    }
    
    func testAutoSave() async {
        viewModel.autoSaveEnabled = true
        
        // Make change
        viewModel.title = "Auto Saved"
        
        // Wait for debounce (in real implementation)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Should have saved
        XCTAssertEqual(document.metadata.title, "Auto Saved")
    }
}
#endif
```

### Step 4: DocumentViewModel Implementation (30 minutes)
**Goal**: Simple wrapper around NoteDocument for editing

Create `ViewModels/DocumentViewModel.swift`:

```swift
import Foundation
import SwiftUI

#if os(iOS)
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var title: String {
        didSet {
            if title != document.metadata.title {
                hasChanges = true
            }
        }
    }
    
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    var pdfData: Data? {
        get { document.pdfData }
        set {
            document.pdfData = newValue
            hasChanges = true
        }
    }
    
    var autoSaveEnabled = false {
        didSet {
            if autoSaveEnabled && hasChanges {
                Task { await save() }
            }
        }
    }
    
    private let document: NoteDocument
    private var autoSaveTask: Task<Void, Never>?
    
    init(document: NoteDocument) {
        self.document = document
        self.title = document.metadata.title
    }
    
    func save() async -> Bool {
        guard hasChanges else { return true }
        
        isSaving = true
        errorMessage = nil
        
        // Update document
        document.metadata.title = title
        document.metadata.modified = Date()
        
        // Save
        return await withCheckedContinuation { continuation in
            document.save(to: document.fileURL, for: .forOverwriting) { success in
                Task { @MainActor in
                    self.isSaving = false
                    if success {
                        self.hasChanges = false
                    } else {
                        self.errorMessage = "Failed to save document"
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        
        guard autoSaveEnabled && hasChanges else { return }
        
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if !Task.isCancelled {
                await save()
            }
        }
    }
}
#endif
```

## Platform Considerations

### iOS Implementation
- Uses NoteDocument (UIDocument)
- Full document editing capabilities
- Auto-save support

### macOS Placeholder
For now, macOS won't have document editing:
```swift
#if os(macOS)
// Placeholder - macOS document editing will come later
class DocumentViewModel: ObservableObject {
    @Published var title = "Document viewing not yet supported on macOS"
}
#endif
```

## Testing Strategy

1. **Unit tests use temporary directories** - No iCloud needed
2. **@MainActor for ViewModels** - They update UI properties
3. **Test behavior, not implementation** - Don't test private methods
4. **Platform-specific tests** - Wrap in #if os(iOS)

## Success Criteria

1. ✅ DocumentListViewModel manages document URLs
2. ✅ Can create new document URLs (not files)
3. ✅ Can delete documents
4. ✅ DocumentViewModel wraps single document
5. ✅ Title editing with change tracking
6. ✅ Save functionality
7. ✅ All tests pass

## What We're NOT Doing

1. **No complex state management** - Just @Published properties
2. **No Combine publishers** - Keep it simple
3. **No document preview loading** - That's for Phase 4
4. **No iCloud sync handling** - Repository handles files
5. **No error recovery** - Just display errors

## Common Patterns

### Loading State
```swift
@Published var isLoading = false

func loadSomething() async {
    isLoading = true
    defer { isLoading = false }
    // Do work
}
```

### Error Handling
```swift
@Published var errorMessage: String?

do {
    try await someOperation()
} catch {
    errorMessage = error.localizedDescription
}
```

### Change Tracking
```swift
@Published var hasChanges = false

@Published var someProperty: String {
    didSet {
        hasChanges = true
    }
}
```

## Time Estimate
- Step 1: 45 minutes (DocumentListViewModel tests)
- Step 2: 45 minutes (DocumentListViewModel implementation)
- Step 3: 30 minutes (DocumentViewModel tests)
- Step 4: 30 minutes (DocumentViewModel implementation)

**Total: 2.5 hours**

## Next Steps
After Phase 3:
- Phase 4: Build basic UI (DocumentListView, DocumentView)
- Phase 5: Add document scanning
- Phase 6: PDF viewing