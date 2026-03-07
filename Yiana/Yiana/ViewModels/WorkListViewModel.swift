import SwiftUI
import os.log

@Observable
final class WorkListViewModel {
    var items: [WorkListItem] = []
    var isExpanded: Bool = true
    var showingAddForm: Bool = false
    var showingClearConfirmation: Bool = false
    var errorMessage: String?

    /// Pre-resolved document URLs for each work list item (keyed by MRN).
    /// Single URL = instant navigation. Multiple = picker needed. Empty = no match.
    private(set) var resolvedURLs: [String: [URL]] = [:]

    /// User-chosen URL when there were multiple matches. Persisted in memory only.
    private var savedChoices: [String: URL] = [:]

    private static let logger = Logger(
        subsystem: "com.vitygas.Yiana",
        category: "WorkListViewModel"
    )

    private var changeObserver: NSObjectProtocol?
    private var documentsObserver: NSObjectProtocol?

    func startObserving() {
        guard changeObserver == nil else { return }

        // Reload when .worklist.json changes externally (e.g. from Yiale)
        changeObserver = NotificationCenter.default.addObserver(
            forName: .workListChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.load()
            }
        }

        // Re-resolve when documents change (new downloads, imports, etc.)
        documentsObserver = NotificationCenter.default.addObserver(
            forName: .yianaDocumentsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.resolveMatches()
            }
        }
    }

    func stopObserving() {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
            changeObserver = nil
        }
        if let observer = documentsObserver {
            NotificationCenter.default.removeObserver(observer)
            documentsObserver = nil
        }
    }

    func load() async {
        do {
            let loaded = try await Task.detached {
                try WorkListRepository().load()
            }.value
            items = loaded.items
            await resolveMatches()
        } catch {
            Self.logger.error("Failed to load work list: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// Build the MRN → [URL] map by matching work list names against document filenames.
    /// Filename format: `Surname_FirstN_ID.yianazip` (first name may be truncated).
    func resolveMatches() async {
        guard !items.isEmpty else {
            resolvedURLs = [:]
            return
        }

        let currentItems = items
        let resolved: [String: [URL]] = await Task.detached {
            let repo = DocumentRepository()
            let allDocs = repo.allDocumentsRecursive()

            var map: [String: [URL]] = [:]
            for item in currentItems {
                let surname = item.surname.trimmingCharacters(in: .whitespaces).lowercased()
                let firstName = item.firstName.trimmingCharacters(in: .whitespaces).lowercased()
                var matches: [URL] = []

                for doc in allDocs {
                    let filename = doc.url.deletingPathExtension().lastPathComponent.lowercased()
                    // Filename format: Surname_Firstname_DDMMYY.yianazip
                    // May have trailing parts (e.g. _Clinic_110824) or spaces around underscores
                    let parts = filename.split(separator: "_").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                    guard parts.count >= 2 else { continue }

                    let fileSurname = parts[0]
                    let fileFirstName = parts[1]

                    // Exact match on both surname and first name
                    if fileSurname == surname && fileFirstName == firstName {
                        matches.append(doc.url)
                    }
                }
                map[item.mrn] = matches
            }
            return map
        }.value

        resolvedURLs = resolved
    }

    /// Returns the URL to navigate to for a given work list item.
    /// - Single match: returns the URL directly.
    /// - Saved choice: returns the saved URL if still valid.
    /// - Multiple/zero: returns nil (caller should show picker or "not found").
    func resolvedURL(for item: WorkListItem) -> URL? {
        let urls = resolvedURLs[item.mrn] ?? []

        // Check saved choice first
        if let saved = savedChoices[item.mrn], urls.contains(saved) {
            return saved
        }

        if urls.count == 1 {
            return urls[0]
        }

        return nil
    }

    /// Save the user's choice for an ambiguous match.
    func saveChoice(mrn: String, url: URL) {
        savedChoices[mrn] = url
    }

    /// Parse and merge new items — existing items (by MRN) are kept, new ones added.
    func importClinicList(_ text: String) {
        let parsed = ClinicListParser.parse(text)
        guard !parsed.isEmpty else { return }

        let existingMRNs = Set(items.map(\.mrn))
        let newItems = parsed.filter { !existingMRNs.contains($0.mrn) }
        items.append(contentsOf: newItems)
        save()
        Task { await resolveMatches() }
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
        Task { await resolveMatches() }
    }

    func remove(mrn: String) {
        items.removeAll { $0.mrn == mrn }
        savedChoices.removeValue(forKey: mrn)
        resolvedURLs.removeValue(forKey: mrn)
        save()
    }

    func clearAll() {
        items = []
        resolvedURLs = [:]
        savedChoices = [:]
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
