//
//  DocumentEditView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit
#if os(iOS)
import UIKit
#endif

#if os(iOS)
enum ActiveSheet: Identifiable, Equatable {
    case share(URL)
    case pageManagement

    var id: String {
        switch self {
        case .share: return "share"
        case .pageManagement: return "pageManagement"
        }
    }
}

struct DocumentEditView: View {
    let documentURL: URL
    @State private var document: NoteDocument?
    @State private var viewModel: DocumentViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveError = false
    @State private var isLoading = true
    @FocusState private var titleFieldFocused: Bool
    @State private var showingScanner = false
    @State private var isProcessingScans = false
    @State private var scanColorMode: ScanColorMode = .color
    @State private var showTitleField = false
    @State private var navigateToPage: Int?
    @State private var currentViewedPage: Int = 0
    @State private var exportedPDFURL: URL?
    @State private var activeSheet: ActiveSheet?
    @State private var showingMarkupError = false
    @State private var markupErrorMessage = ""
    @State private var textEditorViewModel: TextPageEditorViewModel?
    @State private var showTextEditor = false
    @State private var isRenderingTextPage = false
    @State private var pdfFitMode: FitMode = .height
    @State private var textAppendErrorMessage: String?
    @State private var showingTextAppendError = false
    @State private var isSidebarVisible = false
    @State private var sidebarPosition: SidebarPosition = .right
    @State private var thumbnailSize: SidebarThumbnailSize = .medium
    @State private var sidebarDocument: PDFDocument?
    @State private var sidebarDocumentVersion = UUID()
    @State private var selectedSidebarPages: Set<Int> = []
    @State private var isSidebarSelectionMode = false
    @State private var showSidebarDeleteAlert = false
    @State private var pendingDeleteIndices: [Int] = []
    @State private var shouldRestoreSidebarAfterPageManagement = false
    @State private var awaitingDownload = false

    private let scanningService = ScanningService()
    private let exportService = ExportService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let viewModel = viewModel {
                documentContent(viewModel: viewModel)
            } else {
                Text("Failed to load document")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(viewModel?.errorMessage ?? "Failed to save document")
        }
        .task {
            await loadDocument()
            await loadSidebarPreferences()
        }
        .documentScanner(isPresented: $showingScanner) { scannedImages in
            handleScannedImages(scannedImages)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .share(let url):
                ShareSheet(items: [url])
                    .onDisappear {
                        // Clean up temporary file
                        try? FileManager.default.removeItem(at: url)
                        exportedPDFURL = nil
                        activeSheet = nil
                    }
            case .pageManagement:
                if let viewModel = viewModel {
                    PageManagementView(
                        pdfData: Binding(
                            get: { viewModel.pdfData },
                            set: {
                                viewModel.pdfData = $0
                                viewModel.hasChanges = true
                            }
                        ),
                        viewModel: viewModel,
                        isPresented: Binding(
                            get: { activeSheet == .pageManagement },
                            set: { newValue in
                                if !newValue {
                                    activeSheet = nil
                                }
                            }
                        ),
                        currentPageIndex: currentViewedPage,
                        displayPDFData: viewModel.displayPDFData,
                        provisionalPageRange: viewModel.provisionalPageRange,
                        onPageSelected: { pageIndex in
                            guard currentViewedPage != pageIndex else { return }
                            navigateToPage = pageIndex
                            activeSheet = nil
                        },
                        onProvisionalPageSelected: {
                            activeSheet = nil
                            showTextEditor = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showTextEditor) {
            textEditorSheet
        }
        .onChange(of: showTextEditor) { _, newValue in
            guard !newValue,
                  let preview = textEditorViewModel?.latestRenderedPageData else { return }
            Task {
                guard let viewModel = self.viewModel else { return }
                await viewModel.setProvisionalPreviewData(preview)
            }
        }
        .onChange(of: viewModel?.displayPDFData) { _, newValue in
            updateSidebarDocument(with: newValue ?? viewModel?.pdfData)
        }
        .onChange(of: viewModel?.pdfData) { _, newValue in
            if viewModel?.displayPDFData == nil {
                updateSidebarDocument(with: newValue)
            }
        }
#if os(iOS)
        .onChange(of: activeSheet) { _, newValue in
            if newValue == nil && shouldRestoreSidebarAfterPageManagement {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSidebarVisible = true
                }
                shouldRestoreSidebarAfterPageManagement = false
            }
        }
#endif
        .alert("Delete Pages?", isPresented: $showSidebarDeleteAlert) {
            Button("Cancel", role: .cancel) {
                pendingDeleteIndices.removeAll()
            }
            Button("Delete", role: .destructive) {
                deleteSelectedSidebarPages(indices: pendingDeleteIndices)
                pendingDeleteIndices.removeAll()
            }
        } message: {
            Text("Are you sure you want to delete \(pendingDeleteIndices.count) page\(pendingDeleteIndices.count == 1 ? "" : "s")? This action cannot be undone.")
        }
        .alert("Markup Error", isPresented: $showingMarkupError) {
            Button("OK") { }
        } message: {
            Text(markupErrorMessage)
        }
        .alert("Text Page Error", isPresented: $showingTextAppendError) {
            Button("OK") { }
        } message: {
            Text(textAppendErrorMessage ?? "Failed to append text page.")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.yianaDocumentsChanged)) { _ in
            guard awaitingDownload else { return }
            Task { await loadDocument() }
        }
    }

    @ViewBuilder
    private func documentContent(viewModel: DocumentViewModel) -> some View {
        HStack(spacing: 0) {
#if os(iOS)
            if shouldShowSidebar && sidebarPosition == .left {
                sidebar(for: viewModel)
            }
#endif

            ZStack {
                VStack(spacing: 0) {
                // Spacer for collapsible title area
                Color.clear.frame(height: showTitleField ? 60 : 44)

                // PDF content area with scan button
                if isProcessingScans {
                    VStack {
                        ProgressView("Processing scanned documents...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                        Text("Please wait...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                } else if let pdfData = viewModel.displayPDFData ?? viewModel.pdfData {
                    let isShowingProvisional = viewModel.provisionalPageRange?.contains(currentViewedPage) ?? false
                    PDFViewer(pdfData: pdfData,
                              navigateToPage: $navigateToPage,
                              currentPage: $currentViewedPage,
                              fitMode: $pdfFitMode,
                              onRequestPageManagement: {
                                  #if os(iOS)
                                  guard UIDevice.current.userInterfaceIdiom == .pad && isSidebarVisible else {
                                      shouldRestoreSidebarAfterPageManagement = false
                                      activeSheet = .pageManagement
                                      return
                                  }
                                  withAnimation(.easeInOut(duration: 0.2)) {
                                      isSidebarVisible = false
                                      exitSidebarSelection()
                                  }
                                  shouldRestoreSidebarAfterPageManagement = true
                                  #endif
                                  activeSheet = .pageManagement
                              },
                              onRequestMetadataView: {
                                  // TODO: Show metadata/address view when implemented
                                  print("DEBUG: Metadata view requested - coming soon!")
                              })
                        .onAppear { awaitingDownload = false }
                        .overlay(alignment: .topTrailing) {
                            if isShowingProvisional {
                                DraftBadge()
                            }
                        }
                        .overlay(alignment: .bottom) {
                            scanButtonBar
                        }
                        .overlay {
                            if isShowingProvisional {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.85), lineWidth: 3)
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } else {
                    let placeholderState: ContentPlaceholderView.State = shouldShowDownloadPlaceholder(for: viewModel) ? .downloading : .empty
                    ContentPlaceholderView(state: placeholderState)
                        .onAppear { awaitingDownload = (placeholderState == .downloading) }
                        .overlay(alignment: .bottom) {
                            scanButtonBar
                        }
                }
            }

            if isRenderingTextPage {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                ProgressView("Rendering text page…")
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
            }

            // Overlay title field at top
            VStack {
                if showTitleField {
                    HStack {
                        TextField("Document Title", text: Binding(
                            get: { viewModel.title },
                            set: { viewModel.title = $0 }
                        ), onCommit: {
                            showTitleField = false
                            Task {
                                _ = await viewModel.save()
                            }
                        })
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)

                        Button("Done") {
                            showTitleField = false
                            titleFieldFocused = false
                            Task {
                                _ = await viewModel.save()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .shadow(radius: 2)
                } else {
                    // Minimal title display with back button
                    HStack(spacing: 0) {
                        Button(action: {
                            handleDismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 16)  // More space between button and title

                        Text(viewModel.title.isEmpty ? "Untitled" : viewModel.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showTitleField = true
                                titleFieldFocused = true
                            }

                        Spacer()

                        // Markup button
                        if viewModel.pdfData != nil {
                            Button(action: {
                                presentMarkup()
                            }) {
                                Image(systemName: "pencil.tip.crop.circle")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .padding(.trailing, 4)
                        }

                        // Export button
                        if viewModel.pdfData != nil {
                            Button(action: {
                                exportPDF()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .padding(.trailing, 8)
                        }
#if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSidebarVisible.toggle()
                                    if !isSidebarVisible {
                                        exitSidebarSelection()
                                    }
                                }
                            }) {
                                Image(systemName: sidebarPosition == .left ? "sidebar.leading" : "sidebar.trailing")
                                    .font(.title3)
                                    .foregroundColor(isSidebarVisible ? .accentColor : .secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .padding(.trailing, 8)
                            .accessibilityLabel(isSidebarVisible ? "Hide thumbnails" : "Show thumbnails")
                        }
#endif
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 0)
                    .background(Color(.systemBackground).opacity(0.95))
                }
                Spacer()
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(TapGesture().onEnded {
                #if os(iOS)
                if isSidebarSelectionMode {
                    exitSidebarSelection()
                }
                #endif
            })

#if os(iOS)
            if shouldShowSidebar && sidebarPosition == .right {
                sidebar(for: viewModel)
            }
#endif
        }
        .animation(.easeInOut(duration: 0.2), value: isSidebarVisible)
        .animation(.easeInOut(duration: 0.2), value: sidebarPosition)
    }

    private var scanButtonBar: some View {
        HStack(spacing: 32) {
            // Color scan button
            Button(action: {
                if scanningService.isScanningAvailable() {
                    scanColorMode = .color
                    showingScanner = true
                }
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.3), .yellow.opacity(0.3), .green.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)

                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!scanningService.isScanningAvailable())
            .toolbarActionAccessibility(label: "Scan color pages")
            .accessibilityHint(scanningService.isScanningAvailable() ? "Double tap to start scanning pages in color" : "Scanner unavailable")

            // B&W document scan button
            Button(action: {
                if scanningService.isScanningAvailable() {
                    scanColorMode = .blackAndWhite
                    showingScanner = true
                }
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)

                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!scanningService.isScanningAvailable())
            .toolbarActionAccessibility(label: "Scan black and white pages")
            .accessibilityHint(scanningService.isScanningAvailable() ? "Double tap to start scanning pages in black and white" : "Scanner unavailable")

            if textEditorViewModel != nil {
                textPageButton
            }
        }
        .padding(.bottom, 20)
    }

    private var textPageButton: some View {
        let hasDraft = (textEditorViewModel?.state ?? .empty) != .empty

        return Button(action: {
            showTextEditor = true
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color("AccentColor").opacity(0.3))
                        .frame(width: 60, height: 60)

                    Image(systemName: hasDraft ? "doc.badge.plus" : "doc.text")
                        .font(.title2)
                        .foregroundColor(.white)

                    if hasDraft {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .offset(x: 22, y: -22)
                    }
                }
            }
        }
        .toolbarActionAccessibility(label: hasDraft ? "Continue draft text page" : "Add text page")
        .accessibilityHint("Double tap to \(hasDraft ? "resume editing the draft text page" : "add a new text page")")
    }

    private func handleDismiss() {
        if isRenderingTextPage { return }
        Task {
            if showTextEditor {
                await MainActor.run { showTextEditor = false }
            }

            let canDismiss = await finalizeTextPageIfNeeded()
            if canDismiss {
                if let viewModel = viewModel {
                    _ = await viewModel.save()
                }
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }

    private func finalizeTextPageIfNeeded() async -> Bool {
        guard let textEditorViewModel, let viewModel = viewModel else { return true }

        let trimmed = textEditorViewModel.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            await textEditorViewModel.discardDraft()
            viewModel.updatePendingTextPageFlag(false)
            return true
        }

        await MainActor.run { isRenderingTextPage = true }

        do {
            await textEditorViewModel.flushDraftNow()
            let markdown = textEditorViewModel.content
            let cachedRender = textEditorViewModel.latestRenderedPageData
            let cachedPlain = textEditorViewModel.latestRenderedPlainText ?? trimmed
            _ = try await viewModel.appendTextPage(
                markdown: markdown,
                appendPlainTextToMetadata: true,
                cachedRenderedPage: cachedRender,
                cachedPlainText: cachedPlain
            )
            await textEditorViewModel.discardDraft()
            self.textEditorViewModel?.refreshMetadata(viewModel.metadataSnapshot)
            await MainActor.run { isRenderingTextPage = false }
            return true
        } catch {
            await MainActor.run {
                isRenderingTextPage = false
                textAppendErrorMessage = error.localizedDescription
                showingTextAppendError = true
            }
            return false
        }
    }

    @ViewBuilder
    private var textEditorSheet: some View {
        if let textEditorViewModel {
            NavigationStack {
                TextPageEditorView(viewModel: textEditorViewModel)
                    .navigationTitle("Text Page")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            let canDiscard = (textEditorViewModel.state != .empty)
                            Button("Discard") {
                                Task {
                                    await textEditorViewModel.discardDraft()
                                    showTextEditor = false
                                }
                            }
                            .disabled(!canDiscard)
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showTextEditor = false
                            }
                        }
                    }
            }
        } else {
            VStack {
                ProgressView()
                Text("Preparing editor…")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
    }

    private func loadDocument() async {
        let loadedDocument = NoteDocument(fileURL: documentURL)

        await withCheckedContinuation { continuation in
            loadedDocument.open { success in
                Task { @MainActor in
                    if success {
                        self.document = loadedDocument
                        self.viewModel = DocumentViewModel(document: loadedDocument)

                        let metadata = loadedDocument.metadata
                        let textVM = TextPageEditorViewModel(documentURL: documentURL, metadata: metadata)
                        textVM.onDraftStateChange = { hasDraft in
                            Task { @MainActor in
                                self.viewModel?.updatePendingTextPageFlag(hasDraft)
                            }
                        }
                        textVM.onPreviewRenderUpdated = { data in
                            Task { @MainActor in
                                if let viewModel = self.viewModel {
                                    await viewModel.setProvisionalPreviewData(data)
                                }
                            }
                        }
                        if let previewData = textVM.latestRenderedPageData {
                            Task { @MainActor in
                                if let viewModel = self.viewModel {
                                    await viewModel.setProvisionalPreviewData(previewData)
                                }
                            }
                        }
                        self.textEditorViewModel = textVM
#if os(iOS)
                        self.exitSidebarSelection()
#endif

                        Task {
                            await textVM.loadDraftIfAvailable()
                            let manager = TextPageDraftManager.shared
                            let draftExists = await manager.hasDraft(for: documentURL, metadata: metadata)
                            if draftExists {
                                await MainActor.run {
                                    self.viewModel?.updatePendingTextPageFlag(true)
                                    self.showTextEditor = true
                                }
                            } else if metadata.hasPendingTextPage {
                                await MainActor.run {
                                    self.showTextEditor = true
                                }
                            }
                        }
                    }
                    self.isLoading = false
                    continuation.resume()
                }
            }
        }
    }

#if os(iOS)
    private var shouldShowSidebar: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && isSidebarVisible && sidebarDocument != nil
    }

    private func loadSidebarPreferences() async {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let position = await TextPageLayoutSettings.shared.preferredSidebarPosition()
        let size = await TextPageLayoutSettings.shared.preferredThumbnailSize()
        await MainActor.run {
            sidebarPosition = position
            thumbnailSize = size
        }
    }

    private func updateSidebarDocument(with data: Data?) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        sidebarDocument = nil
        let newDocument = data.flatMap { PDFDocument(data: $0) }
        if let newDocument {
            selectedSidebarPages = selectedSidebarPages.filter { $0 < newDocument.pageCount }
        } else {
            selectedSidebarPages.removeAll()
        }
        if let pdf = newDocument {
#if DEBUG
            print("DEBUG Sidebar: sidebarDocument updated with", pdf.pageCount, "pages")
            for i in 0..<pdf.pageCount {
                let text = pdf.page(at: i)?.string ?? "<no text>"
                print("DEBUG Sidebar: page", i, "preview text:", text.prefix(80))
            }
#endif
            sidebarDocument = pdf
            sidebarDocumentVersion = UUID()
        } else {
            sidebarDocument = nil
            sidebarDocumentVersion = UUID()
        }
    }

    @ViewBuilder
    private func sidebar(for viewModel: DocumentViewModel) -> some View {
        if let document = sidebarDocument {
            ThumbnailSidebarView(
                document: document,
                currentPage: currentViewedPage,
                provisionalPageRange: viewModel.provisionalPageRange,
                thumbnailSize: thumbnailSize,
                refreshID: sidebarDocumentVersion,
                isSelecting: isSidebarSelectionMode,
                selectedPages: selectedSidebarPages,
                    onTap: { handleSidebarTap($0) },
                    onDoubleTap: { handleSidebarDoubleTap($0) },
                    onClearSelection: exitSidebarSelection,
                    onToggleSelectionMode: {
                        if isSidebarSelectionMode {
                            exitSidebarSelection()
                        } else {
                            enterSidebarSelection()
                        }
                    },
                    onDeleteSelection: selectedSidebarPages.isEmpty ? nil : { promptDeleteSidebarPages() },
                    onDuplicateSelection: selectedSidebarPages.isEmpty ? nil : { duplicateSelectedSidebarPages() }
                )
                .transition(.move(edge: sidebarPosition == .left ? .leading : .trailing))
        } else {
            Color.clear.frame(width: thumbnailSize.sidebarWidth)
        }
    }

    private func handleSidebarTap(_ index: Int) {
        if isSidebarSelectionMode {
            toggleSidebarSelection(index)
        } else {
            navigateToPage = index
        }
    }

    private func handleSidebarDoubleTap(_ index: Int) {
        if isSidebarSelectionMode {
            toggleSidebarSelection(index)
        } else {
            // Open page organizer instead of entering selection mode
            activeSheet = .pageManagement
        }
    }

    private func enterSidebarSelection(with index: Int? = nil) {
        isSidebarSelectionMode = true
        if let index {
            selectedSidebarPages = [index]
        } else {
            selectedSidebarPages.removeAll()
        }
    }

    private func toggleSidebarSelection(_ index: Int) {
        if selectedSidebarPages.contains(index) {
            selectedSidebarPages.remove(index)
        } else {
            selectedSidebarPages.insert(index)
        }
        if selectedSidebarPages.isEmpty {
            isSidebarSelectionMode = false
        }
    }

    private func exitSidebarSelection() {
        isSidebarSelectionMode = false
        selectedSidebarPages.removeAll()
    }

    private func promptDeleteSidebarPages(indices: [Int]? = nil) {
        pendingDeleteIndices = indices ?? Array(selectedSidebarPages)
        if !pendingDeleteIndices.isEmpty {
            showSidebarDeleteAlert = true
        }
    }

    private func deleteSelectedSidebarPages(indices: [Int]? = nil) {
        guard let viewModel else { return }
        let deletionIndices = indices ?? Array(selectedSidebarPages)
        Task {
            await viewModel.removePages(at: deletionIndices)
            await MainActor.run {
                exitSidebarSelection()
                let maxIndex = self.currentDocumentPageCount(from: viewModel)
                let shift = deletionIndices.filter { $0 < currentViewedPage }.count
                if shift > 0 {
                    currentViewedPage = max(0, currentViewedPage - shift)
                }
                if currentViewedPage >= maxIndex {
                    currentViewedPage = max(0, maxIndex - 1)
                }
                navigateToPage = currentViewedPage
            }
        }
    }

    private func duplicateSelectedSidebarPages() {
        performDuplicate(for: Array(selectedSidebarPages))
    }

    private func performDuplicate(for indices: [Int]) {
        guard let viewModel else { return }
        guard !indices.isEmpty else { return }
        Task {
            #if DEBUG
            viewModel.logDocumentSnapshot(context: "pre-duplicate")
            #endif
            await viewModel.duplicatePages(at: indices)
            await MainActor.run {
                #if DEBUG
                viewModel.logDocumentSnapshot(context: "post-duplicate")
                #endif
                exitSidebarSelection()
                updateSidebarDocument(with: viewModel.displayPDFData ?? viewModel.pdfData)
                if let target = indices.sorted().first.map({ min($0 + indices.count, currentDocumentPageCount(from: viewModel) - 1) }) {
                    currentViewedPage = target
                    navigateToPage = target
                }
            }
        }
    }

    private func currentDocumentPageCount(from viewModel: DocumentViewModel) -> Int {
        if let data = viewModel.displayPDFData ?? viewModel.pdfData,
           let doc = PDFDocument(data: data) {
            return doc.pageCount
        }
        return 0
    }

    private func shouldShowDownloadPlaceholder(for viewModel: DocumentViewModel) -> Bool {
        if viewModel.displayPDFData ?? viewModel.pdfData != nil {
            return false
        }

        do {
            let values = try documentURL.resourceValues(forKeys: [
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey
            ])

            if values.isUbiquitousItem == true {
                if let status = values.ubiquitousItemDownloadingStatus {
                    switch status {
                    case URLUbiquitousItemDownloadingStatus.notDownloaded:
                        return true
                    default:
                        break
                    }
                }
                if values.ubiquitousItemIsDownloading == true {
                    return true
                }
            }
        } catch {
            #if DEBUG
            print("DEBUG DocumentEditView: Failed to read download status - \(error)")
            #endif
        }

        return viewModel.metadataSnapshot.pageCount > 0
    }
#else
    private func loadSidebarPreferences() async { }
    private func updateSidebarDocument(with data: Data?) { }
    private func handleSidebarTap(_ index: Int) { }
    private func handleSidebarDoubleTap(_ index: Int) { }
    private func exitSidebarSelection() { }
    private func currentDocumentPageCount(from viewModel: DocumentViewModel) -> Int { 0 }
#endif
#if !os(iOS)
    private func deleteSelectedSidebarPages() { }
    private func duplicateSelectedSidebarPages() { }
    private func promptDeleteSidebarPages(indices: [Int]? = nil) { }
    private func performDuplicate(for indices: [Int]) { }
#endif

    private func handleScannedImages(_ images: [UIImage]) {
        Task {
            isProcessingScans = true

            // Convert images to PDF with selected color mode
            if let newPDFData = await scanningService.convertImagesToPDF(images, colorMode: scanColorMode),
               let viewModel = viewModel {

                // If document already has PDF data, append pages
                if let existingPDFData = viewModel.pdfData,
                   let existingPDF = PDFDocument(data: existingPDFData),
                   let newPDF = PDFDocument(data: newPDFData) {

                    // Append all pages from new PDF to existing PDF
                    for pageIndex in 0..<newPDF.pageCount {
                        if let page = newPDF.page(at: pageIndex) {
                            existingPDF.insert(page, at: existingPDF.pageCount)
                        }
                    }

                    // Update with combined PDF
                    viewModel.pdfData = existingPDF.dataRepresentation()
                } else {
                    // No existing PDF, just use the new one
                    viewModel.pdfData = newPDFData
                }

                viewModel.hasChanges = true

                // Save the document
                _ = await viewModel.save()
            }

            isProcessingScans = false
        }
    }

    private func presentMarkup() {
        guard let viewModel = viewModel, let pdfData = viewModel.pdfData else {
            print("DEBUG Markup: No PDF data to mark up")
            return
        }

        print("DEBUG Markup: Using PencilKit implementation for page \(currentViewedPage + 1)")
        let markupVC = PencilKitMarkupViewController(
            pdfData: pdfData,
            pageIndex: currentViewedPage
        ) { result in
            Task { @MainActor in
                await handleMarkupResult(result)
            }
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(markupVC, animated: true)
        }
    }

    private func handleMarkupResult(_ result: Result<Data, Error>) async {
        switch result {
        case .success(let markedPDFData):
            print("DEBUG Markup: Received marked PDF with \(markedPDFData.count) bytes")

            // Update the document with marked-up PDF
            if let viewModel = viewModel {
                // TODO: Create backup before first markup
                // TODO: Implement atomic save

                // Update PDF data
                viewModel.pdfData = markedPDFData
                viewModel.hasChanges = true

                // Re-extract text for search
                if let pdfDocument = PDFDocument(data: markedPDFData) {
                    let extractedText = pdfDocument.string ?? ""
                    print("DEBUG Markup: Extracted \(extractedText.count) characters of text")
                    // TODO: Update metadata with extracted text
                }

                // Save the document
                let saved = await viewModel.save()
                if saved {
                    print("DEBUG Markup: Document saved successfully")
                } else {
                    markupErrorMessage = "Failed to save marked-up document"
                    showingMarkupError = true
                }
            }
        case .failure(let error):
            print("DEBUG Markup: Failed - \(error)")
            markupErrorMessage = error.localizedDescription
            showingMarkupError = true
        }
    }

    private func exportPDF() {
        guard let viewModel = viewModel, let pdfData = viewModel.pdfData else {
            print("DEBUG Export: No PDF data to export")
            return
        }

        print("DEBUG Export: PDF data size: \(pdfData.count) bytes")

        // Create a temporary file with the PDF data
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(viewModel.title.isEmpty ? "Document" : viewModel.title).pdf"
        let tempURL = tempDir.appendingPathComponent(fileName)

        print("DEBUG Export: Creating temp file at: \(tempURL.path)")

        do {
            try pdfData.write(to: tempURL)
            print("DEBUG Export: Successfully wrote PDF to temp file")

            // Verify file exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                print("DEBUG Export: File exists, size: \(try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] ?? 0)")
                exportedPDFURL = tempURL
                activeSheet = .share(tempURL)
            } else {
                print("DEBUG Export: ERROR - File doesn't exist after writing!")
            }
        } catch {
            print("DEBUG Export: Failed to write PDF - \(error)")
        }
    }
}

private struct DraftBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "pencil.circle.fill")
            Text("Draft")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.9))
        .foregroundColor(.black)
        .clipShape(Capsule())
        .padding(12)
        .accessibilityLabel("Draft preview page")
    }
}

// ShareSheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("DEBUG ShareSheet: Creating with \(items.count) items")
        for (index, item) in items.enumerated() {
            print("DEBUG ShareSheet: Item \(index): \(type(of: item)) - \(item)")
            if let url = item as? URL {
                print("DEBUG ShareSheet: URL path: \(url.path)")
                print("DEBUG ShareSheet: File exists: \(FileManager.default.fileExists(atPath: url.path))")
            }
        }

        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [.addToReadingList, .assignToContact]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

// Placeholder view for PDF content
struct PDFPlaceholderView: View {
    let pdfData: Data

    var body: some View {
        VStack {
            Image(systemName: "doc.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("PDF Preview")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("\(pdfData.count) bytes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

// Placeholder for empty documents
struct ContentPlaceholderView: View {
    enum State {
        case empty
        case downloading
    }

    let state: State

    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .empty:
                Image(systemName: "doc.text")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
                Text("No Content")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Add content by scanning documents")
                    .foregroundColor(.secondary)
            case .downloading:
                ProgressView()
                    .scaleEffect(1.4)
                Text("Document not downloaded yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("This document is still downloading from iCloud. It will open automatically once the download finishes.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

#Preview {
    NavigationStack {
        DocumentEditView(documentURL: URL(fileURLWithPath: "/tmp/test.yianazip"))
    }
}
#endif
