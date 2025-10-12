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
    
    init(documentURL: URL, searchResult: SearchResult? = nil) {
        self.documentURL = documentURL
        self.searchResult = searchResult
    }
    
    var body: some View {
        HSplitView {
            // Main document view
            ZStack {
            if isLoading {
                ProgressView("Loading document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Unable to load document")
                        .font(.title2)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pdfData = pdfData {
                VStack(spacing: 0) {
                    // Read-only banner
                    if viewModel?.isReadOnly == true {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                            Text("This document is read-only")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .frame(maxWidth: .infinity)
                    }
                    // Title bar
                    HStack {
                        Text(documentTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding()
                        Spacer()
                        
                        // Control buttons
                        HStack(spacing: 12) {
                            // Export button
                            Button(action: {
                                exportPDF()
                            }) {
                                Label("Export PDF", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .help("Export as PDF")
                            
                            // Info panel toggle
                            Button(action: {
                                showingInfoPanel.toggle()
                            }) {
                                Label("Info", systemImage: showingInfoPanel ? "info.circle.fill" : "info.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Toggle document info panel")
                            
                            // Page management button
                            if pdfData.count > 0 {
                                Button(action: {
                                    showingPageManagement = true
                                }) {
                                    Label("Manage Pages", systemImage: "rectangle.stack")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.trailing)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    // PDF content with optional markup mode
                    // Note: searchResult.pageNumber is 1-based
                    let _ = {
                        print("DEBUG DocumentReadView: searchResult = \(String(describing: searchResult))")
                        print("DEBUG DocumentReadView: pageNumber = \(String(describing: searchResult?.pageNumber))")
                        print("DEBUG DocumentReadView: searchTerm = \(String(describing: searchResult?.searchTerm))")
                    }()
                    // PDF viewer - use viewModel's pdfData for live updates
                    MacPDFViewer(pdfData: viewModel?.pdfData ?? pdfData)
                }
            } else {
                VStack(spacing: 20) {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
            // Use the proper view model with bindings if available,
            // or fall back to read-only mode for legacy PDFs
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
                    provisionalPageRange: viewModel.provisionalPageRange
                )
            } else {
                // Legacy fallback for raw PDFs
                PageManagementView(
                    pdfData: $pdfData,
                    viewModel: DocumentViewModel(pdfData: pdfData),
                    isPresented: $showingPageManagement,
                    currentPageIndex: 0,
                    displayPDFData: pdfData,
                    provisionalPageRange: nil
                )
            }
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
                    NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: destinationURL.deletingLastPathComponent().path)
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
