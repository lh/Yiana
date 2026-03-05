import SwiftUI

struct AddressConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ComposeViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Confirm Addresses")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Patient address
                    AddressCard(
                        title: "Patient",
                        name: viewModel.patientName,
                        address: viewModel.patientAddress
                    )

                    // Recipient addresses
                    ForEach(viewModel.recipients) { recipient in
                        if recipient.role != "hospital_records" {
                            AddressCard(
                                title: recipient.role == "gp" ? "GP" : recipient.role.capitalized,
                                name: recipient.name,
                                address: recipient.address,
                                practice: recipient.practice
                            )
                        }
                    }

                    // Yiana target
                    GroupBox("Document Target") {
                        TextField("Yiana target filename", text: $viewModel.yianaTarget)
                            .textFieldStyle(.roundedBorder)
                            .padding(4)
                    }
                }
                .padding()
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Confirm and Send to Print") {
                    dismiss()
                    Task { await viewModel.requestRender() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.yianaTarget.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}

private struct AddressCard: View {
    let title: String
    let name: String
    let address: [String]
    var practice: String? = nil

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.headline)
                if let practice, !practice.isEmpty {
                    Text(practice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(address, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                }
                if address.isEmpty {
                    Text("No address on file")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}
