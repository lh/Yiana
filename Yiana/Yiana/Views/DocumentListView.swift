//
//  DocumentListView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI

struct DocumentListView: View {
    @StateObject private var viewModel = DocumentListViewModel()
    @State private var showingCreateAlert = false
    @State private var newDocumentTitle = ""
    @State private var navigationPath = NavigationPath()
    @State private var showingError = false
    @State private var showingFolderAlert = false
    @State private var newFolderName = ""
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && viewModel.documentURLs.isEmpty && viewModel.folderURLs.isEmpty {
                    ProgressView("Loading documents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.documentURLs.isEmpty && viewModel.folderURLs.isEmpty && viewModel.otherFolderResults.isEmpty {
                    emptyStateView
                } else {
                    documentList
                }
            }
            .navigationTitle(viewModel.currentFolderName)
            .toolbar {
                // Back button for subfolder navigation
                if !viewModel.folderPath.isEmpty {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            Task {
                                await viewModel.navigateToParent()
                            }
                        }) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                    #else
                    ToolbarItem(placement: .navigation) {
                        Button(action: {
                            Task {
                                await viewModel.navigateToParent()
                            }
                        }) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                    #endif
                }
                
                // Create menu
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingCreateAlert = true }) {
                            Label("New Document", systemImage: "doc")
                        }
                        Button(action: { showingFolderAlert = true }) {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                
                #if os(macOS)
                // Search field for macOS in toolbar
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                }
                #endif
            }
            .alert("New Document", isPresented: $showingCreateAlert) {
                TextField("Document Title", text: $newDocumentTitle)
                Button("Cancel", role: .cancel) {
                    newDocumentTitle = ""
                }
                Button("Create") {
                    createDocument()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("New Folder", isPresented: $showingFolderAlert) {
                TextField("Folder Name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
                Button("Create") {
                    createFolder()
                }
            }
            .navigationDestination(for: URL.self) { url in
                #if os(iOS)
                DocumentEditView(documentURL: url)
                #else
                DocumentReadView(documentURL: url)
                #endif
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .searchable(text: $searchText, prompt: "Search documents")
        .onChange(of: searchText) { _ in
            Task {
                await viewModel.filterDocuments(searchText: searchText)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No Documents")
                    .font(.title2)
                Text("Tap + to create your first document")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No Results")
                    .font(.title2)
                Text("No documents or folders match '\(searchText)'")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentList: some View {
        VStack(spacing: 0) {
            // Breadcrumb navigation
            if !viewModel.folderPath.isEmpty {
                breadcrumbView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
            }
            
            List {
                // Folders section
                if !viewModel.folderURLs.isEmpty {
                Section("Folders") {
                    ForEach(viewModel.folderURLs, id: \.self) { folderURL in
                        Button(action: {
                            Task {
                                await viewModel.navigateToFolder(folderURL.lastPathComponent)
                            }
                        }) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                                Text(folderURL.lastPathComponent)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Documents section
            if !viewModel.documentURLs.isEmpty {
                Section(viewModel.isSearching ? "In This Folder" : "Documents") {
                    ForEach(viewModel.documentURLs, id: \.self) { url in
                        NavigationLink(value: url) {
                            DocumentRow(
                                url: url,
                                searchResult: viewModel.searchResults.first { $0.documentURL == url }
                            )
                        }
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
            
            // Other folders section (only when searching)
            if viewModel.isSearching && !viewModel.otherFolderResults.isEmpty {
                Section("In Other Folders") {
                    ForEach(viewModel.otherFolderResults, id: \.url) { result in
                        NavigationLink(value: result.url) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.url.deletingPathExtension().lastPathComponent)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(result.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        }
    }
    
    private func createDocument() {
        Task {
            guard !newDocumentTitle.isEmpty else { return }
            
            if let url = await viewModel.createNewDocument(title: newDocumentTitle) {
                #if os(iOS)
                // Create the actual document
                let document = NoteDocument(fileURL: url)
                document.save(to: url, for: .forCreating) { success in
                    Task { @MainActor in
                        if success {
                            await viewModel.refresh()
                            navigationPath.append(url)
                        } else {
                            viewModel.errorMessage = "Failed to create document"
                            showingError = true
                        }
                    }
                }
                #else
                // macOS: Create a valid NoteDocument structure
                let metadata = DocumentMetadata(
                    id: UUID(),
                    title: newDocumentTitle,
                    created: Date(),
                    modified: Date(),
                    pageCount: 0,
                    tags: [],
                    ocrCompleted: false,
                    fullText: nil
                )
                
                // Create the document in NoteDocument format
                let encoder = JSONEncoder()
                if let metadataData = try? encoder.encode(metadata) {
                    var contents = Data()
                    contents.append(metadataData)
                    contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
                    // No PDF data yet
                    
                    try? contents.write(to: url)
                }
                
                await viewModel.refresh()
                #endif
            }
            
            newDocumentTitle = ""
        }
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let url = viewModel.documentURLs[index]
                do {
                    try await viewModel.deleteDocument(at: url)
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func createFolder() {
        Task {
            guard !newFolderName.isEmpty else { return }
            
            let success = await viewModel.createFolder(name: newFolderName)
            if !success {
                showingError = true
            }
            
            newFolderName = ""
        }
    }
    
    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Button(action: {
                    Task {
                        await viewModel.navigateToRoot()
                    }
                }) {
                    Text("Documents")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                
                ForEach(Array(viewModel.folderPath.enumerated()), id: \.offset) { index, folder in
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            Task {
                                await viewModel.navigateToPathComponent(at: index)
                            }
                        }) {
                            Text(folder)
                                .font(.caption)
                                .foregroundColor(index == viewModel.folderPath.count - 1 ? .primary : .accentColor)
                        }
                    }
                }
            }
        }
    }
}

// Simple row view for document
struct DocumentRow: View {
    let url: URL
    let searchResult: SearchResult?
    
    init(url: URL, searchResult: SearchResult? = nil) {
        self.url = url
        self.searchResult = searchResult
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                // Search indicator
                if let result = searchResult {
                    Image(systemName: result.matchType == .content ? "doc.text.magnifyingglass" : "textformat")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            // Show snippet for content matches
            if let result = searchResult,
               result.matchType == .content || result.matchType == .both,
               let snippet = result.snippet {
                Text(snippet)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 20)
            } else {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        // Get file modification date if available
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modDate = attributes[.modificationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: modDate)
        }
        return url.lastPathComponent
    }
}

#Preview {
    DocumentListView()
}