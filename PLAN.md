# Yiana Implementation Plan

## Phase 1: Project Structure & Core Models

- [x] Prompt: "Create the folder structure for the project. In the Yiana/Yiana directory, create these folders: Models, ViewModels, Views, Services, Utilities, and Tests. Use mkdir to create each folder."

- [x] Prompt: "In Tests folder, create a file DocumentMetadataTests.swift and write failing unit tests for a DocumentMetadata struct that should have properties: id (UUID), title (String), created (Date), modified (Date), pageCount (Int), tags ([String]), ocrCompleted (Bool), and fullText (String?)."

- [x] Prompt: "In Models folder, create DocumentMetadata.swift and implement the DocumentMetadata struct to make the tests pass. Make it Codable and Equatable."

- [x] Prompt: "In Tests folder, create NoteDocumentTests.swift and write failing unit tests for a NoteDocument class that subclasses UIDocument. Test that it can: 1) Initialize with a fileURL, 2) Store PDF data, 3) Store and retrieve metadata, 4) Encode/decode its contents."

- [ ] Prompt: "In Models folder, create NoteDocument.swift and implement the NoteDocument class as a UIDocument subclass. It should have pdfData and metadata properties, and implement contents(forType:) and load(fromContents:ofType:) methods to make the tests pass."

## Phase 2: Remove Core Data & Setup Document Repository

- [ ] Prompt: "Delete the following Core Data files: Persistence.swift and Yiana.xcdatamodeld. Remove Core Data references from YianaApp.swift by deleting persistenceController and the .environment modifier."

- [ ] Prompt: "In Tests folder, create DocumentRepositoryTests.swift and write failing tests for a DocumentRepository class that should: 1) List all documents, 2) Create a new document, 3) Delete a document, 4) Get iCloud documents URL."

- [ ] Prompt: "In Services folder, create DocumentRepository.swift and implement the DocumentRepository class with methods to manage documents in iCloud Documents container. Make the tests pass."

## Phase 3: ViewModels with TDD

- [ ] Prompt: "In Tests folder, create DocumentListViewModelTests.swift and write failing tests for a DocumentListViewModel class that should: 1) Load documents from repository, 2) Create new documents, 3) Delete documents, 4) Publish an array of NoteDocument objects."

- [ ] Prompt: "In ViewModels folder, create DocumentListViewModel.swift and implement the DocumentListViewModel class as an ObservableObject with @Published properties. Make it use DocumentRepository and pass all tests."

- [ ] Prompt: "In Tests folder, create DocumentViewModelTests.swift and write failing tests for a DocumentViewModel that wraps a single NoteDocument and provides: 1) Title editing, 2) Save functionality, 3) PDF data access."

- [ ] Prompt: "In ViewModels folder, create DocumentViewModel.swift and implement the class to make the tests pass."

## Phase 4: Basic UI Implementation

- [ ] Prompt: "In Views folder, create DocumentListView.swift. Implement a SwiftUI view that displays a list of documents using DocumentListViewModel. Include a navigation bar with a + button to create new documents."

- [ ] Prompt: "Update ContentView.swift to use DocumentListView as the main view, removing the default template code."

- [ ] Prompt: "In Views folder, create DocumentView.swift. Implement a basic view that shows a document title (editable) and placeholder for PDF content. Use DocumentViewModel."

## Phase 5: Scanner Integration (iOS only)

- [ ] Prompt: "In Tests folder, create ScanningServiceTests.swift and write tests for a ScanningService that can: 1) Check if scanning is available, 2) Convert scanned images to PDF data."

- [ ] Prompt: "In Services folder, create ScanningService.swift with a protocol that defines scanning operations. Implement a MockScanningService for tests and a placeholder for the real implementation."

- [ ] Prompt: "In Views folder, create ScannerView.swift. Using #if os(iOS), implement a UIViewControllerRepresentable that wraps VNDocumentCameraViewController for document scanning."

- [ ] Prompt: "Update ScanningService.swift to add the real implementation using VisionKit on iOS. Use compiler directives to provide a stub implementation on macOS."

## Phase 6: PDF Viewer Integration

- [ ] Prompt: "In Views folder, create PDFViewer.swift. Implement a view that wraps PDFKit's PDFView for both iOS and macOS. It should display PDF data in read-only mode."

- [ ] Prompt: "Update DocumentView.swift to include the PDFViewer component, showing the PDF content when available."

## Phase 7: iCloud Configuration

- [ ] Prompt: "Update the Info.plist to include the NSUbiquitousContainers key for iCloud Documents. Add necessary entitlements for iCloud Documents & Data."

- [ ] Prompt: "In DocumentRepository.swift, implement proper iCloud Documents URL resolution and ensure documents are saved in the iCloud container."

## Phase 8: Polish & Error Handling

- [ ] Prompt: "Add error handling to DocumentRepository for cases like iCloud not available, disk full, etc. Create an ErrorHandler utility class."

- [ ] Prompt: "Add loading states to ViewModels and update Views to show progress indicators during document operations."

- [ ] Prompt: "Implement pull-to-refresh in DocumentListView to manually sync with iCloud."

## Testing Checkpoints

After each phase, run:
```bash
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Important Notes
- Each prompt is self-contained and testable
- Follow TDD: Write failing tests first, then implementation
- Commit after each successful test/implementation pair
- Update memory-bank/activeContext.md after completing each phase