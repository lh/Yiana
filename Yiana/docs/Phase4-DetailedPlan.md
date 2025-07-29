# Phase 4: Basic UI Implementation - Detailed Plan

## Overview
Phase 4 creates the basic SwiftUI views to display and manage documents. We'll keep it simple and functional.

## Key Design Decisions

1. **Navigation structure** - NavigationStack (iOS 16+) for modern navigation
2. **Document creation flow** - Create URL → Create NoteDocument → Navigate to edit
3. **Platform-aware UI** - iOS gets full editing, macOS gets list only for now
4. **No fancy UI** - Focus on functionality first, polish later
5. **Error handling** - Simple alerts for errors

## Implementation Steps

### Step 1: DocumentListView (45 minutes)
**Goal**: List of documents with navigation and create button

Create `Views/DocumentListView.swift`:

```swift
import SwiftUI

struct DocumentListView: View {
    @StateObject private var viewModel = DocumentListViewModel()
    @State private var showingCreateAlert = false
    @State private var newDocumentTitle = ""
    @State private var navigationPath = NavigationPath()
    @State private var showingError = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && viewModel.documentURLs.isEmpty {
                    ProgressView("Loading documents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.documentURLs.isEmpty {
                    emptyStateView
                } else {
                    documentList
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreateAlert = true }) {
                        Label("New Document", systemImage: "plus")
                    }
                }
            }
            .alert("New Document", isPresented: $showingCreateAlert) {
                TextField("Document Title", text: $newDocumentTitle)
                Button("Cancel", role: .cancel) {
                    newDocumentTitle = ""
                }
                Button("Create") {
                    createDocument()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .navigationDestination(for: URL.self) { url in
                #if os(iOS)
                DocumentEditView(documentURL: url)
                #else
                Text("Document editing not available on macOS")
                #endif
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Documents")
                .font(.title2)
            Text("Tap + to create your first document")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentList: some View {
        List {
            ForEach(viewModel.documentURLs, id: \.self) { url in
                NavigationLink(value: url) {
                    DocumentRow(url: url)
                }
            }
            .onDelete(perform: deleteDocuments)
        }
    }
    
    private func createDocument() {
        Task {
            guard !newDocumentTitle.isEmpty else { return }
            
            if let url = await viewModel.createNewDocument(title: newDocumentTitle) {
                #if os(iOS)
                // Create the actual document
                let document = NoteDocument(fileURL: url)
                document.save(to: url, for: .forCreating) { success in
                    Task { @MainActor in
                        if success {
                            await viewModel.refresh()
                            navigationPath.append(url)
                        } else {
                            viewModel.errorMessage = "Failed to create document"
                            showingError = true
                        }
                    }
                }
                #else
                // macOS: Just refresh to show the URL
                await viewModel.refresh()
                #endif
            }
            
            newDocumentTitle = ""
        }
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let url = viewModel.documentURLs[index]
                do {
                    try await viewModel.deleteDocument(at: url)
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// Simple row view for document
struct DocumentRow: View {
    let url: URL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(url.deletingPathExtension().lastPathComponent)
                .font(.headline)
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

### Step 2: Update ContentView (10 minutes)
**Goal**: Replace placeholder with DocumentListView

Update `ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        DocumentListView()
    }
}

#Preview {
    ContentView()
}
```

### Step 3: DocumentEditView for iOS (45 minutes)
**Goal**: Basic document editing interface

Create `Views/DocumentEditView.swift`:

```swift
import SwiftUI

#if os(iOS)
struct DocumentEditView: View {
    let documentURL: URL
    @StateObject private var viewModel: DocumentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveError = false
    @FocusState private var titleFieldFocused: Bool
    
    init(documentURL: URL) {
        self.documentURL = documentURL
        // Create document and view model
        let document = NoteDocument(fileURL: documentURL)
        self._viewModel = StateObject(wrappedValue: DocumentViewModel(document: document))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title editor
            TextField("Document Title", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .padding()
                .focused($titleFieldFocused)
            
            Divider()
            
            // PDF content area (placeholder for now)
            if let pdfData = viewModel.pdfData {
                PDFPlaceholderView(pdfData: pdfData)
            } else {
                ContentPlaceholderView()
            }
        }
        .navigationTitle("Edit Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    saveAndDismiss()
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else if viewModel.hasChanges {
                    Button("Save") {
                        Task {
                            await saveDocument()
                        }
                    }
                }
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Failed to save document")
        }
        .task {
            // Load document when view appears
            await loadDocument()
        }
    }
    
    private func loadDocument() async {
        let document = NoteDocument(fileURL: documentURL)
        
        await withCheckedContinuation { continuation in
            document.open { success in
                if success {
                    Task { @MainActor in
                        // Update view model with loaded document
                        viewModel.title = document.metadata.title
                        viewModel.pdfData = document.pdfData
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func saveDocument() async {
        let success = await viewModel.save()
        if !success {
            showingSaveError = true
        }
    }
    
    private func saveAndDismiss() {
        if viewModel.hasChanges {
            Task {
                await saveDocument()
                dismiss()
            }
        } else {
            dismiss()
        }
    }
}

// Placeholder view for PDF content
struct PDFPlaceholderView: View {
    let pdfData: Data
    
    var body: some View {
        VStack {
            Image(systemName: "doc.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("PDF Preview")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("\(pdfData.count) bytes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}

// Placeholder for empty documents
struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("No Content")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Add content by scanning documents")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}
#endif
```

### Step 4: Platform-Specific Adjustments (20 minutes)
**Goal**: Ensure macOS builds and shows appropriate UI

Create `Views/DocumentListView+macOS.swift` for macOS-specific adjustments:

```swift
#if os(macOS)
extension DocumentListView {
    // macOS-specific view adjustments
    private var platformToolbar: some ToolbarContent {
        ToolbarItem {
            Button(action: { showingCreateAlert = true }) {
                Label("New Document", systemImage: "plus")
            }
        }
    }
}
#endif
```

## Navigation Flow

### iOS Flow:
1. DocumentListView shows list
2. Tap + → Enter title → Create NoteDocument → Navigate to DocumentEditView
3. Edit title → Auto-save after 1 second
4. Close → Save if needed → Return to list

### macOS Flow (limited):
1. DocumentListView shows list
2. Tap + → Enter title → Create URL only
3. No editing available yet

## UI Components

### DocumentListView Features:
- Empty state with instructions
- List with swipe-to-delete
- Pull-to-refresh
- Loading indicator
- Error alerts
- Navigation to edit view (iOS)

### DocumentEditView Features (iOS):
- Editable title field
- PDF content placeholder
- Save button (appears when changes exist)
- Auto-save indicator
- Close with save prompt

## Testing Strategy

Since these are UI components, testing will be mostly manual:

1. **Create Document Flow**
   - Tap + button
   - Enter title
   - Verify document appears in list
   - Verify navigation to edit view

2. **Edit Document Flow**
   - Change title
   - Verify save button appears
   - Close and verify save prompt

3. **Delete Document Flow**
   - Swipe to delete
   - Verify document removed

4. **Error Handling**
   - Try to create document with empty title
   - Simulate save failures

## Success Criteria

1. ✅ DocumentListView displays documents from repository
2. ✅ Can create new documents with custom titles
3. ✅ Can delete documents with swipe gesture
4. ✅ iOS: Can navigate to edit documents
5. ✅ iOS: Can edit document titles with auto-save
6. ✅ macOS: Shows appropriate placeholder UI
7. ✅ Error messages displayed appropriately
8. ✅ Loading states shown during operations

## What We're NOT Doing

1. **No PDF viewing** - Just placeholders for now
2. **No document scanning** - That's Phase 5
3. **No search/filter** - Keep it simple
4. **No fancy animations** - Basic transitions only
5. **No iCloud sync UI** - Repository handles files

## Common SwiftUI Patterns Used

### State Management:
```swift
@StateObject private var viewModel = DocumentListViewModel()
@State private var showingAlert = false
@Environment(\.dismiss) private var dismiss
```

### Navigation (iOS 16+):
```swift
NavigationStack(path: $navigationPath) {
    // Content
}
.navigationDestination(for: URL.self) { url in
    DocumentEditView(documentURL: url)
}
```

### Task and Async:
```swift
.task {
    await viewModel.loadDocuments()
}
```

### Conditional Platform UI:
```swift
#if os(iOS)
DocumentEditView(documentURL: url)
#else
Text("Not available on macOS")
#endif
```

## Time Estimate
- Step 1: 45 minutes (DocumentListView)
- Step 2: 10 minutes (Update ContentView)
- Step 3: 45 minutes (DocumentEditView)
- Step 4: 20 minutes (Platform adjustments)

**Total: 2 hours**

## Next Steps
After Phase 4:
- Phase 5: Scanner Integration (iOS)
- Phase 6: PDF Viewing
- Phase 7: iCloud Integration