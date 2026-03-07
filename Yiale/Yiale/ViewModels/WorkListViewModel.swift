import SwiftUI

@Observable
final class WorkListViewModel {
    var items: [WorkListItem] = []
    var mrnSet: Set<String> = []
    var errorMessage: String?

    func load() async {
        do {
            let loaded = try await Task.detached {
                try WorkListRepository().load()
            }.value
            items = loaded.items
            mrnSet = Set(loaded.items.map(\.mrn))
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
        mrnSet = Set(items.map(\.mrn))
        save()
    }

    /// Parse and replace the entire work list.
    func replaceClinicList(_ text: String) {
        let parsed = ClinicListParser.parse(text)
        guard !parsed.isEmpty else { return }

        items = parsed
        mrnSet = Set(parsed.map(\.mrn))
        save()
    }

    func remove(mrn: String) {
        items.removeAll { $0.mrn == mrn }
        mrnSet.remove(mrn)
        save()
    }

    func clearAll() {
        items = []
        mrnSet = []
        Task.detached {
            try? WorkListRepository().clear()
        }
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
