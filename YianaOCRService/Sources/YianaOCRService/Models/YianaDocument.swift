import Foundation

/// Represents a Yiana document with metadata and optional PDF data
public struct YianaDocument {
    public let metadata: DocumentMetadata
    public let pdfData: Data?
    
    /// Initialize from raw document data (for reading .yianazip files)
    public init(data: Data) throws {
        // Parse the document format
        // The document can be in two formats:
        // 1. Pure JSON (when saved after OCR processing or without PDF)
        // 2. Binary format: [metadata JSON][separator: 0xFF 0xFF 0xFF 0xFF][PDF data]
        
        // Use default decoder (same as iOS app - numeric dates as TimeInterval since 2001)
        let decoder = JSONDecoder()
        
        // Try to parse as pure JSON first
        if let metadata = try? decoder.decode(DocumentMetadata.self, from: data) {
            // Successfully parsed as pure JSON - no PDF data included
            self.metadata = metadata
            self.pdfData = nil
            return
        }
        
        // If not pure JSON, try the binary format with separator
        let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
        guard let separatorRange = data.range(of: separator) else {
            // No separator found - might be corrupted or unknown format
            throw DocumentError.invalidFormat
        }
        
        // Extract metadata
        let metadataData = data.subdata(in: 0..<separatorRange.lowerBound)
        self.metadata = try decoder.decode(DocumentMetadata.self, from: metadataData)
        
        // Extract PDF data if present
        let pdfDataStart = separatorRange.upperBound
        if pdfDataStart < data.count {
            self.pdfData = data.subdata(in: pdfDataStart..<data.count)
        } else {
            self.pdfData = nil
        }
    }
    
    /// Initialize with known metadata and PDF data
    public init(metadata: DocumentMetadata, pdfData: Data?) {
        self.metadata = metadata
        self.pdfData = pdfData
    }
    
    /// Save document to a file
    public func save(to url: URL) throws {
        // Use default encoder (same as iOS app - numeric dates as TimeInterval since 2001)
        let encoder = JSONEncoder()
        
        // If there's no PDF data, save as pure JSON (matches iOS app after OCR)
        if pdfData == nil || pdfData?.isEmpty == true {
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: url)
        } else {
            // Save in binary format with separator
            let metadataData = try encoder.encode(metadata)
            
            var documentData = Data()
            documentData.append(metadataData)
            documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
            if let pdfData = pdfData {
                documentData.append(pdfData)
            }
            
            try documentData.write(to: url)
        }
    }
    
    /// Export document data for saving
    public func exportData() throws -> Data {
        // Use default encoder (same as iOS app - numeric dates as TimeInterval since 2001)
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        
        var documentData = Data()
        documentData.append(metadataData)
        documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
        if let pdfData = pdfData {
            documentData.append(pdfData)
        }
        
        return documentData
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
            return "Invalid document format - missing separator"
        case .metadataDecodingFailed:
            return "Failed to decode document metadata"
        case .pdfExtractionFailed:
            return "Failed to extract PDF data"
        }
    }
}