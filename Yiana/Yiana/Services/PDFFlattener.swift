
import Foundation
import PDFKit
import CoreGraphics

/// A service class responsible for flattening PDF annotations into a page's content stream,
/// making them a permanent part of the document.
class PDFFlattener {
    struct FlattenConfig {
        var preserveLinksAndForms: Bool = true
        var box: PDFDisplayBox = .cropBox
    }

    /// Takes a PDF page and an array of annotations, and returns a new
    /// PDF page with the annotations permanently rendered into the content.
    ///
    /// - Parameters:
    ///   - page: The original `PDFPage` to flatten.
    ///   - annotations: An array of `PDFAnnotation` objects to draw onto the page.
    /// - Returns: A new, flattened `PDFPage`, or `nil` if the flattening process fails.
    func flattenAnnotations(on page: PDFPage, annotations: [PDFAnnotation]) -> PDFPage? {
        // Compatibility method retained for existing callers.
        let box: PDFDisplayBox = .cropBox
        var mediaBox = page.bounds(for: box)
        guard mediaBox.width > 0 && mediaBox.height > 0 else { return nil }
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }

        context.beginPDFPage(nil)
        renderPage(page, box: box, into: context)
        renderAnnotations(annotations, box: box, into: context)
        context.endPDFPage()
        context.closePDF()

        return PDFDocument(data: pdfData as Data)?.page(at: 0)
    }

    // Overload to support existing call sites using argument labels in the opposite order
    func flattenAnnotations(_ annotations: [PDFAnnotation], on page: PDFPage) throws -> PDFPage? {
        return flattenAnnotations(on: page, annotations: annotations)
    }

    // MARK: - Small helpers for integration

    /// Builds a new PDFDocument by replacing a page at index with a provided page.
    /// - Returns: A new document with the replacement applied.
    func documentByReplacingPage(in document: PDFDocument, at index: Int, with newPage: PDFPage) -> PDFDocument? {
        guard index >= 0, index < document.pageCount else { return nil }
        let newDoc = PDFDocument()
        for i in 0..<document.pageCount {
            if i == index {
                newDoc.insert(newPage, at: i)
            } else if let p = document.page(at: i) {
                newDoc.insert(p, at: i)
            }
        }
        return newDoc
    }

    /// Writes data atomically to a destination by writing to a temporary file on the same volume
    /// and then replacing the destination.
    func writeAtomically(_ data: Data, to destinationURL: URL) throws {
        let dir = destinationURL.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(".yiana.tmp.\(UUID().uuidString)")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.replaceItemAt(destinationURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        }
    }

    /// New API: Flatten overlays for an entire document and return new PDF data.
    func flatten(document: PDFDocument,
                 overlaysByPageIndex: [Int: [PDFAnnotation]],
                 config: FlattenConfig = FlattenConfig()) -> Data? {
        let pageCount = document.pageCount
        guard pageCount > 0 else { return document.dataRepresentation() }

        // Initialize context with first page's box; we will override per page when beginning pages.
        var firstBox = document.page(at: 0)?.bounds(for: config.box) ?? .zero
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
              let ctx = CGContext(consumer: consumer, mediaBox: &firstBox, nil) else {
            return nil
        }

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageBox = page.bounds(for: config.box)
            guard pageBox.width > 0 && pageBox.height > 0 else {
                // Write an empty page of zero size is invalid; skip or add a minimal page
                continue
            }
            ctx.beginPDFPage([kCGPDFContextMediaBox as String: pageBox] as CFDictionary)
            renderPage(page, box: config.box, into: ctx)
            if let overlays = overlaysByPageIndex[i], !overlays.isEmpty {
                renderAnnotations(overlays, box: config.box, into: ctx)
            }
            ctx.endPDFPage()
        }

        ctx.closePDF()

        guard config.preserveLinksAndForms else { return data as Data }
        guard let flattened = PDFDocument(data: data as Data) else { return data as Data }
        copySafeAnnotations(from: document, to: flattened)
        return flattened.dataRepresentation() ?? (data as Data)
    }

    /// Private helper to handle the Core Graphics drawing operations in the correct order.
    ///
    /// - Parameters:
    ///   - context: The `CGContext` to draw into.
    ///   - page: The original page to be drawn as the base layer.
    ///   - annotations: The annotations to be drawn on top of the page.
    private func renderPage(_ page: PDFPage, box: PDFDisplayBox, into context: CGContext) {
        // Let PDFKit handle coordinate transforms internally
        page.draw(with: box, to: context)
    }

    private func renderAnnotations(_ annotations: [PDFAnnotation], box: PDFDisplayBox, into context: CGContext) {
        guard !annotations.isEmpty else { return }
        context.saveGState()
        for annotation in annotations {
            annotation.draw(with: box, in: context)
        }
        context.restoreGState()
    }

    private func copySafeAnnotations(from original: PDFDocument, to flattened: PDFDocument) {
        // Preserve link and widget (form) annotations only.
        for i in 0..<original.pageCount {
            guard let srcPage = original.page(at: i), let dstPage = flattened.page(at: i) else { continue }
            for a in srcPage.annotations {
                // Preserve only link or widget-like annotations
                // Consider it a widget if its widgetFieldType indicates a concrete widget subtype
                let ft = a.widgetFieldType
                let isWidget = (ft == .text || ft == .button || ft == .choice || ft == .signature)
                let isLink = (a.url != nil || a.destination != nil)
                guard isWidget || isLink else { continue }

                let subtype: PDFAnnotationSubtype = isWidget ? .widget : .link
                let copy = PDFAnnotation(bounds: a.bounds, forType: subtype, withProperties: nil)
                copy.url = a.url
                copy.destination = a.destination
                copy.widgetFieldType = a.widgetFieldType
                copy.widgetStringValue = a.widgetStringValue
                dstPage.addAnnotation(copy)
            }
        }
    }
}
