//
//  NoteDocument.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

#if os(iOS)
import UIKit
import UniformTypeIdentifiers

/// A document containing a PDF and associated metadata
class NoteDocument: UIDocument {
    
    // MARK: - Properties
    
    /// The PDF data for the document
    var pdfData: Data?
    
    /// The metadata associated with this document
    var metadata: DocumentMetadata
    
    // MARK: - Initialization
    
    override init(fileURL url: URL) {
        self.metadata = DocumentMetadata(
            id: UUID(),
            title: url.deletingPathExtension().lastPathComponent,
            created: Date(),
            modified: Date(),
            pageCount: 0,
            tags: [],
            ocrCompleted: false,
            fullText: nil,
            hasPendingTextPage: false
        )
        super.init(fileURL: url)
    }
    
    // MARK: - UIDocument Overrides
    
    override var fileType: String? {
        return UTType.yianaDocument.identifier
    }
    
    override func contents(forType typeName: String) throws -> Any {
        // Create a simple data structure combining metadata and PDF
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        
        var contents = Data()
        contents.append(metadataData)
        contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
        contents.append(pdfData ?? Data())
        
        return contents
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Find the separator
        let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
        guard let separatorRange = data.range(of: separator) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Extract metadata and PDF data
        let metadataData = data.subdata(in: 0..<separatorRange.lowerBound)
        let pdfDataStart = separatorRange.upperBound
        
        let decoder = JSONDecoder()
        self.metadata = try decoder.decode(DocumentMetadata.self, from: metadataData)
        
        if pdfDataStart < data.count {
            self.pdfData = data.subdata(in: pdfDataStart..<data.count)
        } else {
            self.pdfData = nil
        }
    }

    // MARK: - Metadata Extraction

    /// Extract metadata from a document file without loading the full PDF
    /// This is useful for operations that need document ID or metadata without opening the entire document
    static func extractMetadata(from url: URL) throws -> DocumentMetadata {
        let data = try Data(contentsOf: url)

        // Find the separator between metadata and PDF data
        let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
        guard let separatorRange = data.range(of: separator) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Extract and decode just the metadata portion
        let metadataData = data.subdata(in: 0..<separatorRange.lowerBound)
        let decoder = JSONDecoder()
        return try decoder.decode(DocumentMetadata.self, from: metadataData)
    }
}

// MARK: - UTType Extension

extension UTType {
    static let yianaDocument = UTType(exportedAs: "com.vitygas.yiana.document")
}
#endif

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// A document containing a PDF and associated metadata (macOS version)
class NoteDocument: NSDocument {
    
    // MARK: - Properties
    
    /// The PDF data for the document
    var pdfData: Data?
    
    /// The metadata associated with this document
    var metadata: DocumentMetadata
    
    // MARK: - Initialization
    
    override init() {
        self.metadata = DocumentMetadata(
            id: UUID(),
            title: "Untitled",
            created: Date(),
            modified: Date(),
            pageCount: 0,
            tags: [],
            ocrCompleted: false,
            fullText: nil,
            hasPendingTextPage: false
        )
        super.init()
    }
    
    convenience init(fileURL: URL) {
        self.init()
        self.fileURL = fileURL
        self.metadata.title = fileURL.deletingPathExtension().lastPathComponent
    }
    
    // MARK: - NSDocument Overrides
    
    override class var autosavesInPlace: Bool {
        return true
    }
    
    override func makeWindowControllers() {
        // No window controllers for this document
    }
    
    override func data(ofType typeName: String) throws -> Data {
        // Create a simple data structure combining metadata and PDF
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        
        var contents = Data()
        contents.append(metadataData)
        contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
        contents.append(pdfData ?? Data())
        
        return contents
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        // Find the separator
        let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
        guard let separatorRange = data.range(of: separator) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Extract metadata and PDF data
        let metadataData = data.subdata(in: 0..<separatorRange.lowerBound)
        let pdfDataStart = separatorRange.upperBound
        
        let decoder = JSONDecoder()
        self.metadata = try decoder.decode(DocumentMetadata.self, from: metadataData)
        
        if pdfDataStart < data.count {
            self.pdfData = data.subdata(in: pdfDataStart..<data.count)
        } else {
            self.pdfData = nil
        }
    }
    
    func read(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try read(from: data, ofType: "yianaDocument")
    }

    // MARK: - Metadata Extraction

    /// Extract metadata from a document file without loading the full PDF
    /// This is useful for operations that need document ID or metadata without opening the entire document
    static func extractMetadata(from url: URL) throws -> DocumentMetadata {
        let data = try Data(contentsOf: url)

        // Find the separator between metadata and PDF data
        let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
        guard let separatorRange = data.range(of: separator) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Extract and decode just the metadata portion
        let metadataData = data.subdata(in: 0..<separatorRange.lowerBound)
        let decoder = JSONDecoder()
        return try decoder.decode(DocumentMetadata.self, from: metadataData)
    }
}
#endif
