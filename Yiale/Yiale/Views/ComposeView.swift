import SwiftUI

struct ComposeView: View {
    @Bindable var viewModel: ComposeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                patientSection
                recipientSection
                bodySection
            }
            .padding()
        }
        .navigationTitle("Compose Letter")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save Draft") {
                    Task { await viewModel.saveDraft() }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!viewModel.canSave || viewModel.isSaving)

                Button("Send to Print") {
                    viewModel.showAddressConfirmation = true
                }
                .disabled(!viewModel.canSend || viewModel.isSaving)
            }
        }
        .sheet(isPresented: $viewModel.showAddressConfirmation) {
            AddressConfirmationSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var patientSection: some View {
        GroupBox("Patient") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Name", value: viewModel.patientName)
                if !viewModel.patientDOB.isEmpty {
                    LabeledContent("DOB", value: viewModel.patientDOB)
                }
                if !viewModel.patientMRN.isEmpty {
                    LabeledContent("MRN", value: viewModel.patientMRN)
                }
                if !viewModel.patientAddress.isEmpty {
                    LabeledContent("Address") {
                        VStack(alignment: .trailing) {
                            ForEach(viewModel.patientAddress, id: \.self) { line in
                                Text(line)
                            }
                        }
                    }
                }
                if !viewModel.patientPhones.isEmpty {
                    LabeledContent("Phone", value: viewModel.patientPhones.joined(separator: ", "))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }

    private var recipientSection: some View {
        GroupBox("Recipients") {
            RecipientEditor(recipients: $viewModel.recipients)
                .padding(4)
        }
    }

    private var bodySection: some View {
        GroupBox("Letter Body") {
            TextEditor(text: $viewModel.body)
                .font(.body)
                .frame(minHeight: 200)
                .padding(4)
        }
    }
}
