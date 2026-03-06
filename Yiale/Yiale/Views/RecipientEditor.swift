import SwiftUI

struct RecipientEditor: View {
    @Binding var recipients: [LetterRecipient]
    @State private var showAddRecipient = false
    @State private var expandedRecipientId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($recipients) { $recipient in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(recipient.name)
                                    .font(.headline)
                                RoleBadge(role: recipient.role)
                            }
                            if let practice = recipient.practice, !practice.isEmpty {
                                Text(practice)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if !recipient.address.isEmpty {
                                Text(recipient.address.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if recipient.role != "hospital_records" {
                            Button {
                                withAnimation {
                                    if expandedRecipientId == recipient.id {
                                        expandedRecipientId = nil
                                    } else {
                                        expandedRecipientId = recipient.id
                                    }
                                }
                            } label: {
                                Image(systemName: expandedRecipientId == recipient.id ? "chevron.up" : "pencil")
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                recipients.removeAll { $0.id == recipient.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if expandedRecipientId == recipient.id {
                        RecipientInlineEditor(recipient: $recipient)
                            .padding(.leading, 8)
                    }
                }
                .padding(.vertical, 4)
                if recipient.id != recipients.last?.id {
                    Divider()
                }
            }

            Button {
                showAddRecipient = true
            } label: {
                Label("Add Recipient", systemImage: "plus.circle")
            }
            .sheet(isPresented: $showAddRecipient) {
                AddRecipientSheet(onAdd: { recipient in
                    recipients.append(recipient)
                })
            }
        }
    }
}

private struct RecipientInlineEditor: View {
    @Binding var recipient: LetterRecipient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: $recipient.name)
                .textFieldStyle(.roundedBorder)
            TextField("Practice", text: Binding(
                get: { recipient.practice ?? "" },
                set: { recipient.practice = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Text("Address")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(recipient.address.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    TextField("Line \(index + 1)", text: $recipient.address[index])
                        .textFieldStyle(.roundedBorder)
                    Button {
                        recipient.address.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                recipient.address.append("")
            } label: {
                Label("Add Line", systemImage: "plus.circle")
                    .font(.caption)
            }
        }
    }
}

private struct RoleBadge: View {
    let role: String

    var body: some View {
        Text(displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }

    private var displayName: String {
        switch role {
        case "gp": return "GP"
        case "patient": return "Patient"
        case "hospital_records": return "Records"
        case "specialist": return "Specialist"
        default: return role.capitalized
        }
    }

    private var color: Color {
        switch role {
        case "gp": return .blue
        case "patient": return .green
        case "hospital_records": return .orange
        case "specialist": return .purple
        default: return .gray
        }
    }
}

private struct AddRecipientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = "specialist"
    @State private var practice = ""
    @State private var addressLines: [String] = [""]

    let onAdd: (LetterRecipient) -> Void

    private let roles = ["gp", "specialist", "patient"]

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Recipient")
                .font(.headline)

            Form {
                Picker("Role", selection: $role) {
                    ForEach(roles, id: \.self) { r in
                        Text(r == "gp" ? "GP" : r.capitalized)
                    }
                }
                TextField("Name", text: $name)
                TextField("Practice", text: $practice)

                Section("Address") {
                    ForEach(addressLines.indices, id: \.self) { index in
                        HStack {
                            TextField("Line \(index + 1)", text: $addressLines[index])
                            if addressLines.count > 1 {
                                Button {
                                    addressLines.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        addressLines.append("")
                    } label: {
                        Label("Add Line", systemImage: "plus.circle")
                            .font(.caption)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let address = addressLines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    onAdd(LetterRecipient(
                        role: role,
                        source: "manual",
                        name: name,
                        practice: practice.isEmpty ? nil : practice,
                        address: address
                    ))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
