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
    
    public init(logger: Logger, customPath: String? = nil) {
        self.logger = logger
        self.processor = OCRProcessor(logger: logger)
        
        if let customPath = customPath {
            // Use the provided custom path
            self.documentsURL = URL(fileURLWithPath: customPath)
        } else {
            // Get the iCloud Documents container
            if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
                self.documentsURL = iCloudURL.appendingPathComponent("Documents")
            } else {
                // Fallback to local Documents if iCloud not available
                self.documentsURL = FileManager.default.urls(for: .documentDirectory, 
                                                            in: .userDomainMask).first!
                    .appendingPathComponent("YianaDocuments")
            }
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
        
        // Check if the directory exists
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: documentsURL.path, isDirectory: &isDirectory)
        
        if !exists {
            logger.error("Documents directory does not exist!", metadata: [
                "path": .string(documentsURL.path)
            ])
            // Try to create it
            do {
                try FileManager.default.createDirectory(at: documentsURL, 
                                                       withIntermediateDirectories: true)
                logger.info("Created documents directory", metadata: [
                    "path": .string(documentsURL.path)
                ])
            } catch {
                logger.critical("Failed to create documents directory! OCR service cannot function.", metadata: [
                    "path": .string(documentsURL.path),
                    "error": .string(error.localizedDescription)
                ])
                return
            }
        } else if !isDirectory.boolValue {
            logger.critical("Documents path exists but is not a directory!", metadata: [
                "path": .string(documentsURL.path)
            ])
            return
        } else {
            logger.info("Documents directory verified", metadata: [
                "path": .string(documentsURL.path)
            ])
        }
        
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
            // Use enumerator to recursively find all files
            let enumerator = FileManager.default.enumerator(
                at: documentsURL,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            
            var documentCount = 0
            var allFiles: [URL] = []
            
            // Collect all files from the enumerator
            while let fileURL = enumerator?.nextObject() as? URL {
                allFiles.append(fileURL)
            }
            
            logger.info("Found items in directory tree", metadata: [
                "count": .stringConvertible(allFiles.count),
                "path": .string(documentsURL.path)
            ])
            
            for fileURL in allFiles {
                logger.debug("Checking file", metadata: [
                    "file": .string(fileURL.lastPathComponent),
                    "path": .string(fileURL.path),
                    "extension": .string(fileURL.pathExtension)
                ])
                
                if fileURL.pathExtension == "yianazip" {
                    documentCount += 1
                    logger.info("Found document to process", metadata: [
                        "file": .string(fileURL.lastPathComponent),
                        "folder": .string(fileURL.deletingLastPathComponent().lastPathComponent)
                    ])
                    await checkAndProcessDocument(at: fileURL)
                }
            }
            
            if documentCount == 0 {
                logger.warning("No Yiana documents found in directory tree!", metadata: [
                    "path": .string(documentsURL.path),
                    "totalFilesScanned": .stringConvertible(allFiles.count)
                ])
            } else {
                logger.info("Found Yiana documents", metadata: [
                    "count": .stringConvertible(documentCount)
                ])
            }
        } catch {
            logger.error("Error scanning documents", metadata: [
                "error": .string(error.localizedDescription),
                "path": .string(documentsURL.path)
            ])
        }
    }
    
    private func setupDirectoryMonitor() {
        // Monitor the main directory
        directoryMonitor = DirectoryMonitor(url: documentsURL) { [weak self] in
            Task {
                await self?.scanExistingDocuments()
            }
        }
        directoryMonitor?.start()
        
        // Also set up a periodic scan to catch any missed changes in subdirectories
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5 seconds
                await scanExistingDocuments()
            }
        }
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
            
            // Check if PDF data exists (might be syncing from iCloud)
            guard let pdfData = document.pdfData, !pdfData.isEmpty else {
                logger.warning("No PDF data found yet, will retry", metadata: [
                    "file": .string(fileName)
                ])
                // Don't mark as processed, will retry on next scan
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
            // Use default encoder (same as iOS app - numeric dates as TimeInterval since 2001)
            let encoder = JSONEncoder()
            updatedMetadata.extractedData = try encoder.encode(extractedData)
        }
        
        // Embed text layer in PDF if we have PDF data
        var pdfDataWithText = document.pdfData
        if let pdfData = document.pdfData {
            do {
                pdfDataWithText = try processor.embedTextLayer(in: pdfData, with: result)
                logger.info("Successfully embedded text layer in PDF", metadata: [
                    "file": .string(url.lastPathComponent),
                    "originalSize": .stringConvertible(pdfData.count),
                    "newSize": .stringConvertible(pdfDataWithText?.count ?? 0)
                ])
            } catch {
                logger.error("Failed to embed text layer", metadata: [
                    "file": .string(url.lastPathComponent),
                    "error": .string(error.localizedDescription)
                ])
                // Continue with original PDF if embedding fails
                pdfDataWithText = pdfData
            }
        }
        
        // Create updated document with OCR'd PDF
        let updatedDocument = YianaDocument(
            metadata: updatedMetadata,
            pdfData: pdfDataWithText
        )
        
        // Save updated document
        try updatedDocument.save(to: url)
        
        // Save OCR results in multiple formats
        // Preserve the folder structure within .ocr_results
        let relativePath = url.deletingLastPathComponent().path.replacingOccurrences(of: documentsURL.path, with: "")
        let trimmedPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        
        let ocrResultsDir = documentsURL
            .appendingPathComponent(".ocr_results")
            .appendingPathComponent(trimmedPath)
        
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