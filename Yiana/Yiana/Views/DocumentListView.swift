//
//  DocumentListView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import YianaDocumentArchive
#if os(macOS)
import UniformTypeIdentifiers

struct PDFImportData: Identifiable {
    let id = UUID()
    let urls: [URL]
    /// Folder URL that granted security scope access - must be released when import completes
    var securityScopedFolderURL: URL?
}
#endif

struct DocumentListView: View {
    @StateObject private var viewModel = DocumentListViewModel()
    @StateObject private var downloadManager = DownloadManager.shared
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
    @State private var pdfImportData: PDFImportData?
    @State private var isDraggingPDFs = false
    @State private var showingDuplicateScanner = false
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var currentSortOption: SortOption = .title
    @State private var isAscending = true
    @State private var hasLoadedAnyContent = false
    @State private var showingSettings = false

    // Build date string for version display
    private var buildDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationTitle(viewModel.currentFolderName)
                .toolbar { toolbarContent }
                .alert("New Document", isPresented: $showingCreateAlert, actions: newDocumentAlertActions)
                .alert("Error", isPresented: $showingError, actions: errorAlertActions, message: errorAlertMessage)
                .alert("New Folder", isPresented: $showingFolderAlert, actions: newFolderAlertActions)
                .alert("Delete Document", isPresented: $showingDeleteConfirmation, actions: deleteDocumentAlertActions, message: deleteDocumentAlertMessage)
                .navigationDestination(for: URL.self, destination: navigationDestination)
                .navigationDestination(for: DocumentNavigationData.self, destination: navigationDestinationForDocument)
        }
        .task {
            await loadDocuments()
            await MainActor.run {
                if contentCountKey > 0 {
                    hasLoadedAnyContent = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.yianaDocumentsChanged)) { _ in
            Task { await viewModel.refresh() }
        }
        .refreshable { await refreshDocuments() }
#if os(iOS)
        .searchable(text: $searchText, prompt: "Search documents")
        .accessibilityHint("Search by document title or document contents")
#endif
        .onChange(of: searchText) { _, newValue in
            handleSearchChange(newValue)
        }
        .onChange(of: contentCountKey) { _, newValue in
            if newValue > 0 {
                hasLoadedAnyContent = true
            }
        }
#if os(macOS)
        .sheet(item: $pdfImportData, content: bulkImportSheet)
        .onDrop(of: [.pdf], isTargeted: $isDraggingPDFs, perform: handleDrop)
        .overlay(macDragOverlay)
        #endif
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        #if os(macOS)
        .sheet(isPresented: $showingDuplicateScanner) {
            DuplicateScannerView(isPresented: $showingDuplicateScanner)
        }
        #endif
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                if !hasLoadedAnyContent {
                    Text("Checking iCloud…")
                        .font(.title2)
                    VStack(spacing: 6) {
                        Text("We’re looking for your existing documents.")
                        Text("Even with a good connection this can take a minute or two after installing or updating.")
                        Text("New here? Tap + to create your first folder or document.")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                } else {
                    Text("No Documents")
                        .font(.title2)
                    Text("Tap + to create your first document")
                        .foregroundColor(.secondary)
                }
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

    @ViewBuilder
    private var mainContent: some View {
        if downloadManager.isDownloading &&
            viewModel.documentURLs.isEmpty &&
            viewModel.folderURLs.isEmpty &&
            viewModel.otherFolderResults.isEmpty {
            downloadingStateView
        } else if viewModel.isLoading && viewModel.documentURLs.isEmpty && viewModel.folderURLs.isEmpty {
            downloadingStateView
        } else if viewModel.isSearchInProgress && viewModel.documentURLs.isEmpty && viewModel.folderURLs.isEmpty && viewModel.otherFolderResults.isEmpty {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Searching...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.documentURLs.isEmpty && viewModel.folderURLs.isEmpty && viewModel.otherFolderResults.isEmpty && !viewModel.isSearchInProgress {
            emptyStateView
        } else {
            documentList
        }
    }

    private var contentCountKey: Int {
        viewModel.documentURLs.count + viewModel.folderURLs.count + viewModel.otherFolderResults.count
    }

    private var downloadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Preparing your documents…")
                .font(.headline)
            Text("Downloading from iCloud. This may take a moment.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createDocument() {
        Task {
            guard !newDocumentTitle.isEmpty else { return }

            if let url = await viewModel.createNewDocument(title: newDocumentTitle) {
                #if os(iOS)
                // Create the actual document
                let document = NoteDocument(fileURL: url)
                let success = await document.save(to: url, for: .forCreating)
                if success {
                    await viewModel.refresh()
                    await MainActor.run {
                        navigationPath.append(url)
                    }
                } else {
                    viewModel.errorMessage = "Failed to create document"
                    showingError = true
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
                do {
                    let metadataData = try encoder.encode(metadata)
                    try DocumentArchive.write(
                        metadata: metadataData,
                        pdf: nil,
                        to: url,
                        formatVersion: DocumentArchive.currentFormatVersion
                    )
                } catch {
                    viewModel.errorMessage = "Failed to create document: \(error.localizedDescription)"
                    showingError = true
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
                    AccessibilityAnnouncer.shared.post("Deleted document \(url.deletingPathExtension().lastPathComponent)")
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                    showingError = true
                    AccessibilityAnnouncer.shared.post("Error deleting document: \(error.localizedDescription)")
                }
            }
        }
    }

    private func duplicateDocument(_ url: URL) {
        Task {
            do {
                try await viewModel.duplicateDocument(at: url)
                AccessibilityAnnouncer.shared.post("Duplicated document \(url.deletingPathExtension().lastPathComponent)")
            } catch {
                viewModel.errorMessage = "Could not duplicate document: \(error.localizedDescription)"
                showingError = true
                AccessibilityAnnouncer.shared.post("Error duplicating document: \(error.localizedDescription)")
            }
        }
    }

    private func downloadAllDocuments() async {
        // Get all document URLs recursively from the repository
        let repository = DocumentRepository()
        let allDocuments = repository.allDocumentsRecursive()
        let urls = allDocuments.map { $0.url }

        print("📥 Starting download of \(urls.count) documents from iCloud")
        downloadManager.downloadAllDocuments(urls: urls)
    }

    @ViewBuilder
    private func newDocumentAlertActions() -> some View {
        TextField("Document Title", text: $newDocumentTitle)
        Button("Cancel", role: .cancel) {
            newDocumentTitle = ""
        }
        Button("Create") {
            createDocument()
        }
    }

    @ViewBuilder
    private func errorAlertActions() -> some View {
        Button("OK") { }
    }

    @ViewBuilder
    private func errorAlertMessage() -> some View {
        Text(viewModel.errorMessage ?? "An error occurred")
    }

    @ViewBuilder
    private func newFolderAlertActions() -> some View {
        TextField("Folder Name", text: $newFolderName)
        Button("Cancel", role: .cancel) {
            newFolderName = ""
        }
        Button("Create") {
            createFolder()
        }
    }

    @ViewBuilder
    private func deleteDocumentAlertActions() -> some View {
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
    }

    @ViewBuilder
    private func deleteDocumentAlertMessage() -> some View {
        Text("Are you sure you want to delete this document? This action cannot be undone.")
    }

    @ViewBuilder
    private func navigationDestination(_ url: URL) -> some View {
        #if os(iOS)
        DocumentEditView(documentURL: url)
        #else
        DocumentReadView(documentURL: url)
        #endif
    }

    @ViewBuilder
    private func navigationDestinationForDocument(_ data: DocumentNavigationData) -> some View {
        #if os(iOS)
        DocumentEditView(documentURL: data.url)
        #else
        DocumentReadView(documentURL: data.url, searchResult: data.searchResult)
        #endif
    }

    private func loadDocuments() async {
        await viewModel.loadDocuments()
    }

    private func refreshDocuments() async {
        await viewModel.refresh()
    }

    private func handleSearchChange(_ newValue: String) {
        Task {
            await viewModel.filterDocuments(searchText: newValue)
        }
    }

    #if os(macOS)
    private func bulkImportSheet(data: PDFImportData) -> some View {
        BulkImportView(
            pdfURLs: data.urls,
            folderPath: viewModel.folderPath.joined(separator: "/"),
            isPresented: .constant(false),
            onDismiss: {
                // Release security-scoped resource access if we had it
                data.securityScopedFolderURL?.stopAccessingSecurityScopedResource()
                pdfImportData = nil
            }
        )
    }

    private var macDragOverlay: some View {
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
    }

    #endif

    @ViewBuilder
    private var documentList: some View {
        VStack(spacing: 0) {
            if !viewModel.folderPath.isEmpty {
                breadcrumbView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
            }

            // Show subtle sync indicator when iCloud placeholders are being filtered
            if viewModel.isSyncing {
                iCloudSyncIndicator
            }

            #if os(iOS)
            if viewModel.isSearchInProgress {
                iosSearchProgress
            }
            #endif

            List {
                foldersSection
                documentsSection
                otherFoldersSection
                versionSection
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        }
    }

    private var iCloudSyncIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Syncing \(viewModel.syncingDocumentCount) document\(viewModel.syncingDocumentCount == 1 ? "" : "s") from iCloud…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
    }

    #if os(iOS)
    private var iosSearchProgress: some View {
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

    @ViewBuilder
    private var foldersSection: some View {
        if !viewModel.folderURLs.isEmpty {
            Section("Folders") {
                ForEach(viewModel.folderURLs, id: \.self) { folderURL in
                    folderRow(for: folderURL)
                }
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        if !viewModel.documentURLs.isEmpty {
            Section(viewModel.isSearching ? "In This Folder" : "Documents") {
                ForEach(viewModel.documentURLs, id: \.self) { url in
                    documentNavigationRow(for: url)
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
    }

    @ViewBuilder
    private var otherFoldersSection: some View {
        if viewModel.isSearching && !viewModel.otherFolderResults.isEmpty {
            Section("In Other Folders") {
                ForEach(viewModel.otherFolderResults, id: \.url) { result in
                    let searchResult = viewModel.searchResults.first { $0.documentURL == result.url }
                    NavigationLink(value: DocumentNavigationData(url: result.url, searchResult: searchResult)) {
                        DocumentRow(
                            url: result.url,
                            searchResult: searchResult,
                            secondaryText: result.path
                        )
                    }
                }
            }
        }
    }

    private var versionSection: some View {
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

    @ViewBuilder
    private func folderRow(for folderURL: URL) -> some View {
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

    @ViewBuilder
    private func documentNavigationRow(for url: URL) -> some View {
        let searchResult = viewModel.searchResults.first { $0.documentURL == url }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !viewModel.folderPath.isEmpty {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: navigateToParent) {
                    Label("Back", systemImage: "chevron.left")
                }
                .toolbarActionAccessibility(label: "Go back")
            }
            #else
            ToolbarItem(placement: .navigation) {
                Button(action: navigateToParent) {
                    Label("Back", systemImage: "chevron.left")
                }
                .toolbarActionAccessibility(label: "Go back")
            }
            #endif
        }

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
                Button(action: selectPDFsForImport) {
                    Label("Import PDFs...", systemImage: "square.and.arrow.down.on.square")
                }
                .keyboardShortcut("I", modifiers: [.command, .shift])

                Button(action: importFromFileList) {
                    Label("Import from File List...", systemImage: "list.bullet.rectangle")
                }
                .help("Import PDFs from a text file containing file paths")

                Button(action: { openWindow(id: "bulk-export") }) {
                    Label("Export PDFs...", systemImage: "square.and.arrow.up.on.square")
                }

                Divider()

                Button(action: { showingDuplicateScanner = true }) {
                    Label("Find Duplicates...", systemImage: "doc.on.doc")
                }
                .help("Scan library for duplicate documents")
                #endif
            } label: {
                Label("Add", systemImage: "plus")
            }
            .toolbarActionAccessibility(label: "Add")
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Section("Sort By") {
                    sortButton(label: "Title", option: .title)
                    sortButton(label: "Date Modified", option: .dateModified)
                    sortButton(label: "Date Created", option: .dateCreated)
                    sortButton(label: "Size", option: .size)
                }

                Divider()

                Button(action: toggleSortOrder) {
                    Label(
                        isAscending ? "Ascending" : "Descending",
                        systemImage: isAscending ? "arrow.up" : "arrow.down"
                    )
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .toolbarActionAccessibility(label: "Sort documents")
            .accessibilityValue("\(currentSortOption.rawValue), \(isAscending ? "ascending" : "descending")")
        }

        ToolbarItem(placement: .automatic) {
            Button(action: startDownloadAll) {
                if downloadManager.isDownloading {
                    HStack(spacing: 6) {
                        ProgressView(value: downloadManager.downloadProgress)
                            .progressViewStyle(.circular)
                            .scaleEffect(0.9)
                        Text("\(downloadManager.downloadedCount)/\(downloadManager.totalCount)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .frame(minWidth: 80)
                } else {
                    Label("Download All", systemImage: "icloud.and.arrow.down")
                }
            }
            .disabled(downloadManager.isDownloading)
            .toolbarActionAccessibility(label: downloadManager.isDownloading ? "Downloading documents" : "Download all documents")
            .accessibilityValue(downloadManager.isDownloading ? "\(downloadManager.downloadedCount) of \(downloadManager.totalCount) downloaded" : "")
            .accessibilityHint(downloadManager.isDownloading ? "Download in progress" : "Double tap to download all documents")
        }

        #if os(macOS)
        ToolbarItem(placement: .automatic) {
            macSearchToolbar
        }
        #endif

        #if DEBUG
        ToolbarItem(placement: .automatic) {
            DevelopmentMenu()
        }
        #endif

#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .toolbarActionAccessibility(label: "Settings")
        }
#else
        ToolbarItem(placement: .automatic) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .toolbarActionAccessibility(label: "Settings")
        }
#endif
    }

    private func sortButton(label: String, option: SortOption) -> some View {
        Button(action: { updateSort(option: option) }) {
            HStack {
                Text(label)
                if currentSortOption == option {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }

    }

    private func updateSort(option: SortOption) {
        currentSortOption = option
        Task {
            await viewModel.sortDocuments(by: option, ascending: isAscending)
        }
    }

    private func toggleSortOrder() {
        isAscending.toggle()
        Task {
            await viewModel.sortDocuments(by: currentSortOption, ascending: isAscending)
        }
    }

    private func navigateToParent() {
        Task {
            await viewModel.navigateToParent()
        }
    }

    private func startDownloadAll() {
        Task {
            await downloadAllDocuments()
        }
    }

    private func clearSearch() {
        searchText = ""
        Task {
            await viewModel.filterDocuments(searchText: "")
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
    private var macSearchToolbar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            if viewModel.isSearchInProgress {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
    }

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

    private func importFromFileList() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a text file containing PDF paths (one per line)"
        panel.prompt = "Open"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let lines = content.components(separatedBy: .newlines)

                    // Parse file paths, skipping comments and empty lines
                    let pdfPaths: [String] = lines.compactMap { line in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)

                        // Skip empty lines and comments
                        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                            return nil
                        }

                        return trimmed
                    }

                    guard !pdfPaths.isEmpty else {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "No Paths Found"
                            alert.informativeText = "The file list did not contain any file paths."
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                        return
                    }

                    // Find the common parent folder to request access
                    let parentFolders = Set(pdfPaths.map { (path: String) -> String in
                        (path as NSString).deletingLastPathComponent
                    })

                    // Request access to the folder containing the PDFs
                    DispatchQueue.main.async {
                        self.requestFolderAccessForImport(pdfPaths: pdfPaths, folders: Array(parentFolders))
                    }
                } catch {
                    print("Failed to read file list: \(error)")
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Failed to Read File"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }

    private func requestFolderAccessForImport(pdfPaths: [String], folders: [String]) {
        // If there's just one folder, we can be more specific
        let folderToRequest = folders.count == 1 ? folders[0] : (folders.first.map { ($0 as NSString).deletingLastPathComponent } ?? "/")

        let folderPanel = NSOpenPanel()
        folderPanel.canChooseDirectories = true
        folderPanel.canChooseFiles = false
        folderPanel.allowsMultipleSelection = false
        folderPanel.directoryURL = URL(fileURLWithPath: folderToRequest)
        folderPanel.message = "Grant access to the folder containing the PDFs to import"
        folderPanel.prompt = "Grant Access"

        folderPanel.begin { response in
            if response == .OK, let folderURL = folderPanel.url {
                // Start security scope access ONCE for the folder
                let didStartAccess = folderURL.startAccessingSecurityScopedResource()
                if !didStartAccess {
                    print("Warning: Could not start security-scoped access to folder")
                }

                // Now we have access to this folder - verify and collect PDFs
                let pdfURLs: [URL] = pdfPaths.compactMap { path in
                    let fileURL = URL(fileURLWithPath: path)

                    // Verify file exists and is a PDF
                    guard FileManager.default.fileExists(atPath: fileURL.path),
                          fileURL.pathExtension.lowercased() == "pdf" else {
                        print("Skipping invalid path: \(path)")
                        return nil
                    }

                    return fileURL
                }

                if !pdfURLs.isEmpty {
                    DispatchQueue.main.async {
                        print("Importing \(pdfURLs.count) PDFs from file list (with folder access)")
                        // Pass the folder URL so scope can be released when import completes
                        self.pdfImportData = PDFImportData(urls: pdfURLs, securityScopedFolderURL: folderURL)
                    }
                } else {
                    // No valid PDFs - release scope immediately
                    folderURL.stopAccessingSecurityScopedResource()
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "No Valid PDFs Found"
                        alert.informativeText = "No valid PDF files were found at the paths in the list. Make sure the files exist and the paths are correct."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
                // NOTE: Don't release scope here - it's released when import completes via onDismiss
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
    let secondaryText: String?
    @State private var statusColor: Color = Color.gray.opacity(0.5)
    private let pinnedTag = "pinned"

    private var metadata: DocumentMetadata? {
        try? NoteDocument.extractMetadata(from: url)
    }

    private var accessibilityTitle: String {
        metadata?.title ?? url.deletingPathExtension().lastPathComponent
    }

    private var accessibilityModifiedDate: Date {
        if let metadataDate = metadata?.modified {
            return metadataDate
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modDate = attributes[.modificationDate] as? Date {
            return modDate
        }
        return Date.distantPast
    }

    private var isPinned: Bool {
        let tags = metadata?.tags ?? []
        return tags.contains { $0.caseInsensitiveCompare(pinnedTag) == .orderedSame }
    }

    init(url: URL, searchResult: SearchResult? = nil, secondaryText: String? = nil) {
        self.url = url
        self.searchResult = searchResult
        self.secondaryText = secondaryText
    }

    var body: some View {
        HStack(spacing: 0) {
            // Status indicator line (hidden during search)
            if searchResult == nil {
                Rectangle()
                    .fill(statusColor)
                    .frame(width: 1.5)
            } else {
                // No status indicator during search
                Color.clear
                    .frame(width: 1.5)
            }

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
                    Text(highlightedSnippet(snippet, searchTerm: result.searchTerm))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.leading, 20)
                }

                if let secondary = secondaryText {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .padding(.leading, searchResult == nil ? 0 : 20)
                } else {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.leading, searchResult == nil ? 0 : 20)
                }
            }
            .padding(.vertical, 4)
            .padding(.leading, 12)
        }
        .task {
            if searchResult == nil {
                await loadStatus()
            }
        }
        .documentRowAccessibility(
            title: accessibilityTitle,
            modified: accessibilityModifiedDate,
            pageCount: metadata?.pageCount,
            isPinned: isPinned,
            hasUnsavedChanges: metadata?.hasPendingTextPage ?? false
        )
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
    private func highlightedSnippet(_ snippet: String, searchTerm: String?) -> AttributedString {
        var attributed = AttributedString(snippet)

        guard let searchTerm = searchTerm, !searchTerm.isEmpty else {
            return attributed
        }

        // Case-insensitive search for all occurrences
        let lowercasedSnippet = snippet.lowercased()
        let lowercasedTerm = searchTerm.lowercased()
        var searchStartIndex = lowercasedSnippet.startIndex

        while searchStartIndex < lowercasedSnippet.endIndex {
            // Find next occurrence from current position
            guard let range = lowercasedSnippet.range(
                of: lowercasedTerm,
                options: [],
                range: searchStartIndex..<lowercasedSnippet.endIndex
            ) else {
                break
            }

            // Convert String.Index to AttributedString.Index
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = .blue
                attributed[attrRange].backgroundColor = .blue.opacity(0.1)
                attributed[attrRange].font = .caption.bold()
            }

            // Move search position forward
            searchStartIndex = range.upperBound
        }

        return attributed
    }

    @MainActor
    private func loadStatus() async {
        let state = downloadState(for: url)
        switch state {
        case .pending, .downloading:
            statusColor = Color.gray.opacity(0.5)
            return
        case .error:
            statusColor = .gray
            return
        case .available:
            break
        }

        guard let metadata = try? NoteDocument.extractMetadata(from: url) else {
            statusColor = .red
            return
        }

        if metadata.pageCount == 0 {
            statusColor = .gray
            return
        }

        let isIndexed = (try? await SearchIndexService.shared.isDocumentIndexed(id: metadata.id)) ?? false

        if metadata.ocrCompleted && isIndexed {
            statusColor = .green
        } else if metadata.ocrCompleted && !isIndexed {
            statusColor = .orange
        } else {
            statusColor = .red
        }
    }

    private enum DownloadState {
        case available
        case pending
        case downloading
        case error
    }

    private func downloadState(for url: URL) -> DownloadState {
        do {
            let values = try url.resourceValues(forKeys: [
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey
            ])

            guard values.isUbiquitousItem == true else {
                return .available
            }

            if let status = values.ubiquitousItemDownloadingStatus {
                switch status {
                case URLUbiquitousItemDownloadingStatus.current,
                     URLUbiquitousItemDownloadingStatus.downloaded:
                    return .available
                case URLUbiquitousItemDownloadingStatus.notDownloaded:
                    return .pending
                default:
                    return .pending
                }
            }

            if values.ubiquitousItemIsDownloading == true {
                return .downloading
            }
        } catch {
            #if DEBUG
            print("DEBUG DocumentRow: Failed to read download state for \(url.lastPathComponent): \(error)")
            #endif
            return .error
        }

        return .available
    }
}

#Preview {
    DocumentListView()
}
