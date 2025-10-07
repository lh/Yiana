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

    /// Whether the document has an in-progress text page draft
    var hasPendingTextPage: Bool

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

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case created
        case modified
        case pageCount
        case tags
        case ocrCompleted
        case fullText
        case hasPendingTextPage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.created = try container.decode(Date.self, forKey: .created)
        self.modified = try container.decode(Date.self, forKey: .modified)
        self.pageCount = try container.decode(Int.self, forKey: .pageCount)
        self.tags = try container.decode([String].self, forKey: .tags)
        self.ocrCompleted = try container.decode(Bool.self, forKey: .ocrCompleted)
        self.fullText = try container.decodeIfPresent(String.self, forKey: .fullText)
        self.hasPendingTextPage = try container.decodeIfPresent(Bool.self, forKey: .hasPendingTextPage) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(created, forKey: .created)
        try container.encode(modified, forKey: .modified)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(tags, forKey: .tags)
        try container.encode(ocrCompleted, forKey: .ocrCompleted)
        try container.encodeIfPresent(fullText, forKey: .fullText)
        if hasPendingTextPage {
            try container.encode(true, forKey: .hasPendingTextPage)
        }
    }
}
