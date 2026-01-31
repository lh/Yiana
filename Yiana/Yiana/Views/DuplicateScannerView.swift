//
//  DuplicateScannerView.swift
//  Yiana
//
//  View for scanning and cleaning up duplicate documents
//

#if os(macOS)
import SwiftUI

struct DuplicateScannerView: View {
    @Binding var isPresented: Bool
    @StateObject private var scanner = DuplicateScanner()
    @State private var selectedDuplicates: Set<DuplicateDocument> = []
    @State private var showingDeleteConfirmation = false
    @State private var deleteResult: (deleted: Int, failed: Int)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Find Duplicate Documents")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Scan your library for documents with identical content")
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            if scanner.isScanning {
                scanningView
            } else if scanner.duplicateGroups.isEmpty {
                if deleteResult != nil {
                    resultsView
                } else {
                    emptyView
                }
            } else {
                duplicateListView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 700, height: 550)
        .alert("Delete Duplicates", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(selectedDuplicates.count) files", role: .destructive) {
                Task {
                    deleteResult = await scanner.deleteDuplicates(Array(selectedDuplicates))
                    selectedDuplicates.removeAll()
                    // Rescan after deletion
                    await scanner.scanForDuplicates()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(selectedDuplicates.count) duplicate files? This cannot be undone.")
        }
    }

    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            if let progress = scanner.progress {
                VStack(spacing: 8) {
                    Text("Scanning documents...")
                        .font(.headline)

                    ProgressView(value: progress.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 300)

                    Text("\(progress.currentIndex) of \(progress.totalFiles)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(progress.currentFile)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            if scanner.hasScanned {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("No Duplicates Found")
                    .font(.headline)

                Text("Your library is clean!")
                    .foregroundColor(.secondary)

                Button("Scan Again") {
                    Task {
                        await scanner.scanForDuplicates()
                    }
                }
            } else {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Duplicate Scanner")
                    .font(.headline)

                Text("Scan your library to find documents with identical PDF content.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: deleteResult!.failed == 0 ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(deleteResult!.failed == 0 ? .green : .orange)

            Text("Cleanup Complete")
                .font(.headline)

            VStack(spacing: 4) {
                Text("\(deleteResult!.deleted) files deleted")
                    .foregroundColor(.secondary)

                if deleteResult!.failed > 0 {
                    Text("\(deleteResult!.failed) files failed to delete")
                        .foregroundColor(.red)
                }
            }

            Button("Done") {
                isPresented = false
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var duplicateListView: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                Text("\(scanner.duplicateGroups.count) groups with \(totalDuplicateCount) duplicates")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if !selectedDuplicates.isEmpty {
                    Text("\(selectedDuplicates.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                Button("Select All Duplicates") {
                    selectAllDuplicates()
                }
                .font(.caption)

                Button("Deselect All") {
                    selectedDuplicates.removeAll()
                }
                .font(.caption)
                .disabled(selectedDuplicates.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // List of duplicate groups
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(scanner.duplicateGroups) { group in
                        DuplicateGroupView(
                            group: group,
                            selectedDuplicates: $selectedDuplicates
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Button("Close") {
                isPresented = false
            }
            .keyboardShortcut(.escape)

            Spacer()

            if !scanner.isScanning && scanner.duplicateGroups.isEmpty && deleteResult == nil {
                Button("Scan for Duplicates") {
                    Task {
                        await scanner.scanForDuplicates()
                    }
                }
                .keyboardShortcut(.return)
            }

            if !selectedDuplicates.isEmpty {
                Button("Delete Selected (\(selectedDuplicates.count))") {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var totalDuplicateCount: Int {
        scanner.duplicateGroups.reduce(0) { $0 + $1.duplicates.count }
    }

    private func selectAllDuplicates() {
        for group in scanner.duplicateGroups {
            for duplicate in group.duplicates {
                selectedDuplicates.insert(duplicate)
            }
        }
    }
}

struct DuplicateGroupView: View {
    let group: DuplicateGroup
    @Binding var selectedDuplicates: Set<DuplicateDocument>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group header
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.blue)

                Text(group.baseTitle)
                    .font(.headline)

                Text("(\(group.documents.count) copies)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Select duplicates") {
                    for duplicate in group.duplicates {
                        selectedDuplicates.insert(duplicate)
                    }
                }
                .font(.caption)
            }

            // Document list
            VStack(spacing: 4) {
                ForEach(Array(group.documents.enumerated()), id: \.element.id) { index, doc in
                    DuplicateDocumentRow(
                        document: doc,
                        isOriginal: index == 0,
                        isSelected: selectedDuplicates.contains(doc),
                        onToggle: {
                            if selectedDuplicates.contains(doc) {
                                selectedDuplicates.remove(doc)
                            } else {
                                selectedDuplicates.insert(doc)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DuplicateDocumentRow: View {
    let document: DuplicateDocument
    let isOriginal: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox (only for duplicates)
            if isOriginal {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .frame(width: 20)
            } else {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(document.title)
                        .font(.subheadline)

                    if isOriginal {
                        Text("(Original)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 8) {
                    if let date = document.createdDate {
                        Text(date, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(ByteCountFormatter.string(fromByteCount: document.fileSize, countStyle: .file))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Show in Finder button
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([document.url])
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

#endif
