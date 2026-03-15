import SwiftUI

enum SidebarItem: Hashable {
    case workListPatient(String)  // work list item id
    case draft(String)            // letterId
}

struct ContentView: View {
    @State private var draftsViewModel = DraftsViewModel()
    @State private var workListViewModel = WorkListViewModel()
    @State private var sidebarSelection: SidebarItem?
    @State private var addressService = AddressSearchService()
    @State private var composeViewModel: ComposeViewModel?
    @State private var iCloudAvailable = true
    @State private var showImportSheet = false

    var body: some View {
        NavigationSplitView {
            DraftsListView(
                viewModel: draftsViewModel,
                workListViewModel: workListViewModel,
                sidebarSelection: $sidebarSelection,
                onNewLetter: { startNewLetter() },
                onShowImportSheet: { showImportSheet = true }
            )
        } detail: {
            if !iCloudAvailable {
                iCloudUnavailableView
            } else {
                detailView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: sidebarSelection) { _, newValue in
            switch newValue {
            case .workListPatient(let itemID):
                startNewLetterForID(itemID)
            case .draft(let letterId):
                loadDraftForEditing(letterId)
            case nil:
                break
            }
        }
        .task {
            iCloudAvailable = ICloudContainer.shared.containerURL != nil
            await workListViewModel.load()
            let service = addressService
            try? await Task.detached {
                try service.loadAll()
            }.value
        }
        .sheet(isPresented: $showImportSheet) {
            ClinicListImportSheet(
                onImport: { text in workListViewModel.importClinicList(text) },
                onReplace: { text in workListViewModel.replaceClinicList(text) },
                existingCount: workListViewModel.items.count
            )
        }
    }

    private var iCloudUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("iCloud Drive is not available")
                .font(.title2)
            Text("Yiale requires iCloud Drive to access patient data and store letter drafts.\nSign in to iCloud in System Settings and enable iCloud Drive.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detailView: some View {
        switch sidebarSelection {
        case .workListPatient:
            if let vm = composeViewModel, vm.selectedPatient != nil {
                ComposeView(viewModel: vm)
            } else {
                PatientSearchView(
                    addressService: addressService,
                    workListItems: workListViewModel.items,
                    onSelect: { patient in
                        let vm = ComposeViewModel()
                        vm.selectPatient(patient)
                        composeViewModel = vm
                    }
                )
            }
        case .draft(let letterId):
            if let draft = draftsViewModel.drafts.first(where: { $0.letterId == letterId }) {
                if draft.status == .rendered {
                    DraftDetailView(draft: draft, onDismiss: {
                        Task { await draftsViewModel.delete(letterId: letterId) }
                        sidebarSelection = nil
                    })
                } else if let vm = composeViewModel {
                    ComposeView(viewModel: vm)
                } else {
                    Text("Loading...")
                }
            } else {
                Text("Draft not found")
                    .foregroundStyle(.secondary)
            }
        case nil:
            if let vm = composeViewModel, vm.selectedPatient != nil {
                ComposeView(viewModel: vm)
            } else if composeViewModel != nil {
                PatientSearchView(
                    addressService: addressService,
                    workListItems: workListViewModel.items,
                    onSelect: { patient in
                        let vm = ComposeViewModel()
                        vm.selectPatient(patient)
                        composeViewModel = vm
                    }
                )
            } else {
                Text("Select or compose a letter")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startNewLetter() {
        sidebarSelection = nil
        composeViewModel = ComposeViewModel()
    }

    private func startNewLetterForID(_ itemID: String) {
        composeViewModel = nil
        guard let workListItem = workListViewModel.item(forID: itemID) else { return }
        if let patient = addressService.findPatient(for: workListItem) {
            let vm = ComposeViewModel()
            vm.selectPatient(patient)
            composeViewModel = vm
        }
    }

    private func loadDraftForEditing(_ letterId: String) {
        guard let draft = draftsViewModel.drafts.first(where: { $0.letterId == letterId }) else { return }
        guard draft.status != .rendered else {
            composeViewModel = nil
            return
        }
        let vm = ComposeViewModel()
        vm.loadDraft(draft)
        composeViewModel = vm
    }
}
