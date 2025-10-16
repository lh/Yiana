//
//  DocumentReadView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

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
    @State private var showingInfoPanel = false
    @State private var document: NoteDocument?
    @State private var viewModel: DocumentViewModel?
    @State private var initialPageToShow: Int?
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""

    // New state for sidebar management
    @State private var isSidebarVisible = true
    @State private var sidebarWasVisibleBeforeOrganiser = true
    @State private var sidebarRefreshID = UUID()

    init(documentURL: URL, searchResult: SearchResult? = nil) {
        self.documentURL = documentURL
        self.searchResult = searchResult
    }

    var body: some View {
        HSplitView {
            // Main document view
            VStack(spacing: 0) {
                ReadOnlyBanner(isReadOnly: isReadOnly)
                DocumentReadToolbar(
                    title: documentTitle,
                    isReadOnly: isReadOnly,
                    hasPDFContent: hasPDFContent,
                    isInfoVisible: showingInfoPanel,
                    onManagePages: handleManagePages,
                    onExport: exportPDF,
                    onToggleInfo: handleToggleInfo
                )
                Divider()
                DocumentReadContent(
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    pdfData: pdfData,
                    viewModel: viewModel,
                    isSidebarVisible: $isSidebarVisible,
                    sidebarRefreshID: sidebarRefreshID,
                    onRequestPageManagement: handleManagePages
                )
            }

            // Info panel (when visible)
            if showingInfoPanel, let document = document {
                DocumentInfoPanel(document: document)
                    .frame(minWidth: 300, maxWidth: 400)
            }
        }
        .navigationTitle(documentURL.deletingPathExtension().lastPathComponent)
        .toolbar {
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
        }
        .task {
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
            // Sync viewModel changes back to local state for legacy support
            if let newValue = newValue {
                pdfData = newValue
            }
        }
    }

    private func loadDocument() async {
        isLoading = true
        errorMessage = nil

        do {
            // Create a NoteDocument instance
            let noteDocument = NoteDocument(fileURL: documentURL)

            // Load the document content
            try noteDocument.read(from: documentURL)

            // Store the document and its data
            self.document = noteDocument
            self.pdfData = noteDocument.pdfData
            self.documentTitle = noteDocument.metadata.title

            // Create view model for document operations
            await MainActor.run {
                self.viewModel = DocumentViewModel(document: noteDocument)
            }

        } catch {
            // If loading as NoteDocument fails, try legacy approach
            do {
                let data = try Data(contentsOf: documentURL)

                if isPDFData(data) {
                    // It's a raw PDF
                    pdfData = data
                    documentTitle = documentURL.deletingPathExtension().lastPathComponent
                } else if data.isEmpty {
                    // Empty file
                    pdfData = nil
                    documentTitle = documentURL.deletingPathExtension().lastPathComponent
                } else {
                    // Try to parse as our document format
                    if let documentData = try? extractDocumentData(from: data) {
                        pdfData = documentData.pdfData
                        documentTitle = documentData.title

                        // Create document with extracted metadata
                        let noteDoc = NoteDocument(fileURL: documentURL)
                        // Load will have been called during extraction
                        self.document = noteDoc

                        // Create view model
                        await MainActor.run {
                            self.viewModel = DocumentViewModel(document: noteDoc)
                        }
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
        // Check for PDF magic number
        let pdfHeader = "%PDF"
        if let string = String(data: data.prefix(4), encoding: .ascii) {
            return string == pdfHeader
        }
        return false
    }

    private func exportPDF() {
        let exportService = ExportService()

        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = exportService.suggestedFileName(for: documentURL)
        savePanel.title = "Export PDF"
        savePanel.message = "Choose where to save the exported PDF"

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    try exportService.exportToPDF(from: documentURL, to: destinationURL)
                    // Optionally show success feedback
                    let parentPath = destinationURL.deletingLastPathComponent().path
                    NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: parentPath)
                } catch {
                    // Show error
                    exportErrorMessage = error.localizedDescription
                    showingExportError = true
                }
            }
        }
    }

    private func extractDocumentData(from data: Data) throws -> (title: String, pdfData: Data?) {
        let payload = try DocumentArchive.read(from: data)

        let decoder = JSONDecoder()
        let metadata = try decoder.decode(DocumentMetadata.self, from: payload.metadata)

        return (
            title: metadata.title,
            pdfData: payload.pdfData
        )
    }

    // MARK: - Computed Properties

    /// Derived state: whether the document is read-only
    private var isReadOnly: Bool {
        viewModel?.isReadOnly ?? false
    }

    /// Derived state: whether PDF has content
    private var hasPDFContent: Bool {
        guard let pdfData = pdfData else { return false }
        return pdfData.count > 0
    }

    // MARK: - Helper Methods

    /// Handles the page management action
    private func handleManagePages() {
        sidebarWasVisibleBeforeOrganiser = isSidebarVisible
        isSidebarVisible = false
        showingPageManagement = true
    }

    /// Handles toggling the info panel
    private func handleToggleInfo() {
        showingInfoPanel.toggle()
        let message = showingInfoPanel ? "Showing document information" : "Hiding document information"
        AccessibilityAnnouncer.shared.post(message)
    }

    /// Builds the page management sheet view
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
                currentPageIndex: 0,  // macOS version doesn't track current page yet
                displayPDFData: viewModel.displayPDFData,
                provisionalPageRange: viewModel.provisionalPageRange,
                onDismiss: {
                    // Restore sidebar visibility and trigger refresh
                    isSidebarVisible = sidebarWasVisibleBeforeOrganiser
                    sidebarRefreshID = UUID()
                }
            )
        } else {
            // Legacy fallback for raw PDFs
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
                    // Restore sidebar visibility and trigger refresh
                    isSidebarVisible = sidebarWasVisibleBeforeOrganiser
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
