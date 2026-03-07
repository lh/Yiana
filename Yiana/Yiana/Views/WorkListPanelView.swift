import SwiftUI

/// Collapsible work list section for the sidebar.
/// macOS: rendered as a `Section` inside the sidebar `List`.
/// iPad: rendered as a `DisclosureGroup` inside the `ScrollView + LazyVStack`.
struct WorkListPanelView: View {
    @Bindable var viewModel: WorkListViewModel
    var onSelectPatient: (WorkListItem) -> Void

    @State private var addSurname = ""
    @State private var addFirstName = ""
    @State private var pasteText = ""
    @State private var showingPasteSheet = false

    var body: some View {
        #if os(macOS)
        macOSContent
        #else
        iPadContent
        #endif
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
                Text("Clinic List")
                if !viewModel.items.isEmpty {
                    Text("(\(viewModel.items.count))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                pasteButton
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
                    Text("Clinic List")
                        .font(.headline)
                    if !viewModel.items.isEmpty {
                        Text("(\(viewModel.items.count))")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    pasteButton
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showingPasteSheet) {
            pasteSheet
        }
    }
    #endif

    // MARK: - Shared

    private func workListRow(_ item: WorkListItem) -> some View {
        Button {
            onSelectPatient(item)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.surname), \(item.firstName)")
                    .lineLimit(1)

                if let detail = rowDetail(for: item) {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
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
        .help("Import clinic list from clipboard")
    }

    #if os(iOS)
    private var pasteSheet: some View {
        NavigationStack {
            VStack {
                Text("Paste a clinic list below:")
                    .font(.subheadline)
                    .padding(.top)
                TextEditor(text: $pasteText)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                    .padding(.horizontal)
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
