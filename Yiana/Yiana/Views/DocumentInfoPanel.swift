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
                                Button("Patient") { Task { await extractAddressFromSelection(type: "patient") } }
                                Button("GP") { Task { await extractAddressFromSelection(type: "gp") } }
                                Button("Optician") { Task { await extractAddressFromSelection(type: "optician") } }
                                Button("Other") { Task { await extractAddressFromSelection(type: "specialist") } }
                            } label: {
                                Label("Address it!", systemImage: "mappin.and.ellipse")
                            }
                            .menuStyle(.borderedButton)
                            .disabled(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func extractAddressFromSelection(type: String) async {
        let parsed = TextAddressParser.parse(selectedText)
        let documentId = document.metadata.title

        // Build a pre-filled address and save as manual override
        var address = ExtractedAddress(documentId: documentId, pageNumber: 0)
        address.fullName = parsed.fullName
        address.title = parsed.title
        address.firstname = parsed.firstName
        address.surname = parsed.surname
        address.dateOfBirth = parsed.dateOfBirth
        address.addressLine1 = parsed.addressLine1
        address.addressLine2 = parsed.addressLine2
        address.city = parsed.city
        address.postcode = parsed.postcode
        address.phoneHome = parsed.phone
        address.addressType = type

        // For GP type, put the name in gpName instead of fullName
        if type == "gp" {
            address.gpName = parsed.fullName
            address.gpPostcode = parsed.postcode
            address.fullName = nil
        }

        do {
            try await repository.saveOverride(
                documentId: documentId,
                pageNumber: 0,
                matchAddressType: type,
                updatedAddress: address,
                reason: "manual"
            )
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

        init(selectedText: Binding<String>) {
            _selectedText = selectedText
        }

        func textViewDidChangeSelection(_ notification: Notification) {
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

    private static let postcodePattern = #"[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}"#
    private static let phonePattern = #"\b(0\d{3,4}\s?\d{5,7}|07\d{3}\s?\d{6})\b"#
    private static let dobPatterns = [
        // With label: DOB, D.O.B, Date of Birth, Born
        #"(?:DOB|D\.O\.B\.?|Date of Birth|Born)[:\s]+(\d{1,2}[/\.\-]\d{1,2}[/\.\-]\d{2,4})"#,
        #"(?:DOB|D\.O\.B\.?|Date of Birth|Born)[:\s]+(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{2,4})"#,
        // Standalone: DD/MM/YYYY, DD-MM-YY, DD.MM.YYYY
        #"\b(\d{1,2}[/\.\-]\d{1,2}[/\.\-]\d{2,4})\b"#,
        // Standalone: 16 July 1939, 16 Jul 39
        #"\b(\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{2,4})\b"#,
    ]

    static func parse(_ text: String) -> Result {
        var result = Result()
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Step 1: Find postcode (anchor)
        if let match = text.range(of: postcodePattern, options: .regularExpression) {
            result.postcode = String(text[match]).uppercased()
        }

        // Step 2: Find DOB
        for pattern in dobPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                result.dateOfBirth = String(text[range])
                break
            }
        }

        // Step 3: Find phone
        if let regex = try? NSRegularExpression(pattern: phonePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            result.phone = String(text[range])
        }

        // Step 4: Walk backwards from postcode to find address lines.
        // Classify each line as: postcode, DOB, phone, or "content".
        // Content lines between the first content line and the postcode are address.
        // Content lines before the address block are name candidates.
        guard result.postcode != nil else { return result }

        let pcLineIdx = lines.lastIndex {
            $0.range(of: postcodePattern, options: .regularExpression) != nil
        }
        guard let pcIdx = pcLineIdx else { return result }

        // Classify lines by what they contain
        var lineRoles: [String] = Array(repeating: "content", count: lines.count)
        for (i, line) in lines.enumerated() {
            if line.range(of: postcodePattern, options: .regularExpression) != nil {
                lineRoles[i] = "postcode"
            } else if line.range(of: phonePattern, options: .regularExpression) != nil {
                lineRoles[i] = "phone"
            } else {
                for pattern in dobPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                       regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                        lineRoles[i] = "dob"
                        break
                    }
                }
            }
        }

        // Walk backwards from postcode, collecting address lines (content only)
        var addressLines: [String] = []
        for i in stride(from: pcIdx - 1, through: 0, by: -1) {
            if lineRoles[i] != "content" { continue }
            // Stop collecting address if we've got enough (max 4 lines)
            if addressLines.count >= 4 { break }
            addressLines.insert(lines[i], at: 0)
        }

        // The postcode line itself may have a city/town before the postcode
        let pcLineText = lines[pcIdx]
        if let pcRange = pcLineText.range(of: postcodePattern, options: .regularExpression) {
            let beforePC = pcLineText[pcLineText.startIndex..<pcRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            if !beforePC.isEmpty {
                addressLines.append(beforePC)
            }
        }

        // Step 5: Separate name from address.
        // If the first address line contains a title (Mr/Mrs/etc), split it there.
        // The title+name part becomes the name, the rest stays as address.
        let titles = ["Mr", "Mrs", "Ms", "Miss", "Dr", "Prof"]
        let titlePattern = #"^((?:Mr|Mrs|Ms|Miss|Dr|Prof)\.?\s+[A-Za-z'\-]+(?:\s+[A-Za-z'\-]+)?)"#

        if let firstLine = addressLines.first,
           let regex = try? NSRegularExpression(pattern: titlePattern),
           let match = regex.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)),
           let nameRange = Range(match.range(at: 1), in: firstLine) {
            // Found title+name at start of first address line
            let namePart = String(firstLine[nameRange])
            let remainder = String(firstLine[nameRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: ","))

            result.fullName = namePart
            // Replace first address line with remainder (if any)
            if remainder.isEmpty {
                addressLines.removeFirst()
            } else {
                addressLines[0] = remainder
            }
        } else {
            // No title found in address lines — check all content lines before postcode
            // that aren't already classified. The first content line might be a name.
            for i in 0..<(pcIdx) {
                if lineRoles[i] == "content" {
                    let line = lines[i]
                    // Check if this line has a title
                    if titles.contains(where: { line.hasPrefix($0) }) {
                        if let regex = try? NSRegularExpression(pattern: titlePattern),
                           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                           let nameRange = Range(match.range(at: 1), in: line) {
                            result.fullName = String(line[nameRange])
                            let remainder = String(line[nameRange.upperBound...])
                                .trimmingCharacters(in: .whitespaces)
                                .trimmingCharacters(in: CharacterSet(charactersIn: ","))
                            if !remainder.isEmpty {
                                addressLines.insert(remainder, at: 0)
                            }
                            // Remove this line from address if it was there
                            addressLines.removeAll { $0 == line }
                        }
                    }
                    break
                }
            }
        }

        // Split name into title/first/surname
        if let name = result.fullName {
            for t in titles where name.hasPrefix(t + ".") || name.hasPrefix(t + " ") {
                result.title = t
                let afterTitle = name.dropFirst(t.count)
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
        }

        // Assign address fields
        if !addressLines.isEmpty { result.addressLine1 = addressLines[0] }
        if addressLines.count > 1 { result.addressLine2 = addressLines[1] }
        if addressLines.count > 2 { result.city = addressLines[2] }

        return result
    }
}

#endif
