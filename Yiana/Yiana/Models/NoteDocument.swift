//
//  NoteDocument.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

#if os(iOS)
import UIKit
import UniformTypeIdentifiers
import YianaDocumentArchive

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
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yiana")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let pdfSource: ArchiveDataSource? = pdfData.map { .data($0) }
        try DocumentArchive.write(
            metadata: metadataData,
            pdf: pdfSource,
            to: tempURL,
            formatVersion: DocumentArchive.currentFormatVersion
        )

        return try Data(contentsOf: tempURL)
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let payload = try DocumentArchive.read(from: data)

        let decoder = JSONDecoder()
        self.metadata = try decoder.decode(DocumentMetadata.self, from: payload.metadata)
        self.pdfData = payload.pdfData
    }

    // MARK: - Metadata Extraction

    /// Extract metadata from a document file without loading the full PDF
    /// This is useful for operations that need document ID or metadata without opening the entire document
    static func extractMetadata(from url: URL) throws -> DocumentMetadata {
        let (metadataData, _) = try DocumentArchive.readMetadata(from: url)
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
import YianaDocumentArchive

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
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yiana")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let pdfSource: ArchiveDataSource? = pdfData.map { .data($0) }
        try DocumentArchive.write(
            metadata: metadataData,
            pdf: pdfSource,
            to: tempURL,
            formatVersion: DocumentArchive.currentFormatVersion
        )

        return try Data(contentsOf: tempURL)
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        let payload = try DocumentArchive.read(from: data)

        let decoder = JSONDecoder()
        self.metadata = try decoder.decode(DocumentMetadata.self, from: payload.metadata)
        self.pdfData = payload.pdfData
    }
    
    func read(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try read(from: data, ofType: "yianaDocument")
    }

    // MARK: - Metadata Extraction

    /// Extract metadata from a document file without loading the full PDF
    /// This is useful for operations that need document ID or metadata without opening the entire document
    static func extractMetadata(from url: URL) throws -> DocumentMetadata {
        let (metadataData, _) = try DocumentArchive.readMetadata(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(DocumentMetadata.self, from: metadataData)
    }
}
#endif
