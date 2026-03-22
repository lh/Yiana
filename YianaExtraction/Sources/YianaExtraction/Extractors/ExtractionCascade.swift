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
            FormExtractor(),
            LabelExtractor(),
            FallbackExtractor(),
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
    ///
    /// If the document ID follows the `Surname_Firstname_DDMMYY` convention,
    /// the filename-parsed name and DOB are used as canonical patient identity,
    /// with OCR-extracted values as fallback.
    public func extractDocument(
        documentId: String,
        pages: [ExtractionInput]
    ) -> DocumentAddressFile {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let filenamePatient = ExtractionHelpers.parsePatientFilename(documentId)

        let extractedPages = pages.compactMap { input -> AddressPageEntry? in
            guard var page = extract(from: input) else { return nil }
            if let fp = filenamePatient {
                applyFilenamePatient(fp, to: &page)
            }
            fillCityFromPostcode(&page)
            return page
        }

        return DocumentAddressFile(
            documentId: documentId,
            extractedAt: formatter.string(from: Date()),
            pageCount: pages.count,
            pages: extractedPages
        )
    }

    /// Fill city from postcode lookup when city is empty but postcode is present.
    private func fillCityFromPostcode(_ page: inout AddressPageEntry) {
        if (page.address?.city == nil || page.address?.city?.isEmpty == true),
           let postcode = page.address?.postcode, !postcode.isEmpty {
            page.address?.city = ExtractionHelpers.townForPostcode(postcode)
        }
    }

    /// Overlay filename-parsed patient name and DOB onto an extracted page.
    /// Filename values are canonical; OCR values are kept only as fallback.
    private func applyFilenamePatient(
        _ fp: ExtractionHelpers.FilenamePatient,
        to page: inout AddressPageEntry
    ) {
        if page.patient == nil {
            page.patient = PatientInfo()
        }
        page.patient?.fullName = fp.fullName
        page.patient?.dateOfBirth = fp.dateOfBirth
    }
}
