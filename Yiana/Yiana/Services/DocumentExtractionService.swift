import Foundation
import os
import YianaExtraction

/// Runs address extraction and NHS lookup after OCR completes,
/// writing results to .addresses/ in iCloud.
///
/// All failures are logged but never thrown — extraction is best-effort
/// and must not block document saving or the UI.
final class DocumentExtractionService {
    static let shared = DocumentExtractionService()

    private let logger = Logger(subsystem: "com.vitygas.Yiana", category: "DocumentExtraction")
    private let cascade = ExtractionCascade()
    private let lookupService: NHSLookupService?

    /// Directory URL for .addresses/ in iCloud container
    private let addressesDirectoryURL: URL?

    private init() {
        if let dbURL = Bundle.main.url(forResource: "nhs_lookup", withExtension: "db") {
            lookupService = try? NHSLookupService(databasePath: dbURL.path)
        } else {
            lookupService = nil
        }

        if let iCloudURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana"
        ) {
            addressesDirectoryURL = iCloudURL
                .appendingPathComponent("Documents")
                .appendingPathComponent(".addresses")
        } else {
            addressesDirectoryURL = nil
        }
    }

    /// Run extraction on OCR results and write to .addresses/
    ///
    /// Preserves existing overrides and enriched data. Safe to call
    /// from any async context — does file I/O off the main actor.
    func extractAndSave(
        documentId: String,
        ocrResult: OnDeviceOCRResult
    ) async {
        guard !ocrResult.pages.isEmpty else { return }
        guard let dirURL = addressesDirectoryURL else {
            logger.warning("iCloud container not available — skipping extraction")
            return
        }

        do {
            // 1. Build ExtractionInput from per-page OCR data
            let inputs = ocrResult.pages.map { page in
                ExtractionInput(
                    documentId: documentId,
                    pageNumber: page.pageNumber,
                    text: page.text,
                    confidence: page.confidence
                )
            }

            // 2. Run extraction cascade
            var extracted = cascade.extractDocument(documentId: documentId, pages: inputs)

            // 3. NHS lookup enrichment
            enrichWithNHSLookup(&extracted)

            // 4. Read-merge-write to preserve overrides and enriched data
            let fileURL = dirURL.appendingPathComponent("\(documentId).json")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let existingData = try Data(contentsOf: fileURL)
                let existingFile = try JSONDecoder().decode(DocumentAddressFile.self, from: existingData)
                extracted.overrides = existingFile.overrides
                extracted.enriched = existingFile.enriched
            }

            // 5. Atomic write
            try atomicWrite(file: extracted, to: dirURL)

            let pageCount = extracted.pages.count
            logger.info("Extracted \(pageCount) pages for \(documentId)")
        } catch {
            logger.error("Extraction failed for \(documentId): \(error)")
        }
    }

    // MARK: - Private

    private func enrichWithNHSLookup(_ file: inout DocumentAddressFile) {
        guard let service = lookupService else { return }

        for i in file.pages.indices {
            let page = file.pages[i]
            // Use GP postcode if available, fall back to patient address postcode
            guard let postcode = page.gp?.postcode ?? page.address?.postcode else {
                continue
            }

            let candidates = try? service.lookupGP(
                postcode: postcode,
                nameHint: page.gp?.practice ?? page.gp?.name,
                addressHint: page.gp?.address
            )

            if let candidates, !candidates.isEmpty {
                if file.pages[i].gp == nil {
                    file.pages[i].gp = GPInfo()
                }
                file.pages[i].gp?.nhsCandidates = candidates
            }
        }
    }

    private func atomicWrite(file: DocumentAddressFile, to dirURL: URL) throws {
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let finalURL = dirURL.appendingPathComponent("\(file.documentId).json")
        let tmpURL = dirURL.appendingPathComponent("\(file.documentId).json.tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: tmpURL, options: .atomic)

        if FileManager.default.fileExists(atPath: finalURL.path) {
            _ = try FileManager.default.replaceItemAt(finalURL, withItemAt: tmpURL)
        } else {
            try FileManager.default.moveItem(at: tmpURL, to: finalURL)
        }
    }
}
