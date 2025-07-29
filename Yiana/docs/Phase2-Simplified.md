# Phase 2: Remove Core Data & Setup Document Repository - SIMPLIFIED

## Overview
Phase 2 removes Core Data and creates a simple file manager for documents. **No iCloud yet** - just local file management.

## Key Simplifications
1. **No iCloud in Phase 2** - Just local documents directory first
2. **DocumentRepository only manages URLs** - Doesn't create document content
3. **Platform-specific code stays platform-specific** - No forced abstractions
4. **One thing at a time** - Each step is independently testable

## Implementation Steps

### Step 1: Remove Core Data (15 minutes)
**Goal**: Delete all Core Data code

1. Delete files:
   - `Yiana.xcdatamodeld`
   - `Persistence.swift`

2. Clean `YianaApp.swift`:
   ```swift
   import SwiftUI
   
   @main
   struct YianaApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
           }
       }
   }
   ```

3. Simplify `ContentView.swift`:
   ```swift
   import SwiftUI
   
   struct ContentView: View {
       var body: some View {
           Text("Yiana")
               .padding()
       }
   }
   ```

4. Verify both platforms build

### Step 2: Create Minimal DocumentRepository (45 minutes)
**Goal**: Simple URL manager for .yianazip files

#### Tests First - `YianaTests/DocumentRepositoryTests.swift`:
```swift
import XCTest
@testable import Yiana

class DocumentRepositoryTests: XCTestCase {
    var repository: DocumentRepository!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: testDirectory, 
                                               withIntermediateDirectories: true)
        repository = DocumentRepository(documentsDirectory: testDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testDirectory)
    }
    
    func testDocumentsDirectory() {
        XCTAssertEqual(repository.documentsDirectory, testDirectory)
    }
    
    func testListURLsEmpty() {
        let urls = repository.documentURLs()
        XCTAssertTrue(urls.isEmpty)
    }
    
    func testListURLsFindsYianaFiles() throws {
        // Create test files
        let doc1 = testDirectory.appendingPathComponent("test1.yianazip")
        let doc2 = testDirectory.appendingPathComponent("test2.yianazip")
        let other = testDirectory.appendingPathComponent("other.pdf")
        
        try Data().write(to: doc1)
        try Data().write(to: doc2)
        try Data().write(to: other)
        
        let urls = repository.documentURLs()
        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls.contains(doc1))
        XCTAssertTrue(urls.contains(doc2))
        XCTAssertFalse(urls.contains(other))
    }
    
    func testGenerateNewDocumentURL() {
        let url = repository.newDocumentURL(title: "Test Doc")
        XCTAssertEqual(url.pathExtension, "yianazip")
        XCTAssertTrue(url.lastPathComponent.contains("Test Doc"))
    }
    
    func testDeleteDocument() throws {
        let url = testDirectory.appendingPathComponent("test.yianazip")
        try Data().write(to: url)
        
        try repository.deleteDocument(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
```

#### Implementation - `Services/DocumentRepository.swift`:
```swift
import Foundation

/// Manages document URLs in a directory. Does NOT handle document content.
class DocumentRepository {
    let documentsDirectory: URL
    
    init(documentsDirectory: URL? = nil) {
        if let directory = documentsDirectory {
            self.documentsDirectory = directory
        } else {
            // Default to app's Documents directory
            self.documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
        }
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: self.documentsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    /// Returns all .yianazip file URLs in the documents directory
    func documentURLs() -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return urls.filter { $0.pathExtension == "yianazip" }
    }
    
    /// Generates a new unique URL for a document with given title
    func newDocumentURL(title: String) -> URL {
        let cleanTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        let baseURL = documentsDirectory
            .appendingPathComponent(cleanTitle)
            .appendingPathExtension("yianazip")
        
        // If file exists, add number
        var url = baseURL
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            url = documentsDirectory
                .appendingPathComponent("\(cleanTitle) \(counter)")
                .appendingPathExtension("yianazip")
            counter += 1
        }
        
        return url
    }
    
    /// Deletes document at URL
    func deleteDocument(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
```

### Step 3: Integration with NoteDocument (iOS only) (30 minutes)
**Goal**: Verify NoteDocument works with DocumentRepository URLs

Add to `NoteDocumentTests.swift`:
```swift
func testIntegrationWithRepository() throws {
    // Given
    let repository = DocumentRepository(
        documentsDirectory: tempDirectory
    )
    let url = repository.newDocumentURL(title: "Integration Test")
    
    // When - Create and save document
    let document = NoteDocument(fileURL: url)
    document.pdfData = Data("Test PDF".utf8)
    
    let saveExpectation = expectation(description: "Document saved")
    document.save(to: url, for: .forCreating) { success in
        XCTAssertTrue(success)
        saveExpectation.fulfill()
    }
    waitForExpectations(timeout: 5.0)
    
    // Then - Repository should find it
    let urls = repository.documentURLs()
    XCTAssertTrue(urls.contains(url))
}
```

## What We're NOT Doing in Phase 2

1. **No iCloud configuration** - Local files only
2. **No document creation in repository** - That's NoteDocument's job
3. **No complex error handling** - Just throw FileManager errors
4. **No document opening** - Repository just manages URLs
5. **No macOS document implementation** - One platform at a time

## Success Criteria

1. ✅ Core Data completely removed
2. ✅ Both platforms build successfully
3. ✅ DocumentRepository tests pass
4. ✅ DocumentRepository only manages URLs (list, generate, delete)
5. ✅ NoteDocument can save to URLs from repository

## Why This Is Better

1. **Separation of Concerns**
   - DocumentRepository: URL management only
   - NoteDocument: Document content and persistence
   - iCloud: Future phase, separate concern

2. **Testable**
   - No iCloud dependency for tests
   - Deterministic file operations
   - Each component tested independently

3. **Incremental**
   - Works locally first
   - Can add iCloud later without changing APIs
   - Each step provides value

## Next Steps
- Phase 2b: Add iCloud support to DocumentRepository (separate step)
- Phase 3: ViewModels that use DocumentRepository
- Phase 4: Basic UI

## Time Estimate
- Step 1: 15 minutes
- Step 2: 45 minutes  
- Step 3: 30 minutes
**Total: 1.5 hours** (vs 3.5 hours in original plan)