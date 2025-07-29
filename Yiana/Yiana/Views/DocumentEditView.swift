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
        .navigationTitle("Edit Document")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel?.hasChanges ?? false)
        .toolbar {
            if viewModel?.hasChanges ?? false {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if viewModel?.isSaving ?? false {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveAndDismiss()
                        }
                    }
                }
            }
        }
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
                    isPresented: $showingPageManagement
                )
            }
        }
    }
    
    @ViewBuilder
    private func documentContent(viewModel: DocumentViewModel) -> some View {
        VStack(spacing: 0) {
            // Title editor
            TextField("Document Title", text: Binding(
                get: { viewModel.title },
                set: { viewModel.title = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.title2)
            .padding()
            .focused($titleFieldFocused)
            
            Divider()
            
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
                PDFViewer(pdfData: pdfData)
                    .overlay(alignment: .bottomTrailing) {
                        VStack(spacing: 16) {
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
                            }
                            
                            // Scan button
                            scanButton
                        }
                        .padding()
                    }
            } else {
                ContentPlaceholderView()
                    .overlay {
                        scanButton
                    }
            }
        }
    }
    
    private var scanButton: some View {
        Button(action: {
            if scanningService.isScanningAvailable() {
                showingScanner = true
            }
        }) {
            Label("Scan", systemImage: "doc.text.viewfinder")
                .font(.title2)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .disabled(!scanningService.isScanningAvailable())
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
    
    private func saveAndDismiss() {
        guard let viewModel = viewModel else { return }
        
        Task {
            let success = await viewModel.save()
            if success {
                dismiss()
            } else {
                showingSaveError = true
            }
        }
    }
    
    private func handleScannedImages(_ images: [UIImage]) {
        Task {
            isProcessingScans = true
            
            // Convert images to PDF
            if let newPDFData = await scanningService.convertImagesToPDF(images),
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