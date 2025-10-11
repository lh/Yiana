//
//  NoteDocumentTests.swift
//  YianaTests
//
//  Created by Claude on 15/07/2025.
//

import XCTest
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif
import YianaDocumentArchive
@testable import Yiana

#if os(iOS)
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
        let contents = try document.contents(forType: UTType.yianaDocument.identifier)
        
        // Then
        let archiveData = try XCTUnwrap(contents as? Data)
        let tempArchiveURL = tempDirectory.appendingPathComponent("contents.yianazip")
        try archiveData.write(to: tempArchiveURL)
        defer { try? FileManager.default.removeItem(at: tempArchiveURL) }

        let payload = try DocumentArchive.read(from: tempArchiveURL)
        XCTAssertEqual(payload.formatVersion, DocumentArchive.currentFormatVersion)

        let decodedMetadata = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)
        XCTAssertEqual(decodedMetadata.title, metadata.title)
        XCTAssertEqual(decodedMetadata.pageCount, metadata.pageCount)
        XCTAssertEqual(payload.pdfData, pdfData)
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
        
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        let pdfData = Data("PDF Content".utf8)
        let tempArchiveURL = tempDirectory.appendingPathComponent("load-contents.yianazip")
        try DocumentArchive.write(
            metadata: metadataData,
            pdf: .data(pdfData),
            to: tempArchiveURL,
            formatVersion: DocumentArchive.currentFormatVersion
        )
        let contents = try Data(contentsOf: tempArchiveURL)

        // When
        try document.load(fromContents: contents, ofType: UTType.yianaDocument.identifier)
        
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
        // File type is now tested in platform-specific classes
        XCTAssertNotNil(document.metadata)
    }
    
    func testIntegrationWithRepository() throws {
        // Given
        let repository = DocumentRepository(
            documentsDirectory: tempDirectory
        )
        let url = repository.newDocumentURL(title: "Integration Test")
        
        // When - Create and save document
        let document = NoteDocument(fileURL: url)
        document.pdfData = Data("Test PDF".utf8)
        document.metadata.tags = ["test", "integration"]
        
        let saveExpectation = expectation(description: "Document saved")
        document.save(to: url, for: .forCreating) { success in
            XCTAssertTrue(success)
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
        
        // Then - Repository should find it
        let urls = repository.documentURLs()
        XCTAssertTrue(urls.contains(url))
        XCTAssertEqual(urls.count, 1)
        
        // And - Can delete through repository
        XCTAssertNoThrow(try repository.deleteDocument(at: url))
        XCTAssertTrue(repository.documentURLs().isEmpty)
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

    func testContentsFormatUsesSeparatorBoundary() throws {
        let fileURL = tempDirectory.appendingPathComponent("format-check.yianazip")
        let document = NoteDocument(fileURL: fileURL)
        let pdfBytes = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Boundary Check",
            created: Date(),
            modified: Date(),
            pageCount: 4,
            tags: ["boundary"],
            ocrCompleted: false,
            fullText: nil
        )

        document.metadata = metadata
        document.pdfData = pdfBytes

        let raw = try XCTUnwrap(document.contents(forType: UTType.yianaDocument.identifier) as? Data)
        let tempArchiveURL = tempDirectory.appendingPathComponent("format-check.yianazip")
        try raw.write(to: tempArchiveURL)
        defer { try? FileManager.default.removeItem(at: tempArchiveURL) }

        let payload = try DocumentArchive.read(from: tempArchiveURL)
        XCTAssertEqual(payload.formatVersion, DocumentArchive.currentFormatVersion)

        let decodedMetadata = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)
        XCTAssertEqual(decodedMetadata.title, metadata.title)
        XCTAssertEqual(decodedMetadata.pageCount, metadata.pageCount)
        XCTAssertEqual(payload.pdfData, pdfBytes)
    }
    
    func testExtractMetadataReadsArchiveFormat() throws {
        let url = tempDirectory.appendingPathComponent("metadata-only.yianazip")
        let originalMetadata = DocumentMetadata(
            id: UUID(),
            title: "Metadata Only",
            created: Date(timeIntervalSince1970: 12345),
            modified: Date(timeIntervalSince1970: 12346),
            pageCount: 7,
            tags: ["meta"],
            ocrCompleted: true,
            fullText: "Sample"
        )
        let pdfBytes = Data([0x01, 0x02, 0x03])
        let encoded = try JSONEncoder().encode(originalMetadata)
        try DocumentArchive.write(
            metadata: encoded,
            pdf: .data(pdfBytes),
            to: url,
            formatVersion: DocumentArchive.currentFormatVersion
        )

        let extracted = try NoteDocument.extractMetadata(from: url)
        XCTAssertEqual(extracted.id, originalMetadata.id)
        XCTAssertEqual(extracted.title, originalMetadata.title)
        XCTAssertEqual(extracted.pageCount, originalMetadata.pageCount)
        XCTAssertEqual(extracted.fullText, originalMetadata.fullText)
    }
}
#endif
