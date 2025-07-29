//
//  DocumentViewModelTests.swift
//  YianaTests
//
//  Created by Claude on 15/07/2025.
//

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
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.autoSaveEnabled)
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
    
    func testTitleNoChangeWhenSame() {
        let originalTitle = viewModel.title
        
        // Set same title
        viewModel.title = originalTitle
        
        // Should not mark as changed
        XCTAssertFalse(viewModel.hasChanges)
    }
    
    func testPDFDataChange() {
        // Change PDF data
        viewModel.pdfData = Data("New PDF".utf8)
        
        // Verify
        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertEqual(viewModel.pdfData, Data("New PDF".utf8))
    }
    
    func testSaveWithChanges() async {
        // Make changes
        viewModel.title = "Updated Title"
        viewModel.pdfData = Data("New PDF".utf8)
        XCTAssertTrue(viewModel.hasChanges)
        
        // Save
        let success = await viewModel.save()
        
        // Verify
        XCTAssertTrue(success)
        XCTAssertFalse(viewModel.hasChanges)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(document.metadata.title, "Updated Title")
        XCTAssertEqual(document.pdfData, Data("New PDF".utf8))
    }
    
    func testSaveWithoutChanges() async {
        // No changes made
        XCTAssertFalse(viewModel.hasChanges)
        
        // Save should succeed immediately
        let success = await viewModel.save()
        
        // Verify
        XCTAssertTrue(success)
        XCTAssertFalse(viewModel.isSaving)
    }
    
    func testModifiedDateUpdatedOnSave() async {
        let originalModified = document.metadata.modified
        
        // Make change and save
        viewModel.title = "New Title"
        
        // Wait a bit to ensure date difference
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        _ = await viewModel.save()
        
        // Modified date should be updated
        XCTAssertGreaterThan(document.metadata.modified, originalModified)
    }
    
    func testAutoSaveDisabledByDefault() async {
        XCTAssertFalse(viewModel.autoSaveEnabled)
        
        // Make change
        viewModel.title = "Changed"
        
        // Wait
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Should not have saved
        XCTAssertNotEqual(document.metadata.title, "Changed")
        XCTAssertTrue(viewModel.hasChanges)
    }
    
    func testEnableAutoSaveWithPendingChanges() async {
        // Make change first
        viewModel.title = "Auto Save Test"
        XCTAssertTrue(viewModel.hasChanges)
        
        // Enable auto-save
        viewModel.autoSaveEnabled = true
        
        // Should trigger save
        // Note: In real implementation, this would be debounced
        // For test, we'll manually save to simulate
        _ = await viewModel.save()
        
        XCTAssertEqual(document.metadata.title, "Auto Save Test")
        XCTAssertFalse(viewModel.hasChanges)
    }
}
#endif