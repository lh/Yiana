//
//  DocumentMetadata.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation

/// Metadata for a document in the Yiana app
struct DocumentMetadata: Codable, Equatable {
    /// Unique identifier for the document
    let id: UUID
    
    /// Document title
    var title: String
    
    /// Date when the document was created
    let created: Date
    
    /// Date when the document was last modified
    var modified: Date
    
    /// Number of pages in the PDF document
    var pageCount: Int
    
    /// Tags associated with the document for organization
    var tags: [String]
    
    /// Whether OCR processing has been completed
    var ocrCompleted: Bool

    /// Full text extracted from the document via OCR
    var fullText: String?
    
    init(
        id: UUID,
        title: String,
        created: Date,
        modified: Date,
        pageCount: Int,
        tags: [String],
        ocrCompleted: Bool,
        fullText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.created = created
        self.modified = modified
        self.pageCount = pageCount
        self.tags = tags
        self.ocrCompleted = ocrCompleted
        self.fullText = fullText
    }
}