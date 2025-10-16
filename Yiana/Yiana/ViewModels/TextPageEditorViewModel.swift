//
//  TextPageEditorViewModel.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Coordinates the lifecycle of a single in-progress text page draft. The view
//  model loads existing drafts, autosaves user input to the sidecar manager,
//  tracks cursor state, and notifies listeners when the draft state changes.
//

import Foundation

@MainActor
final class TextPageEditorViewModel: ObservableObject {
    enum DraftState: Equatable {
        case empty
        case loaded(updatedAt: Date)
        case modified
        case saved(updatedAt: Date)
        case failed(Error)

        static func == (lhs: DraftState, rhs: DraftState) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty), (.modified, .modified):
                return true
            case let (.loaded(dateA), .loaded(dateB)):
                return dateA == dateB
            case let (.saved(dateA), .saved(dateB)):
                return dateA == dateB
            case let (.failed(errorA), .failed(errorB)):
                return String(describing: errorA) == String(describing: errorB)
            default:
                return false
            }
        }
    }

    @Published var content: String {
        didSet {
            guard content != oldValue else { return }
            if isProgrammaticContentChange {
                isProgrammaticContentChange = false
                notifyDraftStateChange()
                return
            }
            hasPendingChanges = true
            scheduleAutosave()
            notifyDraftStateChange()
            scheduleLiveRender()
        }
    }

    @Published private(set) var state: DraftState
    @Published private(set) var lastSavedAt: Date?
    @Published var cursorPosition: Int? {
        didSet {
            lastKnownCursorPosition = cursorPosition
        }
    }
    @Published var showPreview: Bool = false
    @Published var recoveredDraftTimestamp: Date?
    @Published private(set) var latestRenderedPageData: Data? {
        didSet {
            if latestRenderedPageData != oldValue {
                onPreviewRenderUpdated?(latestRenderedPageData)
            }
        }
    }
    @Published private(set) var latestRenderedPlainText: String?
    @Published private(set) var liveRenderError: String?

    let documentURL: URL
    private(set) var metadata: DocumentMetadata

    var onDraftStateChange: ((Bool) -> Void)?
    var onPreviewRenderUpdated: ((Data?) -> Void)?

    private let draftManager: TextPageDraftManager
    private let autosaveInterval: TimeInterval
    private let renderService = TextPageRenderService.shared

    private var hasPendingChanges = false
    private var autosaveTask: Task<Void, Never>?
    private var hasLoadedInitialDraft = false
    private var lastSavedContent = ""
    private var lastKnownCursorPosition: Int?
    private var isProgrammaticContentChange = false
    private var liveRenderTask: Task<Void, Never>?

    init(
        documentURL: URL,
        metadata: DocumentMetadata,
        initialContent: String = "",
        draftManager: TextPageDraftManager = .shared,
        autosaveInterval: TimeInterval = 30
    ) {
        self.documentURL = documentURL
        self.metadata = metadata
        self.draftManager = draftManager
        self.autosaveInterval = autosaveInterval
        self.content = initialContent
        self.lastSavedContent = initialContent
        self.state = initialContent.isEmpty ? .empty : .loaded(updatedAt: Date())
        self.lastSavedAt = nil
        self.recoveredDraftTimestamp = nil
    }

    deinit {
        autosaveTask?.cancel()
        liveRenderTask?.cancel()
    }

    func refreshMetadata(_ metadata: DocumentMetadata) {
        guard metadata.id == self.metadata.id else { return }
        self.metadata = metadata
    }

    func loadDraftIfAvailable() async {
        guard !hasLoadedInitialDraft else { return }
        if let draft = await draftManager.loadDraft(for: documentURL, metadata: metadata) {
            isProgrammaticContentChange = true
            content = draft.content
            lastSavedContent = draft.content
            cursorPosition = draft.metadata.cursorPosition
            lastKnownCursorPosition = draft.metadata.cursorPosition
            lastSavedAt = draft.metadata.updatedAt
            recoveredDraftTimestamp = draft.metadata.updatedAt
            state = .loaded(updatedAt: draft.metadata.updatedAt)
            hasPendingChanges = false
            notifyDraftStateChange()
        } else {
            state = content.isEmpty ? .empty : .loaded(updatedAt: Date())
            notifyDraftStateChange()
        }
        hasLoadedInitialDraft = true
        scheduleLiveRender(immediate: true)
    }

    func togglePreview(forTraitCollectionIsCompact: Bool) {
        if forTraitCollectionIsCompact {
            showPreview.toggle()
        } else {
            showPreview = true
        }
    }

    func applyFormatting(_ transform: (inout String, inout Int?) -> Void) {
        var mutableText = content
        var cursor = cursorPosition
        transform(&mutableText, &cursor)
        content = mutableText
        cursorPosition = cursor
    }

    func flushDraftNow() async {
        autosaveTask?.cancel()
        await performSave()
    }

    func refreshRenderForPaperSizeChange() {
        liveRenderTask?.cancel()
        scheduleLiveRender(immediate: true)
    }

    func discardDraft() async {
        autosaveTask?.cancel()
        liveRenderTask?.cancel()
        do {
            try await draftManager.removeDraft(for: documentURL, metadata: metadata)
            lastSavedContent = ""
            isProgrammaticContentChange = true
            content = ""
            lastSavedAt = nil
            state = .empty
            hasPendingChanges = false
            notifyDraftStateChange()
            latestRenderedPageData = nil
            latestRenderedPlainText = nil
            liveRenderError = nil
        } catch {
            state = .failed(error)
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        guard hasLoadedInitialDraft else { return }
        guard hasPendingChanges else { return }

        autosaveTask = Task { [weak self] in
            guard let self else { return }
            let delay = UInt64(autosaveInterval * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            if Task.isCancelled { return }
            await self.performSave()
        }
    }

    private func performSave() async {
        guard hasPendingChanges else { return }
        hasPendingChanges = false

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty {
            do {
                try await draftManager.removeDraft(for: documentURL, metadata: metadata)
                lastSavedContent = ""
                lastSavedAt = nil
                state = .empty
                notifyDraftStateChange()
                latestRenderedPageData = nil
                latestRenderedPlainText = nil
                liveRenderError = nil
            } catch {
                state = .failed(error)
            }
            return
        }

        let timestamp = Date()
        let draft = TextPageDraft(
            content: content,
            metadata: TextPageDraftMetadata(updatedAt: timestamp, cursorPosition: lastKnownCursorPosition)
        )

        do {
            try await draftManager.saveDraft(draft, for: documentURL, metadata: metadata)
            lastSavedContent = content
            lastSavedAt = timestamp
            state = .saved(updatedAt: timestamp)
            notifyDraftStateChange()
        } catch {
            state = .failed(error)
            hasPendingChanges = true
        }
    }

    private func scheduleLiveRender(immediate: Bool = false) {
        guard hasLoadedInitialDraft else { return }

        liveRenderTask?.cancel()

        let snapshot = content
        liveRenderTask = Task { [weak self] in
            guard let self else { return }

            let trimmed = snapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                await MainActor.run { [weak self] in
                    self?.latestRenderedPageData = nil
                    self?.latestRenderedPlainText = nil
                    self?.liveRenderError = nil
                }
                return
            }

            if !immediate {
                do {
                    try await Task.sleep(nanoseconds: 400_000_000)
                } catch { return }
            }

            if Task.isCancelled { return }

            do {
                let output = try await renderService.render(markdown: snapshot)
                await MainActor.run { [weak self] in
                    self?.latestRenderedPageData = output.pdfData
                    self?.latestRenderedPlainText = output.plainText
                    self?.liveRenderError = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.liveRenderError = error.localizedDescription
                }
            }
        }
    }

    private func notifyDraftStateChange() {
        let hasDraft = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !lastSavedContent.isEmpty
        onDraftStateChange?(hasDraft)
    }
}

extension TextPageEditorViewModel.DraftState {
    var updatedAt: Date? {
        switch self {
        case .loaded(let date): return date
        case .saved(let date): return date
        default: return nil
        }
    }
}
