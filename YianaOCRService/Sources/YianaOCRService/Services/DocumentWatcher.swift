import Foundation
import Logging

/// Watches for new or modified Yiana documents in the iCloud Documents folder
public class DocumentWatcher {
    private let logger: Logger
    private let documentsURL: URL
    private let processor: OCRProcessor
    private var directoryMonitor: DirectoryMonitor?
    private var processedDocuments = Set<String>()
    private let processedDocumentsFile: URL
    
    public init(logger: Logger) {
        self.logger = logger
        self.processor = OCRProcessor(logger: logger)
        
        // Get the iCloud Documents container
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
            self.documentsURL = iCloudURL.appendingPathComponent("Documents")
        } else {
            // Fallback to local Documents if iCloud not available
            self.documentsURL = FileManager.default.urls(for: .documentDirectory, 
                                                        in: .userDomainMask).first!
                .appendingPathComponent("YianaDocuments")
        }
        
        // Track processed documents
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first!
        let ocrDir = appSupport.appendingPathComponent("YianaOCR")
        try? FileManager.default.createDirectory(at: ocrDir, withIntermediateDirectories: true)
        self.processedDocumentsFile = ocrDir.appendingPathComponent("processed.json")
        
        loadProcessedDocuments()
        
        logger.info("Document watcher initialized", metadata: [
            "documentsPath": .string(documentsURL.path)
        ])
    }
    
    /// Start watching for documents
    public func start() async {
        logger.info("Starting document watcher")
        
        // Ensure documents directory exists
        try? FileManager.default.createDirectory(at: documentsURL, 
                                                withIntermediateDirectories: true)
        
        // Initial scan of existing documents
        await scanExistingDocuments()
        
        // Set up directory monitoring
        setupDirectoryMonitor()
    }
    
    /// Stop watching
    public func stop() {
        logger.info("Stopping document watcher")
        directoryMonitor?.stop()
        saveProcessedDocuments()
    }
    
    private func scanExistingDocuments() async {
        logger.info("Scanning existing documents")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "yianazip" {
                    await checkAndProcessDocument(at: fileURL)
                }
            }
        } catch {
            logger.error("Error scanning documents", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    private func setupDirectoryMonitor() {
        directoryMonitor = DirectoryMonitor(url: documentsURL) { [weak self] in
            Task {
                await self?.scanExistingDocuments()
            }
        }
        directoryMonitor?.start()
    }
    
    private func checkAndProcessDocument(at url: URL) async {
        let fileName = url.lastPathComponent
        let fileIdentifier = getFileIdentifier(for: url)
        
        // Check if already processed
        if processedDocuments.contains(fileIdentifier) {
            logger.debug("Document already processed", metadata: [
                "file": .string(fileName)
            ])
            return
        }
        
        logger.info("Checking document", metadata: [
            "file": .string(fileName)
        ])
        
        do {
            // Load document data
            let documentData = try Data(contentsOf: url)
            
            // Parse document
            let document = try YianaDocument(data: documentData)
            
            // Check if OCR is needed
            if document.metadata.ocrCompleted {
                logger.info("Document already has OCR", metadata: [
                    "file": .string(fileName)
                ])
                processedDocuments.insert(fileIdentifier)
                saveProcessedDocuments()
                return
            }
            
            // Check if PDF has text
            if let pdfData = document.pdfData, pdfHasText(pdfData) {
                logger.info("PDF already has text", metadata: [
                    "file": .string(fileName)
                ])
                // Update metadata to mark as OCR completed
                var updatedMetadata = document.metadata
                updatedMetadata.ocrCompleted = true
                updatedMetadata.modified = Date()
                
                let updatedDocument = YianaDocument(
                    metadata: updatedMetadata,
                    pdfData: pdfData
                )
                
                try updatedDocument.save(to: url)
                processedDocuments.insert(fileIdentifier)
                saveProcessedDocuments()
                return
            }
            
            logger.info("Processing OCR", metadata: [
                "file": .string(fileName)
            ])
            
            // Process OCR with options from document
            let options = ProcessingOptions(
                recognitionLevel: .accurate,
                languages: ["en-US"],
                useLanguageCorrection: true,
                extractFormData: false,
                extractDemographics: false,
                customDataHints: nil
            )
            let result = try await processor.processDocument(document, options: options)
            
            // Save OCR results
            try await saveOCRResults(result, for: document, at: url)
            
            // Mark as processed
            processedDocuments.insert(fileIdentifier)
            saveProcessedDocuments()
            
            logger.info("OCR completed successfully", metadata: [
                "file": .string(fileName),
                "pages": .stringConvertible(result.pages.count),
                "confidence": .stringConvertible(result.confidence)
            ])
            
        } catch {
            logger.error("Failed to process document", metadata: [
                "file": .string(fileName),
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    private func pdfHasText(_ pdfData: Data) -> Bool {
        // This is a simple check - you might want to use PDFKit for more accurate detection
        if let string = String(data: pdfData, encoding: .ascii) {
            // Look for common PDF text stream operators
            return string.contains("BT") && string.contains("ET") && string.contains("Tj")
        }
        return false
    }
    
    private func saveOCRResults(_ result: OCRResult, for document: YianaDocument, at url: URL) async throws {
        // Update document metadata with OCR results
        var updatedMetadata = document.metadata
        updatedMetadata.ocrCompleted = true
        updatedMetadata.fullText = result.fullText
        updatedMetadata.modified = Date()
        updatedMetadata.ocrProcessedAt = result.processedAt
        updatedMetadata.ocrConfidence = result.confidence
        updatedMetadata.ocrEngineVersion = result.engineVersion
        
        // Store extracted data if available
        if let extractedData = result.extractedData {
            let encoder = JSONEncoder()
            updatedMetadata.extractedData = try encoder.encode(extractedData)
        }
        
        // Create updated document with OCR'd PDF if available
        let updatedDocument = YianaDocument(
            metadata: updatedMetadata,
            pdfData: document.pdfData // TODO: Replace with OCR'd PDF when text layer is added
        )
        
        // Save updated document
        try updatedDocument.save(to: url)
        
        // Save OCR results in multiple formats
        let ocrResultsDir = documentsURL.appendingPathComponent(".ocr_results")
        try FileManager.default.createDirectory(at: ocrResultsDir, 
                                               withIntermediateDirectories: true)
        
        let baseFileName = url.deletingPathExtension().lastPathComponent
        
        // Save as JSON
        let jsonExporter = JSONExporter()
        let jsonData = try jsonExporter.export(result)
        let jsonURL = ocrResultsDir.appendingPathComponent("\(baseFileName).json")
        try jsonData.write(to: jsonURL)
        
        // Save as XML
        let xmlExporter = XMLExporter()
        let xmlData = try xmlExporter.export(result)
        let xmlURL = ocrResultsDir.appendingPathComponent("\(baseFileName).xml")
        try xmlData.write(to: xmlURL)
        
        // Save as hOCR
        let hocrExporter = HOCRExporter()
        let hocrData = try hocrExporter.export(result)
        let hocrURL = ocrResultsDir.appendingPathComponent("\(baseFileName).hocr")
        try hocrData.write(to: hocrURL)
        
        logger.info("OCR results saved", metadata: [
            "formats": .array([.string("json"), .string("xml"), .string("hocr")])
        ])
    }
    
    private func getFileIdentifier(for url: URL) -> String {
        // Use file name and modification date as identifier
        let fileName = url.lastPathComponent
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modDate = attributes[.modificationDate] as? Date {
            return "\(fileName)_\(modDate.timeIntervalSince1970)"
        }
        return fileName
    }
    
    private func loadProcessedDocuments() {
        guard FileManager.default.fileExists(atPath: processedDocumentsFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: processedDocumentsFile)
            processedDocuments = try JSONDecoder().decode(Set<String>.self, from: data)
            logger.info("Loaded processed documents", metadata: [
                "count": .stringConvertible(processedDocuments.count)
            ])
        } catch {
            logger.error("Failed to load processed documents", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    private func saveProcessedDocuments() {
        do {
            let data = try JSONEncoder().encode(processedDocuments)
            try data.write(to: processedDocumentsFile)
        } catch {
            logger.error("Failed to save processed documents", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
}

/// Simple directory monitor using DispatchSource
class DirectoryMonitor {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    
    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }
    
    func start() {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .link],
            queue: .main
        )
        
        source?.setEventHandler { [weak self] in
            self?.onChange()
        }
        
        source?.setCancelHandler {
            close(descriptor)
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
}