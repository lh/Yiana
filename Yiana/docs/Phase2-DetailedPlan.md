# Phase 2: Remove Core Data & Setup Document Repository - Detailed Plan

## Overview
Phase 2 focuses on removing Core Data (which came with the Xcode template) and implementing a proper document-based architecture using iCloud Documents.

## Prerequisites
- ✅ Phase 1 completed (DocumentMetadata and NoteDocument implemented)
- ✅ Both iOS and macOS targets building successfully
- ✅ Tests passing for existing code

## Step-by-Step Implementation Plan

### Step 1: Remove Core Data Files
**Goal**: Clean up all Core Data remnants from the project

1. **Delete Core Data model file**
   - Remove `Yiana.xcdatamodeld` from project navigator
   - Move to trash when prompted

2. **Delete Persistence.swift**
   - Remove `Persistence.swift` from project navigator
   - This contains the Core Data stack setup

3. **Update YianaApp.swift**
   - Remove `import CoreData` if present
   - Delete the line: `let persistenceController = PersistenceController.shared`
   - Remove `.environment(\.managedObjectContext, persistenceController.container.viewContext)`
   - The app should now initialize without Core Data

4. **Update ContentView.swift**
   - Remove any Core Data related code (@FetchRequest, @Environment for managedObjectContext)
   - Temporarily show a simple "Hello, World!" text

5. **Verify build**
   - Build both iOS and macOS targets
   - Ensure no Core Data references remain

### Step 2: Configure iCloud Entitlements
**Goal**: Enable iCloud Documents capability

1. **Update entitlements file**
   - Verify `Yiana.entitlements` has:
     ```xml
     <key>com.apple.developer.icloud-container-identifiers</key>
     <array>
         <string>iCloud.com.vitygas.Yiana</string>
     </array>
     <key>com.apple.developer.icloud-services</key>
     <array>
         <string>CloudDocuments</string>
     </array>
     ```

2. **Update Info.plist**
   - Add document types support:
     ```xml
     <key>CFBundleDocumentTypes</key>
     <array>
         <dict>
             <key>CFBundleTypeName</key>
             <string>Yiana Document</string>
             <key>LSItemContentTypes</key>
             <array>
                 <string>com.vitygas.yiana.document</string>
             </array>
             <key>LSHandlerRank</key>
             <string>Owner</string>
         </dict>
     </array>
     ```

### Step 3: Write DocumentRepository Tests
**Goal**: Define the API through tests first

Create `YianaTests/DocumentRepositoryTests.swift`:

```swift
class DocumentRepositoryTests: XCTestCase {
    var repository: DocumentRepository!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Use temp directory for tests instead of iCloud
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        repository = DocumentRepository(containerURL: testDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }
    
    func testGetDocumentsURL() {
        // Test that repository provides correct documents directory
    }
    
    func testListDocumentsEmptyDirectory() {
        // Test listing when no documents exist
    }
    
    func testListDocumentsWithFiles() {
        // Create test files and verify listing
    }
    
    func testCreateNewDocument() {
        // Test document creation
    }
    
    func testDeleteDocument() {
        // Test document deletion
    }
    
    func testDocumentExists() {
        // Test checking if document exists
    }
}
```

### Step 4: Implement DocumentRepository
**Goal**: Manage document files in iCloud container

Create `Services/DocumentRepository.swift`:

```swift
class DocumentRepository {
    private let containerURL: URL?
    
    init(containerURL: URL? = nil) {
        if let url = containerURL {
            self.containerURL = url
        } else {
            // Get iCloud container
            self.containerURL = FileManager.default
                .url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana")
        }
    }
    
    var documentsURL: URL? {
        return containerURL?.appendingPathComponent("Documents")
    }
    
    func listDocuments() -> [URL] {
        // List all .yianazip files
    }
    
    func createDocument(title: String) -> URL? {
        // Generate unique filename and return URL
    }
    
    func deleteDocument(at url: URL) throws {
        // Delete document file
    }
    
    func documentExists(at url: URL) -> Bool {
        // Check if file exists
    }
}
```

### Step 5: Integration Testing
**Goal**: Verify iCloud integration works

1. **Manual testing on device**
   - iCloud requires real device or logged-in simulator
   - Test creating documents appears in Files app
   - Test documents sync between devices

2. **Handle iCloud availability**
   - Add proper error handling for when iCloud is unavailable
   - Provide fallback to local documents directory

### Step 6: Update Tests for Platform Differences
**Goal**: Ensure tests work correctly with iOS-only NoteDocument

1. **Wrap iOS-specific tests**
   ```swift
   #if os(iOS)
   class NoteDocumentTests: XCTestCase {
       // Existing tests
   }
   #endif
   ```

2. **Create platform-agnostic repository tests**
   - DocumentRepository should work on both platforms
   - Use conditional compilation for platform-specific paths

## Success Criteria

1. ✅ All Core Data code removed
2. ✅ Project builds without errors on both platforms
3. ✅ DocumentRepository tests pass
4. ✅ Can create/list/delete documents in test directory
5. ✅ iCloud entitlements properly configured
6. ✅ Manual test shows documents in Files app (on device)

## Common Issues & Solutions

1. **iCloud container nil**
   - Ensure entitlements are correct
   - Must be signed in to iCloud on device/simulator
   - Check container identifier matches

2. **Permission errors**
   - Ensure Documents directory exists
   - Create directory if needed with `.createIntermediates`

3. **Tests fail on CI**
   - iCloud not available in CI environment
   - Use mock/test directory for unit tests
   - Mark integration tests as requiring real device

## Next Steps
After completing Phase 2:
- Phase 3: Create ViewModels with TDD
- Phase 4: Build basic UI
- Phase 5: Add document scanning

## Time Estimate
- Step 1: 15 minutes (file deletion)
- Step 2: 30 minutes (configuration)
- Step 3: 45 minutes (write tests)
- Step 4: 1 hour (implementation)
- Step 5: 30 minutes (testing)
- Step 6: 30 minutes (platform fixes)

**Total: ~3.5 hours**