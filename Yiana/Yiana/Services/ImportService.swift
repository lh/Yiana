//
//  ImportService.swift
//  Yiana
//
//  Created by Assistant on 02/09/2025.
//

import Foundation
import PDFKit
import YianaDocumentArchive

struct ImportResult {
    let url: URL
}

enum ImportMode {
    case createNew(title: String)
    case appendToExisting(targetURL: URL)
}

enum ImportError: Error {
    case invalidPDF
    case ioFailed
    case corruptDocument
}

/// Handles importing external PDFs into Yiana documents.
/// - Creates new documents from a PDF
/// - Appends PDF pages to an existing .yianazip
class ImportService {
    private let folderPath: String
    
    init(folderPath: String = "") {
        self.folderPath = folderPath
    }

    func importPDF(from pdfURL: URL, mode: ImportMode) throws -> ImportResult {
        guard let importedData = try? Data(contentsOf: pdfURL),
              PDFDocument(data: importedData) != nil else {
            throw ImportError.invalidPDF
        }

        switch mode {
        case .createNew(let title):
            return try createNewDocument(from: importedData, title: title)
        case .appendToExisting(let targetURL):
            return try append(to: targetURL, importedPDFData: importedData)
        }
    }

    // MARK: - Private

    private func createNewDocument(from pdfData: Data, title: String) throws -> ImportResult {
        let repository = DocumentRepository()
        // Set the folder path if provided
        if !folderPath.isEmpty {
            // Navigate to the correct folder
            let components = folderPath.components(separatedBy: "/").filter { !$0.isEmpty }
            for component in components {
                repository.navigateToFolder(component)
            }
        }
        let targetURL = repository.newDocumentURL(title: title)

        let pageCount = PDFDocument(data: pdfData)?.pageCount ?? 0

        let metadata = DocumentMetadata(
            id: UUID(),
            title: title,
            created: Date(),
            modified: Date(),
            pageCount: pageCount,
            tags: [],
            ocrCompleted: false,
            fullText: nil,
            hasPendingTextPage: false
        )

        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)

        do {
            try DocumentArchive.write(
                metadata: metadataData,
                pdf: .data(pdfData),
                to: targetURL,
                formatVersion: DocumentArchive.currentFormatVersion
            )

            // Index the newly created document
            Task {
                do {
                    try await SearchIndexService.shared.indexDocument(
                        id: metadata.id,
                        url: targetURL,
                        title: metadata.title,
                        fullText: "", // No OCR text yet
                        tags: metadata.tags,
                        metadata: metadata
                    )
                    print("✓ Indexed new document: \(metadata.title)")
                } catch {
                    print("⚠️ Failed to index new document: \(error)")
                }
            }

            return ImportResult(url: targetURL)
        } catch {
            throw ImportError.ioFailed
        }
    }

    private func append(to documentURL: URL, importedPDFData: Data) throws -> ImportResult {
        let payload: DocumentArchivePayload
        do {
            payload = try DocumentArchive.read(from: documentURL)
        } catch {
            throw ImportError.corruptDocument
        }
        let metadataData = payload.metadata
        let existingPDFData = payload.pdfData ?? Data()

        // Merge PDFs
        let basePDF: PDFDocument
        if existingPDFData.isEmpty {
            basePDF = PDFDocument()
        } else if let doc = PDFDocument(data: existingPDFData) {
            basePDF = doc
        } else {
            throw ImportError.invalidPDF
        }

        guard let importedPDF = PDFDocument(data: importedPDFData) else {
            throw ImportError.invalidPDF
        }

        for index in 0..<importedPDF.pageCount {
            if let page = importedPDF.page(at: index) {
                basePDF.insert(page, at: basePDF.pageCount)
            }
        }

        guard let mergedData = basePDF.dataRepresentation() else { throw ImportError.ioFailed }

        // Update metadata
        var metadata = try JSONDecoder().decode(DocumentMetadata.self, from: metadataData)
        metadata.modified = Date()
        metadata.pageCount = basePDF.pageCount
        // Mark OCR as stale so backend will reprocess/augment if needed
        let updatedMetadata = DocumentMetadata(
            id: metadata.id,
            title: metadata.title,
            created: metadata.created,
            modified: metadata.modified,
            pageCount: metadata.pageCount,
            tags: metadata.tags,
            ocrCompleted: false,
            fullText: metadata.fullText,
            hasPendingTextPage: metadata.hasPendingTextPage
        )

        let newMetadataData = try JSONEncoder().encode(updatedMetadata)

        do {
            try DocumentArchive.write(
                metadata: newMetadataData,
                pdf: .data(mergedData),
                to: documentURL,
                formatVersion: DocumentArchive.currentFormatVersion
            )

            // Re-index the updated document (OCR will be stale until backend processes it)
            Task {
                do {
                    try await SearchIndexService.shared.indexDocument(
                        id: updatedMetadata.id,
                        url: documentURL,
                        title: updatedMetadata.title,
                        fullText: "", // OCR text will be updated when backend reprocesses
                        tags: updatedMetadata.tags,
                        metadata: updatedMetadata
                    )
                    print("✓ Re-indexed appended document: \(updatedMetadata.title)")
                } catch {
                    print("⚠️ Failed to re-index appended document: \(error)")
                }
            }

            return ImportResult(url: documentURL)
        } catch {
            throw ImportError.ioFailed
        }
    }
}
