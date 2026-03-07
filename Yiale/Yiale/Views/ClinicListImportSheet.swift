import SwiftUI

struct ClinicListImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pastedText = ""

    let onImport: (String) -> Void
    let onReplace: (String) -> Void
    let existingCount: Int

    private var parsed: [WorkListItem] {
        ClinicListParser.parse(pastedText)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            textArea
            Divider()
            preview
            Divider()
            buttons
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var header: some View {
        HStack {
            Text("Import Clinic List")
                .font(.headline)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var textArea: some View {
        TextEditor(text: $pastedText)
            .font(.system(.body, design: .monospaced))
            .padding(4)
    }

    private var preview: some View {
        HStack {
            if pastedText.isEmpty {
                Text("Paste a clinic list above")
                    .foregroundStyle(.secondary)
            } else if parsed.isEmpty {
                Text("No patients found -- check the format")
                    .foregroundStyle(.red)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(parsed.count) patient\(parsed.count == 1 ? "" : "s") found")
                        .font(.subheadline.bold())
                    Text(parsed.map { "\($0.surname), \($0.firstName)" }.joined(separator: " / "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding()
    }

    private var buttons: some View {
        HStack {
            Spacer()
            if existingCount > 0 {
                Button("Replace (\(existingCount) existing)") {
                    onReplace(pastedText)
                    dismiss()
                }
                .disabled(parsed.isEmpty)
            }
            Button("Import") {
                onImport(pastedText)
                dismiss()
            }
            .disabled(parsed.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}
