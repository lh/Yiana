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
            // Only update if drafts actually changed, to avoid needless SwiftUI re-renders
            if !draftsEqual(drafts, loaded) {
                drafts = loaded
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Cheap comparison: same IDs in same order with same modification timestamps.
    private func draftsEqual(_ a: [LetterDraft], _ b: [LetterDraft]) -> Bool {
        guard a.count == b.count else { return false }
        for (lhs, rhs) in zip(a, b) {
            if lhs.letterId != rhs.letterId || lhs.modified != rhs.modified || lhs.status != rhs.status {
                return false
            }
        }
        return true
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
