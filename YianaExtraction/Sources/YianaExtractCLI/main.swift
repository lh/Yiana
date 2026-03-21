import Foundation
import YianaExtraction

// MARK: - OCR Input Model (matches .ocr_results/ JSON format)

struct OCRFile: Codable {
    var documentId: String
    var pages: [OCRPage]
}

struct OCRPage: Codable {
    var pageNumber: Int
    var text: String
    var confidence: Double?
}

// MARK: - Entity Ingestion Mode

func runIngestAll() throws {
    let args = CommandLine.arguments
    guard let idx = args.firstIndex(of: "--ingest-all"), idx + 1 < args.count else {
        FileHandle.standardError.write("Usage: --ingest-all <addresses-directory> [--entity-db <path>]\n".data(using: .utf8)!)
        exit(1)
    }
    let dirPath = args[idx + 1]

    var entityDbPath = "/tmp/yiana_entities_validation.db"
    if let dbIdx = args.firstIndex(of: "--entity-db"), dbIdx + 1 < args.count {
        entityDbPath = args[dbIdx + 1]
    }

    // Remove existing DB for clean validation
    try? FileManager.default.removeItem(atPath: entityDbPath)

    let db = try EntityDatabase(path: entityDbPath)
    let dirURL = URL(fileURLWithPath: dirPath)
    let files = try FileManager.default.contentsOfDirectory(
        at: dirURL, includingPropertiesForKeys: nil, options: []
    ).filter { $0.pathExtension == "json" && !$0.lastPathComponent.contains(".overrides.") }

    var ingested = 0
    var failed = 0
    for fileURL in files {
        do {
            try db.ingestAddressFile(at: fileURL)
            ingested += 1
        } catch {
            FileHandle.standardError.write("Failed: \(fileURL.lastPathComponent): \(error)\n".data(using: .utf8)!)
            failed += 1
        }
    }

    let stats = try db.statistics()
    print("")
    print("Swift Entity Database Statistics")
    print("=============================================")
    print("  Files found:                  \(String(format: "%6d", files.count))")
    print("  Ingested:                     \(String(format: "%6d", ingested))")
    print("  Failed:                       \(String(format: "%6d", failed))")
    print("  Documents:                    \(String(format: "%6d", stats.documentCount))")
    print("  Extractions:                  \(String(format: "%6d", stats.extractionCount))")
    print("  Patients (deduplicated):      \(String(format: "%6d", stats.patientCount))")
    print("  Practitioners:                \(String(format: "%6d", stats.practitionerCount))")
    print("  Patient-Practitioner links:   \(String(format: "%6d", stats.linkCount))")
    print("")
    print("  Entity DB written to: \(entityDbPath)")
}

// MARK: - Main

func run() throws {
    // Parse arguments
    var dbPath: String?
    var documentIdOverride: String?
    let args = CommandLine.arguments
    if let idx = args.firstIndex(of: "--db-path"), idx + 1 < args.count {
        dbPath = args[idx + 1]
    }
    if let idx = args.firstIndex(of: "--document-id"), idx + 1 < args.count {
        documentIdOverride = args[idx + 1]
    }

    // Check for ingest-all mode
    if args.contains("--ingest-all") {
        try runIngestAll()
        return
    }

    // Read OCR JSON from stdin
    let inputData = FileHandle.standardInput.readDataToEndOfFile()
    guard !inputData.isEmpty else {
        FileHandle.standardError.write("Error: no input on stdin\n".data(using: .utf8)!)
        exit(1)
    }

    let ocrFile = try JSONDecoder().decode(OCRFile.self, from: inputData)

    // Use --document-id override (filename stem) if provided, otherwise JSON field
    let documentId = documentIdOverride ?? ocrFile.documentId

    // Build ExtractionInput per page
    let inputs = ocrFile.pages.map { page in
        ExtractionInput(
            documentId: documentId,
            pageNumber: page.pageNumber,
            text: page.text,
            confidence: page.confidence ?? 0.85
        )
    }

    // Run extraction cascade
    let cascade = ExtractionCascade()
    var result = cascade.extractDocument(documentId: documentId, pages: inputs)

    // NHS lookup enrichment
    if let dbPath {
        if let service = try? NHSLookupService(databasePath: dbPath) {
            for i in result.pages.indices {
                let page = result.pages[i]
                guard let postcode = page.gp?.postcode ?? page.address?.postcode else {
                    continue
                }
                let candidates = try? service.lookupGP(
                    postcode: postcode,
                    nameHint: page.gp?.practice ?? page.gp?.name,
                    addressHint: page.gp?.address
                )
                if let candidates, !candidates.isEmpty {
                    if result.pages[i].gp == nil {
                        result.pages[i].gp = GPInfo()
                    }
                    result.pages[i].gp?.nhsCandidates = candidates
                }
            }
        } else {
            FileHandle.standardError.write("Warning: could not open NHS DB at \(dbPath)\n".data(using: .utf8)!)
        }
    }

    // Encode and write to stdout
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let outputData = try encoder.encode(result)
    FileHandle.standardOutput.write(outputData)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}

do {
    try run()
} catch {
    FileHandle.standardError.write("Error: \(error)\n".data(using: .utf8)!)
    exit(1)
}
