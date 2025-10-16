//
//  BulkImportView.swift
//  Yiana
//
//  Bulk PDF import interface for macOS
//

#if os(macOS)
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct BulkImportView: View {
    let pdfURLs: [URL]
    let folderPath: String
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?

    @AppStorage("lastUsedImportFolder") private var lastUsedImportFolder = ""
    @StateObject private var importService: BulkImportService
    @State private var titles: [String]
    @State private var isImporting = false
    @State private var importResult: BulkImportResult?
    @State private var showingResults = false
    @State private var showingWarning = false

    private let maxFilesWithoutWarning = 50
    private let absoluteMaxFiles = 500

    init(pdfURLs: [URL], folderPath: String = "", isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        // Limit the number of files
        let limitedURLs = Array(pdfURLs.prefix(absoluteMaxFiles))
        print("BulkImportView init with \(limitedURLs.count) PDFs (original: \(pdfURLs.count))")

        self.pdfURLs = limitedURLs
        self.folderPath = folderPath
        self._isPresented = isPresented
        self.onDismiss = onDismiss

        // Create import service with folder path
        let service = BulkImportService(folderPath: folderPath)
        self._importService = StateObject(wrappedValue: service)
        self._titles = State(initialValue: service.suggestedTitles(for: limitedURLs))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Import Multiple PDFs")
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack {
                    Text("\(pdfURLs.count) files selected")
                        .foregroundColor(.secondary)

                    if pdfURLs.count > maxFilesWithoutWarning {
                        Label("Large import may take several minutes", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Show target folder
                HStack {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Import to: \(folderPath.isEmpty ? "Documents (Root)" : folderPath)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // File list with editable titles
            ScrollView {
                LazyVStack(spacing: 12) { // Use LazyVStack for better performance with many items
                    ForEach(Array(pdfURLs.enumerated()), id: \.offset) { index, url in
                        PDFImportRow(
                            url: url,
                            title: $titles[index],
                            index: index
                        )
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)

            Divider()

            // Progress or Action buttons
            VStack(spacing: 12) {
                if isImporting {
                    if let progress = importService.currentProgress {
                        VStack(spacing: 8) {
                            ProgressView(value: progress.progress) {
                                Text(progress.progressDescription)
                                    .font(.caption)
                            }
                            .progressViewStyle(.linear)

                            Text("\(Int(progress.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                } else {
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isPresented = false
                            onDismiss?()
                        }
                        .keyboardShortcut(.escape)

                        Spacer()

                        Button("Reset Titles") {
                            titles = importService.suggestedTitles(for: pdfURLs)
                        }

                        Button("Import All") {
                            startImport()
                        }
                        .keyboardShortcut(.return)
                        .disabled(titles.contains { $0.isEmpty })
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .onAppear {
            print("BulkImportView appeared with \(pdfURLs.count) PDFs, \(titles.count) titles")
        }
        .sheet(isPresented: $showingResults) {
            if let result = importResult {
                BulkImportResultsView(
                    result: result,
                    isPresented: $showingResults,
                    onDismiss: {
                        isPresented = false
                    }
                )
            }
        }
    }

    private func startImport() {
        isImporting = true

        Task {
            let result = await importService.importPDFs(
                from: pdfURLs,
                withTitles: titles
            )

            await MainActor.run {
                self.importResult = result
                self.isImporting = false

                if result.failed.isEmpty {
                    // All successful - save folder preference and close
                    lastUsedImportFolder = folderPath
                    isPresented = false
                    onDismiss?()
                } else {
                    // Some failures - still save preference but show results
                    if !result.successful.isEmpty {
                        lastUsedImportFolder = folderPath
                    }
                    showingResults = true
                }
            }
        }
    }
}

struct PDFImportRow: View {
    let url: URL
    @Binding var title: String
    let index: Int
    @State private var thumbnail: NSImage?
    @State private var isLoadingThumbnail = false

    // Only load thumbnails for first 100 files to prevent memory issues
    private var shouldLoadThumbnail: Bool {
        index < 100
    }

    var body: some View {
        HStack(spacing: 12) {
            // Row number
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // PDF thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                }
            }

            // File info and title
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                TextField("Document title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            // File size
            Text(fileSizeString(for: url))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            if shouldLoadThumbnail && !isLoadingThumbnail {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        isLoadingThumbnail = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Use autoreleasepool to manage memory for large batches
            autoreleasepool {
                if let data = try? Data(contentsOf: url),
                   let pdf = PDFDocument(data: data),
                   let page = pdf.page(at: 0) {

                    let size = NSSize(width: 40, height: 40) // Smaller thumbnails for better performance

                    // Use the thumbnail method which is modern and efficient
                    let thumbnail = page.thumbnail(of: size, for: .mediaBox)
                    DispatchQueue.main.async {
                        self.thumbnail = thumbnail
                        self.isLoadingThumbnail = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoadingThumbnail = false
                    }
                }
            }
        }
    }

    private func fileSizeString(for url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct BulkImportResultsView: View {
    let result: BulkImportResult
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Summary
            VStack(spacing: 8) {
                Image(systemName: result.failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(result.failed.isEmpty ? .green : .orange)

                Text("Import Complete")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(result.successful.count) of \(result.totalProcessed) files imported successfully")
                    .foregroundColor(.secondary)
            }

            // Failed files list
            if !result.failed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed imports:")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.failed, id: \.url) { failed in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)

                                    VStack(alignment: .leading) {
                                        Text(failed.url.lastPathComponent)
                                            .font(.caption)
                                        Text(failed.error.localizedDescription)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            Button("Done") {
                isPresented = false
                onDismiss()
            }
            .keyboardShortcut(.return)
        }
        .padding()
        .frame(width: 400)
    }
}

#endif
