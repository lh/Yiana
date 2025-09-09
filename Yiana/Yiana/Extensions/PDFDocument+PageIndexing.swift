//
//  PDFDocument+PageIndexing.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import PDFKit

/// Extension to provide 1-based page indexing for PDFKit
/// All Yiana code should use 1-based page numbers (page 1 is the first page)
/// These extensions handle the conversion to/from PDFKit's 0-based indexing
extension PDFDocument {
    
    /// Get a page using 1-based index (page 1 is the first page)
    /// - Parameter pageNumber: 1-based page number
    /// - Returns: The PDF page, or nil if out of bounds
    func getPage(number pageNumber: Int) -> PDFPage? {
        guard pageNumber > 0 && pageNumber <= pageCount else { return nil }
        return page(at: pageNumber - 1)
    }
    
    /// Get the 1-based page number for a given PDFPage
    /// - Parameter page: The PDF page
    /// - Returns: 1-based page number, or nil if page not in document
    func getPageNumber(for page: PDFPage) -> Int? {
        let zeroBasedIndex = index(for: page)
        guard zeroBasedIndex >= 0 else { return nil }
        return zeroBasedIndex + 1
    }
    
    /// Insert a page using 1-based index
    /// - Parameters:
    ///   - page: The page to insert
    ///   - pageNumber: 1-based position (1 to insert at beginning)
    func insertPage(_ page: PDFPage, at pageNumber: Int) {
        let zeroBasedIndex = max(0, min(pageNumber - 1, pageCount))
        insert(page, at: zeroBasedIndex)
    }
    
    /// Remove a page using 1-based index
    /// - Parameter pageNumber: 1-based page number to remove
    func removePage(byNumber pageNumber: Int) {
        guard pageNumber > 0 && pageNumber <= pageCount else { return }
        removePage(at: pageNumber - 1)
    }
    
    /// Find string with 1-based page numbers in results
    /// - Parameters:
    ///   - string: The string to search for
    ///   - options: Search options
    /// - Returns: Array of search results with 1-based page numbers
    func findStringWith1BasedPages(_ string: String, withOptions options: NSString.CompareOptions = []) -> [(selection: PDFSelection, pageNumber: Int)] {
        let selections = findString(string, withOptions: options)
        
        return selections.compactMap { selection in
            guard let page = selection.pages.first,
                  let pageNum = getPageNumber(for: page) else { return nil }
            return (selection, pageNum)
        }
    }
}

extension PDFView {
    
    /// Navigate to a page using 1-based index
    /// - Parameter pageNumber: 1-based page number
    func goToPage(number pageNumber: Int) {
        guard let document = document,
              let page = document.getPage(number: pageNumber) else { return }
        go(to: page)
    }
    
    /// Get the current 1-based page number
    /// - Returns: Current page number (1-based), or nil if no document/page
    var currentPageNumber: Int? {
        guard let currentPage = currentPage,
              let document = document else { return nil }
        return document.getPageNumber(for: currentPage)
    }
    
    /// Check if can go to a specific 1-based page number
    /// - Parameter pageNumber: 1-based page number
    /// - Returns: true if navigation is possible
    func canGoToPage(number pageNumber: Int) -> Bool {
        guard let document = document else { return false }
        return pageNumber > 0 && pageNumber <= document.pageCount
    }
    
    /// Check if can go to next page (using 1-based thinking)
    var canGoToNextPageNumber: Bool {
        guard let current = currentPageNumber,
              let document = document else { return false }
        return current < document.pageCount
    }
    
    /// Check if can go to previous page (using 1-based thinking)
    var canGoToPreviousPageNumber: Bool {
        guard let current = currentPageNumber else { return false }
        return current > 1
    }
    
    /// Go to next page
    func goToNextPageNumber() {
        guard canGoToNextPageNumber,
              let current = currentPageNumber else { return }
        goToPage(number: current + 1)
    }
    
    /// Go to previous page
    func goToPreviousPageNumber() {
        guard canGoToPreviousPageNumber,
              let current = currentPageNumber else { return }
        goToPage(number: current - 1)
    }
}