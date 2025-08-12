//
//  DocumentEditView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit

#if os(iOS)
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
    @State private var showingPageManagement = false
    @State private var scanColorMode: ScanColorMode = .color
    @State private var showTitleField = false
    @State private var navigateToPage: Int? = nil
    
    private let scanningService = ScanningService()
    
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
        }
        .documentScanner(isPresented: $showingScanner) { scannedImages in
            handleScannedImages(scannedImages)
        }
        .sheet(isPresented: $showingPageManagement) {
            if let viewModel = viewModel {
                PageManagementView(
                    pdfData: Binding(
                        get: { viewModel.pdfData },
                        set: { 
                            viewModel.pdfData = $0
                            viewModel.hasChanges = true
                        }
                    ),
                    isPresented: $showingPageManagement,
                    onPageSelected: { pageIndex in
                        navigateToPage = pageIndex
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func documentContent(viewModel: DocumentViewModel) -> some View {
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
            } else if let pdfData = viewModel.pdfData {
                PDFViewer(pdfData: pdfData, navigateToPage: $navigateToPage)
                    .overlay(alignment: .bottomTrailing) {
                        // Page management button
                        if pdfData.count > 0 {
                            Button(action: {
                                showingPageManagement = true
                            }) {
                                Label("Pages", systemImage: "rectangle.stack")
                                    .font(.title3)
                                    .padding(12)
                                    .background(Color.secondary.opacity(0.8))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding()
                        }
                    }
                    .overlay(alignment: .bottom) {
                        scanButtonBar
                    }
            } else {
                ContentPlaceholderView()
                    .overlay(alignment: .bottom) {
                        scanButtonBar
                    }
            }
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
                            dismiss()
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
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 0)
                    .background(Color(.systemBackground).opacity(0.95))
                }
                Spacer()
            }
        }
    }
    
    private var scanButtonBar: some View {
        HStack(spacing: 40) {
            // Color scan button - "Scan"
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
                    Text("Scan")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .disabled(!scanningService.isScanningAvailable())
            
            // B&W document scan button - "Doc"
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
                    Text("Doc")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .disabled(!scanningService.isScanningAvailable())
        }
        .padding(.bottom, 20)
    }
    
    private func loadDocument() async {
        let loadedDocument = NoteDocument(fileURL: documentURL)
        
        await withCheckedContinuation { continuation in
            loadedDocument.open { success in
                Task { @MainActor in
                    if success {
                        self.document = loadedDocument
                        self.viewModel = DocumentViewModel(document: loadedDocument)
                    }
                    self.isLoading = false
                    continuation.resume()
                }
            }
        }
    }
    

    
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
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("No Content")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Add content by scanning documents")
                .foregroundColor(.secondary)
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