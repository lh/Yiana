//
//  TextPageRenderService.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Convenience wrapper that bridges layout preferences with the PDF renderer
//  and produces data ready to append to an existing document.
//

import Foundation
import PDFKit
#if os(iOS)
import UIKit
#endif

final class TextPageRenderService {
    static let shared = TextPageRenderService()

    private let renderer = TextPagePDFRenderer()
    private let layoutSettings = TextPageLayoutSettings.shared
    private let headerFormatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        headerFormatter = formatter
    }

    func render(markdown: String, on date: Date = Date()) async throws -> TextPageRenderOutput {
        let paperSize = await layoutSettings.preferredPaperSize()
        let options = TextPageRenderOptions.default(for: paperSize)
        let headerText = "Inserted note — \(headerFormatter.string(from: date))"
        return try renderer.render(markdown: markdown, headerText: headerText, options: options)
    }

    func renderAndAppend(
        markdown: String,
        existingPDFData: Data?,
        on date: Date = Date()
    ) async throws -> (combinedPDF: Data, plainText: String, addedPages: Int, renderedPagePDF: Data) {
        let renderOutput = try await render(markdown: markdown, on: date)

        let baseDocument: PDFDocument
        if let data = existingPDFData, let existing = PDFDocument(data: data) {
            baseDocument = existing
        } else {
            baseDocument = PDFDocument()
        }

        let appendedDocument = PDFDocument(data: renderOutput.pdfData) ?? PDFDocument()
        let appendedPageCount = appendedDocument.pageCount
        guard appendedPageCount > 0 else {
            throw NSError(domain: "TextPageRenderService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Rendered PDF contained no pages"])
        }

#if DEBUG
        if let previewString = appendedDocument.page(at: 0)?.string {
            print("DEBUG TextPageRenderService: Rendered text page content length = \(previewString.count)")
            print("DEBUG TextPageRenderService: Rendered text page content: \n\(previewString)")
        } else {
            print("DEBUG TextPageRenderService: Rendered text page has no extractable string")
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("yiana-rendered-text-page.pdf")
        do {
            try renderOutput.pdfData.write(to: tempURL)
            print("DEBUG TextPageRenderService: Wrote rendered page to \(tempURL.path)")
        } catch {
            print("DEBUG TextPageRenderService: Failed to write temp PDF: \(error)")
        }
#endif

        for index in 0..<appendedPageCount {
            guard let page = appendedDocument.page(at: index) else { continue }

            if let copiedPage = page.copy() as? PDFPage {
                baseDocument.insert(copiedPage, at: baseDocument.pageCount)
            } else {
                baseDocument.insert(page, at: baseDocument.pageCount)
            }
        }

        guard let combinedData = baseDocument.dataRepresentation() else {
            throw NSError(domain: "TextPageRenderService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize combined PDF"])
        }

        return (combinedData, renderOutput.plainText, appendedPageCount, renderOutput.pdfData)
    }
}
