//
//  DocumentListView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers

struct PDFImportData: Identifiable {
    let id = UUID()
    let urls: [URL]
}
#endif

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
    @State private var showingDeleteConfirmation = false
    @State private var documentToDelete: URL?
    #if os(macOS)
    @State private var pdfImportData: PDFImportData? = nil
    @State private var isDraggingPDFs = false
    #endif
    @State private var currentSortOption: SortOption = .title
    @State private var isAscending = true
    
    // Build date string for version display
    private var buildDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
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
                        #if os(macOS)
                        Divider()
                        Button(action: { selectPDFsForImport() }) {
                            Label("Import PDFs...", systemImage: "square.and.arrow.down.on.square")
                        }
                        .keyboardShortcut("I", modifiers: [.command, .shift])
                        #endif
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }

                // Sort menu
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Section("Sort By") {
                            Button(action: {
                                currentSortOption = .title
                                Task {
                                    await viewModel.sortDocuments(by: .title, ascending: isAscending)
                                }
                            }) {
                                HStack {
                                    Text("Title")
                                    if currentSortOption == .title {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button(action: {
                                currentSortOption = .dateModified
                                Task {
                                    await viewModel.sortDocuments(by: .dateModified, ascending: isAscending)
                                }
                            }) {
                                HStack {
                                    Text("Date Modified")
                                    if currentSortOption == .dateModified {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button(action: {
                                currentSortOption = .dateCreated
                                Task {
                                    await viewModel.sortDocuments(by: .dateCreated, ascending: isAscending)
                                }
                            }) {
                                HStack {
                                    Text("Date Created")
                                    if currentSortOption == .dateCreated {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button(action: {
                                currentSortOption = .size
                                Task {
                                    await viewModel.sortDocuments(by: .size, ascending: isAscending)
                                }
                            }) {
                                HStack {
                                    Text("Size")
                                    if currentSortOption == .size {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Button(action: {
                            isAscending.toggle()
                            Task {
                                await viewModel.sortDocuments(by: currentSortOption, ascending: isAscending)
                            }
                        }) {
                            Label(isAscending ? "Ascending" : "Descending",
                                  systemImage: isAscending ? "arrow.up" : "arrow.down")
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
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
                            // Remove onSubmit - we use onChange for all search triggers
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                // Clearing will be handled by onChange
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        // Show progress indicator during search
                        if viewModel.isSearchInProgress {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                #endif
                
                // Development menu (DEBUG only)
                #if DEBUG && os(macOS)
                ToolbarItem(placement: .automatic) {
                    DevelopmentMenu()
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
            .alert("Delete Document", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    documentToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let url = documentToDelete {
                        Task {
                            do {
                                try await viewModel.deleteDocument(at: url)
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    }
                    documentToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this document? This action cannot be undone.")
            }
            .navigationDestination(for: URL.self) { url in
                #if os(iOS)
                DocumentEditView(documentURL: url)
                #else
                DocumentReadView(documentURL: url)
                #endif
            }
            .navigationDestination(for: DocumentNavigationData.self) { navData in
                #if os(iOS)
                DocumentEditView(documentURL: navData.url)
                #else
                DocumentReadView(
                    documentURL: navData.url,
                    searchResult: navData.searchResult
                )
                #endif
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.yianaDocumentsChanged)) { _ in
            Task { await viewModel.refresh() }
        }
        .refreshable {
            await viewModel.refresh()
        }
        #if os(iOS)
        .searchable(text: $searchText, prompt: "Search documents")
        #endif
        .onChange(of: searchText) { _, newValue in
            Task {
                await viewModel.filterDocuments(searchText: newValue)
            }
        }
        #if os(macOS)
        .sheet(item: $pdfImportData) { data in
            BulkImportView(
                pdfURLs: data.urls,
                folderPath: viewModel.folderPath.joined(separator: "/"),
                isPresented: .constant(false),
                onDismiss: {
                    pdfImportData = nil
                }
            )
        }
        .onDrop(of: [.pdf], isTargeted: $isDraggingPDFs) { providers in
            handleDrop(providers: providers)
        }
        .overlay(
            Group {
                if isDraggingPDFs {
                    ZStack {
                        Color.accentColor.opacity(0.1)
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .padding(20)
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.accentColor)
                            Text("Drop PDFs to import")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
        )
        #endif
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
            
            // Show search progress indicator for iOS
            #if os(iOS)
            if viewModel.isSearchInProgress {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            #endif
            
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
                        let searchResult = viewModel.searchResults.first { $0.documentURL == url }
                        Group {
                            if let result = searchResult {
                                NavigationLink(value: DocumentNavigationData(url: url, searchResult: result)) {
                                    DocumentRow(url: url, searchResult: result)
                                }
                            } else {
                                NavigationLink(value: url) {
                                    DocumentRow(url: url, searchResult: nil)
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                duplicateDocument(url)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.indigo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                documentToDelete = url
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
            
            // Other folders section (only when searching)
            if viewModel.isSearching && !viewModel.otherFolderResults.isEmpty {
                Section("In Other Folders") {
                    ForEach(viewModel.otherFolderResults, id: \.url) { result in
                        // Find the corresponding search result
                        let searchResult = viewModel.searchResults.first { $0.documentURL == result.url }
                        NavigationLink(value: DocumentNavigationData(url: result.url, searchResult: searchResult)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.url.deletingPathExtension().lastPathComponent)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(result.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    // Show snippet if available
                                    if let snippet = searchResult?.snippet {
                                        Text(snippet)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            
            // Version info section at the bottom
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text("Build Date: \(buildDateString)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
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

    private func duplicateDocument(_ url: URL) {
        Task {
            do {
                try await viewModel.duplicateDocument(at: url)
            } catch {
                viewModel.errorMessage = "Could not duplicate document: \(error.localizedDescription)"
                showingError = true
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
    
    #if os(macOS)
    private func selectPDFsForImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select PDF files to import"
        panel.prompt = "Import"
        
        panel.begin { response in
            if response == .OK && !panel.urls.isEmpty {
                print("Selected PDFs: \(panel.urls)")
                // Create PDFImportData which will trigger the sheet
                DispatchQueue.main.async {
                    self.pdfImportData = PDFImportData(urls: panel.urls)
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var pdfURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, error in
                    if let url = url {
                        // Copy to temporary location since the provided URL is temporary
                        // Use just the original filename - the temp directory ensures uniqueness
                        let tempDir = FileManager.default.temporaryDirectory
                            .appendingPathComponent("YianaPDFImport", isDirectory: true)
                        
                        // Create the temp subdirectory if needed
                        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                        
                        // Use timestamp for uniqueness instead of UUID in filename
                        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                        let cleanName = url.lastPathComponent
                        let destinationURL = tempDir.appendingPathComponent("\(timestamp)_\(cleanName)")
                        
                        do {
                            try FileManager.default.copyItem(at: url, to: destinationURL)
                            pdfURLs.append(destinationURL)
                        } catch {
                            print("Failed to copy dropped file: \(error)")
                        }
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if !pdfURLs.isEmpty {
                self.pdfImportData = PDFImportData(urls: pdfURLs)
            }
        }
        
        return !providers.isEmpty
    }
    #endif
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
