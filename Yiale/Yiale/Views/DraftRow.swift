import SwiftUI

struct DraftRow: View {
    let draft: LetterDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(draft.patient.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: draft.status)
            }
            HStack(spacing: 8) {
                Text(draft.patient.mrn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: draft.modified) else {
            return draft.modified
        }
        let display = DateFormatter()
        display.dateStyle = .short
        display.timeStyle = .short
        return display.string(from: date)
    }
}

private struct StatusBadge: View {
    let status: LetterStatus

    var body: some View {
        Text(displayText)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }

    private var displayText: String {
        switch status {
        case .draft: return "Draft"
        case .renderRequested: return "Printing"
        case .rendered: return "Ready"
        }
    }

    private var color: Color {
        switch status {
        case .draft: return .gray
        case .renderRequested: return .orange
        case .rendered: return .green
        }
    }
}
