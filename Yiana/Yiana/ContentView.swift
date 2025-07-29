//
//  ContentView.swift
//  Yiana
//
//  Created by Luke Herbert on 15/07/2025.
//

import SwiftUI
import PDFKit

struct ContentView: View {
    @EnvironmentObject var importHandler: DocumentImportHandler
    @State private var showingImportSheet = false
    @State private var importTitle = ""
    @State private var selectedFolder = ""
    
    var body: some View {
        DocumentListView()
            .sheet(isPresented: $importHandler.showingImportDialog) {
                ImportPDFView(
                    pdfURL: importHandler.pdfToImport,
                    isPresented: $importHandler.showingImportDialog
                )
            }
    }
}

struct ImportPDFView: View {
    let pdfURL: URL?
    @Binding var isPresented: Bool
    @State private var documentTitle = ""
    @State private var selectedFolderPath = ""
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let pdfURL = pdfURL {
                    // PDF Preview
                    PDFViewer(pdfData: (try? Data(contentsOf: pdfURL)) ?? Data())
                        .frame(height: 300)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Title input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Document Title")
                            .font(.headline)
                        TextField("Enter title", text: $documentTitle)
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                // Suggest filename as title
                                documentTitle = pdfURL.deletingPathExtension().lastPathComponent
                            }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                } else {
                    Text("No PDF to import")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Import PDF")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importPDF()
                    }
                    .disabled(documentTitle.isEmpty || isImporting)
                }
            }
        }
    }
    
    private func importPDF() {
        guard let pdfURL = pdfURL,
              let pdfData = try? Data(contentsOf: pdfURL) else { return }
        
        isImporting = true
        
        Task {
            // Create a new document with the PDF
            let repository = DocumentRepository()
            let documentURL = repository.newDocumentURL(title: documentTitle)
            
            // Create metadata
            let metadata = DocumentMetadata(
                id: UUID(),
                title: documentTitle,
                created: Date(),
                modified: Date(),
                pageCount: 0, // Could calculate from PDF
                tags: [],
                ocrCompleted: false,
                fullText: nil
            )
            
            // Create document in NoteDocument format
            let encoder = JSONEncoder()
            if let metadataData = try? encoder.encode(metadata) {
                var contents = Data()
                contents.append(metadataData)
                contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
                contents.append(pdfData)
                
                do {
                    try contents.write(to: documentURL)
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: pdfURL)
                    
                    await MainActor.run {
                        isPresented = false
                    }
                } catch {
                    print("Error saving imported PDF: \(error)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DocumentImportHandler())
}