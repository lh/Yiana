//
//  DocumentInfoSheet.swift
//  Yiana
//
//  Created by Claude on 28/10/2025.
//  Info sheet for inspecting document metadata and OCR output on iOS
//

#if os(iOS)
import SwiftUI
import PDFKit

struct DocumentInfoSheet: View {
    let document: NoteDocument
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = "metadata"
    @State private var showingRawJSON = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Info Type", selection: $selectedTab) {
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
                        case "metadata":
                            MetadataView(metadata: document.metadata)
                                .padding()
                        case "ocr":
                            OCRView(metadata: document.metadata)
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
            .navigationTitle("Document Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingRawJSON.toggle() }) {
                        Image(systemName: showingRawJSON ? "doc.plaintext" : "doc.badge.gearshape")
                    }
                }
            }
        }
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
                    FlowLayout(spacing: 8) {
                        ForEach(metadata.tags, id: \.self) { tag in
                            TagView(tag: tag)
                        }
                    }
                }
            }

            Divider()
                .padding(.vertical, 5)

            // OCR Status
            HStack {
                Text("OCR Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                OCRStatusBadge(isCompleted: metadata.ocrCompleted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let metadata: DocumentMetadata
    @State private var searchText = ""
    @State private var showingShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Status header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("OCR Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    OCRStatusBadge(isCompleted: metadata.ocrCompleted)
                }

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
                            if searchText.isEmpty {
                                // Use TextEditor for better text selection on iOS
                                TextEditor(text: .constant(fullText))
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 200)
                                    .scrollContentBackground(.hidden)
                            } else {
                                // Use Text with highlighting when searching
                                ScrollView {
                                    Text(highlightedText(fullText, search: searchText))
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                }
                                .frame(minHeight: 200)
                            }
                        }

                        // Actions and character count
                        HStack {
                            Text("\(fullText.count) characters")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: {
                                UIPasteboard.general.string = fullText
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                showingShareSheet = true
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .sheet(isPresented: $showingShareSheet) {
                        if let fullText = metadata.fullText {
                            ShareSheet(items: [fullText])
                        }
                    }
                } else {
                    Text("OCR completed but no text found")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            } else {
                VStack(spacing: 15) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("OCR not yet processed")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            InfoRow(label: "File URL", value: document.fileURL.path, monospaced: true)
            InfoRow(label: "File Type", value: document.fileType ?? "Unknown")
            InfoRow(label: "File Size", value: fileSize)

            if let pdfData = document.pdfData {
                InfoRow(label: "PDF Data Size", value: ByteCountFormatter.string(fromByteCount: Int64(pdfData.count), countStyle: .file))
            }

            Divider()
                .padding(.vertical, 5)

            Text("Document State")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    StateRow(label: "Has Unsaved Changes", value: document.hasUnsavedChanges)
                    StateRow(label: "Is Closed", value: document.documentState == .closed)
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            calculateFileSize()
        }
    }

    func calculateFileSize() {
        let fileURL = document.fileURL
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

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowLayoutResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if x + subviewSize.width > maxWidth && x > 0 {
                    // Move to next line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, subviewSize.height)
                x += subviewSize.width + spacing
                size.width = max(size.width, x - spacing)
            }

            size.height = y + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}

#endif
