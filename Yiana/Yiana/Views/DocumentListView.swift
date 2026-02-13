//
//  DocumentListView.swift
//  Yiana
//

import SwiftUI
import Combine
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
    @State private var hasLoadedAnyContent = false
    @State private var showingSettings = false
    @State private var downloadingURLs: Set<URL> = []
    /// URL to auto-open once its download completes
    @State private var pendingOpenURL: URL?

    // File management state
    @State private var showingRenameAlert = false
    @State private var renameTarget: RenameTarget?
    @State private var renameText = ""
    @State private var showingFolderPicker = false
    @State private var moveTarget: MoveTarget?
    @State private var showingDeleteFolderConfirmation = false
    @State private var folderToDelete: URL?
    @State private var folderDeleteContents: DocumentRepository.FolderContents?

    // Multi-select state
    @State private var isSelectMode = false
    @State private var selectedDocumentIDs: Set<UUID> = []
    @State private var showingBulkDeleteConfirmation = false

    enum RenameTarget {
        case document(DocumentListItem)
        case folder(URL)
    }

    enum MoveTarget {
        case document(DocumentListItem)
        case folder(URL)
        case bulkDocuments(Set<UUID>)
    }

    // Build date string for version display
    private var buildDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    private var documentListTitle: String {
        let total = viewModel.documents.count
        let downloaded = total - viewModel.syncingDocumentCount
        if viewModel.syncingDocumentCount > 0 {
            return "\(viewModel.currentFolderName) (\(downloaded)/\(total))"
        }
        return "\(viewModel.currentFolderName) (\(total))"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationTitle(documentListTitle)
                .toolbar { toolbarContent }
                .alert("New Document", isPresented: $showingCreateAlert, actions: newDocumentAlertActions)
                .alert("Error", isPresented: $showingError, actions: errorAlertActions, message: errorAlertMessage)
                .alert("New Folder", isPresented: $showingFolderAlert, actions: newFolderAlertActions)
                .alert("Delete Document", isPresented: $showingDeleteConfirmation, actions: deleteDocumentAlertActions, message: deleteDocumentAlertMessage)
                .alert("Rename", isPresented: $showingRenameAlert, actions: renameAlertActions)
                .alert("Delete Folder", isPresented: $showingDeleteFolderConfirmation, actions: deleteFolderAlertActions, message: deleteFolderAlertMessage)
                .alert("Delete Documents", isPresented: $showingBulkDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        let idsToDelete = selectedDocumentIDs
                        selectedDocumentIDs.removeAll()
                        isSelectMode = false
                        Task { try? await viewModel.deleteDocuments(ids: idsToDelete) }
                    }
                } message: {
                    Text("Delete \(selectedDocumentIDs.count) documents? This cannot be undone.")
                }
                .sheet(isPresented: $showingFolderPicker) {
                    folderPickerSheet
                }
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
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name.yianaDocumentsChanged)
                .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
        ) { _ in
            // Document list updates via ValueObservation; this only refreshes folders
            #if DEBUG
            SyncPerfLog.shared.countNotification()
            #endif
            Task { await viewModel.refresh() }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .yianaDocumentsDownloaded)
        ) { notification in
            guard let urls = notification.userInfo?["urls"] as? [URL] else { return }
            for url in urls {
                let standardURL = url.standardizedFileURL
                downloadingURLs.remove(standardURL)
                // Auto-open if this was a user-initiated download
                if standardURL == pendingOpenURL {
                    pendingOpenURL = nil
                    navigationPath.append(standardURL)
                }
            }
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
            viewModel.documents.isEmpty &&
            viewModel.folderURLs.isEmpty &&
            viewModel.otherFolderResults.isEmpty {
            downloadingStateView
        } else if viewModel.isLoading && viewModel.documents.isEmpty && viewModel.folderURLs.isEmpty {
            downloadingStateView
        } else if viewModel.isSearchInProgress && viewModel.documents.isEmpty && viewModel.folderURLs.isEmpty && viewModel.otherFolderResults.isEmpty {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Searching...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.documents.isEmpty && viewModel.folderURLs.isEmpty && viewModel.otherFolderResults.isEmpty && !viewModel.isSearchInProgress {
            emptyStateView
        } else {
            documentList
        }
    }

    private var contentCountKey: Int {
        viewModel.documents.count + viewModel.folderURLs.count + viewModel.otherFolderResults.count
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
                let item = viewModel.documents[index]
                do {
                    try await viewModel.deleteDocument(at: item.url)
                    AccessibilityAnnouncer.shared.post("Deleted document \(item.title)")
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
    private func renameAlertActions() -> some View {
        TextField("Name", text: $renameText)
        Button("Cancel", role: .cancel) {
            renameTarget = nil
            renameText = ""
        }
        Button("Rename") {
            let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else { return }
            Task {
                do {
                    switch renameTarget {
                    case .document(let item):
                        try await viewModel.renameDocument(item, newName: newName)
                    case .folder(let url):
                        try await viewModel.renameFolder(url, newName: newName)
                    case nil:
                        break
                    }
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
            renameTarget = nil
            renameText = ""
        }
    }

    @ViewBuilder
    private func deleteFolderAlertActions() -> some View {
        Button("Cancel", role: .cancel) {
            folderToDelete = nil
            folderDeleteContents = nil
        }
        Button("Delete", role: .destructive) {
            if let url = folderToDelete {
                Task {
                    do {
                        try await viewModel.deleteFolder(url)
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
            folderToDelete = nil
            folderDeleteContents = nil
        }
    }

    @ViewBuilder
    private func deleteFolderAlertMessage() -> some View {
        if let contents = folderDeleteContents {
            if contents.isEmpty {
                Text("Delete this empty folder?")
            } else {
                Text("This folder contains \(contents.documentCount) document(s) and \(contents.subfolderCount) subfolder(s). All contents will be permanently deleted.")
            }
        } else {
            Text("Delete this folder and all its contents?")
        }
    }

    @ViewBuilder
    private var folderPickerSheet: some View {
        let currentPath: String = {
            switch moveTarget {
            case .document(let item): return item.folderPath
            case .folder(let url): return url.relativeFolderPath(relativeTo: viewModel.documentsDirectory)
            case .bulkDocuments: return viewModel.folderPath.joined(separator: "/")
            case nil: return ""
            }
        }()

        let excludedPath: String? = {
            switch moveTarget {
            case .folder(let url):
                let rel = url.relativeFolderPath(relativeTo: viewModel.documentsDirectory)
                if rel.isEmpty {
                    return url.lastPathComponent
                } else {
                    return rel + "/" + url.lastPathComponent
                }
            default: return nil
            }
        }()

        let allFolders = viewModel.allFolderPaths()
        let filteredFolders: [(name: String, path: String)] = {
            guard let excluded = excludedPath else { return allFolders }
            return allFolders.filter { folder in
                folder.path != excluded && !folder.path.hasPrefix(excluded + "/")
            }
        }()

        FolderPickerView(
            currentFolderPath: currentPath,
            folders: filteredFolders
        ) { targetPath in
            let captured = moveTarget
            moveTarget = nil
            if case .bulkDocuments = captured {
                selectedDocumentIDs.removeAll()
                isSelectMode = false
            }
            Task {
                do {
                    switch captured {
                    case .document(let item):
                        try await viewModel.moveDocument(item, toFolder: targetPath)
                    case .folder(let url):
                        try await viewModel.moveFolder(url, toFolder: targetPath)
                    case .bulkDocuments(let ids):
                        try await viewModel.moveDocuments(ids: ids, toFolder: targetPath)
                    case nil:
                        break
                    }
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
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

    /// Force a high-priority iCloud download using NSFileCoordinator.
    /// Unlike startDownloadingUbiquitousItem (which is a low-priority hint),
    /// a coordinated read tells the FileProvider to download NOW.
    private func prioritizeDownload(for url: URL) {
        // Kick off the hint immediately so the system knows we want it
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        scheduleDownloadTimeout(for: url)

        // Coordinated read forces high-priority download
        let standardURL = url.standardizedFileURL
        Task.detached(priority: .userInitiated) {
            let coordinator = NSFileCoordinator()
            var coordError: NSError?
            var succeeded = false
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { _ in
                succeeded = true
            }
            if let coordError {
                print("[Download] Failed: \(url.lastPathComponent): \(coordError.localizedDescription)")
            }
            // Post notification to clear download indicator — don't wait for UbiquityMonitor round-trip
            if succeeded {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .yianaDocumentsDownloaded,
                        object: nil,
                        userInfo: ["urls": [standardURL]]
                    )
                }
            }
        }
    }

    private func scheduleDownloadTimeout(for url: URL) {
        let standardURL = url.standardizedFileURL
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            guard downloadingURLs.contains(standardURL) else { return }
            let values = try? standardURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            let status = values?.ubiquitousItemDownloadingStatus
            if status != .current && status != .downloaded {
                downloadingURLs.remove(standardURL)
            }
        }
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

            List(selection: isSelectMode ? $selectedDocumentIDs : nil) {
                foldersSection
                documentsSection
                otherFoldersSection
                versionSection
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            .environment(\.editMode, isSelectMode ? .constant(.active) : .constant(.inactive))
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
                        .contextMenu {
                            Button {
                                renameTarget = .folder(folderURL)
                                renameText = folderURL.lastPathComponent
                                showingRenameAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                moveTarget = .folder(folderURL)
                                showingFolderPicker = true
                            } label: {
                                Label("Move to...", systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                folderToDelete = folderURL
                                folderDeleteContents = viewModel.folderContents(at: folderURL)
                                showingDeleteFolderConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        if !viewModel.documents.isEmpty {
            Section(viewModel.isSearching ? "In This Folder" : "Documents") {
                ForEach(viewModel.documents) { item in
                    documentNavigationRow(for: item)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                duplicateDocument(item.url)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.indigo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                documentToDelete = item.url
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                renameTarget = .document(item)
                                renameText = item.title
                                showingRenameAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                moveTarget = .document(item)
                                showingFolderPicker = true
                            } label: {
                                Label("Move to...", systemImage: "folder")
                            }
                            .disabled(item.isPlaceholder)

                            Button {
                                duplicateDocument(item.url)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                documentToDelete = item.url
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
                ForEach(viewModel.otherFolderResults, id: \.item.id) { result in
                    let searchResult = viewModel.searchResults.first { $0.documentURL == result.item.url }
                    if isSelectMode {
                        DocumentRow(
                            item: result.item,
                            searchResult: searchResult,
                            secondaryText: result.path
                        )
                        .tag(result.item.id)
                    } else {
                        NavigationLink(value: DocumentNavigationData(url: result.item.url, searchResult: searchResult)) {
                            DocumentRow(
                                item: result.item,
                                searchResult: searchResult,
                                secondaryText: result.path
                            )
                        }
                        .tag(result.item.id)
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
            isSelectMode = false
            selectedDocumentIDs.removeAll()
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
    private func documentNavigationRow(for item: DocumentListItem) -> some View {
        Group {
            if isSelectMode {
                let searchResult = viewModel.searchResults.first { $0.documentURL == item.url }
                DocumentRow(
                    item: item,
                    searchResult: searchResult,
                    isDownloading: downloadingURLs.contains(item.url.standardizedFileURL)
                )
            } else if item.isPlaceholder {
                Button {
                    let standardURL = item.url.standardizedFileURL
                    downloadingURLs.insert(standardURL)
                    pendingOpenURL = standardURL
                    prioritizeDownload(for: item.url)
                } label: {
                    DocumentRow(
                        item: item,
                        searchResult: nil,
                        isDownloading: downloadingURLs.contains(item.url.standardizedFileURL)
                    )
                }
                .buttonStyle(.plain)
            } else {
                let searchResult = viewModel.searchResults.first { $0.documentURL == item.url }
                if let result = searchResult {
                    NavigationLink(value: DocumentNavigationData(url: item.url, searchResult: result)) {
                        DocumentRow(item: item, searchResult: result)
                    }
                } else {
                    NavigationLink(value: item.url) {
                        DocumentRow(item: item, searchResult: nil)
                    }
                }
            }
        }
        .tag(item.id)
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

        // Select / Done toggle
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                if isSelectMode {
                    selectedDocumentIDs.removeAll()
                    isSelectMode = false
                } else {
                    isSelectMode = true
                }
            } label: {
                Text(isSelectMode ? "Done" : "Select")
            }
        }
        #else
        ToolbarItem(placement: .automatic) {
            Button {
                if isSelectMode {
                    selectedDocumentIDs.removeAll()
                    isSelectMode = false
                } else {
                    isSelectMode = true
                }
            } label: {
                Text(isSelectMode ? "Done" : "Select")
            }
        }
        #endif

        if !isSelectMode {
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
                    .help("Import up to 100 PDF files")

                    Button(action: selectFolderForImport) {
                        Label("Import from Folder...", systemImage: "folder.badge.plus")
                    }
                    .keyboardShortcut("I", modifiers: [.command, .option])
                    .help("Import all PDFs from a folder (for bulk imports)")

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
                            viewModel.currentSortAscending ? "Ascending" : "Descending",
                            systemImage: viewModel.currentSortAscending ? "arrow.up" : "arrow.down"
                        )
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .toolbarActionAccessibility(label: "Sort documents")
                .accessibilityValue("\(viewModel.currentSortOption.rawValue), \(viewModel.currentSortAscending ? "ascending" : "descending")")
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

        // Bulk action bar (visible when in select mode with items selected)
        if isSelectMode && !selectedDocumentIDs.isEmpty {
            #if os(iOS)
            ToolbarItemGroup(placement: .bottomBar) {
                bulkActionButtons
            }
            #else
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    bulkActionButtons
                }
            }
            #endif
        }

        // Select All (visible in select mode even with empty selection)
        if isSelectMode {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Select All") {
                    selectAllDocuments()
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button("Select All") {
                    selectAllDocuments()
                }
                .keyboardShortcut("a", modifiers: .command)
            }
            #endif
        }
    }

    @ViewBuilder
    private var bulkActionButtons: some View {
        Button(role: .destructive) {
            showingBulkDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }

        Spacer()

        Text("\(selectedDocumentIDs.count) selected")
            .font(.caption)
            .foregroundStyle(.secondary)

        Spacer()

        Button {
            moveTarget = .bulkDocuments(selectedDocumentIDs)
            showingFolderPicker = true
        } label: {
            Label("Move", systemImage: "folder")
        }
        .disabled(selectionContainsPlaceholder)
    }

    private var selectionContainsPlaceholder: Bool {
        selectedDocumentIDs.contains { id in
            viewModel.documents.first(where: { $0.id == id })?.isPlaceholder == true
                || viewModel.otherFolderResults.first(where: { $0.item.id == id })?.item.isPlaceholder == true
        }
    }

    private func selectAllDocuments() {
        var ids = Set(viewModel.documents.map(\.id))
        for result in viewModel.otherFolderResults {
            ids.insert(result.item.id)
        }
        selectedDocumentIDs = ids
    }

    private func sortButton(label: String, option: SortOption) -> some View {
        Button(action: { updateSort(option: option) }) {
            HStack {
                Text(label)
                if viewModel.currentSortOption == option {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }

    }

    private func updateSort(option: SortOption) {
        Task {
            await viewModel.sortDocuments(by: option, ascending: viewModel.currentSortAscending)
        }
    }

    private func toggleSortOrder() {
        Task {
            await viewModel.sortDocuments(by: viewModel.currentSortOption, ascending: !viewModel.currentSortAscending)
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
        panel.message = "Select up to 100 PDF files to import (use 'Import from Folder' for more)"
        panel.prompt = "Import"

        panel.begin { response in
            if response == .OK && !panel.urls.isEmpty {
                if panel.urls.count > 100 {
                    // Show alert guiding user to folder import
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Too Many Files Selected"
                        alert.informativeText = "For importing more than 100 files, please use 'Import from Folder' instead. This ensures reliable importing of large collections."
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                    return
                }
                print("Selected PDFs: \(panel.urls)")
                // Create PDFImportData which will trigger the sheet
                DispatchQueue.main.async {
                    self.pdfImportData = PDFImportData(urls: panel.urls)
                }
            }
        }
    }

    /// Import PDFs from a folder (for bulk imports > 100 files)
    /// Uses a single folder-level sandbox extension, avoiding per-file limits
    private func selectFolderForImport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder containing PDF files to import"
        panel.prompt = "Import Folder"

        panel.begin { response in
            if response == .OK, let folderURL = panel.url {
                // Start security-scoped access to folder
                guard folderURL.startAccessingSecurityScopedResource() else {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Access Denied"
                        alert.informativeText = "Could not access the selected folder. Please try again."
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                    return
                }

                // Scan folder for PDF files (top-level only)
                let pdfURLs = self.findPDFs(in: folderURL)

                if pdfURLs.isEmpty {
                    folderURL.stopAccessingSecurityScopedResource()
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "No PDFs Found"
                        alert.informativeText = "The selected folder does not contain any PDF files."
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                    return
                }

                print("Found \(pdfURLs.count) PDFs in folder: \(folderURL.path)")

                DispatchQueue.main.async {
                    // Pass folder URL for cleanup when import completes
                    self.pdfImportData = PDFImportData(
                        urls: pdfURLs,
                        securityScopedFolderURL: folderURL
                    )
                }
            }
        }
    }

    /// Find all PDF files in a folder (non-recursive)
    private func findPDFs(in folderURL: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            url.pathExtension.lowercased() == "pdf"
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
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

// Simple row view for document -- driven entirely by DocumentListItem (no ZIP opens)
struct DocumentRow: View {
    let item: DocumentListItem
    let searchResult: SearchResult?
    let secondaryText: String?
    let isDownloading: Bool
    @State private var statusColor: Color = Color.gray.opacity(0.5)
    @State private var isPulsing = false

    init(item: DocumentListItem, searchResult: SearchResult? = nil, secondaryText: String? = nil, isDownloading: Bool = false) {
        self.item = item
        self.searchResult = searchResult
        self.secondaryText = secondaryText
        self.isDownloading = isDownloading
    }

    var body: some View {
        HStack(spacing: 0) {
            // Status indicator line (hidden during search)
            if searchResult == nil {
                Rectangle()
                    .fill(isDownloading ? Color.red : statusColor)
                    .frame(width: isDownloading ? 3 : 1.5)
                    .opacity(isDownloading ? (isPulsing ? 1.0 : 0.2) : 1.0)
                    .animation(
                        isDownloading
                            ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                            : .default,
                        value: isPulsing
                    )
                    .onChange(of: isDownloading) {
                        isPulsing = isDownloading
                    }
                    .onAppear {
                        if isDownloading { isPulsing = true }
                    }
            } else {
                Color.clear
                    .frame(width: 1.5)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if item.isPlaceholder {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let result = searchResult {
                        Image(systemName: result.matchType == .content ? "doc.text.magnifyingglass" : "textformat")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Text(item.url.deletingPathExtension().lastPathComponent)
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
                loadStatus()
            }
        }
        .onChange(of: item.ocrCompleted) {
            loadStatus()
        }
        .documentRowAccessibility(
            title: item.title,
            modified: item.modifiedDate,
            pageCount: item.pageCount,
            isPinned: item.isPinned,
            hasUnsavedChanges: item.hasPendingTextPage
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: item.modifiedDate)
    }

    private func highlightedSnippet(_ snippet: String, searchTerm: String?) -> AttributedString {
        var attributed = AttributedString(snippet)

        guard let searchTerm = searchTerm, !searchTerm.isEmpty else {
            return attributed
        }

        let lowercasedSnippet = snippet.lowercased()
        let lowercasedTerm = searchTerm.lowercased()
        var searchStartIndex = lowercasedSnippet.startIndex

        while searchStartIndex < lowercasedSnippet.endIndex {
            guard let range = lowercasedSnippet.range(
                of: lowercasedTerm,
                options: [],
                range: searchStartIndex..<lowercasedSnippet.endIndex
            ) else {
                break
            }

            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = .blue
                attributed[attrRange].backgroundColor = .blue.opacity(0.1)
                attributed[attrRange].font = .caption.bold()
            }

            searchStartIndex = range.upperBound
        }

        return attributed
    }

    private func loadStatus() {
        // Short-circuit for placeholders -- no filesystem I/O needed
        if item.isPlaceholder {
            statusColor = Color.gray.opacity(0.5)
            return
        }

        #if DEBUG
        SyncPerfLog.shared.countDownloadStateCheck()
        #endif

        let state = downloadState(for: item.url)
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

        if item.pageCount == 0 {
            statusColor = .gray
        } else if item.ocrCompleted {
            statusColor = .green
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
