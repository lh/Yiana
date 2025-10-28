import Foundation
import Logging
import PDFKit

private enum OCRSource: String {
    case embedded
    case service
}

/// Watches for new or modified Yiana documents in the iCloud Documents folder
public class DocumentWatcher {
    private let logger: Logger
    private let documentsURL: URL
    private let processor: OCRProcessor
    private var directoryMonitor: DirectoryMonitor?
    private var processedDocuments = Set<String>()
    private let processedDocumentsFile: URL
    private let health: HealthMonitor
    private var lastCleanupTime: Date = .distantPast
    private let cleanupInterval: TimeInterval = 60 * 60
    private var isScanning = false  // Prevent concurrent scans
    private var processingDocuments = Set<String>()  // Track documents currently being processed
    
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
        self.health = HealthMonitor(logger: logger)
        
        loadProcessedDocuments()
        
        logger.info("Document watcher initialized", metadata: [
            "documentsPath": .string(documentsURL.path)
        ])
    }
    
    /// Start watching for documents
    public func start() async {
        logger.info("Starting document watcher")
        health.touchHeartbeat(note: "start")
        
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
        health.touchHeartbeat(note: "initial-scan-complete")
        
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
        // Prevent concurrent scans from piling up
        guard !isScanning else {
            logger.debug("Scan already in progress, skipping")
            return
        }

        isScanning = true
        defer { isScanning = false }

        logger.info("Scanning existing documents")
        health.touchHeartbeat(note: "scan")

        guard let enumerator = FileManager.default.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )?.allObjects as? [URL] else {
            logger.error("Failed to enumerate documents", metadata: [
                "path": .string(documentsURL.path)
            ])
            health.recordError("scanExistingDocuments: failed to enumerate directory")
            return
        }

        var documentCount = 0
        var documentURLs: [URL] = []

        for fileURL in enumerator {
            logger.debug("Checking file", metadata: [
                "file": .string(fileURL.lastPathComponent),
                "path": .string(fileURL.path),
                "extension": .string(fileURL.pathExtension)
            ])

            if fileURL.pathExtension == "yianazip" {
                documentCount += 1
                documentURLs.append(fileURL)
                logger.info("Found document to process", metadata: [
                    "file": .string(fileURL.lastPathComponent),
                    "folder": .string(fileURL.deletingLastPathComponent().lastPathComponent)
                ])
                await checkAndProcessDocument(at: fileURL)
            }
        }

        logger.info("Found items in directory tree", metadata: [
            "count": .stringConvertible(enumerator.count),
            "path": .string(documentsURL.path)
        ])

        if documentCount == 0 {
            logger.warning("No Yiana documents found in directory tree!", metadata: [
                "path": .string(documentsURL.path),
                "totalFilesScanned": .stringConvertible(enumerator.count)
            ])
        } else {
            logger.info("Found Yiana documents", metadata: [
                "count": .stringConvertible(documentCount)
            ])
        }

        performCleanupIfNeeded(existingDocuments: documentURLs)
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
        // Reduced frequency to prevent concurrent scan deadlocks
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Check every 60 seconds (was 5)
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

        // Check if currently being processed by another scan
        if processingDocuments.contains(fileIdentifier) {
            logger.debug("Document currently being processed, skipping", metadata: [
                "file": .string(fileName)
            ])
            return
        }

        // Mark as being processed
        processingDocuments.insert(fileIdentifier)
        defer { processingDocuments.remove(fileIdentifier) }
        
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
            
            if let pdfData = document.pdfData,
               let embeddedResult = embeddedOCRResult(from: pdfData, document: document) {
                logger.info("PDF already has embedded text", metadata: [
                    "file": .string(fileName),
                    "pageCount": .stringConvertible(embeddedResult.pages.count),
                    "textLength": .stringConvertible(embeddedResult.fullText.count)
                ])
                try await saveOCRResults(embeddedResult, for: document, at: url)
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
            health.recordError("processDocument: \(fileName): \(error.localizedDescription)")
        }
    }
    
    private func embeddedOCRResult(from pdfData: Data, document: YianaDocument) -> OCRResult? {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return nil }

        var pages: [OCRPage] = []
        var aggregated: [String] = []

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let rawText = page.string else { continue }

            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            aggregated.append(trimmed)

            let lineStrings = trimmed.split(separator: "\n").map(String.init)
            let lines: [TextLine]
            if lineStrings.isEmpty {
                lines = [TextLine(text: trimmed,
                                  boundingBox: BoundingBox(x: 0, y: 0, width: 1, height: 1),
                                  words: [])]
            } else {
                lines = lineStrings.map { line in
                    TextLine(text: line,
                             boundingBox: BoundingBox(x: 0, y: 0, width: 1, height: 1),
                             words: [])
                }
            }

            let block = TextBlock(
                text: trimmed,
                boundingBox: BoundingBox(x: 0, y: 0, width: 1, height: 1),
                confidence: 1.0,
                lines: lines
            )

            let pageResult = OCRPage(
                pageNumber: pageIndex + 1,
                text: trimmed,
                textBlocks: [block],
                formFields: nil,
                confidence: 1.0
            )

            pages.append(pageResult)
        }

        guard !aggregated.isEmpty else { return nil }

        return OCRResult(
            id: UUID(),
            processedAt: Date(),
            documentId: document.metadata.id,
            engineVersion: "embedded-text",
            pages: pages,
            extractedData: nil,
            confidence: 1.0,
            metadata: ProcessingMetadata(
                processingTime: 0,
                pageCount: pdfDocument.pageCount,
                detectedLanguages: [],
                warnings: [],
                options: .default
            )
        )
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
        updatedMetadata.ocrSource = result.engineVersion == "embedded-text" ? OCRSource.embedded.rawValue : OCRSource.service.rawValue
        
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
                if result.engineVersion == "embedded-text" {
                    pdfDataWithText = pdfData
                } else {
                    pdfDataWithText = try processor.embedTextLayer(in: pdfData, with: result)
                    logger.info("Successfully embedded text layer in PDF", metadata: [
                        "file": .string(url.lastPathComponent),
                        "originalSize": .stringConvertible(pdfData.count),
                        "newSize": .stringConvertible(pdfDataWithText?.count ?? 0)
                    ])
                }
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

    private func performCleanupIfNeeded(existingDocuments: [URL]? = nil) {
        performCleanup(existingDocuments: existingDocuments, force: false)
    }

    private func performCleanup(existingDocuments: [URL]? = nil, force: Bool) {
        let now = Date()
        if !force && now.timeIntervalSince(lastCleanupTime) < cleanupInterval {
            return
        }

        let documents = existingDocuments ?? collectDocumentURLs()
        let removedProcessed = cleanupProcessedEntries(using: documents)
        let removedResults = cleanupOrphanedOCRResults(using: documents)

        lastCleanupTime = now

        if removedProcessed > 0 || removedResults > 0 {
            logger.info("OCR cleanup removed stale data", metadata: [
                "processedEntriesRemoved": .stringConvertible(removedProcessed),
                "orphanResultsRemoved": .stringConvertible(removedResults)
            ])
        } else {
            logger.debug("OCR cleanup found no stale data")
        }
    }

    public func cleanupNow() async {
        logger.info("Running manual cleanup")
        performCleanup(existingDocuments: collectDocumentURLs(), force: true)
    }

    private func collectDocumentURLs() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var documents: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "yianazip" {
                documents.append(fileURL)
            }
        }
        return documents
    }

    private func cleanupProcessedEntries(using documents: [URL]) -> Int {
        let existingIdentifiers = Set(documents.map(getFileIdentifier))
        let before = processedDocuments.count
        processedDocuments.formIntersection(existingIdentifiers)
        let removed = before - processedDocuments.count
        if removed > 0 {
            saveProcessedDocuments()
        }
        return removed
    }

    private func cleanupOrphanedOCRResults(using documents: [URL]) -> Int {
        let fileManager = FileManager.default
        let ocrRoot = documentsURL.appendingPathComponent(".ocr_results")
        guard fileManager.fileExists(atPath: ocrRoot.path) else { return 0 }

        let existingBases = Set(documents.map(relativeDocumentBasePath))
        var removedCount = 0
        var candidateDirectories = Set<URL>()

        if let enumerator = fileManager.enumerator(
            at: ocrRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let itemURL as URL in enumerator {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    candidateDirectories.insert(itemURL)
                    continue
                }

                let relative = relativeOCRBasePath(for: itemURL, root: ocrRoot)
                if !existingBases.contains(relative) {
                    do {
                        try fileManager.removeItem(at: itemURL)
                        removedCount += 1
                        logger.debug("Removed orphaned OCR result", metadata: [
                            "file": .string(relative)
                        ])
                    } catch {
                        logger.error("Failed to remove orphaned OCR result", metadata: [
                            "path": .string(itemURL.path),
                            "error": .string(error.localizedDescription)
                        ])
                    }
                }
            }
        }

        let sortedDirectories = candidateDirectories.sorted { $0.path.count > $1.path.count }
        for directory in sortedDirectories {
            if let contents = try? fileManager.contentsOfDirectory(atPath: directory.path),
               contents.isEmpty {
                try? fileManager.removeItem(at: directory)
            }
        }

        return removedCount
    }

    private func relativeDocumentBasePath(for documentURL: URL) -> String {
        return trimmedRelativePath(for: documentURL.deletingPathExtension(), base: documentsURL)
    }

    private func relativeOCRBasePath(for resultURL: URL, root: URL) -> String {
        return trimmedRelativePath(for: resultURL.deletingPathExtension(), base: root)
    }

    private func trimmedRelativePath(for url: URL, base: URL) -> String {
        var path = url.path
        let basePath = base.path
        if path.hasPrefix(basePath) {
            path.removeFirst(basePath.count)
        }
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        return path
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
