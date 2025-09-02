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
    @State private var importMode: ImportTarget = .createNew
    @State private var selectedExistingURL: URL? = nil
    @State private var isImporting = false
    @State private var availableDocuments: [URL] = []

    enum ImportTarget: String, CaseIterable, Identifiable {
        case createNew = "New Document"
        case appendExisting = "Append to Existing"
        var id: String { rawValue }
    }
    
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
                    
                    // Target and title selection
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Import Target", selection: $importMode) {
                            ForEach(ImportTarget.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if importMode == .createNew {
                            Text("Document Title")
                                .font(.headline)
                            TextField("Enter title", text: $documentTitle)
                                .textFieldStyle(.roundedBorder)
                                .onAppear {
                                    // Suggest filename as title
                                    documentTitle = pdfURL.deletingPathExtension().lastPathComponent
                                }
                        } else {
                            Text("Choose an existing document to append")
                                .font(.headline)
                            List(availableDocuments, id: \.self, selection: $selectedExistingURL) {
                                Text($0.deletingPathExtension().lastPathComponent)
                                    .lineLimit(1)
                            }
                            .frame(minHeight: 160)
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
            .task {
                // Load available documents for append option
                let repo = DocumentRepository()
                availableDocuments = repo.documentURLs()
            }
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
                    .disabled(disableImportButton)
                }
            }
        }
    }
    
    private func importPDF() {
        guard let pdfURL = pdfURL else { return }

        isImporting = true

        Task {
            let service = ImportService()
            do {
                switch importMode {
                case .createNew:
                    _ = try service.importPDF(from: pdfURL, mode: .createNew(title: documentTitle))
                case .appendExisting:
                    guard let target = selectedExistingURL else { return }
                    _ = try service.importPDF(from: pdfURL, mode: .appendToExisting(targetURL: target))
                }
                // Clean up temp file
                try? FileManager.default.removeItem(at: pdfURL)
                await MainActor.run { isPresented = false }
            } catch {
                print("Error importing PDF: \(error)")
            }
            isImporting = false
        }
    }
}

// Helpers
extension ImportPDFView {
    private var disableImportButton: Bool {
        if isImporting { return true }
        switch importMode {
        case .createNew:
            return documentTitle.isEmpty
        case .appendExisting:
            return selectedExistingURL == nil
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DocumentImportHandler())
}
