import SwiftUI

/// Collapsible work list section for the sidebar.
/// macOS: rendered as a `Section` inside the sidebar `List`.
/// iPad: rendered as a `DisclosureGroup` inside the `ScrollView + LazyVStack`.
struct WorkListPanelView: View {
    @Bindable var viewModel: WorkListViewModel
    /// Navigate directly to a document URL.
    var onNavigate: (URL) -> Void

    @State private var addSurname = ""
    @State private var addFirstName = ""
    @State private var pasteText = ""
    @State private var showingPasteSheet = false
    @State private var pickerItem: WorkListItem?
    @State private var pickerURLs: [URL] = []
    @State private var selectedMRN: String?

    var body: some View {
        Group {
            #if os(macOS)
            macOSContent
            #else
            iPadContent
            #endif
        }
        .sheet(item: $pickerItem) { item in
            pickerSheet(for: item)
        }
    }

    // MARK: - macOS (Section inside List)

    #if os(macOS)
    private var macOSContent: some View {
        Section(isExpanded: $viewModel.isExpanded) {
            if viewModel.items.isEmpty {
                Text("No patients")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.items) { item in
                    workListRow(item)
                        .selectionDisabled()
                        .listRowBackground(
                            selectedMRN == item.mrn
                                ? RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.2))
                                : nil
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.remove(mrn: item.mrn)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }

            addButton
        } header: {
            HStack {
                Text("Work List")
                if !viewModel.items.isEmpty {
                    Text("(\(viewModel.items.count))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !viewModel.items.isEmpty {
                    clearButton
                }
                pasteButton
            }
        }
        .confirmationDialog(
            "Clear all patients from the work list?",
            isPresented: $viewModel.showingClearConfirmation
        ) {
            Button("Clear All", role: .destructive) {
                viewModel.clearAll()
            }
        }
    }
    #endif

    // MARK: - iPad (DisclosureGroup inside ScrollView)

    #if os(iOS)
    private var iPadContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.top, 8)

            DisclosureGroup(isExpanded: $viewModel.isExpanded) {
                if viewModel.items.isEmpty {
                    Text("No patients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.items) { item in
                        workListRow(item)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.remove(mrn: item.mrn)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        Divider()
                            .padding(.leading, 16)
                    }
                }

                addButton
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } label: {
                HStack {
                    Text("Work List")
                        .font(.headline)
                    if !viewModel.items.isEmpty {
                        Text("(\(viewModel.items.count))")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !viewModel.items.isEmpty {
                        clearButton
                    }
                    pasteButton
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .confirmationDialog(
            "Clear all patients from the work list?",
            isPresented: $viewModel.showingClearConfirmation
        ) {
            Button("Clear All", role: .destructive) {
                viewModel.clearAll()
            }
        }
        .sheet(isPresented: $showingPasteSheet) {
            pasteSheet
        }
    }
    #endif

    // MARK: - Shared

    private func workListRow(_ item: WorkListItem) -> some View {
        let matchCount = viewModel.resolvedURLs[item.mrn]?.count ?? 0

        return Button {
            handleTap(item)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.surname), \(item.firstName)")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if let detail = rowDetail(for: item) {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if matchCount == 0 {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if matchCount > 1 && viewModel.resolvedURL(for: item) == nil {
                    Text("\(matchCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.secondary.opacity(0.2)))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func handleTap(_ item: WorkListItem) {
        let url = viewModel.resolvedURL(for: item)
        if let url {
            selectedMRN = item.mrn
            onNavigate(url)
        } else {
            let urls = viewModel.resolvedURLs[item.mrn] ?? []
            if urls.count > 1 {
                pickerURLs = urls
                pickerItem = item
            }
            // If 0 matches, do nothing — the ? icon indicates no document
        }
    }

    private func rowDetail(for item: WorkListItem) -> String? {
        var parts: [String] = []
        if let doctor = item.doctor {
            parts.append(doctor)
        } else {
            if let age = item.age, let gender = item.gender {
                parts.append("\(gender), \(age)")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    // MARK: - Picker

    private func pickerSheet(for item: WorkListItem) -> some View {
        NavigationStack {
            List(pickerURLs, id: \.self) { url in
                Button {
                    viewModel.saveChoice(mrn: item.mrn, url: url)
                    pickerItem = nil
                    onNavigate(url)
                } label: {
                    Text(url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " "))
                }
            }
            .navigationTitle("Choose Document")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pickerItem = nil }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pickerItem = nil }
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 300, minHeight: 200)
        #endif
    }

    // MARK: - Add / Paste / Clear

    private var addButton: some View {
        VStack(spacing: 4) {
            if viewModel.showingAddForm {
                addForm
            } else {
                Button {
                    viewModel.showingAddForm = true
                } label: {
                    Label("Add Patient", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addForm: some View {
        VStack(spacing: 6) {
            TextField("Surname", text: $addSurname)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            TextField("First name", text: $addFirstName)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            HStack {
                Button("Cancel") {
                    addSurname = ""
                    addFirstName = ""
                    viewModel.showingAddForm = false
                }
                .font(.caption)
                Spacer()
                Button("Add") {
                    viewModel.add(surname: addSurname, firstName: addFirstName)
                    addSurname = ""
                    addFirstName = ""
                    viewModel.showingAddForm = false
                }
                .font(.caption)
                .disabled(addSurname.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private var clearButton: some View {
        Button {
            viewModel.showingClearConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Clear all patients")
    }

    private var pasteButton: some View {
        Button {
            #if os(macOS)
            if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
                viewModel.importClinicList(string)
            }
            #else
            showingPasteSheet = true
            #endif
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Import work list from clipboard")
    }

    #if os(iOS)
    private var pasteSheet: some View {
        NavigationStack {
            VStack {
                Text("Paste a work list below:")
                    .font(.subheadline)
                    .padding(.top)
                TextEditor(text: $pasteText)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                    .padding(.horizontal)
            }
            .navigationTitle("Import Work List")
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
                        viewModel.importClinicList(pasteText)
                        pasteText = ""
                        showingPasteSheet = false
                    }
                    .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    #endif
}
