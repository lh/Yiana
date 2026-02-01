//
//  DocumentInfoPanel.swift
//  Yiana
//
//  Created by Claude on 02/09/2025.
//  Info panel for inspecting document metadata and OCR output on macOS
//

#if os(macOS)
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct DocumentInfoPanel: View {
    let document: NoteDocument
    @State private var selectedTab: String
    @State private var isLoadingOCR = false
    @State private var showingRawJSON = false

    private var showAddressesTab: Bool {
        AddressRepository.isDatabaseAvailable
    }

    init(document: NoteDocument) {
        self.document = document
        // Default to addresses tab if available, otherwise metadata
        _selectedTab = State(initialValue: AddressRepository.isDatabaseAvailable ? "addresses" : "metadata")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Document Info")
                    .font(.headline)
                Spacer()
                Button(action: { showingRawJSON.toggle() }) {
                    Image(systemName: showingRawJSON ? "doc.plaintext" : "doc.badge.gearshape")
                        .help(showingRawJSON ? "Show formatted view" : "Show raw JSON")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tab selector
            Picker("Info Type", selection: $selectedTab) {
                if showAddressesTab {
                    Text("Addresses").tag("addresses")
                }
                Text("Metadata").tag("metadata")
                Text("Text").tag("ocr")
                Text("Debug").tag("debug")
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            ScrollView {
                if showingRawJSON {
                    RawJSONView(metadata: document.metadata)
                        .padding()
                } else {
                    switch selectedTab {
                    case "addresses":
                        AddressesView(documentId: document.metadata.title)
                            .padding()
                    case "metadata":
                        MetadataView(metadata: document.metadata)
                            .padding()
                    case "ocr":
                        OCRView(document: document, isLoading: $isLoadingOCR)
                            .padding()
                    case "debug":
                        DebugView(document: document)
                            .padding()
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .frame(minWidth: 300, idealWidth: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Metadata View
struct MetadataView: View {
    let metadata: DocumentMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            InfoRow(label: "Title", value: metadata.title)
            InfoRow(label: "ID", value: metadata.id.uuidString, monospaced: true)
            InfoRow(label: "Pages", value: "\(metadata.pageCount)")
            InfoRow(label: "Created", value: formatDate(metadata.created))
            InfoRow(label: "Modified", value: formatDate(metadata.modified))

            if !metadata.tags.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        ForEach(metadata.tags, id: \.self) { tag in
                            TagView(tag: tag)
                        }
                    }
                }
            }

            Divider()

            // OCR Status
            HStack {
                Text("OCR Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                OCRStatusBadge(isCompleted: metadata.ocrCompleted)
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - OCR View
struct OCRView: View {
    let document: NoteDocument
    @Binding var isLoading: Bool

    private var metadata: DocumentMetadata { document.metadata }
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Status header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OCR Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    OCRStatusBadge(isCompleted: metadata.ocrCompleted)
                    if metadata.ocrCompleted {
                        VStack(alignment: .leading, spacing: 4) {
                            if let processedAt = metadata.ocrProcessedAt {
                                Text("Processed: \(formatDate(processedAt))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if let confidence = metadata.ocrConfidence {
                                Text(String(format: "Confidence: %.1f%%", confidence * 100))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if let source = metadata.ocrSource {
                                Text("Source: \(source.displayName)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                if metadata.ocrCompleted, let text = metadata.fullText {
                    Menu {
                        Button("Copy All Text") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }
                        Button("Export to File...") {
                            exportOCRText(text)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            Divider()

            // OCR Text content
            if metadata.ocrCompleted {
                if let fullText = metadata.fullText {
                    VStack(alignment: .leading, spacing: 10) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search in text...", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Text view
                        GroupBox {
                            ScrollView {
                                Text(highlightedText(fullText, search: searchText))
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                            .frame(minHeight: 200)
                        }

                        // Character count
                        Text("\(fullText.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        reprocessOCRButton
                    }
                } else {
                    VStack(spacing: 10) {
                        Text("OCR completed but no text found")
                            .foregroundColor(.secondary)
                            .italic()
                        reprocessOCRButton
                    }
                }
            } else {
                VStack(spacing: 15) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("OCR not yet processed")
                        .foregroundColor(.secondary)

                    Button("Process OCR") {
                        isLoading = true

                        // Reset OCR metadata so the service picks it up again
                        document.metadata.ocrCompleted = false
                        document.metadata.fullText = nil
                        document.metadata.ocrProcessedAt = nil
                        document.metadata.ocrConfidence = nil
                        document.metadata.ocrSource = nil
                        document.metadata.pageProcessingStates = (1...document.metadata.pageCount).map {
                            PageProcessingState(pageNumber: $0, needsOCR: true)
                        }
                        document.metadata.modified = Date()

                        // Save to update the file's modification date, which
                        // causes the OCR service to reprocess it.
                        guard let fileURL = document.fileURL else {
                            print("[Process OCR] No fileURL, cannot save")
                            isLoading = false
                            return
                        }
                        let typeName = document.fileType ?? UTType.yianaDocument.identifier
                        document.save(to: fileURL, ofType: typeName, for: .saveOperation) { error in
                            if let error {
                                print("[Process OCR] Save failed: \(error)")
                            } else {
                                print("[Process OCR] Document saved, OCR service should pick it up")

                                // Write to priority queue so OCR service processes this file first
                                let fileName = fileURL.lastPathComponent
                                let priorityFileURL = fileURL
                                    .deletingLastPathComponent()
                                    .appendingPathComponent("ocr_priority.txt")
                                let coordinator = NSFileCoordinator()
                                var coordinatorError: NSError?
                                coordinator.coordinate(writingItemAt: priorityFileURL, options: .forMerging, error: &coordinatorError) { coordURL in
                                    if let existing = try? String(contentsOf: coordURL, encoding: .utf8) {
                                        let lines = existing.components(separatedBy: .newlines).filter { !$0.isEmpty }
                                        if !lines.contains(fileName) {
                                            try? (existing.trimmingCharacters(in: .whitespacesAndNewlines) + "\n" + fileName)
                                                .write(to: coordURL, atomically: true, encoding: .utf8)
                                        }
                                    } else {
                                        try? fileName.write(to: coordURL, atomically: true, encoding: .utf8)
                                    }
                                }
                                if let coordinatorError {
                                    print("[Process OCR] Priority file write failed: \(coordinatorError)")
                                }
                            }
                            Task { @MainActor in
                                isLoading = false
                            }
                        }
                    }
                    .disabled(isLoading)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    private var reprocessOCRButton: some View {
        Button("Reprocess OCR") {
            isLoading = true

            document.metadata.ocrCompleted = false
            document.metadata.fullText = nil
            document.metadata.ocrProcessedAt = nil
            document.metadata.ocrConfidence = nil
            document.metadata.ocrSource = nil
            document.metadata.pageProcessingStates = (1...document.metadata.pageCount).map {
                PageProcessingState(pageNumber: $0, needsOCR: true)
            }
            document.metadata.modified = Date()

            guard let fileURL = document.fileURL else {
                print("[Reprocess OCR] No fileURL, cannot save")
                isLoading = false
                return
            }
            let typeName = document.fileType ?? UTType.yianaDocument.identifier
            document.save(to: fileURL, ofType: typeName, for: .saveOperation) { error in
                if let error {
                    print("[Reprocess OCR] Save failed: \(error)")
                } else {
                    print("[Reprocess OCR] Document saved, OCR service should pick it up")

                    let fileName = fileURL.lastPathComponent
                    let priorityFileURL = fileURL
                        .deletingLastPathComponent()
                        .appendingPathComponent("ocr_priority.txt")
                    let coordinator = NSFileCoordinator()
                    var coordinatorError: NSError?
                    coordinator.coordinate(writingItemAt: priorityFileURL, options: .forMerging, error: &coordinatorError) { coordURL in
                        if let existing = try? String(contentsOf: coordURL, encoding: .utf8) {
                            let lines = existing.components(separatedBy: .newlines).filter { !$0.isEmpty }
                            if !lines.contains(fileName) {
                                try? (existing.trimmingCharacters(in: .whitespacesAndNewlines) + "\n" + fileName)
                                    .write(to: coordURL, atomically: true, encoding: .utf8)
                            }
                        } else {
                            try? fileName.write(to: coordURL, atomically: true, encoding: .utf8)
                        }
                    }
                    if let coordinatorError {
                        print("[Reprocess OCR] Priority file write failed: \(coordinatorError)")
                    }
                }
                Task { @MainActor in
                    isLoading = false
                }
            }
        }
        .disabled(isLoading)
        .font(.caption)
    }

    func highlightedText(_ text: String, search: String) -> AttributedString {
        guard !search.isEmpty else {
            return AttributedString(text)
        }

        var attributed = AttributedString(text)
        let searchLower = search.lowercased()
        let textLower = text.lowercased()

        var searchStartIndex = textLower.startIndex
        while let range = textLower.range(of: searchLower, range: searchStartIndex..<textLower.endIndex) {
            let nsRange = NSRange(range, in: text)
            if let attributedRange = Range(nsRange, in: attributed) {
                attributed[attributedRange].backgroundColor = .yellow.opacity(0.3)
            }
            searchStartIndex = range.upperBound
        }

        return attributed
    }

    func exportOCRText(_ text: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "OCR_output.txt"

        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save OCR text: \(error)")
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Debug View
struct DebugView: View {
    let document: NoteDocument
    @State private var fileSize: String = "Calculating..."

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            InfoRow(label: "File URL", value: document.fileURL?.path ?? "Unknown", monospaced: true)
            InfoRow(label: "File Type", value: document.fileType ?? "Unknown")
            InfoRow(label: "File Size", value: fileSize)

            if let pdfData = document.pdfData {
                InfoRow(label: "PDF Data Size", value: ByteCountFormatter.string(fromByteCount: Int64(pdfData.count), countStyle: .file))
            }

            Divider()

            Text("Document State")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 5) {
                    #if os(iOS)
                    StateRow(label: "Has Unsaved Changes", value: document.hasUnsavedChanges)
                    StateRow(label: "Document State", value: "\(document.documentState.rawValue)")
                    StateRow(label: "Is Closed", value: document.documentState == .closed)
                    #else
                    StateRow(label: "Has Unsaved Changes", value: document.hasUnautosavedChanges)
                    StateRow(label: "Is Document Edited", value: document.isDocumentEdited)
                    #endif
                }
                .padding(8)
            }
        }
        .onAppear {
            calculateFileSize()
        }
    }

    func calculateFileSize() {
        guard let fileURL = document.fileURL else {
            fileSize = "Unknown"
            return
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let size = attributes[FileAttributeKey.size] as? Int64 {
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            fileSize = "Unknown"
        }
    }
}

// MARK: - Raw JSON View
struct RawJSONView: View {
    let metadata: DocumentMetadata

    var body: some View {
        GroupBox {
            ScrollView {
                Text(jsonString)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
    }

    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(metadata),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "Failed to encode metadata"
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
    }
}

struct StateRow: View {
    let label: String
    let value: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(value ? .green : .secondary)
                .font(.caption)
        }
    }
}

struct TagView: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(4)
    }
}

struct OCRStatusBadge: View {
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "clock")
                .font(.caption)
            Text(isCompleted ? "Completed" : "Not Processed")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(isCompleted ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .foregroundColor(isCompleted ? .green : .orange)
        .cornerRadius(4)
    }
}

#endif
