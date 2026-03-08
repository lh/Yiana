//
//  WorkListView.swift
//  Yiana
//

import SwiftUI

/// Data for the multi-match picker sheet. Using `.sheet(item:)` so the
/// URLs are available on first render (avoids empty-sheet-on-first-open bug).
private struct PickerData: Identifiable {
    let id = UUID()
    let entryID: UUID
    let urls: [URL]
}

/// Sidebar work list view. Uses ScrollView + LazyVStack (not List).
/// Click handling: resolved entries navigate directly, unresolved entries search and resolve.
struct WorkListView: View {
    @ObservedObject var viewModel: WorkListViewModel
    var onNavigate: (URL) -> Void

    @State private var manualSearchText = ""
    @State private var showingClearConfirmation = false
    @State private var pickerData: PickerData?
    @State private var showingPasteSheet = false
    @State private var pasteText = ""

    var body: some View {
        VStack(spacing: 0) {
            addControls

            if viewModel.entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 400)
        #endif
        .sheet(item: $pickerData) { data in
            pickerSheet(data: data)
        }
        #if os(iOS)
        .sheet(isPresented: $showingPasteSheet) {
            pasteSheet
        }
        #endif
        .confirmationDialog("Clear Work List", isPresented: $showingClearConfirmation) {
            Button("Clear All", role: .destructive) {
                Task { await viewModel.clearAll() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove all \(viewModel.entryCount) entries?")
        }
    }

    // MARK: - Add Controls

    private var addControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                TextField("Search text...", text: $manualSearchText)
                    .textFieldStyle(.roundedBorder)
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .onSubmit { addManualEntry() }

                Button("Add") { addManualEntry() }
                    .disabled(manualSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
            }

            HStack(spacing: 6) {
                #if os(macOS)
                Button("Paste List") { pasteFromClipboard() }
                    .controlSize(.small)
                #else
                Button("Paste List") { showingPasteSheet = true }
                #endif

                Spacer()

                if !viewModel.entries.isEmpty {
                    Button("Clear") { showingClearConfirmation = true }
                        .foregroundColor(.red)
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Entry List

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.entries) { entry in
                    entryRow(entry)
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    private func entryRow(_ entry: WorkListEntry) -> some View {
        Button {
            handleTap(entry)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayText)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    if entry.resolvedFilename == nil, let source = sourceLabel(entry) {
                        Text(source)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                statusIndicator(entry)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.remove(entryID: entry.id) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(_ entry: WorkListEntry) -> some View {
        if entry.resolvedFilename != nil {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        } else if let count = viewModel.matchCounts[entry.id] {
            if count == 0 {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    .foregroundColor(.accentColor)
            }
        }
    }

    private func sourceLabel(_ entry: WorkListEntry) -> String? {
        switch entry.source {
        case .yiale: return "From Yiale"
        case .manual: return nil
        case .document: return nil
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.clipboard")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No entries")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Add names to quickly open documents during a session.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tap Handling

    private func handleTap(_ entry: WorkListEntry) {
        let entryID = entry.id
        if entry.resolvedFilename != nil {
            // Resolved — look up URL and navigate
            Task {
                if let url = await viewModel.urlForResolved(entry) {
                    await MainActor.run { onNavigate(url) }
                } else {
                    // Stale resolution — re-search
                    let urls = await viewModel.resolve(entryID: entryID)
                    await MainActor.run { handleResolveResult(urls, entryID: entryID) }
                }
            }
        } else {
            // Unresolved — search
            Task {
                let urls = await viewModel.resolve(entryID: entryID)
                await MainActor.run { handleResolveResult(urls, entryID: entryID) }
            }
        }
    }

    private func handleResolveResult(_ urls: [URL], entryID: UUID) {
        if urls.count == 1 {
            onNavigate(urls[0])
        } else if urls.count > 1 {
            pickerData = PickerData(entryID: entryID, urls: urls)
        }
        // 0 matches: do nothing (status indicator shows ?)
    }

    // MARK: - Picker Sheet

    private func pickerSheet(data: PickerData) -> some View {
        NavigationStack {
            List(data.urls, id: \.self) { url in
                Button {
                    let entryID = data.entryID
                    pickerData = nil
                    Task {
                        await viewModel.resolveToURL(entryID: entryID, url: url)
                        await MainActor.run { onNavigate(url) }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(url.deletingPathExtension().lastPathComponent
                            .replacingOccurrences(of: "_", with: " "))
                            .foregroundColor(.primary)
                        Text(url.deletingLastPathComponent().lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Multiple Matches")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pickerData = nil }
                }
            }
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pickerData = nil }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 300, minHeight: 200)
        #endif
    }

    // MARK: - Manual Add

    private func addManualEntry() {
        let text = manualSearchText
        manualSearchText = ""
        Task { await viewModel.addManual(searchText: text) }
    }

    // MARK: - Paste Import

    #if os(macOS)
    private func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        Task { await viewModel.importClinicList(string) }
    }
    #endif

    #if os(iOS)
    private var pasteSheet: some View {
        NavigationStack {
            VStack {
                Text("Paste a clinic list below:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)

                TextEditor(text: $pasteText)
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.3))
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Import Clinic List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pasteText = ""
                        showingPasteSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        let text = pasteText
                        pasteText = ""
                        showingPasteSheet = false
                        Task { await viewModel.importClinicList(text) }
                    }
                    .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    #endif
}
