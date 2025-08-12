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
    
    private func searchPDFContent(at url: URL, for searchText: String) -> String? {
        // Load the document to extract PDF data
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        // Try to parse as our document format to get PDF data
        if let pdfData = extractPDFData(from: data),
           let pdfDocument = PDFDocument(data: pdfData) {
            
            // Search through the PDF
            let selections = pdfDocument.findString(searchText, withOptions: .caseInsensitive)
            
            if !selections.isEmpty, let firstMatch = selections.first {
                // Get the page and surrounding text for context
                if let page = firstMatch.pages.first,
                   let pageText = page.string {
                    // Find the match in the page text and get surrounding context
                    let snippet = extractSnippet(from: pageText, around: searchText)
                    return snippet
                }
            }
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
        guard let separatorRange = data.range(of: separator) else { return nil }
        
        let pdfDataStart = separatorRange.upperBound
        if pdfDataStart < data.count {
            return data[pdfDataStart...]
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
                if let contentSnippet = searchPDFContent(at: url, for: currentSearchText) {
                    if !titleMatch {
                        contentMatches.append(url)
                        searchResults.append(SearchResult(
                            documentURL: url,
                            matchType: .content,
                            snippet: contentSnippet
                        ))
                    } else {
                        // Both title and content match
                        if let index = searchResults.firstIndex(where: { $0.documentURL == url }) {
                            searchResults.remove(at: index)
                        }
                        searchResults.append(SearchResult(
                            documentURL: url,
                            matchType: .both,
                            snippet: contentSnippet
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
            otherFolderResults = allDocumentsGlobal
                .filter { item in
                    // Check if document matches search
                    item.url.deletingPathExtension().lastPathComponent.lowercased().contains(searchLower)
                }
                .filter { item in
                    // Exclude documents in current folder
                    item.relativePath != currentPath
                }
                .map { item in
                    // Format the path for display
                    let displayPath = item.relativePath.isEmpty ? "Documents" : item.relativePath.replacingOccurrences(of: "/", with: " > ")
                    return (item.url, displayPath)
                }
                .sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
            
            print("DEBUG: Found \(documentURLs.count) in current folder, \(otherFolderResults.count) in other folders")
        }
    }
}