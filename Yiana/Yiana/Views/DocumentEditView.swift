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
    case metadata

    var id: String {
        switch self {
        case .share: return "share"
        case .pageManagement: return "pageManagement"
        case .metadata: return "metadata"
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
    @State private var isSidebarVisible = UIDevice.current.userInterfaceIdiom == .pad
    @State private var sidebarPosition: SidebarPosition = .right
    @State private var thumbnailSize: SidebarThumbnailSize = .medium
    @State private var sidebarDocument: PDFDocument?
    @State private var sidebarDocumentVersion = UUID()
    @State private var isSidebarEditing = false
    @State private var sidebarSelectedPages: Set<Int> = []
    @State private var sidebarCutPageIndices: Set<Int>?
    @State private var sidebarClipboardHasPayload = PageClipboard.shared.hasPayload
    @State private var showProvisionalReorderAlert = false
    @State private var sidebarAlertMessage: String?
    @EnvironmentObject var workListViewModel: WorkListViewModel
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
            case .metadata:
                if let document = document {
                    DocumentInfoSheet(document: document)
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
            refreshSidebar(with: newValue ?? viewModel?.pdfData)
        }
        .onChange(of: viewModel?.pdfData) { _, _ in
            refreshSidebar(with: viewModel?.displayPDFData ?? viewModel?.pdfData)
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
        .alert("Finish Editing", isPresented: $showProvisionalReorderAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Save or discard the draft text page before reordering.")
        }
        .alert("Page Edit Error", isPresented: Binding(
            get: { sidebarAlertMessage != nil },
            set: { if !$0 { sidebarAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(sidebarAlertMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.yianaDocumentsChanged)) { _ in
            guard awaitingDownload else { return }
            Task { await loadDocument() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.yianaDocumentContentChanged)) { notification in
            guard let changedURL = notification.object as? URL,
                  changedURL.path == documentURL.path else { return }
            Task { await loadDocument() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.yianaAppendPagesToDocument)) { notification in
            guard let userInfo = notification.userInfo,
                  let targetURL = userInfo["url"] as? URL,
                  targetURL.path == documentURL.path,
                  let pdfData = userInfo["pdfData"] as? Data,
                  let vm = viewModel else { return }
            let payload = PageClipboardPayload(
                sourceDocumentID: nil,
                operation: .copy,
                pageCount: PDFDocument(data: pdfData)?.pageCount ?? 0,
                pdfData: pdfData
            )
            Task {
                _ = try? await vm.insertPages(from: payload, at: nil)
            }
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
                                  if UIDevice.current.userInterfaceIdiom == .pad {
                                      if !isSidebarVisible {
                                          withAnimation(.easeInOut(duration: 0.2)) {
                                              isSidebarVisible = true
                                          }
                                      }
                                      enterSidebarEditMode(selecting: currentViewedPage)
                                      return
                                  }
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
                                _ = await viewModel.renameFileIfNeeded()
                            }
                        })
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)

                        Button("Done") {
                            showTitleField = false
                            titleFieldFocused = false
                            Task {
                                _ = await viewModel.save()
                                _ = await viewModel.renameFileIfNeeded()
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

                        // Work list star button
                        Button(action: { toggleWorkList() }) {
                            Image(systemName: isInWorkList ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(isInWorkList ? .yellow : .accentColor)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, 4)

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
                            .padding(.trailing, 4)
                        }

                        // Info button for metadata
                        if viewModel.pdfData != nil {
                            Button(action: {
                                activeSheet = .metadata
                            }) {
                                Image(systemName: "info.circle")
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
                                if isSidebarVisible && isSidebarEditing {
                                    exitSidebarEditMode()
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSidebarVisible.toggle()
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

    // MARK: - Work List

    private var documentFilenameStem: String {
        documentURL.deletingPathExtension().lastPathComponent
    }

    private var isInWorkList: Bool {
        workListViewModel.containsDocument(filename: documentFilenameStem)
    }

    private func toggleWorkList() {
        let filename = documentFilenameStem
        Task { await workListViewModel.toggleDocument(filename: filename) }
    }

    private func loadDocument() async {
        nonisolated(unsafe) let loadedDocument = NoteDocument(fileURL: documentURL)

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

                        // Index immediately so placeholder is replaced in the list
                        if let vm = self.viewModel {
                            Task { await vm.indexDocument() }
                        }

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

    private func refreshSidebar(with data: Data?) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        sidebarDocument = nil
        let newDocument = data.flatMap { PDFDocument(data: $0) }
        if let pdf = newDocument {
            sidebarDocument = pdf
            sidebarDocumentVersion = UUID()
            // Clip selected pages to new page count
            let maxIndex = pdf.pageCount - 1
            sidebarSelectedPages = sidebarSelectedPages.filter { $0 <= maxIndex }
        } else {
            sidebarDocument = nil
            sidebarDocumentVersion = UUID()
        }
        sidebarClipboardHasPayload = PageClipboard.shared.hasPayload
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
                onTap: { index in
                    if isSidebarEditing {
                        toggleSidebarSelection(index)
                    } else {
                        navigateToPage = index
                    }
                },
                onDoubleTap: { index in
                    if !isSidebarEditing {
                        enterSidebarEditMode(selecting: index)
                    }
                },
                isEditing: isSidebarEditing,
                selectedPages: sidebarSelectedPages,
                cutPageIndices: sidebarCutPageIndices,
                clipboardHasPayload: sidebarClipboardHasPayload,
                hasCutToRestore: PageClipboard.shared.activeCutPayload(for: viewModel.documentID) != nil,
                onEditAction: { action in
                    handleSidebarEditAction(action, viewModel: viewModel)
                }
            )
            .transition(.move(edge: sidebarPosition == .left ? .leading : .trailing))
        } else {
            Color.clear.frame(width: thumbnailSize.sidebarWidth)
        }
    }

    // MARK: - Sidebar Edit Mode

    private func enterSidebarEditMode(selecting index: Int) {
        let isProvisional = viewModel?.provisionalPageRange?.contains(index) ?? false
        isSidebarEditing = true
        sidebarSelectedPages = isProvisional ? [] : [index]
        sidebarClipboardHasPayload = PageClipboard.shared.hasPayload
    }

    private func exitSidebarEditMode() {
        isSidebarEditing = false
        sidebarSelectedPages.removeAll()
        sidebarCutPageIndices = nil
    }

    private func toggleSidebarSelection(_ index: Int) {
        let isProvisional = viewModel?.provisionalPageRange?.contains(index) ?? false
        guard !isProvisional else { return }
        if sidebarSelectedPages.contains(index) {
            sidebarSelectedPages.remove(index)
        } else {
            sidebarSelectedPages.insert(index)
        }
    }

    private func handleSidebarEditAction(_ action: SidebarEditAction, viewModel: DocumentViewModel) {
        switch action {
        case .toggleSelection(let index):
            toggleSidebarSelection(index)

        case .done:
            exitSidebarEditMode()

        case .delete:
            let indices = filteredSidebarSelection(viewModel: viewModel)
            guard !indices.isEmpty else { return }
            Task {
                await viewModel.removePages(at: Array(indices))
                sidebarSelectedPages.removeAll()
            }

        case .duplicate:
            let indices = filteredSidebarSelection(viewModel: viewModel)
            guard !indices.isEmpty else { return }
            Task {
                await viewModel.duplicatePages(at: Array(indices))
                sidebarSelectedPages.removeAll()
            }

        case .cut:
            let indices = filteredSidebarSelection(viewModel: viewModel)
            guard !indices.isEmpty else { return }
            Task {
                do {
                    let payload = try await viewModel.cutPages(atZeroBasedIndices: indices)
                    PageClipboard.shared.setPayload(payload)
                    sidebarClipboardHasPayload = true
                    sidebarCutPageIndices = indices
                    sidebarSelectedPages.removeAll()
                } catch {
                    sidebarAlertMessage = error.localizedDescription
                }
            }

        case .copy:
            let indices = filteredSidebarSelection(viewModel: viewModel)
            guard !indices.isEmpty else { return }
            Task {
                do {
                    let payload = try await viewModel.copyPages(atZeroBasedIndices: indices)
                    PageClipboard.shared.setPayload(payload)
                    sidebarClipboardHasPayload = true
                } catch {
                    sidebarAlertMessage = error.localizedDescription
                }
            }

        case .paste:
            guard let payload = PageClipboard.shared.currentPayload() else { return }
            let insertAt = (sidebarSelectedPages.max().map { $0 + 1 }) ?? (sidebarDocument?.pageCount ?? 0)
            Task {
                do {
                    let inserted = try await viewModel.insertPages(from: payload, at: insertAt)
                    if payload.operation == .cut {
                        PageClipboard.shared.clear()
                        sidebarClipboardHasPayload = false
                    }
                    sidebarCutPageIndices = nil
                    sidebarSelectedPages = Set(insertAt..<(insertAt + inserted))
                } catch {
                    sidebarAlertMessage = error.localizedDescription
                }
            }

        case .restoreCut:
            guard let cutPayload = PageClipboard.shared.activeCutPayload(for: viewModel.documentID),
                  let sourceData = cutPayload.sourceDataBeforeCut else { return }
            viewModel.pdfData = sourceData
            sidebarCutPageIndices = nil
            PageClipboard.shared.clear()
            sidebarClipboardHasPayload = false

        case .move(let source, let destination):
            if let range = viewModel.provisionalPageRange {
                let touchesProvisional = source.contains(where: { range.contains($0) }) || range.contains(destination) || (destination > 0 && range.contains(destination - 1))
                if touchesProvisional {
                    showProvisionalReorderAlert = true
                    return
                }
            }
            Task {
                await viewModel.movePages(from: source, to: destination)
            }
        }
    }

    private func filteredSidebarSelection(viewModel: DocumentViewModel) -> Set<Int> {
        sidebarSelectedPages.filter { index in
            if let range = viewModel.provisionalPageRange {
                return !range.contains(index)
            }
            return true
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
    private func refreshSidebar(with data: Data?) { }
    private func currentDocumentPageCount(from viewModel: DocumentViewModel) -> Int { 0 }
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

                // Run on-device OCR and save again with text
                if let pdfData = viewModel.pdfData {
                    let ocrResult = await OnDeviceOCRService.shared.recognizeText(in: pdfData)
                    if !ocrResult.fullText.isEmpty {
                        viewModel.applyOCRResult(ocrResult)
                        if let docTitle = document?.metadata.title, !docTitle.isEmpty {
                            Task.detached {
                                await DocumentExtractionService.shared.extractAndSave(
                                    documentId: docTitle, ocrResult: ocrResult)
                            }
                        }
                        _ = await viewModel.save()
                        await viewModel.indexDocument()
                    }
                }
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
