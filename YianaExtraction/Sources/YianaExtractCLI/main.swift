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

// MARK: - Main

func run() throws {
    // Parse arguments
    var dbPath: String?
    let args = CommandLine.arguments
    if let idx = args.firstIndex(of: "--db-path"), idx + 1 < args.count {
        dbPath = args[idx + 1]
    }

    // Read OCR JSON from stdin
    let inputData = FileHandle.standardInput.readDataToEndOfFile()
    guard !inputData.isEmpty else {
        FileHandle.standardError.write("Error: no input on stdin\n".data(using: .utf8)!)
        exit(1)
    }

    let ocrFile = try JSONDecoder().decode(OCRFile.self, from: inputData)

    // Build ExtractionInput per page
    let inputs = ocrFile.pages.map { page in
        ExtractionInput(
            documentId: ocrFile.documentId,
            pageNumber: page.pageNumber,
            text: page.text,
            confidence: page.confidence ?? 0.85
        )
    }

    // Run extraction cascade
    let cascade = ExtractionCascade()
    var result = cascade.extractDocument(documentId: ocrFile.documentId, pages: inputs)

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
