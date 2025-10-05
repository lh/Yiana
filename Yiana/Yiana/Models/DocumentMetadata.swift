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

    /// Whether there's a pending text page draft to be rendered
    var hasPendingTextPage: Bool

    private enum CodingKeys: String, CodingKey {
        case id, title, created, modified, pageCount, tags, ocrCompleted, fullText, hasPendingTextPage
    }

    init(
        id: UUID,
        title: String,
        created: Date,
        modified: Date,
        pageCount: Int,
        tags: [String],
        ocrCompleted: Bool,
        fullText: String? = nil,
        hasPendingTextPage: Bool = false
    ) {
        self.id = id
        self.title = title
        self.created = created
        self.modified = modified
        self.pageCount = pageCount
        self.tags = tags
        self.ocrCompleted = ocrCompleted
        self.fullText = fullText
        self.hasPendingTextPage = hasPendingTextPage
    }

    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        created = try container.decode(Date.self, forKey: .created)
        modified = try container.decode(Date.self, forKey: .modified)
        pageCount = try container.decode(Int.self, forKey: .pageCount)
        tags = try container.decode([String].self, forKey: .tags)
        ocrCompleted = try container.decode(Bool.self, forKey: .ocrCompleted)
        fullText = try container.decodeIfPresent(String.self, forKey: .fullText)
        // Default to false for existing documents without this field
        hasPendingTextPage = try container.decodeIfPresent(Bool.self, forKey: .hasPendingTextPage) ?? false
    }
}