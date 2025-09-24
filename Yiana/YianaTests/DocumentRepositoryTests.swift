//
//  DocumentRepositoryTests.swift
//  YianaTests
//
//  Created by Claude on 15/07/2025.
//

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
        super.tearDown()
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
        // Ensure we're at the root level (not in a subfolder)
        repository.navigateToRoot()

        let url = repository.newDocumentURL(title: "Test Doc")
        XCTAssertEqual(url.pathExtension, "yianazip")
        XCTAssertTrue(url.lastPathComponent.contains("Test Doc"))
        
        // Debug the paths
        let parent = url.deletingLastPathComponent()
        print("DEBUG: Generated URL: \(url.path)")
        print("DEBUG: Parent: \(parent.path)")
        print("DEBUG: Expected testDirectory: \(testDirectory.path)")
        
        // Use standardizedFileURL to handle any path differences
        XCTAssertEqual(parent.standardizedFileURL.path, testDirectory.standardizedFileURL.path)
    }
    
    func testGenerateNewDocumentURLHandlesSpecialCharacters() {
        let url = repository.newDocumentURL(title: "Test/Doc:With:Slashes")
        XCTAssertEqual(url.pathExtension, "yianazip")
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertFalse(url.lastPathComponent.contains(":"))
        XCTAssertTrue(url.lastPathComponent.contains("Test-Doc-With-Slashes"))
    }
    
    func testGenerateNewDocumentURLIncrementsForDuplicates() throws {
        let title = "Duplicate Test"
        
        // Create first file
        let url1 = repository.newDocumentURL(title: title)
        try Data().write(to: url1)
        
        // Generate second URL - should add number
        let url2 = repository.newDocumentURL(title: title)
        XCTAssertNotEqual(url1, url2)
        XCTAssertTrue(url2.lastPathComponent.contains("Duplicate Test 1"))
        
        // Create second file
        try Data().write(to: url2)
        
        // Generate third URL - should increment number
        let url3 = repository.newDocumentURL(title: title)
        XCTAssertTrue(url3.lastPathComponent.contains("Duplicate Test 2"))
    }
    
    func testDuplicateDocument() throws {
        // Create an original document
        let originalURL = testDirectory.appendingPathComponent("Original.yianazip")
        let testData = "Test content".data(using: .utf8)!
        try testData.write(to: originalURL)

        // Duplicate the document
        let duplicateURL = try repository.duplicateDocument(at: originalURL)

        // Verify the duplicate exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicateURL.path))

        // Verify the duplicate has a different name
        XCTAssertNotEqual(originalURL, duplicateURL)
        XCTAssertTrue(duplicateURL.lastPathComponent.contains("Original Copy"))

        // Verify the content is the same
        let duplicateData = try Data(contentsOf: duplicateURL)
        XCTAssertEqual(duplicateData, testData)
    }

    func testDuplicateDocumentMultipleTimes() throws {
        // Create an original document
        let originalURL = testDirectory.appendingPathComponent("Original.yianazip")
        let testData = "Test content".data(using: .utf8)!
        try testData.write(to: originalURL)

        // First duplicate
        let duplicate1 = try repository.duplicateDocument(at: originalURL)
        XCTAssertTrue(duplicate1.lastPathComponent.contains("Original Copy.yianazip"))

        // Second duplicate
        let duplicate2 = try repository.duplicateDocument(at: originalURL)
        XCTAssertTrue(duplicate2.lastPathComponent.contains("Original Copy 1.yianazip"))

        // Third duplicate
        let duplicate3 = try repository.duplicateDocument(at: originalURL)
        XCTAssertTrue(duplicate3.lastPathComponent.contains("Original Copy 2.yianazip"))

        // Verify all exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicate1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicate2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicate3.path))
    }

    func testDuplicateDocumentInSubfolder() throws {
        // Create a subfolder
        try repository.createFolder(name: "TestFolder")
        repository.navigateToFolder("TestFolder")

        // Create an original document in the subfolder
        let originalURL = testDirectory
            .appendingPathComponent("TestFolder")
            .appendingPathComponent("Original.yianazip")
        try FileManager.default.createDirectory(
            at: testDirectory.appendingPathComponent("TestFolder"),
            withIntermediateDirectories: true
        )
        let testData = "Test content".data(using: .utf8)!
        try testData.write(to: originalURL)

        // Duplicate the document
        let duplicateURL = try repository.duplicateDocument(at: originalURL)

        // Verify the duplicate is in the same subfolder
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicateURL.path))
        XCTAssertEqual(
            duplicateURL.deletingLastPathComponent().lastPathComponent,
            "TestFolder"
        )
        XCTAssertTrue(duplicateURL.lastPathComponent.contains("Original Copy"))
    }

    func testDuplicateNonExistentDocumentThrows() {
        let nonExistentURL = testDirectory.appendingPathComponent("nonexistent.yianazip")

        XCTAssertThrowsError(try repository.duplicateDocument(at: nonExistentURL)) { error in
            // Verify it's the expected error
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }
    }

    func testDeleteDocument() throws {
        let url = testDirectory.appendingPathComponent("test.yianazip")
        try Data().write(to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        try repository.deleteDocument(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeleteNonExistentDocumentThrows() {
        let url = testDirectory.appendingPathComponent("nonexistent.yianazip")

        XCTAssertThrowsError(try repository.deleteDocument(at: url))
    }
}