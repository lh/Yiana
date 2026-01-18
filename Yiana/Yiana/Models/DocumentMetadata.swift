//
//  DocumentMetadata.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation

/// Tracks processing state for a single page (OCR and address extraction)
struct PageProcessingState: Codable, Equatable {
    /// Page number (1-based)
    let pageNumber: Int

    /// Whether this page needs OCR processing
    var needsOCR: Bool

    /// Whether this page needs address extraction (set true after OCR completes)
    var needsExtraction: Bool

    /// When OCR was last completed for this page
    var ocrProcessedAt: Date?

    /// When address extraction was last completed for this page
    var addressExtractedAt: Date?

    init(
        pageNumber: Int,
        needsOCR: Bool = true,
        needsExtraction: Bool = false,
        ocrProcessedAt: Date? = nil,
        addressExtractedAt: Date? = nil
    ) {
        self.pageNumber = pageNumber
            self.needsOCR = needsOCR
        self.needsExtraction = needsExtraction
        self.ocrProcessedAt = ocrProcessedAt
        self.addressExtractedAt = addressExtractedAt
    }
}

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

    /// Full text extracted from the document via OCR or embedded in the PDF
    var fullText: String?

    /// When OCR (or embedded text detection) last completed
    var ocrProcessedAt: Date?

    /// Confidence returned by OCR service (0…1)
    var ocrConfidence: Double?

    /// Source of the text content (embedded or OCR engine)
    var ocrSource: OCRSource?

    /// Whether the document has an in-progress text page draft
    var hasPendingTextPage: Bool

    /// Per-page processing state for incremental OCR and extraction
    var pageProcessingStates: [PageProcessingState]

    init(
        id: UUID,
        title: String,
        created: Date,
        modified: Date,
        pageCount: Int,
        tags: [String],
        ocrCompleted: Bool,
        fullText: String? = nil,
        ocrProcessedAt: Date? = nil,
        ocrConfidence: Double? = nil,
        ocrSource: OCRSource? = nil,
        hasPendingTextPage: Bool = false,
        pageProcessingStates: [PageProcessingState] = []
    ) {
        self.id = id
        self.title = title
        self.created = created
        self.modified = modified
        self.pageCount = pageCount
        self.tags = tags
        self.ocrCompleted = ocrCompleted
        self.fullText = fullText
        self.ocrProcessedAt = ocrProcessedAt
        self.ocrConfidence = ocrConfidence
        self.ocrSource = ocrSource
        self.hasPendingTextPage = hasPendingTextPage
        self.pageProcessingStates = pageProcessingStates
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
        case ocrProcessedAt
        case ocrConfidence
        case ocrSource
        case hasPendingTextPage
        case pageProcessingStates
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
        self.ocrProcessedAt = try container.decodeIfPresent(Date.self, forKey: .ocrProcessedAt)
        self.ocrConfidence = try container.decodeIfPresent(Double.self, forKey: .ocrConfidence)
        self.ocrSource = try container.decodeIfPresent(OCRSource.self, forKey: .ocrSource)
        self.hasPendingTextPage = try container.decodeIfPresent(Bool.self, forKey: .hasPendingTextPage) ?? false

        // Migration: if pageProcessingStates is missing, initialize based on ocrCompleted
        if let states = try container.decodeIfPresent([PageProcessingState].self, forKey: .pageProcessingStates) {
            self.pageProcessingStates = states
        } else {
            // Existing document without page-level tracking - initialize from document-level state
            // Use local variables to avoid capturing self before initialization
            let count = self.pageCount
            let completed = self.ocrCompleted
            let processedAt = self.ocrProcessedAt
            // Handle documents with 0 pages (1...0 would crash)
            self.pageProcessingStates = count > 0 ? (1...count).map { pageNumber in
                PageProcessingState(
                    pageNumber: pageNumber,
                    needsOCR: !completed,
                    needsExtraction: false,
                    ocrProcessedAt: completed ? processedAt : nil,
                    addressExtractedAt: nil
                )
            } : []
        }
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
        try container.encodeIfPresent(ocrProcessedAt, forKey: .ocrProcessedAt)
        try container.encodeIfPresent(ocrConfidence, forKey: .ocrConfidence)
        try container.encodeIfPresent(ocrSource, forKey: .ocrSource)
        if hasPendingTextPage {
            try container.encode(true, forKey: .hasPendingTextPage)
        }
        if !pageProcessingStates.isEmpty {
            try container.encode(pageProcessingStates, forKey: .pageProcessingStates)
        }
    }
}

enum OCRSource: String, Codable {
    case embedded
    case service

    var displayName: String {
        switch self {
        case .embedded:
            return "Embedded Text"
        case .service:
            return "OCR Service"
        }
    }
}
