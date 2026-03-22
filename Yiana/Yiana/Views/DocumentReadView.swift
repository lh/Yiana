import SwiftUI
import PDFKit
import YianaDocumentArchive

#if os(macOS)
struct DocumentReadView: View {
    let documentURL: URL
    let searchResult: SearchResult?
    @State private var pdfData: Data?
    @State private var documentTitle: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingPageManagement = false
    @State private var document: NoteDocument?
    @State private var viewModel: DocumentViewModel?
    @State private var initialPageToShow: Int?
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    @EnvironmentObject var workListViewModel: WorkListViewModel

    // Unified panel state
    @State private var isPanelVisible = true
    @State private var panelWasVisibleBeforeOrganiser = true
    @State private var sidebarRefreshID = UUID()
    @State private var selectedPanelTab: PanelTab = .pages
    @State private var panelPosition: SidebarPosition = .left
    @State private var panelWidth: CGFloat = 200
    @State private var dragStartWidth: CGFloat?

    // Hoisted PDF state (shared with MacPDFViewer and UnifiedSidePanel)
    @State private var currentPage: Int = 0
    @State private var navigateToPage: Int?
    @State private var pdfDocument: PDFDocument?

    @State private var isEditingTitle = false
    @FocusState private var titleFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(documentURL: URL, searchResult: SearchResult? = nil) {
        self.documentURL = documentURL
        self.searchResult = searchResult
    }

    /// Panel width depends on selected tab — narrow for pages, wider for info tabs
    private var activePanelWidth: CGFloat {
        selectedPanelTab == .pages ? panelWidth : 340
    }

    var body: some View {
        mainLayout
        .task {
            let position = await TextPageLayoutSettings.shared.preferredSidebarPosition()
            panelPosition = position
            await loadDocument()
        }
        .sheet(isPresented: $showingPageManagement) {
            pageManagementSheet
        }
        .alert("Export Error", isPresented: $showingExportError) {
            Button("OK") { }
        } message: {
            Text(exportErrorMessage)
        }
        .onChange(of: viewModel?.pdfData) { _, newValue in
            if let newValue = newValue {
                pdfData = newValue
            }
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

    // MARK: - Main Layout

    private var mainLayout: some View {
        HStack(spacing: 0) {
            if panelPosition == .left {
                panelToggleColumn
                if isPanelVisible {
                    panelContent
                    resizeHandle
                }
            }

            // Main content — must claim remaining space
            VStack(spacing: 0) {
                ReadOnlyBanner(isReadOnly: isReadOnly)
                DocumentReadContent(
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    pdfData: pdfData,
                    viewModel: viewModel,
                    currentPage: $currentPage,
                    navigateToPage: $navigateToPage,
                    pdfDocument: $pdfDocument,
                    sidebarRefreshID: sidebarRefreshID,
                    onRequestPageManagement: handleManagePages
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if panelPosition == .right {
                if isPanelVisible {
                    resizeHandle
                    panelContent
                }
                panelToggleColumn
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isPanelVisible)
        .animation(.easeInOut(duration: 0.15), value: selectedPanelTab)
        .navigationTitle(isEditingTitle ? "" : documentTitle)
        .navigationBarBackButtonHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .printDocument)) { _ in
            printDocument()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .help("Back to documents")
            }

            ToolbarItem(placement: .principal) {
                if isEditingTitle {
                    TextField("Document Title", text: $documentTitle, onCommit: {
                        commitTitleEdit()
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .focused($titleFocused)
                    .onExitCommand {
                        cancelTitleEdit()
                    }
                } else {
                    Text(documentTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .onTapGesture {
                            isEditingTitle = true
                            titleFocused = true
                        }
                        .help("Click to rename")
                }
            }

            ToolbarItem(placement: .automatic) {
                if let viewModel = viewModel {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                                .help("Saving document...")
                        } else if viewModel.hasChanges {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 8))
                                .help("Unsaved changes")
                        }
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    Button(action: toggleWorkList) {
                        Label(isInWorkList ? "Remove from Work List" : "Add to Work List",
                              systemImage: isInWorkList ? "star.fill" : "star")
                    }
                    .help(isInWorkList ? "Remove from work list" : "Add to work list")

                    if hasPDFContent {
                        Button(action: handleManagePages) {
                            Label("Manage Pages", systemImage: "rectangle.stack")
                        }
                        .help("Manage pages")
                    }

                    Button(action: printDocument) {
                        Label("Print", systemImage: "printer")
                    }
                    .help("Print document")

                    Button(action: exportPDF) {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                    .help("Export as PDF")
                }
            }
        }
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - Panel Components

    private var panelToggleColumn: some View {
        VStack {
            Button {
                isPanelVisible.toggle()
            } label: {
                Image(systemName: panelPosition == .left ? "sidebar.left" : "sidebar.right")
                    .foregroundColor(isPanelVisible ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isPanelVisible ? "Hide panel" : "Show panel")
            .padding(.top, 6)
            .padding(.horizontal, 6)
            Spacer()
        }
        .frame(width: 32)
    }

    private var panelContent: some View {
        UnifiedSidePanel(
            document: document,
            pdfDocument: pdfDocument,
            selectedTab: $selectedPanelTab,
            currentPage: $currentPage,
            navigateToPage: $navigateToPage,
            refreshTrigger: sidebarRefreshID,
            onRequestPageManagement: handleManagePages
        )
        .frame(width: activePanelWidth - 32)
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color(NSColor.separatorColor))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                if selectedPanelTab == .pages {
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        guard selectedPanelTab == .pages else { return }
                        if dragStartWidth == nil {
                            dragStartWidth = panelWidth
                        }
                        let delta = panelPosition == .left ? value.translation.width : -value.translation.width
                        panelWidth = max(120, min(400, (dragStartWidth ?? 200) + delta))
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
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
        isLoading = true
        errorMessage = nil

        do {
            let noteDocument = NoteDocument(fileURL: documentURL)
            try noteDocument.read(from: documentURL)

            self.document = noteDocument
            self.pdfData = noteDocument.pdfData
            self.documentTitle = noteDocument.metadata.title

            let vm = DocumentViewModel(document: noteDocument)
            await MainActor.run {
                self.viewModel = vm
            }
            await vm.indexDocument()

        } catch {
            do {
                let data = try Data(contentsOf: documentURL)

                if isPDFData(data) {
                    pdfData = data
                    documentTitle = documentURL.deletingPathExtension().lastPathComponent
                } else if data.isEmpty {
                    pdfData = nil
                    documentTitle = documentURL.deletingPathExtension().lastPathComponent
                } else {
                    if let documentData = try? extractDocumentData(from: data) {
                        pdfData = documentData.pdfData
                        documentTitle = documentData.title

                        let noteDoc = NoteDocument(fileURL: documentURL)
                        self.document = noteDoc

                        let vm = DocumentViewModel(document: noteDoc)
                        await MainActor.run {
                            self.viewModel = vm
                        }
                        await vm.indexDocument()
                    } else {
                        throw YianaError.invalidFormat
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func isPDFData(_ data: Data) -> Bool {
        let pdfHeader = "%PDF"
        if let string = String(data: data.prefix(4), encoding: .ascii) {
            return string == pdfHeader
        }
        return false
    }

    private func exportPDF() {
        let exportService = ExportService()
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = exportService.suggestedFileName(for: documentURL)
        savePanel.title = "Export PDF"
        savePanel.message = "Choose where to save the exported PDF"

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    try exportService.exportToPDF(from: documentURL, to: destinationURL)
                    let parentPath = destinationURL.deletingLastPathComponent().path
                    NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: parentPath)
                } catch {
                    exportErrorMessage = error.localizedDescription
                    showingExportError = true
                }
            }
        }
    }

    private func printDocument() {
        guard let data = pdfData,
              let pdfDoc = PDFDocument(data: data),
              let printOp = pdfDoc.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true),
              let window = NSApp.keyWindow else { return }

        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    private func extractDocumentData(from data: Data) throws -> (title: String, pdfData: Data?) {
        let payload = try DocumentArchive.read(from: data)
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(DocumentMetadata.self, from: payload.metadata)
        return (title: metadata.title, pdfData: payload.pdfData)
    }

    // MARK: - Computed Properties

    private var isReadOnly: Bool {
        viewModel?.isReadOnly ?? false
    }

    private var hasPDFContent: Bool {
        guard let pdfData = pdfData else { return false }
        return pdfData.count > 0
    }

    // MARK: - Helper Methods

    private func handleManagePages() {
        panelWasVisibleBeforeOrganiser = isPanelVisible
        isPanelVisible = false
        showingPageManagement = true
    }

    private func commitTitleEdit() {
        isEditingTitle = false
        titleFocused = false
        guard let viewModel = viewModel else { return }
        viewModel.title = documentTitle
        Task {
            _ = await viewModel.save()
            if let newURL = await viewModel.renameFileIfNeeded() {
                documentTitle = newURL.deletingPathExtension().lastPathComponent
            }
            documentTitle = viewModel.title
        }
    }

    private func cancelTitleEdit() {
        isEditingTitle = false
        titleFocused = false
        documentTitle = viewModel?.title ?? documentTitle
    }

    @ViewBuilder
    private var pageManagementSheet: some View {
        if let viewModel = viewModel {
            PageManagementView(
                pdfData: Binding(
                    get: { viewModel.pdfData ?? Data() },
                    set: { viewModel.pdfData = $0 }
                ),
                viewModel: viewModel,
                isPresented: $showingPageManagement,
                currentPageIndex: 0,
                displayPDFData: viewModel.displayPDFData,
                provisionalPageRange: viewModel.provisionalPageRange,
                onDismiss: {
                    isPanelVisible = panelWasVisibleBeforeOrganiser
                    sidebarRefreshID = UUID()
                }
            )
        } else {
            PageManagementView(
                pdfData: Binding(
                    get: { pdfData ?? Data() },
                    set: { pdfData = $0 }
                ),
                viewModel: DocumentViewModel(pdfData: pdfData),
                isPresented: $showingPageManagement,
                currentPageIndex: 0,
                displayPDFData: pdfData,
                provisionalPageRange: nil,
                onDismiss: {
                    isPanelVisible = panelWasVisibleBeforeOrganiser
                    sidebarRefreshID = UUID()
                }
            )
        }
    }
}

enum YianaError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "This document format is not supported"
        }
    }
}
#endif
