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
}