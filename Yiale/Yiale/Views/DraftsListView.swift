import SwiftUI

struct DraftsListView: View {
    @Bindable var viewModel: DraftsViewModel
    @Binding var selectedDraftId: String?
    let onNewLetter: () -> Void

    var body: some View {
        List(selection: $selectedDraftId) {
            ForEach(viewModel.drafts) { draft in
                DraftRow(draft: draft)
                    .tag(draft.letterId)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let draft = viewModel.drafts[index]
                    Task { await viewModel.delete(letterId: draft.letterId) }
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
