//
//  DocumentListViewModel.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation
import SwiftUI
import PDFKit

// Search result type to track what matched
struct SearchResult: Identifiable {
    let id = UUID()
    let documentURL: URL
    let matchType: MatchType
    let snippet: String?
    let pageNumber: Int?  // 1-based page number (page 1 is first page)
    let searchTerm: String?  // The search term that matched
    
    enum MatchType {
        case title
        case content
        case both
    }
}

@MainActor
class DocumentListViewModel: ObservableObject {
    @Published var documentURLs: [URL] = []
    @Published var folderURLs: [URL] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentFolderName: String = "Documents"
    @Published var folderPath: [String] = []
    
    // Search results
    @Published var otherFolderResults: [(url: URL, path: String)] = []
    @Published var isSearching = false
    @Published var searchResults: [SearchResult] = []
    
    private let repository: DocumentRepository
    private var allDocumentURLs: [URL] = []
    private var allFolderURLs: [URL] = []
    private var currentSearchText = ""
    private var allDocumentsGlobal: [(url: URL, relativePath: String)] = []
    
    init(repository: DocumentRepository? = nil) {
        self.repository = repository ?? DocumentRepository()
    }
    
    func loadDocuments() async {
        isLoading = true
        errorMessage = nil
        
        // Simulate async work (file system is actually sync)
        await Task.yield()
        
        allDocumentURLs = repository.documentURLs()
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        allFolderURLs = repository.folderURLs()
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        currentFolderName = repository.currentFolderName
        folderPath = repository.folderPathComponents
        
        // Load all documents globally for search
        allDocumentsGlobal = repository.allDocumentsRecursive()
        print("DEBUG: Loaded \(allDocumentsGlobal.count) documents globally")
        print("DEBUG: Current folder: \(repository.currentFolderPath)")
        
        // Apply current filter
        applyFilter()
        
        isLoading = false
    }
    
    func createNewDocument(title: String) async -> URL? {
        let url = repository.newDocumentURL(title: title)
        // Note: We don't create the file here, just return the URL
        // The UI will create the actual NoteDocument
        return url
    }
    
    func deleteDocument(at url: URL) async throws {
        do {
            try repository.deleteDocument(at: url)
            // Remove from our lists
            allDocumentURLs.removeAll { $0 == url }
            documentURLs.removeAll { $0 == url }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            throw error
        }
    }
    
    func refresh() async {
        await loadDocuments()
    }
    
    // MARK: - Folder Navigation
    
    func navigateToFolder(_ folderName: String) async {
        repository.navigateToFolder(folderName)
        await loadDocuments()
    }
    
    func navigateToParent() async {
        repository.navigateToParent()
        await loadDocuments()
    }
    
    func navigateToRoot() async {
        repository.navigateToRoot()
        await loadDocuments()
    }
    
    func navigateToPathComponent(at index: Int) async {
        // Navigate to a specific component in the path
        let components = repository.folderPathComponents
        guard index < components.count else { return }
        
        // Build path up to the selected component
        let newPath = components.prefix(index + 1).joined(separator: "/")
        
        // Navigate directly to that path
        repository.navigateToRoot()
        if !newPath.isEmpty {
            repository.navigateToFolder(newPath)
        }
        await loadDocuments()
    }
    
    func createFolder(name: String) async -> Bool {
        do {
            try repository.createFolder(name: name)
            await loadDocuments()
            return true
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Search
    
    private func searchPDFContent(at url: URL, for searchText: String) -> (snippet: String, pageNumber: Int?)? {
        // First try to use our OCR data with page info
        if let ocrResult = searchOCRContentWithPageInfo(at: url, for: searchText) {
            return (snippet: ocrResult.snippet, pageNumber: ocrResult.pageNumber)
        }
        
        // Fallback: Load the document to extract PDF data
        guard let data = try? Data(contentsOf: url) else { 
            return nil 
        }
        
        // Try to parse as our document format to get PDF data
        if let pdfData = extractPDFData(from: data),
           let pdfDocument = PDFDocument(data: pdfData) {
            
            // NOTE: PDFs created from scanned images in this app don't have searchable text
            // VisionKit performs OCR for display/selection but doesn't embed it in the PDF
            // This will only work for PDFs that already have embedded text layers
            
            // Try PDFKit's built-in search
            let selections = pdfDocument.findString(searchText, withOptions: .caseInsensitive)
            
            if !selections.isEmpty, let firstMatch = selections.first {
                // Get the page and surrounding text for context
                if let page = firstMatch.pages.first,
                   let pageText = page.string {
                    // Find the match in the page text and get surrounding context
                    let snippet = extractSnippet(from: pageText, around: searchText)
                    let pageIndex = pdfDocument.index(for: page)
                    return (snippet: snippet, pageNumber: pageIndex + 1)  // Convert to 1-based
                }
            }
        }
        
        return nil
    }
    
    private func searchOCRContent(at documentURL: URL, for searchText: String) -> String? {
        let result = searchOCRContentWithPageInfo(at: documentURL, for: searchText)
        return result?.snippet
    }
    
    private func searchOCRContentWithPageInfo(at documentURL: URL, for searchText: String) -> (snippet: String, pageNumber: Int)? {
        // Build path to OCR JSON file
        let documentsDir = repository.documentsDirectory
        let relativePath = documentURL.deletingLastPathComponent().path.replacingOccurrences(of: documentsDir.path, with: "")
        let trimmedPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        
        let ocrResultsDir = documentsDir
            .appendingPathComponent(".ocr_results")
            .appendingPathComponent(trimmedPath)
        
        let baseFileName = documentURL.deletingPathExtension().lastPathComponent
        let jsonURL = ocrResultsDir.appendingPathComponent("\(baseFileName).json")
        
        // Check if OCR JSON exists
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            return nil
        }
        
        do {
            // Read and parse OCR JSON
            let jsonData = try Data(contentsOf: jsonURL)
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let pages = json["pages"] as? [[String: Any]] {
                
                // Search through all pages and track page numbers
                var allMatches: [(snippet: String, pageNumber: Int)] = []
                
                for (index, page) in pages.enumerated() {
                    if let pageText = page["text"] as? String,
                       let pageNumber = page["pageNumber"] as? Int {  // 1-based from OCR
                        if pageText.lowercased().contains(searchText.lowercased()) {
                            let snippet = extractSnippet(from: pageText, around: searchText)
                            allMatches.append((snippet: snippet, pageNumber: pageNumber))
                            print("DEBUG: Found '\(searchText)' in OCR page \(pageNumber) (array index \(index))")
                            print("DEBUG: Page text preview: \(String(pageText.prefix(100)))")
                        }
                    }
                }
                
                // Return first match for now (we'll enhance this later to show all matches)
                return allMatches.first
            }
        } catch {
            print("DEBUG: Error reading OCR data: \(error)")
        }
        
        return nil
    }
    
    private func extractPDFData(from data: Data) -> Data? {
        // Check if it's raw PDF
        let pdfHeader = "%PDF"
        if let string = String(data: data.prefix(4), encoding: .ascii), string == pdfHeader {
            return data
        }
        
        // Try to parse as our document format
        let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
        guard let separatorRange = data.range(of: separator) else { 
            return nil 
        }
        
        let pdfDataStart = separatorRange.upperBound
        if pdfDataStart < data.count {
            return Data(data[pdfDataStart...])
        }
        
        return nil
    }
    
    private func extractSnippet(from text: String, around searchTerm: String, contextLength: Int = 50) -> String {
        let lowercaseText = text.lowercased()
        let lowercaseSearch = searchTerm.lowercased()
        
        guard let range = lowercaseText.range(of: lowercaseSearch) else {
            return ""
        }
        
        let startIndex = text.index(range.lowerBound, offsetBy: -contextLength, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: contextLength, limitedBy: text.endIndex) ?? text.endIndex
        
        var snippet = String(text[startIndex..<endIndex])
        
        // Clean up the snippet
        snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "  ", with: " ")
        
        // Add ellipsis if truncated
        if startIndex != text.startIndex {
            snippet = "..." + snippet
        }
        if endIndex != text.endIndex {
            snippet = snippet + "..."
        }
        
        return snippet
    }
    
    func filterDocuments(searchText: String) async {
        currentSearchText = searchText
        print("DEBUG: Searching for '\(searchText)' in folder '\(repository.currentFolderPath)'")
        applyFilter()
    }
    
    private func applyFilter() {
        if currentSearchText.isEmpty {
            // No filter - show all in current folder
            documentURLs = allDocumentURLs
            folderURLs = allFolderURLs
            otherFolderResults = []
            searchResults = []
            isSearching = false
        } else {
            // Filter by name and content
            let searchLower = currentSearchText.lowercased()
            isSearching = true
            searchResults = []
            
            
            // Filter current folder documents by title and content
            var titleMatches: [URL] = []
            var contentMatches: [URL] = []
            
            for url in allDocumentURLs {
                let titleMatch = url.deletingPathExtension().lastPathComponent.lowercased().contains(searchLower)
                if titleMatch {
                    titleMatches.append(url)
                }
                
                // Also search PDF content
                if let contentResult = searchPDFContent(at: url, for: currentSearchText) {
                    if !titleMatch {
                        contentMatches.append(url)
                        searchResults.append(SearchResult(
                            documentURL: url,
                            matchType: .content,
                            snippet: contentResult.snippet,
                            pageNumber: contentResult.pageNumber,
                            searchTerm: currentSearchText
                        ))
                    } else {
                        // Both title and content match
                        if let index = searchResults.firstIndex(where: { $0.documentURL == url }) {
                            searchResults.remove(at: index)
                        }
                        searchResults.append(SearchResult(
                            documentURL: url,
                            matchType: .both,
                            snippet: contentResult.snippet,
                            pageNumber: contentResult.pageNumber,
                            searchTerm: currentSearchText
                        ))
                    }
                }
            }
            
            // Combine results - title matches first, then content matches
            documentURLs = titleMatches + contentMatches
            
            // Filter current folder subdirectories
            folderURLs = allFolderURLs.filter { url in
                url.lastPathComponent.lowercased().contains(searchLower)
            }
            
            // Search globally for documents NOT in current folder
            let currentPath = repository.currentFolderPath
            var globalResults: [(URL, String)] = []
            
            for item in allDocumentsGlobal {
                // Skip documents in current folder (already searched above)
                if item.relativePath == currentPath {
                    continue
                }
                
                let titleMatch = item.url.deletingPathExtension().lastPathComponent.lowercased().contains(searchLower)
                let contentResult = searchPDFContent(at: item.url, for: currentSearchText)
                
                // Include if title matches OR content matches
                if titleMatch || contentResult != nil {
                    let displayPath = item.relativePath.isEmpty ? "Documents" : item.relativePath.replacingOccurrences(of: "/", with: " > ")
                    globalResults.append((item.url, displayPath))
                    
                    // Add to search results if content matches
                    if let result = contentResult {
                        let matchType: SearchResult.MatchType = titleMatch ? .both : .content
                        searchResults.append(SearchResult(
                            documentURL: item.url,
                            matchType: matchType,
                            snippet: result.snippet,
                            pageNumber: result.pageNumber,
                            searchTerm: currentSearchText
                        ))
                    }
                }
            }
            
            otherFolderResults = globalResults.sorted { $0.0.lastPathComponent < $1.0.lastPathComponent }
            
            print("DEBUG: Found \(documentURLs.count) in current folder, \(otherFolderResults.count) in other folders")
        }
    }
}