//
//  ExtractionCascade.swift
//  YianaExtraction
//
//  Runs extractors in priority order on OCR text.
//

import Foundation

/// Runs extractors in priority order: registration form, NLP (form/label), fallback (unstructured).
/// Returns the first successful extraction result.
public struct ExtractionCascade: Sendable {

    private let extractors: [any Extractor]

    public init(extractors: [any Extractor]? = nil) {
        self.extractors = extractors ?? [
            RegistrationFormExtractor(),
            // NLPExtractor(),         // TODO: Session 3
            // FallbackExtractor(),    // TODO: Session 3
        ]
    }

    /// Extract address data from a single page of OCR text.
    public func extract(from input: ExtractionInput) -> AddressPageEntry? {
        for extractor in extractors {
            if let result = extractor.extract(from: input) {
                return result
            }
        }
        return nil
    }

    /// Extract address data from all pages of a document.
    public func extractDocument(
        documentId: String,
        pages: [ExtractionInput]
    ) -> DocumentAddressFile {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let extractedPages = pages.compactMap { input -> AddressPageEntry? in
            extract(from: input)
        }

        return DocumentAddressFile(
            documentId: documentId,
            extractedAt: formatter.string(from: Date()),
            pageCount: pages.count,
            pages: extractedPages
        )
    }
}
