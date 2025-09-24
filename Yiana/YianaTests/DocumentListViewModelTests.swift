//
//  DocumentListViewModelTests.swift
//  YianaTests
//
//  Created by Claude on 15/07/2025.
//

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
        XCTAssertNil(viewModel.errorMessage)
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
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadDocumentsEmpty() async {
        // Load documents from empty directory
        await viewModel.loadDocuments()
        
        // Verify
        XCTAssertTrue(viewModel.documentURLs.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testDocumentsSortedByName() async throws {
        // Create test files
        let urlB = repository.newDocumentURL(title: "B Document")
        let urlA = repository.newDocumentURL(title: "A Document")
        let urlC = repository.newDocumentURL(title: "C Document")
        try Data().write(to: urlB)
        try Data().write(to: urlA)
        try Data().write(to: urlC)
        
        // Load documents
        await viewModel.loadDocuments()
        
        // Verify sorted order
        XCTAssertEqual(viewModel.documentURLs.count, 3)
        XCTAssertEqual(viewModel.documentURLs[0], urlA)
        XCTAssertEqual(viewModel.documentURLs[1], urlB)
        XCTAssertEqual(viewModel.documentURLs[2], urlC)
    }
    
    func testCreateNewDocument() async {
        // Create new document
        let url = await viewModel.createNewDocument(title: "New Doc")
        
        // Verify URL was generated
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.pathExtension, "yianazip")
        XCTAssertTrue(url?.lastPathComponent.contains("New Doc") ?? false)
        
        // Note: ViewModel doesn't create the file or add to list
        XCTAssertTrue(viewModel.documentURLs.isEmpty)
    }
    
    func testDeleteDocument() async throws {
        // Create test file
        let url = repository.newDocumentURL(title: "To Delete")
        try Data().write(to: url)
        await viewModel.loadDocuments()
        XCTAssertEqual(viewModel.documentURLs.count, 1)
        
        // Delete
        try await viewModel.deleteDocument(at: url)
        
        // Verify removed from list
        XCTAssertFalse(viewModel.documentURLs.contains(url))
        XCTAssertTrue(viewModel.documentURLs.isEmpty)
        
        // Verify file is gone
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    
    func testDeleteNonExistentDocument() async {
        let url = testDirectory.appendingPathComponent("nonexistent.yianazip")
        
        // Should throw error
        do {
            try await viewModel.deleteDocument(at: url)
            XCTFail("Should have thrown error")
        } catch {
            // Expected
            XCTAssertNotNil(viewModel.errorMessage)
        }
    }
    
    func testRefresh() async throws {
        // Load initial (empty)
        await viewModel.loadDocuments()
        XCTAssertTrue(viewModel.documentURLs.isEmpty)
        
        // Create file outside of view model
        let url = repository.newDocumentURL(title: "New File")
        try Data().write(to: url)
        
        // Refresh should find it
        await viewModel.refresh()
        XCTAssertEqual(viewModel.documentURLs.count, 1)
        XCTAssertTrue(viewModel.documentURLs.contains(url))
    }

    
    func testSortByDateModified() async throws {
        // Create test files with different modification dates
        let url1 = repository.newDocumentURL(title: "First")
        let url2 = repository.newDocumentURL(title: "Second")
        let url3 = repository.newDocumentURL(title: "Third")
        
        // Create files with time delays
        try Data("content1".data(using: .utf8)!).write(to: url1)
        Thread.sleep(forTimeInterval: 0.1)
        try Data("content2".data(using: .utf8)!).write(to: url2)
        Thread.sleep(forTimeInterval: 0.1)
        try Data("content3".data(using: .utf8)!).write(to: url3)
        
        // Load and sort by date modified (newest first)
        await viewModel.loadDocuments()
        await viewModel.sortDocuments(by: .dateModified, ascending: false)
        
        // Verify order - newest first
        XCTAssertEqual(viewModel.documentURLs.count, 3)
        XCTAssertEqual(viewModel.documentURLs[0], url3)
        XCTAssertEqual(viewModel.documentURLs[1], url2)
        XCTAssertEqual(viewModel.documentURLs[2], url1)
    }
    
    func testSortByDateCreated() async throws {
        // Create test files
        let url1 = repository.newDocumentURL(title: "Alpha")
        let url2 = repository.newDocumentURL(title: "Beta")
        let url3 = repository.newDocumentURL(title: "Gamma")
        
        try Data().write(to: url1)
        Thread.sleep(forTimeInterval: 0.1)
        try Data().write(to: url2)
        Thread.sleep(forTimeInterval: 0.1)
        try Data().write(to: url3)
        
        // Load and sort by date created (newest first)
        await viewModel.loadDocuments()
        await viewModel.sortDocuments(by: .dateCreated, ascending: false)
        
        // Verify order
        XCTAssertEqual(viewModel.documentURLs.count, 3)
        XCTAssertEqual(viewModel.documentURLs[0], url3)
        XCTAssertEqual(viewModel.documentURLs[1], url2)
        XCTAssertEqual(viewModel.documentURLs[2], url1)
    }
    
    func testSortBySize() async throws {
        // Create test files with different sizes
        let url1 = repository.newDocumentURL(title: "Small")
        let url2 = repository.newDocumentURL(title: "Medium")
        let url3 = repository.newDocumentURL(title: "Large")
        
        try Data("x".data(using: .utf8)!).write(to: url1)  // 1 byte
        try Data("medium content".data(using: .utf8)!).write(to: url2)  // 14 bytes
        try Data("this is much larger content with more data".data(using: .utf8)!).write(to: url3)  // 43 bytes
        
        // Load and sort by size (largest first)
        await viewModel.loadDocuments()
        await viewModel.sortDocuments(by: .size, ascending: false)
        
        // Verify order
        XCTAssertEqual(viewModel.documentURLs.count, 3)
        XCTAssertEqual(viewModel.documentURLs[0], url3)  // Largest
        XCTAssertEqual(viewModel.documentURLs[1], url2)  // Medium
        XCTAssertEqual(viewModel.documentURLs[2], url1)  // Smallest
    }
    
    func testSortByTitle() async throws {
        // Create test files
        let urlZ = repository.newDocumentURL(title: "Zebra")
        let urlA = repository.newDocumentURL(title: "Apple")
        let urlM = repository.newDocumentURL(title: "Mango")
        
        try Data().write(to: urlZ)
        try Data().write(to: urlA)
        try Data().write(to: urlM)
        
        // Load documents (default sort is by title)
        await viewModel.loadDocuments()
        
        // Explicitly sort by title
        await viewModel.sortDocuments(by: .title)
        
        // Verify alphabetical order
        XCTAssertEqual(viewModel.documentURLs.count, 3)
        XCTAssertEqual(viewModel.documentURLs[0], urlA)
        XCTAssertEqual(viewModel.documentURLs[1], urlM)
        XCTAssertEqual(viewModel.documentURLs[2], urlZ)
    }
    
    func testToggleSortOrder() async throws {
        // Create test files
        let urlA = repository.newDocumentURL(title: "A Document")
        let urlB = repository.newDocumentURL(title: "B Document")
        let urlC = repository.newDocumentURL(title: "C Document")
        
        try Data().write(to: urlA)
        try Data().write(to: urlB)
        try Data().write(to: urlC)
        
        // Load and sort ascending
        await viewModel.loadDocuments()
        await viewModel.sortDocuments(by: .title, ascending: true)
        
        // Verify ascending order
        XCTAssertEqual(viewModel.documentURLs[0], urlA)
        XCTAssertEqual(viewModel.documentURLs[2], urlC)
        
        // Sort descending
        await viewModel.sortDocuments(by: .title, ascending: false)
        
        // Verify descending order
        XCTAssertEqual(viewModel.documentURLs[0], urlC)
        XCTAssertEqual(viewModel.documentURLs[2], urlA)
    }
}