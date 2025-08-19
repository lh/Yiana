import Foundation
import ArgumentParser
import Logging

@main
struct YianaOCR: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "yiana-ocr",
        abstract: "OCR service for Yiana documents",
        version: "1.0.0",
        subcommands: [Watch.self, Process.self, Batch.self],
        defaultSubcommand: Watch.self
    )
}

extension YianaOCR {
    struct Watch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Watch for new documents and process them automatically"
        )
        
        @Option(name: .shortAndLong, help: "Log level (trace, debug, info, notice, warning, error, critical)")
        var logLevel: String = "info"
        
        @Option(name: .shortAndLong, help: "Path to watch for documents")
        var path: String?
        
        mutating func run() async throws {
            let logger = Logger(label: "com.vitygas.yiana.ocr")
            logger.info("Starting Yiana OCR service in watch mode")
            
            let watcher = DocumentWatcher(logger: logger)
            await watcher.start()
            
            // Keep the service running
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await Task.sleepForever()
                }
            }
        }
    }
    
    struct Process: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Process a single document"
        )
        
        @Argument(help: "Path to the document to process")
        var documentPath: String
        
        @Option(name: .shortAndLong, help: "Output format (json, xml, hocr)")
        var format: String = "json"
        
        @Flag(name: .long, help: "Extract form data")
        var extractForms: Bool = false
        
        @Flag(name: .long, help: "Extract demographics")
        var extractDemographics: Bool = false
        
        mutating func run() async throws {
            let logger = Logger(label: "com.vitygas.yiana.ocr")
            logger.info("Processing document", metadata: [
                "path": .string(documentPath)
            ])
            
            let url = URL(fileURLWithPath: documentPath)
            let processor = OCRProcessor(logger: logger)
            
            // Configure processing options
            let options = ProcessingOptions(
                recognitionLevel: .accurate,
                languages: ["en-US"],
                useLanguageCorrection: true,
                extractFormData: extractForms,
                extractDemographics: extractDemographics,
                customDataHints: nil
            )
            
            // Load document
            let documentData = try Data(contentsOf: url)
            let document = try YianaDocument(data: documentData)
            
            // Process OCR
            let result = try await processor.processDocument(document, options: options)
            
            // Export results
            let exporter: OCRExporter = switch format.lowercased() {
            case "xml":
                XMLExporter()
            case "hocr":
                HOCRExporter()
            default:
                JSONExporter(prettyPrint: true)
            }
            
            let exportedData = try exporter.export(result)
            
            // Write to stdout
            if let output = String(data: exportedData, encoding: .utf8) {
                print(output)
            }
            
            logger.info("Document processed successfully", metadata: [
                "pages": .stringConvertible(result.pages.count),
                "confidence": .stringConvertible(result.confidence)
            ])
        }
    }
    
    struct Batch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Process multiple documents in batch"
        )
        
        @Argument(help: "Directory containing documents to process")
        var directory: String
        
        @Option(name: .shortAndLong, help: "Output directory for results")
        var output: String = "./ocr_results"
        
        @Option(name: .shortAndLong, help: "Output format (json, xml, hocr)")
        var format: String = "json"
        
        @Flag(name: .long, help: "Process files in parallel")
        var parallel: Bool = false
        
        mutating func run() async throws {
            let logger = Logger(label: "com.vitygas.yiana.ocr")
            logger.info("Starting batch processing", metadata: [
                "directory": .string(directory)
            ])
            
            let directoryURL = URL(fileURLWithPath: directory)
            let outputURL = URL(fileURLWithPath: output)
            
            // Create output directory
            try FileManager.default.createDirectory(at: outputURL, 
                                                   withIntermediateDirectories: true)
            
            // Find all .yianazip files
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "yianazip" }
            
            logger.info("Found documents to process", metadata: [
                "count": .stringConvertible(fileURLs.count)
            ])
            
            let processor = OCRProcessor(logger: logger)
            
            let finalFormat = format
            let finalOutputURL = outputURL
            
            if parallel {
                // Process in parallel
                await withTaskGroup(of: Void.self) { group in
                    for fileURL in fileURLs {
                        group.addTask {
                            await Self.processFile(fileURL, processor: processor, 
                                            outputURL: finalOutputURL, format: finalFormat, 
                                            logger: logger)
                        }
                    }
                }
            } else {
                // Process sequentially
                for fileURL in fileURLs {
                    await Self.processFile(fileURL, processor: processor, 
                                    outputURL: finalOutputURL, format: finalFormat, 
                                    logger: logger)
                }
            }
            
            logger.info("Batch processing completed")
        }
        
        private static func processFile(_ fileURL: URL, processor: OCRProcessor, 
                               outputURL: URL, format: String, 
                               logger: Logger) async {
            do {
                let documentData = try Data(contentsOf: fileURL)
                let document = try YianaDocument(data: documentData)
                
                let result = try await processor.processDocument(document)
                
                let exporter: OCRExporter = switch format.lowercased() {
                case "xml":
                    XMLExporter()
                case "hocr":
                    HOCRExporter()
                default:
                    JSONExporter(prettyPrint: true)
                }
                
                let exportedData = try exporter.export(result)
                let outputFile = outputURL.appendingPathComponent(
                    fileURL.deletingPathExtension().lastPathComponent
                ).appendingPathExtension(exporter.fileExtension)
                
                try exportedData.write(to: outputFile)
                
                logger.info("Processed document", metadata: [
                    "file": .string(fileURL.lastPathComponent)
                ])
            } catch {
                logger.error("Failed to process document", metadata: [
                    "file": .string(fileURL.lastPathComponent),
                    "error": .string(error.localizedDescription)
                ])
            }
        }
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleepForever() async {
        do {
            try await Task.sleep(nanoseconds: .max)
        } catch {
            // Task was cancelled
        }
    }
}