//
//  DocumentMetadataTests.swift
//  YianaTests
//
//  Created by Claude on 15/07/2025.
//

import XCTest
@testable import Yiana

final class DocumentMetadataTests: XCTestCase {
    
    func testDocumentMetadataInitialization() {
        // Given
        let id = UUID()
        let title = "Test Document"
        let created = Date()
        let modified = Date()
        let pageCount = 5
        let tags = ["important", "work"]
        let ocrCompleted = true
        let fullText = "This is the OCR text content"
        
        // When
        let metadata = DocumentMetadata(
            id: id,
            title: title,
            created: created,
            modified: modified,
            pageCount: pageCount,
            tags: tags,
            ocrCompleted: ocrCompleted,
            fullText: fullText
        )
        
        // Then
        XCTAssertEqual(metadata.id, id)
        XCTAssertEqual(metadata.title, title)
        XCTAssertEqual(metadata.created, created)
        XCTAssertEqual(metadata.modified, modified)
        XCTAssertEqual(metadata.pageCount, pageCount)
        XCTAssertEqual(metadata.tags, tags)
        XCTAssertEqual(metadata.ocrCompleted, ocrCompleted)
        XCTAssertEqual(metadata.fullText, fullText)
    }
    
    func testDocumentMetadataInitializationWithNilFullText() {
        // Given
        let id = UUID()
        let title = "Test Document"
        let created = Date()
        let modified = Date()
        let pageCount = 3
        let tags = ["draft"]
        let ocrCompleted = false
        
        // When
        let metadata = DocumentMetadata(
            id: id,
            title: title,
            created: created,
            modified: modified,
            pageCount: pageCount,
            tags: tags,
            ocrCompleted: ocrCompleted,
            fullText: nil
        )
        
        // Then
        XCTAssertNil(metadata.fullText)
        XCTAssertFalse(metadata.ocrCompleted)
    }
    
    func testDocumentMetadataEquatable() {
        // Given
        let id = UUID()
        let created = Date()
        let modified = Date()
        
        let metadata1 = DocumentMetadata(
            id: id,
            title: "Document",
            created: created,
            modified: modified,
            pageCount: 2,
            tags: ["test"],
            ocrCompleted: false,
            fullText: nil
        )
        
        let metadata2 = DocumentMetadata(
            id: id,
            title: "Document",
            created: created,
            modified: modified,
            pageCount: 2,
            tags: ["test"],
            ocrCompleted: false,
            fullText: nil
        )
        
        let metadata3 = DocumentMetadata(
            id: UUID(), // Different ID
            title: "Document",
            created: created,
            modified: modified,
            pageCount: 2,
            tags: ["test"],
            ocrCompleted: false,
            fullText: nil
        )
        
        // Then
        XCTAssertEqual(metadata1, metadata2)
        XCTAssertNotEqual(metadata1, metadata3)
    }
    
    func testDocumentMetadataCodable() throws {
        // Given
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Codable Test",
            created: Date(),
            modified: Date(),
            pageCount: 10,
            tags: ["test", "codable"],
            ocrCompleted: true,
            fullText: "Some text content"
        )
        
        // When - Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        
        // When - Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedMetadata = try decoder.decode(DocumentMetadata.self, from: data)
        
        // Then
        XCTAssertEqual(metadata.id, decodedMetadata.id)
        XCTAssertEqual(metadata.title, decodedMetadata.title)
        XCTAssertEqual(metadata.pageCount, decodedMetadata.pageCount)
        XCTAssertEqual(metadata.tags, decodedMetadata.tags)
        XCTAssertEqual(metadata.ocrCompleted, decodedMetadata.ocrCompleted)
        XCTAssertEqual(metadata.fullText, decodedMetadata.fullText)
        
        // Date comparison with tolerance due to encoding/decoding
        XCTAssertEqual(metadata.created.timeIntervalSince1970, decodedMetadata.created.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(metadata.modified.timeIntervalSince1970, decodedMetadata.modified.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testDocumentMetadataEmptyTags() {
        // Given/When
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "No Tags",
            created: Date(),
            modified: Date(),
            pageCount: 1,
            tags: [],
            ocrCompleted: false,
            fullText: nil
        )
        
        // Then
        XCTAssertTrue(metadata.tags.isEmpty)
    }
}