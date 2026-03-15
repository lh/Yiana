import SwiftUI

@Observable
final class WorkListViewModel {
    var items: [SharedWorkListItem] = []
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

    /// Parse and merge new items by id — existing items are kept, new ones added.
    func importClinicList(_ text: String) {
        let parsed = ClinicListParser.parse(text)
        guard !parsed.isEmpty else { return }

        let existingIDs = Set(items.map(\.id))
        let newItems = parsed.filter { !existingIDs.contains($0.id) }
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

    func remove(id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        items = []
        Task.detached {
            try? WorkListRepository().clear()
        }
    }

    /// Find the work list item for a given id.
    func item(forID id: String) -> SharedWorkListItem? {
        items.first { $0.id == id }
    }

    private func save() {
        let snapshot = SharedWorkList(
            modified: ISO8601DateFormatter().string(from: Date()),
            items: items
        )
        Task.detached {
            try? WorkListRepository().save(snapshot)
        }
    }
}
