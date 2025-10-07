//
//  ProvisionalPageManager.swift
//  Yiana
//
//  Created by GPT-5 Codex on 10/07/2025.
//
//  Maintains a cached PDF document that splices provisional (draft) pages into
//  the currently saved PDF so the UI can display in-progress text pages without
//  committing them to disk. The actor serialises PDFKit work and avoids
//  rebuilding the combined document unless the source data changes.
//

import Foundation
import PDFKit

actor ProvisionalPageManager {
    private var provisionalData: Data?
    private var cachedCombinedData: Data?
    private var cachedSavedHash: Int?
    private var cachedProvisionalHash: Int?
    private var cachedRange: Range<Int>?

    /// Sets (or clears) the provisional page data. Any cached combined PDF is
    /// invalidated so the next request rebuilds with the new draft content.
    func updateProvisionalData(_ data: Data?) {
        provisionalData = data
        cachedCombinedData = nil
        cachedSavedHash = nil
        cachedProvisionalHash = data?.hashValue
        cachedRange = nil
    }

    /// Returns a tuple containing the combined PDF (saved pages + provisional
    /// pages) and the range inside that combined document where provisional
    /// pages live. When no provisional data exists, the saved data is returned
    /// unchanged with a nil range.
    func combinedData(using savedData: Data?) -> (data: Data?, provisionalRange: Range<Int>?) {
        let savedHash = savedData?.hashValue
        let provisionalHash = provisionalData?.hashValue

        if let cachedCombinedData,
           cachedSavedHash == savedHash,
           cachedProvisionalHash == provisionalHash {
            return (cachedCombinedData, cachedRange)
        }

        guard let provisionalData else {
            cachedCombinedData = savedData
            cachedSavedHash = savedHash
            cachedProvisionalHash = provisionalHash
            cachedRange = nil
            return (savedData, nil)
        }

        let baseDocument = savedData.flatMap { PDFDocument(data: $0) } ?? PDFDocument()
        guard let draftDocument = PDFDocument(data: provisionalData) else {
            cachedCombinedData = savedData
            cachedSavedHash = savedHash
            cachedProvisionalHash = provisionalHash
            cachedRange = nil
            return (savedData, nil)
        }

        let combinedDocument = PDFDocument()
        let savedPageCount = baseDocument.pageCount

        // Copy saved pages into the combined document.
        for index in 0..<savedPageCount {
            guard let page = baseDocument.page(at: index) else { continue }
            if let copiedPage = page.copy() as? PDFPage {
                combinedDocument.insert(copiedPage, at: combinedDocument.pageCount)
            } else {
                combinedDocument.insert(page, at: combinedDocument.pageCount)
            }
        }

        // Append provisional pages.
        var appendedCount = 0
        for index in 0..<draftDocument.pageCount {
            guard let page = draftDocument.page(at: index) else { continue }
            if let copiedPage = page.copy() as? PDFPage {
                combinedDocument.insert(copiedPage, at: combinedDocument.pageCount)
            } else {
                combinedDocument.insert(page, at: combinedDocument.pageCount)
            }
            appendedCount += 1
        }

        guard appendedCount > 0,
              let combinedData = combinedDocument.dataRepresentation() else {
            cachedCombinedData = savedData
            cachedSavedHash = savedHash
            cachedProvisionalHash = provisionalHash
            cachedRange = nil
            return (savedData, nil)
        }

        cachedCombinedData = combinedData
        cachedSavedHash = savedHash
        cachedProvisionalHash = provisionalHash
        let range = savedPageCount..<(savedPageCount + appendedCount)
        cachedRange = range
        return (combinedData, range)
    }

    /// Clears cached state so we rebuild on the next request.
    func reset() {
        cachedCombinedData = nil
        cachedSavedHash = nil
        cachedProvisionalHash = provisionalData?.hashValue
        cachedRange = nil
    }
}
