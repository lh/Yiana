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
import NaturalLanguage

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
                        OCRView(document: document, isLoading: $isLoadingOCR) {
                            selectedTab = "addresses"
                        }
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
    var onAddressExtracted: (() -> Void)?

    private var metadata: DocumentMetadata { document.metadata }
    @State private var searchText = ""
    @State private var selectedText = ""
    @State private var parsedPreview: TextAddressParser.Result?
    @State private var previewType: String = "patient"
    @StateObject private var repository = AddressRepository()

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
                            SelectableTextView(
                                text: fullText,
                                searchText: searchText,
                                selectedText: $selectedText
                            )
                            .frame(minHeight: 200)
                        }

                        // Character count and Address it! button
                        HStack {
                            Text("\(fullText.count) characters")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Menu {
                                Button("Patient") { parsePreview(type: "patient") }
                                Button("GP") { parsePreview(type: "gp") }
                                Button("Optician") { parsePreview(type: "optician") }
                                Button("Other") { parsePreview(type: "specialist") }
                            } label: {
                                Label("Address it!", systemImage: "mappin.and.ellipse")
                            }
                            .menuStyle(.borderedButton)
                            .disabled(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        // Inline preview of parsed address
                        if let preview = parsedPreview {
                            addressPreviewCard(preview)
                        }

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

    private func parsePreview(type: String) {
        parsedPreview = TextAddressParser.parse(selectedText)
        previewType = type
    }

    private func addressPreviewCard(_ preview: TextAddressParser.Result) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(previewType.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Discard") {
                        parsedPreview = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Button("Save") {
                        Task { await savePreview(preview) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Divider()

                if let name = preview.fullName {
                    previewRow("Name", name)
                }
                if let dob = preview.dateOfBirth {
                    previewRow("DOB", dob)
                }
                if let addr = preview.addressLine1 {
                    previewRow("Address", [addr, preview.addressLine2, preview.city]
                        .compactMap { $0 }.joined(separator: ", "))
                }
                if let pc = preview.postcode {
                    previewRow("Postcode", pc)
                }
                if let phone = preview.phone {
                    previewRow("Phone", phone)
                }

                if preview.fullName == nil && preview.postcode == nil && preview.phone == nil {
                    Text("Nothing recognised — try selecting different text")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(4)
        }
    }

    private func previewRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .font(.caption)
        }
    }

    private func savePreview(_ preview: TextAddressParser.Result) async {
        let documentId = document.metadata.title

        var address = ExtractedAddress(documentId: documentId, pageNumber: 0)
        address.fullName = preview.fullName
        address.title = preview.title
        address.firstname = preview.firstName
        address.surname = preview.surname
        address.dateOfBirth = preview.dateOfBirth
        address.addressLine1 = preview.addressLine1
        address.addressLine2 = preview.addressLine2
        address.city = preview.city
        address.postcode = preview.postcode
        address.phoneHome = preview.phone
        address.addressType = previewType

        if previewType == "gp" {
            address.gpName = preview.fullName
            address.gpPostcode = preview.postcode
            address.fullName = nil
        }

        do {
            try await repository.saveOverride(
                documentId: documentId,
                pageNumber: 0,
                matchAddressType: previewType,
                updatedAddress: address,
                reason: "manual"
            )
            parsedPreview = nil
            onAddressExtracted?()
        } catch {
            print("Failed to save extracted address: \(error)")
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

// MARK: - Selectable Text View (NSTextView wrapper)

struct SelectableTextView: NSViewRepresentable {
    let text: String
    let searchText: String
    @Binding var selectedText: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.verticalScrollElasticity = .none
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        let storage = textView.textStorage!
        let coordinator = context.coordinator

        coordinator.isUpdatingStorage = true
        defer { coordinator.isUpdatingStorage = false }

        // Only update text content if it changed
        if storage.string != text {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.textColor
            ]
            storage.setAttributedString(NSAttributedString(string: text, attributes: attrs))
        }

        // Apply search highlighting
        storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
        if !searchText.isEmpty {
            let lowered = text.lowercased()
            let searchLowered = searchText.lowercased()
            var searchStart = lowered.startIndex
            while let range = lowered[searchStart...].range(of: searchLowered) {
                let nsRange = NSRange(range, in: text)
                storage.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.3), range: nsRange)
                searchStart = range.upperBound
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedText: $selectedText)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var selectedText: String
        var isUpdatingStorage = false

        init(selectedText: Binding<String>) {
            _selectedText = selectedText
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdatingStorage else { return }
            guard let textView = notification.object as? NSTextView else { return }
            let ranges = textView.selectedRanges
            guard let range = ranges.first?.rangeValue, range.length > 0 else {
                selectedText = ""
                return
            }
            selectedText = (textView.string as NSString).substring(with: range)
        }
    }
}

// MARK: - Text Address Parser

struct TextAddressParser {
    struct Result {
        var fullName: String?
        var title: String?
        var firstName: String?
        var surname: String?
        var dateOfBirth: String?
        var addressLine1: String?
        var addressLine2: String?
        var city: String?
        var postcode: String?
        var phone: String?
    }

    static func parse(_ text: String) -> Result {
        var result = Result()

        // 1. Find person names via NLTagger (NER)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var nameSpans: [(name: String, range: Range<String.Index>)] = []
        var currentName = ""
        var spanStart: String.Index?
        var spanEnd: String.Index?

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if tag == .personalName {
                if spanStart == nil { spanStart = range.lowerBound }
                spanEnd = range.upperBound
                if !currentName.isEmpty { currentName += " " }
                currentName += text[range].trimmingCharacters(in: .whitespaces)
            } else if spanStart != nil {
                nameSpans.append((currentName, spanStart!..<spanEnd!))
                currentName = ""
                spanStart = nil
                spanEnd = nil
            }
            return true
        }
        if let s = spanStart, let e = spanEnd {
            nameSpans.append((currentName, s..<e))
        }

        // Take the longest name span
        if let best = nameSpans.max(by: { $0.name.count < $1.name.count }) {
            result.fullName = best.name
        }

        // 1b. Title-prefix fallback — NLTagger struggles with OCR line breaks
        // and "Re: Mr Terence Dillon Cedar House" patterns. If we got no name
        // or only a single word, look for title + 2-3 words.
        let nameWordCount = result.fullName?.components(separatedBy: " ").count ?? 0
        if nameWordCount < 2 {
            // Flatten line breaks for matching — OCR often splits mid-name
            let flat = text.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            // Greedy: take title + up to 5 capitalised words. Better to over-match
            // (user deletes "Cedar House") than under-match (user has to type the name).
            // Stops at comma, digits, or known labels.
            let titleNamePattern = #"(?:^|[\s,:])(Mr|Mrs|Ms|Miss|Dr|Prof)\.?\s+((?:[A-Z][a-zA-Z'\-]+\s+){1,4}[A-Z][a-zA-Z'\-]+)"#
            if let regex = try? NSRegularExpression(pattern: titleNamePattern),
               let match = regex.firstMatch(in: flat, range: NSRange(flat.startIndex..., in: flat)),
               let titleRange = Range(match.range(at: 1), in: flat),
               let nameRange = Range(match.range(at: 2), in: flat) {
                let titleStr = String(flat[titleRange])
                let nameStr = String(flat[nameRange])
                result.fullName = "\(titleStr) \(nameStr)"
            }
        }

        // 2. Find addresses, phones, dates via NSDataDetector
        let detectorTypes: NSTextCheckingResult.CheckingType = [.address, .phoneNumber, .date]
        if let detector = try? NSDataDetector(types: detectorTypes.rawValue) {
            let nsText = text as NSString
            let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                switch match.resultType {
                case .address:
                    if let components = match.addressComponents {
                        if result.addressLine1 == nil {
                            result.addressLine1 = components[.street]
                        }
                        if result.city == nil {
                            result.city = components[.city]
                        }
                        if result.postcode == nil {
                            result.postcode = components[.zip]?.uppercased()
                        }
                    }
                case .phoneNumber:
                    if result.phone == nil {
                        result.phone = match.phoneNumber
                    }
                case .date:
                    if result.dateOfBirth == nil {
                        let matchedText = nsText.substring(with: match.range)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        result.dateOfBirth = matchedText
                    }
                default:
                    break
                }
            }
        }

        // 3. Label-based fallbacks for structured/form text
        // NLTagger and NSDataDetector struggle with "Name: James Barr" style labels.
        let labelPatterns: [(field: String, patterns: [String])] = [
            ("name", [
                #"(?:Name|Patient|Patient Name|Full Name)[:\s]+(.+)"#,
            ]),
            ("dob", [
                #"(?:DOB|D\.O\.B\.?|Date of Birth|Born|Date of birth)[:\s]+(.+)"#,
            ]),
            ("address", [
                #"(?:Address|Addr|Add)[:\s]+(.+)"#,
            ]),
        ]
        for (field, patterns) in labelPatterns {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                      let range = Range(match.range(at: 1), in: text) else { continue }
                let value = String(text[range]).trimmingCharacters(in: .whitespaces)
                if value.isEmpty { continue }

                switch field {
                case "name":
                    if result.fullName == nil { result.fullName = value }
                case "dob":
                    if result.dateOfBirth == nil { result.dateOfBirth = value }
                case "address":
                    if result.addressLine1 == nil {
                        let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                        let postcodePattern = #"[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}"#

                        // Extract postcode first
                        if result.postcode == nil,
                           let pcMatch = cleaned.range(of: postcodePattern, options: .regularExpression) {
                            result.postcode = String(cleaned[pcMatch]).uppercased()
                        }

                        // Remove postcode from the address text
                        var addrText = cleaned
                        if let pc = result.postcode {
                            addrText = addrText.replacingOccurrences(of: pc, with: "")
                                .trimmingCharacters(in: .whitespaces)
                                .trimmingCharacters(in: CharacterSet(charactersIn: ",."))
                        }

                        // Split by comma if present, otherwise treat as single line
                        let parts = addrText.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }

                        if !parts.isEmpty { result.addressLine1 = parts[0] }
                        if parts.count > 1 { result.addressLine2 = parts[1] }
                        if parts.count > 2 && result.city == nil { result.city = parts.last }
                    }
                default:
                    break
                }
                break // found a match for this field, move to next
            }
        }

        // 4. Postcode fallback — NSDataDetector sometimes misses UK postcodes
        if result.postcode == nil {
            let postcodePattern = #"[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}"#
            if let match = text.range(of: postcodePattern, options: .regularExpression) {
                result.postcode = String(text[match]).uppercased()
            }
        }

        // 4. Address line fallback — if NSDataDetector didn't parse street lines,
        // walk backwards from postcode to find them
        if result.addressLine1 == nil, let pc = result.postcode {
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let pcLineIdx = lines.lastIndex { $0.localizedCaseInsensitiveContains(String(pc.prefix(4))) }
            if let pcIdx = pcLineIdx {
                let skipTerms = [result.fullName, result.phone, result.dateOfBirth].compactMap { $0 }
                var addressLines: [String] = []
                for i in stride(from: pcIdx - 1, through: max(0, pcIdx - 4), by: -1) {
                    let line = lines[i]
                    if skipTerms.contains(where: { line.localizedCaseInsensitiveContains($0) }) { continue }
                    addressLines.insert(line, at: 0)
                }
                if !addressLines.isEmpty { result.addressLine1 = addressLines[0] }
                if addressLines.count > 1 { result.addressLine2 = addressLines[1] }
                if addressLines.count > 2 && result.city == nil { result.city = addressLines[2] }
            }
        }

        // 5. Split name into title/first/surname
        if let name = result.fullName {
            let knownTitles = ["Mr", "Mrs", "Ms", "Miss", "Dr", "Prof"]
            for t in knownTitles where name.hasPrefix(t + ".") || name.hasPrefix(t + " ") {
                result.title = t
                let afterTitle = String(name.dropFirst(t.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                let parts = afterTitle.components(separatedBy: " ").filter { !$0.isEmpty }
                if parts.count >= 2 {
                    result.firstName = parts.dropLast().joined(separator: " ")
                    result.surname = parts.last
                } else if parts.count == 1 {
                    result.surname = parts[0]
                }
                break
            }
            // No title — still split first/surname
            if result.title == nil {
                let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
                if parts.count >= 2 {
                    result.firstName = parts.dropLast().joined(separator: " ")
                    result.surname = parts.last
                }
            }
        }

        return result
    }
}

#endif
