import Foundation
import YianaDocumentArchive

/// Represents a Yiana document with metadata and optional PDF data
public struct YianaDocument {
    public let metadata: DocumentMetadata
    public let pdfData: Data?
    
    /// Initialize from raw document data (for reading .yianazip files)
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        
        // Try to parse as pure JSON first
        if let metadata = try? decoder.decode(DocumentMetadata.self, from: data) {
            // Successfully parsed as pure JSON - no PDF data included
            self.metadata = metadata
            self.pdfData = nil
            return
        }
        
        let payload: DocumentArchivePayload
        do {
            payload = try DocumentArchive.read(from: data)
        } catch {
            throw DocumentError.invalidFormat
        }

        do {
            self.metadata = try decoder.decode(DocumentMetadata.self, from: payload.metadata)
        } catch {
            throw DocumentError.metadataDecodingFailed
        }
        self.pdfData = payload.pdfData
    }
    
    /// Initialize with known metadata and PDF data
    public init(metadata: DocumentMetadata, pdfData: Data?) {
        self.metadata = metadata
        self.pdfData = pdfData
    }
    
    /// Save document to a file
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        let pdfSource: ArchiveDataSource?
        if let pdfData, !pdfData.isEmpty {
            pdfSource = .data(pdfData)
        } else {
            pdfSource = nil
        }
        try DocumentArchive.write(
            metadata: metadataData,
            pdf: pdfSource,
            to: url,
            formatVersion: DocumentArchive.currentFormatVersion
        )
    }
    
    /// Export document data for saving
    public func exportData() throws -> Data {
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        let pdfSource: ArchiveDataSource?
        if let pdfData, !pdfData.isEmpty {
            pdfSource = .data(pdfData)
        } else {
            pdfSource = nil
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yiana")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try DocumentArchive.write(
            metadata: metadataData,
            pdf: pdfSource,
            to: tempURL,
            formatVersion: DocumentArchive.currentFormatVersion
        )

        return try Data(contentsOf: tempURL)
    }
}

/// Tracks processing state for a single page (OCR and address extraction)
public struct PageProcessingState: Codable {
    /// Page number (1-based)
    public let pageNumber: Int

    /// Whether this page needs OCR processing
    public var needsOCR: Bool

    /// Whether this page needs address extraction (set true after OCR completes)
    public var needsExtraction: Bool

    /// When OCR was last completed for this page
    public var ocrProcessedAt: Date?

    /// When address extraction was last completed for this page
    public var addressExtractedAt: Date?

    public init(
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

/// Document metadata structure (matching the iOS app)
public struct DocumentMetadata: Codable {
    public let id: UUID
    public var title: String
    public let created: Date
    public var modified: Date
    public let pageCount: Int
    public let tags: [String]
    public var ocrCompleted: Bool
    public var fullText: String?
    
    /// Additional OCR-related metadata
    public var ocrProcessedAt: Date?
    public var ocrConfidence: Double?
    public var ocrEngineVersion: String?
    public var extractedData: Data? // JSON encoded ExtractedFormData
    public var ocrSource: String?

    /// Per-page processing state for incremental OCR and extraction
    public var pageProcessingStates: [PageProcessingState]

    public init(
        id: UUID = UUID(),
        title: String,
        created: Date = Date(),
        modified: Date = Date(),
        pageCount: Int,
        tags: [String] = [],
        ocrCompleted: Bool = false,
        fullText: String? = nil,
        ocrProcessedAt: Date? = nil,
        ocrConfidence: Double? = nil,
        ocrEngineVersion: String? = nil,
        extractedData: Data? = nil,
        ocrSource: String? = nil,
        pageProcessingStates: [PageProcessingState]? = nil
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
        self.ocrEngineVersion = ocrEngineVersion
        self.extractedData = extractedData
        self.ocrSource = ocrSource
        // Use provided states or initialize from document-level ocrCompleted
        self.pageProcessingStates = pageProcessingStates ?? (1...pageCount).map { pageNumber in
            PageProcessingState(
                pageNumber: pageNumber,
                needsOCR: !ocrCompleted,
                needsExtraction: false,
                ocrProcessedAt: ocrCompleted ? ocrProcessedAt : nil
            )
        }
    }

    // Custom decoder for migration support
    public init(from decoder: Decoder) throws {
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
        self.ocrEngineVersion = try container.decodeIfPresent(String.self, forKey: .ocrEngineVersion)
        self.extractedData = try container.decodeIfPresent(Data.self, forKey: .extractedData)
        self.ocrSource = try container.decodeIfPresent(String.self, forKey: .ocrSource)

        // Migration: if pageProcessingStates is missing, initialize based on ocrCompleted
        if let states = try container.decodeIfPresent([PageProcessingState].self, forKey: .pageProcessingStates) {
            self.pageProcessingStates = states
        } else {
            // Use local variables to avoid capturing self before initialization
            let count = self.pageCount
            let completed = self.ocrCompleted
            let processedAt = self.ocrProcessedAt
            self.pageProcessingStates = (1...count).map { pageNumber in
                PageProcessingState(
                    pageNumber: pageNumber,
                    needsOCR: !completed,
                    needsExtraction: false,
                    ocrProcessedAt: completed ? processedAt : nil
                )
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, created, modified, pageCount, tags, ocrCompleted, fullText
        case ocrProcessedAt, ocrConfidence, ocrEngineVersion, extractedData, ocrSource
        case pageProcessingStates
    }
}

/// Document-related errors
public enum DocumentError: Error, LocalizedError {
    case invalidFormat
    case metadataDecodingFailed
    case pdfExtractionFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid document format"
        case .metadataDecodingFailed:
            return "Failed to decode document metadata"
        case .pdfExtractionFailed:
            return "Failed to extract PDF data"
        }
    }
}
