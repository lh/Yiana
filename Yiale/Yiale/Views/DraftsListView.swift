import SwiftUI

struct DraftsListView: View {
    @Bindable var viewModel: DraftsViewModel
    @Bindable var workListViewModel: WorkListViewModel
    @Binding var sidebarSelection: SidebarItem?
    let onNewLetter: () -> Void
    let onShowImportSheet: () -> Void

    var body: some View {
        List(selection: $sidebarSelection) {
            if !workListViewModel.items.isEmpty {
                Section {
                    ForEach(workListViewModel.items) { item in
                        WorkListRow(item: item)
                            .tag(SidebarItem.workListPatient(item.mrn))
                    }
                    .onDelete { indexSet in
                        let mrns = indexSet.map { workListViewModel.items[$0].mrn }
                        for mrn in mrns {
                            workListViewModel.remove(mrn: mrn)
                        }
                    }
                } header: {
                    Text("Clinic List (\(workListViewModel.items.count))")
                }
            }

            Section("Drafts") {
                ForEach(viewModel.drafts) { draft in
                    DraftRow(draft: draft)
                        .tag(SidebarItem.draft(draft.letterId))
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let draft = viewModel.drafts[index]
                        Task { await viewModel.delete(letterId: draft.letterId) }
                    }
                }
            }
        }
        .navigationTitle("Yiale")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onNewLetter()
                } label: {
                    Label("New Letter", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    onShowImportSheet()
                } label: {
                    Label("Import Clinic List", systemImage: "list.clipboard")
                }
            }
            if !workListViewModel.items.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        sidebarSelection = nil
                        workListViewModel.clearAll()
                    } label: {
                        Label("Clear Clinic List", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.load()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

private struct WorkListRow: View {
    let item: WorkListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(item.surname), \(item.firstName)")
                .font(.body)
            HStack(spacing: 8) {
                Text(item.mrn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let doctor = item.doctor {
                    Text(doctor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
