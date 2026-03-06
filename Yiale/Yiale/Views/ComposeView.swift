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
                Picker("Title", selection: Binding(
                    get: { viewModel.patientTitle ?? "" },
                    set: { viewModel.patientTitle = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    ForEach(ComposeViewModel.availableTitles, id: \.self) { title in
                        Text(title).tag(title)
                    }
                }
                if !viewModel.patientDOB.isEmpty {
                    LabeledContent("DOB", value: viewModel.patientDOB)
                }
                if !viewModel.patientMRN.isEmpty {
                    LabeledContent("MRN", value: viewModel.patientMRN)
                }
                patientAddressSection
                patientPhonesSection
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

    private var patientAddressSection: some View {
        LabeledContent("Address") {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(viewModel.patientAddress.indices, id: \.self) { index in
                    HStack(spacing: 4) {
                        TextField("Line \(index + 1)", text: $viewModel.patientAddress[index])
                            .textFieldStyle(.roundedBorder)
                        Button {
                            viewModel.patientAddress.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    viewModel.patientAddress.append("")
                } label: {
                    Label("Add Line", systemImage: "plus.circle")
                        .font(.caption)
                }
            }
        }
    }

    private var patientPhonesSection: some View {
        LabeledContent("Phone") {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(viewModel.patientPhones.indices, id: \.self) { index in
                    HStack(spacing: 4) {
                        TextField("Phone", text: $viewModel.patientPhones[index])
                            .textFieldStyle(.roundedBorder)
                        Button {
                            viewModel.patientPhones.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    viewModel.patientPhones.append("")
                } label: {
                    Label("Add Phone", systemImage: "plus.circle")
                        .font(.caption)
                }
            }
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
