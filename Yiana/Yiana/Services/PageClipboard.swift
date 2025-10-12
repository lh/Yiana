//
//  PageClipboard.swift
//  Yiana
//

import Foundation
import PDFKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Manages page copy/cut/paste operations across documents
@MainActor
final class PageClipboard {
    static let shared = PageClipboard()

    /// Custom UTI for Yiana page data
    static let pasteboardType = "com.vitygas.yiana.pages"

    /// In-memory storage for the current payload (survives view changes but not app restarts)
    private var activePayload: PageClipboardPayload?

    /// Cache for hasPayload to avoid repeated decoding
    private var _hasPayloadCache: Bool = false

    private init() {}

    /// Sets a new payload in both memory and system pasteboard
    func setPayload(_ payload: PageClipboardPayload) {
        activePayload = payload
        _hasPayloadCache = true
        writeToPasteboard(payload)
    }

    /// Retrieves the current payload from memory first, then pasteboard
    func currentPayload() -> PageClipboardPayload? {
        // First check memory
        if let activePayload = activePayload {
            return activePayload
        }

        // Then check pasteboard and cache if found
        if let payload = readFromPasteboard() {
            activePayload = payload  // Cache for next access
            _hasPayloadCache = true
            return payload
        }

        _hasPayloadCache = false
        return nil
    }

    /// Clears both memory and pasteboard
    func clear() {
        activePayload = nil
        _hasPayloadCache = false
        clearPasteboard()
    }

    /// Returns true if there's currently page data available (optimized with caching)
    var hasPayload: Bool {
        // Use cached value if we have an active payload
        if activePayload != nil {
            return true
        }

        // If no cached payload but cache says true, verify with pasteboard
        if _hasPayloadCache {
            return currentPayload() != nil
        }

        // Check pasteboard and update cache
        let payload = currentPayload()
        _hasPayloadCache = (payload != nil)
        return _hasPayloadCache
    }

    /// Returns the active cut payload if it matches the given document
    func activeCutPayload(for documentID: UUID) -> PageClipboardPayload? {
        guard let payload = currentPayload(),
              payload.operation == .cut,
              payload.sourceDocumentID == documentID else {
            return nil
        }
        return payload
    }

    /// Creates a payload from selected pages in a document
    func createPayload(from pdfData: Data?,
                      indices: Set<Int>,
                      documentID: UUID,
                      operation: PageClipboardPayload.Operation,
                      sourceDataBeforeCut: Data? = nil) throws -> PageClipboardPayload {
        guard !indices.isEmpty else {
            throw PageOperationError.noValidPagesSelected
        }

        guard indices.count <= PageOperationLimits.hardLimit else {
            throw PageOperationError.selectionTooLarge(limit: PageOperationLimits.hardLimit)
        }

        guard let pdfData, let sourcePDF = PDFDocument(data: pdfData) else {
            throw PageOperationError.sourceDocumentUnavailable
        }

        let orderedIndices = indices.sorted()
        let extractedPDF = PDFDocument()

        // Process in chunks for memory efficiency
        if indices.count > PageOperationLimits.warningThreshold {
            for chunk in orderedIndices.chunked(into: PageOperationLimits.chunkSize) {
                autoreleasepool {
                    for index in chunk {
                        guard index >= 0 && index < sourcePDF.pageCount,
                              let page = sourcePDF.page(at: index),
                              let pageCopy = page.copy() as? PDFPage else { continue }
                        extractedPDF.insert(pageCopy, at: extractedPDF.pageCount)
                    }
                }
            }
        } else {
            // For smaller selections, process normally
            for index in orderedIndices {
                guard index >= 0 && index < sourcePDF.pageCount,
                      let page = sourcePDF.page(at: index),
                      let pageCopy = page.copy() as? PDFPage else { continue }
                extractedPDF.insert(pageCopy, at: extractedPDF.pageCount)
            }
        }

        guard let extractedData = extractedPDF.dataRepresentation() else {
            throw PageOperationError.unableToSerialise
        }

        return PageClipboardPayload(
            sourceDocumentID: documentID,
            operation: operation,
            pageCount: orderedIndices.count,
            pdfData: extractedData,
            sourceDataBeforeCut: sourceDataBeforeCut,
            cutIndices: operation == .cut ? orderedIndices : nil
        )
    }

    // MARK: - Pasteboard Operations

    private func writeToPasteboard(_ payload: PageClipboardPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }

        #if os(iOS)
        UIPasteboard.general.setData(data, forPasteboardType: Self.pasteboardType)
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: NSPasteboard.PasteboardType(Self.pasteboardType))
        #endif
    }

    private func readFromPasteboard() -> PageClipboardPayload? {
        #if os(iOS)
        guard let data = UIPasteboard.general.data(forPasteboardType: Self.pasteboardType) else {
            return nil
        }
        #elseif os(macOS)
        guard let data = NSPasteboard.general.data(forType: NSPasteboard.PasteboardType(Self.pasteboardType)) else {
            return nil
        }
        #endif

        do {
            let payload = try JSONDecoder().decode(PageClipboardPayload.self, from: data)
            // Validate version
            if payload.version > 1 {
                // Future versions might need migration
                print("Warning: Clipboard payload version \(payload.version) is newer than supported version 1")
            }
            return payload
        } catch {
            print("Failed to decode clipboard payload: \(error)")
            return nil
        }
    }

    private func clearPasteboard() {
        #if os(iOS)
        if UIPasteboard.general.data(forPasteboardType: Self.pasteboardType) != nil {
            UIPasteboard.general.setData(Data(), forPasteboardType: Self.pasteboardType)
        }
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        if pasteboard.data(forType: NSPasteboard.PasteboardType(Self.pasteboardType)) != nil {
            // Only clear our custom type, preserve other clipboard content
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(Self.pasteboardType))
        }
        #endif
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    /// Splits the array into chunks of the specified size
    func chunked(into size: Int) -> [ArraySlice<Element>] {
        guard size > 0 else { return [] }
        var result: [ArraySlice<Element>] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(self[start..<end])
            start = end
        }
        return result
    }
}