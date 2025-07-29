//
//  DocumentListViewModel.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation
import SwiftUI

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
            isSearching = false
        } else {
            // Filter by name (case insensitive)
            let searchLower = currentSearchText.lowercased()
            isSearching = true
            
            // Filter current folder documents
            documentURLs = allDocumentURLs.filter { url in
                url.deletingPathExtension().lastPathComponent.lowercased().contains(searchLower)
            }
            
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