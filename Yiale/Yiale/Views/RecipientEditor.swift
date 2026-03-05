import SwiftUI

struct RecipientEditor: View {
    @Binding var recipients: [LetterRecipient]
    @State private var showAddRecipient = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(recipients) { recipient in
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
                        Button(role: .destructive) {
                            recipients.removeAll { $0.id == recipient.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
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
    @State private var addressText = ""

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
                TextField("Address (comma-separated lines)", text: $addressText)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let address = addressText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
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
