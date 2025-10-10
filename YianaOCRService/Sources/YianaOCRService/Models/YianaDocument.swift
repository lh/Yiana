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
        extractedData: Data? = nil
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
