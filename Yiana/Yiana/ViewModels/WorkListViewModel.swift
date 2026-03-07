import SwiftUI
import os.log

@Observable
final class WorkListViewModel {
    var items: [WorkListItem] = []
    var isExpanded: Bool = true
    var showingAddForm: Bool = false
    var errorMessage: String?

    private static let logger = Logger(
        subsystem: "com.vitygas.Yiana",
        category: "WorkListViewModel"
    )

    private var changeObserver: NSObjectProtocol?

    func startObserving() {
        guard changeObserver == nil else { return }
        changeObserver = NotificationCenter.default.addObserver(
            forName: .workListChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.load()
            }
        }
    }

    func stopObserving() {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
            changeObserver = nil
        }
    }

    func load() async {
        do {
            let loaded = try await Task.detached {
                try WorkListRepository().load()
            }.value
            items = loaded.items
        } catch {
            Self.logger.error("Failed to load work list: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// Parse and merge new items — existing items (by MRN) are kept, new ones added.
    func importClinicList(_ text: String) {
        let parsed = ClinicListParser.parse(text)
        guard !parsed.isEmpty else { return }

        let existingMRNs = Set(items.map(\.mrn))
        let newItems = parsed.filter { !existingMRNs.contains($0.mrn) }
        items.append(contentsOf: newItems)
        save()
    }

    func add(surname: String, firstName: String) {
        let trimmedSurname = surname.trimmingCharacters(in: .whitespaces)
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        guard !trimmedSurname.isEmpty else { return }

        let item = WorkListItem(
            mrn: "Y-" + UUID().uuidString.prefix(8).lowercased(),
            surname: trimmedSurname,
            firstName: trimmedFirst,
            gender: nil,
            age: nil,
            doctor: nil,
            added: ISO8601DateFormatter().string(from: Date())
        )
        items.append(item)
        save()
    }

    func remove(mrn: String) {
        items.removeAll { $0.mrn == mrn }
        save()
    }

    func clearAll() {
        items = []
        save()
    }

    private func save() {
        let snapshot = WorkList(
            modified: ISO8601DateFormatter().string(from: Date()),
            items: items
        )
        Task.detached {
            do {
                try WorkListRepository().save(snapshot)
            } catch {
                Self.logger.error("Failed to save work list: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
