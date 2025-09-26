//
//  SearchCrashFixTests.swift
//  YianaTests
//

import XCTest
@testable import Yiana

@MainActor
class SearchCrashFixTests: XCTestCase {
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
    
    func testSearchDebouncing() async throws {
        // Create test documents
        let url1 = repository.newDocumentURL(title: "Test Document 1")
        let url2 = repository.newDocumentURL(title: "Another File")
        try Data().write(to: url1)
        try Data().write(to: url2)
        
        await viewModel.loadDocuments()
        
        // Rapid search updates (simulating fast typing)
        await viewModel.filterDocuments(searchText: "T")
        await viewModel.filterDocuments(searchText: "Te")
        await viewModel.filterDocuments(searchText: "Tes")
        await viewModel.filterDocuments(searchText: "Test")
        
        // Wait for debounce to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should only show matching document
        XCTAssertEqual(viewModel.documentURLs.count, 1)
        XCTAssertTrue(viewModel.documentURLs.contains(url1))
    }
    
    func testSearchCancellation() async throws {
        // Create many test documents to simulate heavy load
        var urls: [URL] = []
        for i in 1...20 {
            let url = repository.newDocumentURL(title: "Document \(i)")
            try Data().write(to: url)
            urls.append(url)
        }
        
        await viewModel.loadDocuments()
        
        // Start search then immediately change it
        await viewModel.filterDocuments(searchText: "Document")
        // Immediately change search
        await viewModel.filterDocuments(searchText: "1")
        
        // Wait for search to complete
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Should only show documents containing "1"
        let expectedCount = urls.filter { 
            $0.deletingPathExtension().lastPathComponent.contains("1") 
        }.count
        XCTAssertEqual(viewModel.documentURLs.count, expectedCount)
    }
    
    func testEmptySearchResetsImmediately() async throws {
        let url1 = repository.newDocumentURL(title: "Test Document")
        let url2 = repository.newDocumentURL(title: "Another File")
        try Data().write(to: url1)
        try Data().write(to: url2)
        
        await viewModel.loadDocuments()
        
        // Filter documents
        await viewModel.filterDocuments(searchText: "Test")
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(viewModel.documentURLs.count, 1)
        
        // Clear search - should reset immediately
        await viewModel.filterDocuments(searchText: "")
        // No delay needed for empty search
        XCTAssertEqual(viewModel.documentURLs.count, 2)
    }
    
    func testSearchProgressIndicator() async throws {
        await viewModel.loadDocuments()
        
        XCTAssertFalse(viewModel.isSearchInProgress)
        
        // Start a search
        let searchTask = Task {
            await viewModel.filterDocuments(searchText: "test")
        }
        
        // Give it a moment to start
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Wait for search to complete
        await searchTask.value
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Progress indicator should be off when done
        XCTAssertFalse(viewModel.isSearchInProgress)
    }
}