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

                if result.failed.isEmpty && result.timedOut.isEmpty {
                    // All successful - save folder preference and close
                    lastUsedImportFolder = folderPath
                    isPresented = false
                    onDismiss?()
                } else {
                    // Some failures or timeouts - still save preference but show results
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

    private var hasProblems: Bool {
        !result.failed.isEmpty || !result.timedOut.isEmpty
    }

    private var problemCount: Int {
        result.failed.count + result.timedOut.count
    }

    var body: some View {
        VStack(spacing: 20) {
            // Summary
            VStack(spacing: 8) {
                Image(systemName: hasProblems ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(hasProblems ? .orange : .green)

                Text("Import Complete")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(result.successful.count) of \(result.totalProcessed) files imported successfully")
                    .foregroundColor(.secondary)

                if !result.timedOut.isEmpty {
                    Text("\(result.timedOut.count) files timed out (may be corrupted or too large)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Timed out files list
            if !result.timedOut.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Timed out (\(result.timedOut.count)):")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.timedOut, id: \.self) { url in
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)

                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Failed files list
            if !result.failed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Failed (\(result.failed.count)):")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }

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
                                            .lineLimit(1)
                                        Text(failed.error.localizedDescription)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Action buttons
            HStack(spacing: 12) {
                if hasProblems {
                    Button("Export Problem Files") {
                        exportProblemFiles()
                    }
                }

                Spacer()

                Button("Done") {
                    isPresented = false
                    onDismiss()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 450)
    }

    private func exportProblemFiles() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "failed-imports.txt"
        savePanel.title = "Export Problem Files"
        savePanel.message = "Save a list of files that failed to import"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            var content = "# Failed Import Report\n"
            content += "# Generated: \(Date())\n\n"

            if !result.timedOut.isEmpty {
                content += "## Timed Out Files (\(result.timedOut.count))\n"
                content += "# These files took too long to import and may be corrupted or too large\n\n"
                for timedOutURL in result.timedOut {
                    content += "\(timedOutURL.path)\n"
                }
                content += "\n"
            }

            if !result.failed.isEmpty {
                content += "## Failed Files (\(result.failed.count))\n\n"
                for failed in result.failed {
                    content += "\(failed.url.path)\n"
                    content += "  Error: \(failed.error.localizedDescription)\n\n"
                }
            }

            // Write just the paths for easy re-import
            content += "\n## File Paths Only (for re-import)\n"
            content += "# Copy these paths to a text file and use 'Import from File List'\n\n"
            for timedOutURL in result.timedOut {
                content += "\(timedOutURL.path)\n"
            }
            for failed in result.failed {
                content += "\(failed.url.path)\n"
            }

            try? content.write(to: url, atomically: true, encoding: .utf8)

            // Open in Finder
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

#endif
