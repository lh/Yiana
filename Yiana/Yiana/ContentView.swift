//
//  ContentView.swift
//  Yiana
//
//  Created by Luke Herbert on 15/07/2025.
//

import SwiftUI
import PDFKit
import YianaDocumentArchive
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
                    isPresented: $importHandler.showingImportDialog,
                    activeDocumentURL: importHandler.activeDocumentURL
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
    let activeDocumentURL: URL?
    @AppStorage("lastUsedImportFolder") private var lastUsedImportFolder = ""
    @State private var documentTitle = ""
    @State private var selectedFolderPath = ""
    @State private var importMode: ImportTarget = .createNew
    @State private var selectedExistingURL: URL?
    @State private var isImporting = false
    @State private var searchText = ""
    @State private var showingOtherOptions = false
    @State private var availableDocuments: [(url: URL, relativePath: String)] = []
    @State private var availableFolders: [String] = []
    @State private var previewFitMode: FitMode = .height

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
                    PDFViewer(pdfData: (try? Data(contentsOf: pdfURL)) ?? Data(), fitMode: $previewFitMode)
                        .frame(height: 300)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    // Target selection
                    VStack(alignment: .leading, spacing: 12) {
                        // Direct "add to open document" when a document is active
                        if let activeURL = activeDocumentURL, !showingOtherOptions {
                            Button {
                                appendToDocument(pdfURL: pdfURL, targetURL: activeURL)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("Add to open document")
                                            .font(.headline)
                                        Text(activeURL.deletingPathExtension().lastPathComponent)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .disabled(isImporting)

                            Button("Other options...") {
                                showingOtherOptions = true
                            }
                            .font(.subheadline)
                        }

                        // Full picker (always shown when no active doc, or after tapping "Other options")
                        if activeDocumentURL == nil || showingOtherOptions {
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
                                        documentTitle = pdfURL.deletingPathExtension().lastPathComponent
                                    }

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

                                TextField("Search documents", text: $searchText)
                                    .textFieldStyle(.roundedBorder)

                                List(selection: $selectedExistingURL) {
                                    ForEach(filteredDocuments, id: \.url) { doc in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(doc.url.deletingPathExtension().lastPathComponent)
                                                .lineLimit(1)
                                            if !doc.relativePath.isEmpty {
                                                Text(doc.relativePath)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .tag(doc.url as URL?)
                                    }
                                }
                                .frame(minHeight: 160)
                            }
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
                let repo = DocumentRepository()
                let docsDir = repo.documentsDirectory

                // File I/O off main thread
                let (docs, folders) = await Task.detached {
                    let docs = repo.allDocumentsRecursive()
                        .sorted { $0.url.deletingPathExtension().lastPathComponent
                            .localizedStandardCompare($1.url.deletingPathExtension().lastPathComponent) == .orderedAscending }
                    let folders = importFolderPaths(in: docsDir)
                    return (docs, folders)
                }.value

                availableDocuments = docs
                availableFolders = folders

                // Set the selected folder to last used, if it still exists
                if !lastUsedImportFolder.isEmpty &&
                   (lastUsedImportFolder == "" || availableFolders.contains(lastUsedImportFolder)) {
                    selectedFolderPath = lastUsedImportFolder
                } else {
                    selectedFolderPath = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                if activeDocumentURL == nil || showingOtherOptions {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            importPDF()
                        }
                        .disabled(disableImportButton)
                    }
                }
            }
        }
    }

    private func appendToDocument(pdfURL: URL?, targetURL: URL) {
        guard let pdfURL = pdfURL else { return }
        isImporting = true
        let captured = targetURL
        Task {
            let service = ImportService(folderPath: "")
            do {
                let result = try service.importPDF(from: pdfURL, mode: .appendToExisting(targetURL: captured))
                try? FileManager.default.removeItem(at: pdfURL)
                await performOCROnImportedDocument(at: result.url)
                await MainActor.run {
                    NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
                    isPresented = false
                }
            } catch {
                print("Error appending PDF: \(error)")
            }
            isImporting = false
        }
    }

    private func importPDF() {
        guard let pdfURL = pdfURL else { return }

        isImporting = true

        Task {
            // Use the selected folder path for import
            let service = ImportService(folderPath: selectedFolderPath)
            do {
                let result: ImportResult
                switch importMode {
                case .createNew:
                    result = try service.importPDF(from: pdfURL, mode: .createNew(title: documentTitle))
                    // Save the folder preference for next time
                    lastUsedImportFolder = selectedFolderPath
                case .appendExisting:
                    guard let target = selectedExistingURL else { return }
                    result = try service.importPDF(from: pdfURL, mode: .appendToExisting(targetURL: target))
                }
                // Clean up temp file
                try? FileManager.default.removeItem(at: pdfURL)

                // Run on-device OCR on the imported document
                await performOCROnImportedDocument(at: result.url)

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

    private func performOCROnImportedDocument(at url: URL) async {
        do {
            let payload = try DocumentArchive.read(from: url)
            guard let pdfData = payload.pdfData else { return }

            let ocrResult = await OnDeviceOCRService.shared.recognizeText(in: pdfData)
            guard !ocrResult.fullText.isEmpty else { return }

            var metadata = try JSONDecoder().decode(DocumentMetadata.self, from: payload.metadata)
            metadata.fullText = ocrResult.fullText
            metadata.ocrCompleted = true
            metadata.ocrProcessedAt = Date()
            metadata.ocrConfidence = ocrResult.confidence
            metadata.ocrSource = .onDevice
            for i in 0..<metadata.pageProcessingStates.count {
                metadata.pageProcessingStates[i].needsOCR = false
                metadata.pageProcessingStates[i].ocrProcessedAt = Date()
            }

            let updatedMetadata = try JSONEncoder().encode(metadata)
            _ = try DocumentArchive.write(
                metadata: updatedMetadata,
                pdf: .data(pdfData),
                to: url
            )

            try await SearchIndexService.shared.indexDocument(
                id: metadata.id,
                url: url,
                title: metadata.title,
                fullText: ocrResult.fullText,
                tags: metadata.tags,
                metadata: metadata,
                folderPath: "",
                fileSize: Int64((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0)
            )
        } catch {
            print("OCR on imported document failed: \(error)")
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

    private var filteredDocuments: [(url: URL, relativePath: String)] {
        guard !searchText.isEmpty else { return availableDocuments }
        return availableDocuments.filter {
            $0.url.deletingPathExtension().lastPathComponent
                .localizedCaseInsensitiveContains(searchText)
        }
    }

}

private func importFolderPaths(in directory: URL, relativeTo base: URL? = nil, currentPath: String = "") -> [String] {
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

                let subfolders = importFolderPaths(in: item, relativeTo: baseURL, currentPath: fullPath)
                folders.append(contentsOf: subfolders)
            }
        }
    } catch {
        print("Error getting folders: \(error)")
    }

    return folders.sorted()
}

#Preview {
    ContentView()
        .environmentObject(DocumentImportHandler())
}
