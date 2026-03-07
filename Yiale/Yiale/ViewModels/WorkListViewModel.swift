import SwiftUI

@Observable
final class WorkListViewModel {
    var items: [WorkListItem] = []
    var errorMessage: String?

    func load() async {
        do {
            let loaded = try await Task.detached {
                try WorkListRepository().load()
            }.value
            items = loaded.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Parse and merge new items by MRN — existing items are kept, new ones added.
    func importClinicList(_ text: String) {
        let parsed = ClinicListParser.parse(text)
        guard !parsed.isEmpty else { return }

        let existingMRNs = Set(items.map(\.mrn))
        let newItems = parsed.filter { !existingMRNs.contains($0.mrn) }
        items.append(contentsOf: newItems)
        save()
    }

    /// Parse and replace the entire work list.
    func replaceClinicList(_ text: String) {
        let parsed = ClinicListParser.parse(text)
        guard !parsed.isEmpty else { return }

        items = parsed
        save()
    }

    func remove(mrn: String) {
        items.removeAll { $0.mrn == mrn }
        save()
    }

    func clearAll() {
        items = []
        Task.detached {
            try? WorkListRepository().clear()
        }
    }

    /// Find the work list item for a given MRN.
    func item(forMRN mrn: String) -> WorkListItem? {
        items.first { $0.mrn == mrn }
    }

    private func save() {
        let snapshot = WorkList(
            modified: ISO8601DateFormatter().string(from: Date()),
            items: items
        )
        Task.detached {
            try? WorkListRepository().save(snapshot)
        }
    }
}
