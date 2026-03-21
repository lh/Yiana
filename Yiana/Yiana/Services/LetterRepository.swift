import Foundation

enum LetterRepositoryError: Error {
    case noiCloudContainer
}

class LetterRepository {
    static let shared = LetterRepository()

    private var cachedContainerURL: URL?

    /// Call from main thread to cache the iCloud container URL.
    /// `url(forUbiquityContainerIdentifier:)` returns nil from `Task.detached`.
    func cacheContainerURL() {
        if cachedContainerURL == nil {
            cachedContainerURL = FileManager.default.url(
                forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana"
            )
        }
    }

    private var documentsURL: URL? {
        cachedContainerURL?.appendingPathComponent("Documents")
    }

    private var draftsURL: URL? {
        documentsURL?.appendingPathComponent(".letters")
            .appendingPathComponent("drafts")
    }

    private var renderedURL: URL? {
        documentsURL?.appendingPathComponent(".letters")
            .appendingPathComponent("rendered")
    }

    var injectDirectory: URL? {
        documentsURL?.appendingPathComponent(".letters")
            .appendingPathComponent("inject")
    }

    /// Returns the rendered output directory for a letter.
    func renderedDirectory(letterId: String) throws -> URL {
        guard let renderedURL else {
            throw LetterRepositoryError.noiCloudContainer
        }
        return renderedURL.appendingPathComponent(letterId)
    }

    /// List all drafts from `.letters/drafts/`.
    /// Call from `Task.detached` (file I/O off main thread).
    func listDrafts() throws -> [LetterDraft] {
        guard let draftsURL else { return [] }

        let fm = FileManager.default
        if !fm.fileExists(atPath: draftsURL.path) {
            try fm.createDirectory(at: draftsURL, withIntermediateDirectories: true)
            return []
        }

        // No .skipsHiddenFiles — iCloud marks synced files as hidden
        let contents = try fm.contentsOfDirectory(
            at: draftsURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        let jsonFiles = contents.filter { $0.pathExtension == "json" }
        let decoder = JSONDecoder()
        var drafts: [LetterDraft] = []
        for url in jsonFiles {
            if let data = try? Data(contentsOf: url),
               let draft = try? decoder.decode(LetterDraft.self, from: data) {
                drafts.append(draft)
            }
        }
        return drafts.sorted { $0.modified > $1.modified }
    }

    /// Save a draft with atomic write.
    func save(_ draft: LetterDraft) throws {
        guard let draftsURL else { return }

        let fm = FileManager.default
        try fm.createDirectory(at: draftsURL, withIntermediateDirectories: true)

        let finalURL = draftsURL.appendingPathComponent("\(draft.letterId).json")
        let tmpURL = draftsURL.appendingPathComponent("\(draft.letterId).json.tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(draft)
        try data.write(to: tmpURL, options: .atomic)

        if fm.fileExists(atPath: finalURL.path) {
            _ = try fm.replaceItemAt(finalURL, withItemAt: tmpURL)
        } else {
            try fm.moveItem(at: tmpURL, to: finalURL)
        }
    }

    /// Delete a draft by letter ID.
    func delete(letterId: String) throws {
        guard let draftsURL else { return }

        let fileURL = draftsURL.appendingPathComponent("\(letterId).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Set status to render_requested and save.
    func requestRender(_ draft: inout LetterDraft) throws {
        draft.status = .renderRequested
        draft.renderRequest = ISO8601DateFormatter().string(from: Date())
        draft.modified = ISO8601DateFormatter().string(from: Date())
        try save(draft)
    }

    /// Check if rendered output exists for a draft.
    func renderedOutputExists(letterId: String) -> Bool {
        guard let renderedURL else { return false }
        let outputDir = renderedURL.appendingPathComponent(letterId)
        return FileManager.default.fileExists(atPath: outputDir.path)
    }

    /// Get PDF URLs in the rendered output directory for a draft.
    func renderedPDFs(letterId: String) throws -> [URL] {
        guard let renderedURL else { return [] }

        let outputDir = renderedURL.appendingPathComponent(letterId)
        guard FileManager.default.fileExists(atPath: outputDir.path) else { return [] }

        let contents = try FileManager.default.contentsOfDirectory(
            at: outputDir,
            includingPropertiesForKeys: nil,
            options: []
        )
        return contents.filter { $0.pathExtension.lowercased() == "pdf" }
    }
}
