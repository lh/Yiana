//
//  NoteDocumentTests.swift
//  YianaTests
//
//  Created by Claude on 15/07/2025.
//

import XCTest
import UniformTypeIdentifiers
@testable import Yiana

final class NoteDocumentTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testNoteDocumentInitialization() {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.yianazip")
        
        // When
        let document = NoteDocument(fileURL: fileURL)
        
        // Then
        XCTAssertEqual(document.fileURL, fileURL)
        XCTAssertNotNil(document.metadata)
        XCTAssertNil(document.pdfData)
    }
    
    func testNoteDocumentStorePDFData() {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.yianazip")
        let document = NoteDocument(fileURL: fileURL)
        let pdfData = Data("Mock PDF Data".utf8)
        
        // When
        document.pdfData = pdfData
        
        // Then
        XCTAssertEqual(document.pdfData, pdfData)
    }
    
    func testNoteDocumentStoreAndRetrieveMetadata() {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.yianazip")
        let document = NoteDocument(fileURL: fileURL)
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Test Document",
            created: Date(),
            modified: Date(),
            pageCount: 3,
            tags: ["test", "sample"],
            ocrCompleted: false,
            fullText: nil
        )
        
        // When
        document.metadata = metadata
        
        // Then
        XCTAssertEqual(document.metadata.id, metadata.id)
        XCTAssertEqual(document.metadata.title, metadata.title)
        XCTAssertEqual(document.metadata.pageCount, metadata.pageCount)
        XCTAssertEqual(document.metadata.tags, metadata.tags)
    }
    
    func testNoteDocumentContentsForType() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.yianazip")
        let document = NoteDocument(fileURL: fileURL)
        let pdfData = Data("Mock PDF Data".utf8)
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Test Document",
            created: Date(),
            modified: Date(),
            pageCount: 1,
            tags: ["test"],
            ocrCompleted: false,
            fullText: nil
        )
        
        document.pdfData = pdfData
        document.metadata = metadata
        
        // When
        let contents = try document.contents(forType: .yianaDocument)
        
        // Then
        XCTAssertNotNil(contents)
        XCTAssertTrue(contents is Data)
    }
    
    func testNoteDocumentLoadFromContents() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.yianazip")
        let document = NoteDocument(fileURL: fileURL)
        
        // Create a mock zip data structure
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Loaded Document",
            created: Date(),
            modified: Date(),
            pageCount: 2,
            tags: ["loaded"],
            ocrCompleted: true,
            fullText: "Sample text"
        )
        
        // Create mock contents (this would normally be a zip file)
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        let pdfData = Data("PDF Content".utf8)
        
        // For this test, we'll use a simple data structure
        // In the real implementation, this would be a proper zip file
        var contents = Data()
        contents.append(metadataData)
        contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
        contents.append(pdfData)
        
        // When
        try document.load(fromContents: contents, ofType: .yianaDocument)
        
        // Then
        XCTAssertNotNil(document.pdfData)
        XCTAssertEqual(document.metadata.title, "Loaded Document")
        XCTAssertEqual(document.metadata.pageCount, 2)
        XCTAssertEqual(document.metadata.tags, ["loaded"])
    }
    
    func testNoteDocumentFileType() {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.yianazip")
        let document = NoteDocument(fileURL: fileURL)
        
        // Then
        XCTAssertEqual(document.fileType, UTType.yianaDocument.identifier)
    }
    
    func testNoteDocumentSaveAndLoad() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.yianazip")
        let originalDocument = NoteDocument(fileURL: fileURL)
        let pdfData = Data("Test PDF Content".utf8)
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Save and Load Test",
            created: Date(),
            modified: Date(),
            pageCount: 5,
            tags: ["save", "load", "test"],
            ocrCompleted: true,
            fullText: "Full text content"
        )
        
        originalDocument.pdfData = pdfData
        originalDocument.metadata = metadata
        
        // When - Save
        let expectation = self.expectation(description: "Document saved")
        originalDocument.save(to: fileURL, for: .forCreating) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
        
        // When - Load
        let loadedDocument = NoteDocument(fileURL: fileURL)
        let loadExpectation = self.expectation(description: "Document loaded")
        loadedDocument.open { success in
            XCTAssertTrue(success)
            loadExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
        
        // Then
        XCTAssertEqual(loadedDocument.pdfData, pdfData)
        XCTAssertEqual(loadedDocument.metadata.title, metadata.title)
        XCTAssertEqual(loadedDocument.metadata.pageCount, metadata.pageCount)
        XCTAssertEqual(loadedDocument.metadata.tags, metadata.tags)
        XCTAssertEqual(loadedDocument.metadata.fullText, metadata.fullText)
    }
}

// Extension to define the custom UTType for our documents
extension UTType {
    static let yianaDocument = UTType(exportedAs: "com.vitygas.yiana.document")
}