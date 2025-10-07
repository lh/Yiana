//
//  ContentView.swift
//  Yiana
//
//  Created by Luke Herbert on 15/07/2025.
//

import SwiftUI
import PDFKit
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @EnvironmentObject var importHandler: DocumentImportHandler
    @StateObject private var backgroundIndexer = BackgroundIndexer.shared
    @State private var showingImportSheet = false
    @State private var importTitle = ""
    @State private var selectedFolder = ""
    @State private var hasTriggeredIndexing = false

    var body: some View {
        DocumentListView()
            .tint(Color("AccentColor"))
            .sheet(isPresented: $importHandler.showingImportDialog) {
                ImportPDFView(
                    pdfURL: importHandler.pdfToImport,
                    isPresented: $importHandler.showingImportDialog
                )
            }
            .task {
                if !hasTriggeredIndexing {
                    hasTriggeredIndexing = true
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    backgroundIndexer.indexAllDocuments()
                }
            }
    }
}

struct ImportPDFView: View {
    let pdfURL: URL?
    @Binding var isPresented: Bool
    @AppStorage("lastUsedImportFolder") private var lastUsedImportFolder = ""
    @State private var documentTitle = ""
    @State private var selectedFolderPath = ""
    @State private var importMode: ImportTarget = .createNew
    @State private var selectedExistingURL: URL? = nil
    @State private var isImporting = false
    @State private var availableDocuments: [URL] = []
    @State private var availableFolders: [String] = []

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
                            
                            // Folder selection
                            if !availableFolders.isEmpty {
                                Text("Folder")
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                Picker("Select Folder", selection: $selectedFolderPath) {
                                    Text("Documents (Root)").tag("")
                                    ForEach(availableFolders, id: \.self) { folder in
                                        Text(folder).tag(folder)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        } else {
                            Text("Choose an existing document to append")
                                .font(.headline)
                            List(selection: $selectedExistingURL) {
                                ForEach(availableDocuments, id: \.self) { url in
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .lineLimit(1)
                                        .tag(url as URL?)
                                }
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
                // Load available documents and folders
                let repo = DocumentRepository()
                availableDocuments = repo.documentURLs()
                
                // Get all folders recursively
                availableFolders = getAllFolderPaths(in: repo.documentsDirectory)
                
                // Set the selected folder to last used, if it still exists
                if !lastUsedImportFolder.isEmpty && 
                   (lastUsedImportFolder == "" || availableFolders.contains(lastUsedImportFolder)) {
                    selectedFolderPath = lastUsedImportFolder
                } else {
                    // Default to root if last used folder doesn't exist
                    selectedFolderPath = ""
                }
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
            // Use the selected folder path for import
            let service = ImportService(folderPath: selectedFolderPath)
            do {
                switch importMode {
                case .createNew:
                    _ = try service.importPDF(from: pdfURL, mode: .createNew(title: documentTitle))
                    // Save the folder preference for next time
                    lastUsedImportFolder = selectedFolderPath
                case .appendExisting:
                    guard let target = selectedExistingURL else { return }
                    _ = try service.importPDF(from: pdfURL, mode: .appendToExisting(targetURL: target))
                }
                // Clean up temp file
                try? FileManager.default.removeItem(at: pdfURL)
                await MainActor.run {
                    // Notify list to refresh and close sheet
                    NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
                    isPresented = false
                }
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
    
    private func getAllFolderPaths(in directory: URL, relativeTo base: URL? = nil, currentPath: String = "") -> [String] {
        var folders: [String] = []
        let fileManager = FileManager.default
        let baseURL = base ?? directory
        
        do {
            let items = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for item in items {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    let folderName = item.lastPathComponent
                    let fullPath = currentPath.isEmpty ? folderName : "\(currentPath)/\(folderName)"
                    folders.append(fullPath)
                    
                    // Recursively get subfolders
                    let subfolders = getAllFolderPaths(in: item, relativeTo: baseURL, currentPath: fullPath)
                    folders.append(contentsOf: subfolders)
                }
            }
        } catch {
            print("Error getting folders: \(error)")
        }
        
        return folders.sorted()
    }
}

#Preview {
    ContentView()
        .environmentObject(DocumentImportHandler())
}
