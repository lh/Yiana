import SwiftUI

@Observable
final class DraftsViewModel {
    var drafts: [LetterDraft] = []
    var errorMessage: String?

    private let repository = LetterRepository()
    private var pollTimer: Timer?

    func load() async {
        do {
            let loaded = try await Task.detached {
                try LetterRepository().listDrafts()
            }.value
            drafts = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.load() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func delete(letterId: String) async {
        do {
            try await Task.detached {
                try LetterRepository().delete(letterId: letterId)
            }.value
            drafts.removeAll { $0.letterId == letterId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
