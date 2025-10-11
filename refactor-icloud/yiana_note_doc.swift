//
//  NoteDocument.swift
//  Yiana
//
//  Enhanced with iCloud state monitoring and conflict resolution
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
    
    /// Callback for document state changes
    var onStateChanged: ((UIDocument.State) -> Void)?
    
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
        
        // Monitor document state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(documentStateChanged),
            name: UIDocument.stateChangedNotification,
            object: self
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
    
    // MARK: - State Monitoring
    
    @objc private func documentStateChanged() {
        print("📄 Document state changed: \(documentState.description)")
        
        if documentState.contains(.inConflict) {
            print("⚠️  Document is in conflict state")
            resolveConflicts()
        }
        
        if documentState.contains(.savingError) {
            print("❌ Document save failed")
        }
        
        if documentState.contains(.editingDisabled) {
            print("⚠️  Document editing disabled")
        }
        
        // Notify observers
        onStateChanged?(documentState)
    }
    
    // MARK: - Error Handling
    
    override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
        
        print("❌ Document error: \(error.localizedDescription)")
        
        if userInteractionPermitted {
            // Show error to user
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Document Error",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    viewController.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflicts() {
        guard documentState.contains(.inConflict) else { return }
        
        do {
            let versions = try NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL)
            
            print("📋 Found \(versions.count) conflicting versions")
            
            // Strategy: Keep current version (most recent edit), discard conflicts
            // In production, you might want to show UI for user to choose
            for version in versions {
                version.isResolved = true
                print("   Resolved conflict: \(version.modificationDate ?? Date())")
            }
            
            try NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
            print("✅ Conflicts resolved")
            
        } catch {
            print("❌ Could not resolve conflicts: \(error)")
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

// MARK: - UIDocument.State Extension

extension UIDocument.State: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        if contains(.normal) { parts.append("normal") }
        if contains(.closed) { parts.append("closed") }
        if contains(.inConflict) { parts.append("inConflict") }
        if contains(.savingError) { parts.append("savingError") }
        if contains(.editingDisabled) { parts.append("editingDisabled") }
        if contains(.progressAvailable) { parts.append("progressAvailable") }
        return parts.isEmpty ? "unknown" : parts.joined(separator: ", ")
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
    
    /// Callback for document state changes
    var onConflict: (() -> Void)?
    
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
    
    // MARK: - Conflict Resolution
    
    override func presentedItemDidChange() {
        super.presentedItemDidChange()
        
        // Check for conflicts
        if let fileURL = fileURL {
            do {
                let versions = try NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL)
                if !versions.isEmpty {
                    print("⚠️  Document has \(versions.count) conflicts")
                    resolveConflicts()
                }
            } catch {
                print("❌ Error checking for conflicts: \(error)")
            }
        }
    }
    
    private func resolveConflicts() {
        guard let fileURL = fileURL else { return }
        
        do {
            let versions = try NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL)
            
            // Strategy: Keep current version, discard conflicts
            for version in versions {
                version.isResolved = true
            }
            
            try NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
            print("✅ Conflicts resolved")
            
            onConflict?()
            
        } catch {
            print("❌ Could not resolve conflicts: \(error)")
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
#endif
