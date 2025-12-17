//
//  BulkExportView.swift
//  Yiana
//
//  Bulk export view for macOS - select documents/folders and export as PDFs

#if os(macOS)
import SwiftUI
import AppKit

/// Represents a selectable item in the export picker
struct ExportItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let isFolder: Bool
    let relativePath: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExportItem, rhs: ExportItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Main bulk export view with picker and progress
struct BulkExportView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: DocumentRepository

    @State private var currentPath: String = ""
    @State private var items: [ExportItem] = []
    @State private var selectedItems: Set<String> = []
    @State private var isExporting = false
    @State private var exportResult: ExportService.BulkExportResult?
    @State private var exportProgress: (current: Int, total: Int, fileName: String) = (0, 0, "")

    var body: some View {
        VStack(spacing: 0) {
            if isExporting {
                exportProgressView
            } else if let result = exportResult {
                exportResultView(result)
            } else {
                pickerView
            }
        }
        .frame(width: 500, height: 450)
        .onAppear {
            loadItems()
        }
    }

    // MARK: - Picker View

    private var pickerView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Export Documents as PDFs")
                    .font(.headline)
                Text("Select folders or individual documents to export. Folder structure will be preserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // Breadcrumb navigation
            breadcrumbBar

            Divider()

            // Item list
            List(selection: Binding<Set<String>?>(
                get: { nil },
                set: { _ in }
            )) {
                ForEach(items) { item in
                    itemRow(item)
                }
            }
            .listStyle(.plain)

            Divider()

            // Footer with selection summary and buttons
            footerView
        }
    }

    private var breadcrumbBar: some View {
        HStack {
            Button(action: navigateToRoot) {
                Image(systemName: "house")
            }
            .buttonStyle(.borderless)
            .disabled(currentPath.isEmpty)

            if !currentPath.isEmpty {
                let components = currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
                ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(component) {
                        let newPath = components.prefix(index + 1).joined(separator: "/")
                        navigateToPath(newPath)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Spacer()

            // Select all / Deselect all
            Button("Select All") {
                for item in items {
                    selectedItems.insert(item.id)
                }
            }
            .buttonStyle(.borderless)

            Button("Deselect All") {
                selectedItems.removeAll()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func itemRow(_ item: ExportItem) -> some View {
        HStack {
            // Checkbox
            Image(systemName: selectedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                .foregroundColor(selectedItems.contains(item.id) ? .accentColor : .secondary)
                .onTapGesture {
                    toggleSelection(item)
                }

            // Icon
            Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                .foregroundColor(item.isFolder ? .accentColor : .secondary)

            // Name
            Text(item.name)
                .lineLimit(1)

            Spacer()

            // Navigate into folder
            if item.isFolder {
                Button(action: { navigateIntoFolder(item) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(item)
        }
    }

    private var footerView: some View {
        HStack {
            // Selection summary
            Text(selectionSummary)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Export...") {
                startExport()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedItems.isEmpty)
        }
        .padding()
    }

    private var selectionSummary: String {
        if selectedItems.isEmpty {
            return "No items selected"
        }

        let selectedFolders = items.filter { $0.isFolder && selectedItems.contains($0.id) }
        let selectedDocs = items.filter { !$0.isFolder && selectedItems.contains($0.id) }

        var parts: [String] = []
        if !selectedFolders.isEmpty {
            parts.append("\(selectedFolders.count) folder\(selectedFolders.count == 1 ? "" : "s")")
        }
        if !selectedDocs.isEmpty {
            parts.append("\(selectedDocs.count) document\(selectedDocs.count == 1 ? "" : "s")")
        }

        return "Selected: " + parts.joined(separator: ", ")
    }

    // MARK: - Progress View

    private var exportProgressView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Exporting...")
                .font(.headline)

            if exportProgress.total > 0 {
                Text("\(exportProgress.current) of \(exportProgress.total)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !exportProgress.fileName.isEmpty {
                    Text(exportProgress.fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                ProgressView(value: Double(exportProgress.current), total: Double(exportProgress.total))
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result View

    private func exportResultView(_ result: ExportService.BulkExportResult) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: result.failedItems.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(result.failedItems.isEmpty ? .green : .orange)

            Text("Export Complete")
                .font(.headline)

            Text("\(result.successfulCount) document\(result.successfulCount == 1 ? "" : "s") exported successfully")
                .foregroundColor(.secondary)

            if !result.failedItems.isEmpty {
                Text("\(result.failedItems.count) failed")
                    .foregroundColor(.red)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.failedItems.prefix(10), id: \.fileName) { item in
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text(item.fileName)
                                    .font(.caption)
                            }
                        }
                        if result.failedItems.count > 10 {
                            Text("...and \(result.failedItems.count - 10) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 100)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()

            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: result.destinationFolder.path)
                }

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func loadItems() {
        items = []

        let baseURL = currentPath.isEmpty
            ? repository.documentsDirectory
            : repository.documentsDirectory.appendingPathComponent(currentPath)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in contents.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }) {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                // It's a folder (but not a .yianazip which is also a "directory")
                if url.pathExtension != "yianazip" {
                    let relativePath = currentPath.isEmpty ? url.lastPathComponent : "\(currentPath)/\(url.lastPathComponent)"
                    items.append(ExportItem(
                        id: "folder:\(relativePath)",
                        url: url,
                        name: url.lastPathComponent,
                        isFolder: true,
                        relativePath: relativePath
                    ))
                }
            }

            if url.pathExtension == "yianazip" {
                let relativePath = currentPath
                items.append(ExportItem(
                    id: "doc:\(url.path)",
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    isFolder: false,
                    relativePath: relativePath
                ))
            }
        }
    }

    private func toggleSelection(_ item: ExportItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func navigateToRoot() {
        currentPath = ""
        loadItems()
    }

    private func navigateToPath(_ path: String) {
        currentPath = path
        loadItems()
    }

    private func navigateIntoFolder(_ item: ExportItem) {
        guard item.isFolder else { return }
        currentPath = item.relativePath
        loadItems()
    }

    private func startExport() {
        // Show folder picker
        let panel = NSOpenPanel()
        panel.title = "Choose Export Destination"
        panel.message = "Select a folder where PDFs will be exported"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        // Gather all documents to export
        let documentsToExport = gatherDocumentsToExport()

        guard !documentsToExport.isEmpty else {
            return
        }

        // Start export
        isExporting = true
        exportProgress = (0, documentsToExport.count, "")

        Task.detached { [documentsToExport, destinationURL] in
            let exportService = ExportService()
            let result = exportService.exportWithStructure(
                documents: documentsToExport,
                to: destinationURL
            ) { current, total, fileName in
                Task { @MainActor in
                    exportProgress = (current, total, fileName)
                }
            }

            await MainActor.run {
                isExporting = false
                exportResult = result
            }
        }
    }

    private func gatherDocumentsToExport() -> [(url: URL, relativePath: String)] {
        var result: [(url: URL, relativePath: String)] = []
        var addedPaths = Set<String>()

        for itemId in selectedItems {
            guard let item = items.first(where: { $0.id == itemId }) else {
                continue
            }

            if item.isFolder {
                // Recursively get all documents in this folder
                let folderDocs = getDocumentsInFolder(at: item.url, relativePath: item.relativePath)
                for doc in folderDocs {
                    if !addedPaths.contains(doc.url.path) {
                        result.append(doc)
                        addedPaths.insert(doc.url.path)
                    }
                }
            } else {
                // Single document
                if !addedPaths.contains(item.url.path) {
                    result.append((url: item.url, relativePath: item.relativePath))
                    addedPaths.insert(item.url.path)
                }
            }
        }

        return result
    }

    private func getDocumentsInFolder(at folderURL: URL, relativePath: String) -> [(url: URL, relativePath: String)] {
        var results: [(url: URL, relativePath: String)] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return results
        }

        for url in contents {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if url.pathExtension == "yianazip" {
                results.append((url: url, relativePath: relativePath))
            } else if isDirectory.boolValue {
                // Recurse into subdirectory
                let subPath = relativePath.isEmpty ? url.lastPathComponent : "\(relativePath)/\(url.lastPathComponent)"
                results.append(contentsOf: getDocumentsInFolder(at: url, relativePath: subPath))
            }
        }

        return results
    }
}

#Preview {
    BulkExportView(repository: DocumentRepository())
}
#endif
