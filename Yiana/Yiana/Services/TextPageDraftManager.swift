//
//  TextPageDraftManager.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Handles storage and retrieval of text page drafts that live alongside
//  .yianazip documents. Drafts are stored as Markdown in a hidden sidecar
//  directory so that iCloud sync keeps them available across devices without
//  inflating the primary metadata payload.
//

import Foundation

/// Persisted metadata for a text page draft.
struct TextPageDraftMetadata: Codable, Equatable {
    var updatedAt: Date
    var cursorPosition: Int?

    init(updatedAt: Date = Date(), cursorPosition: Int? = nil) {
        self.updatedAt = updatedAt
        self.cursorPosition = cursorPosition
    }
}

/// Combined payload returned by the draft manager.
struct TextPageDraft: Equatable {
    var content: String
    var metadata: TextPageDraftMetadata
}

/// Actor that manages disk IO for text page drafts.
actor TextPageDraftManager {
    static let shared = TextPageDraftManager()

    private let fileManager = FileManager.default
    private let draftsDirectoryName = ".text-drafts"
    private let markdownExtension = "md"
    private let metadataExtension = "meta"

    // MARK: - Paths

    private func draftsDirectory(for documentURL: URL) -> URL {
        documentURL
            .deletingLastPathComponent()
            .appendingPathComponent(draftsDirectoryName, isDirectory: true)
    }

    private func baseFileName(for metadata: DocumentMetadata) -> String {
        metadata.id.uuidString.lowercased()
    }

    private func draftContentURL(for documentURL: URL, metadata: DocumentMetadata) -> URL {
        draftsDirectory(for: documentURL)
            .appendingPathComponent(baseFileName(for: metadata))
            .appendingPathExtension(markdownExtension)
    }

    private func draftMetadataURL(for documentURL: URL, metadata: DocumentMetadata) -> URL {
        draftsDirectory(for: documentURL)
            .appendingPathComponent(baseFileName(for: metadata))
            .appendingPathExtension(metadataExtension)
    }

    // MARK: - Public API

    func hasDraft(for documentURL: URL, metadata: DocumentMetadata) -> Bool {
        fileManager.fileExists(atPath: draftContentURL(for: documentURL, metadata: metadata).path)
    }

    func loadDraft(for documentURL: URL, metadata: DocumentMetadata) -> TextPageDraft? {
        let contentURL = draftContentURL(for: documentURL, metadata: metadata)
        guard let contentData = try? Data(contentsOf: contentURL),
              let content = String(data: contentData, encoding: .utf8) else {
            return nil
        }

        let metadataURL = draftMetadataURL(for: documentURL, metadata: metadata)
        let draftMetadata: TextPageDraftMetadata

        if let metaData = try? Data(contentsOf: metadataURL) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(TextPageDraftMetadata.self, from: metaData) {
                draftMetadata = decoded
            } else {
            draftMetadata = TextPageDraftMetadata(updatedAt: fileManager.modificationDate(for: contentURL) ?? Date())
        }
        } else {
            draftMetadata = TextPageDraftMetadata(updatedAt: fileManager.modificationDate(for: contentURL) ?? Date())
        }

        return TextPageDraft(content: content, metadata: draftMetadata)
    }

    func saveDraft(_ draft: TextPageDraft, for documentURL: URL, metadata: DocumentMetadata) throws {
        let directory = draftsDirectory(for: documentURL)
        try ensureDirectoryExists(directory)

        let contentURL = draftContentURL(for: documentURL, metadata: metadata)
        let metadataURL = draftMetadataURL(for: documentURL, metadata: metadata)

        let contentData = Data(draft.content.utf8)
        try contentData.write(to: contentURL, options: .atomic)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let metaData = try encoder.encode(draft.metadata)
        try metaData.write(to: metadataURL, options: .atomic)
    }

    func updateDraftContent(_ content: String, for documentURL: URL, metadata: DocumentMetadata, cursorPosition: Int?) throws {
        let draft = TextPageDraft(
            content: content,
            metadata: TextPageDraftMetadata(updatedAt: Date(), cursorPosition: cursorPosition)
        )
        try saveDraft(draft, for: documentURL, metadata: metadata)
    }

    func removeDraft(for documentURL: URL, metadata: DocumentMetadata) throws {
        let contentURL = draftContentURL(for: documentURL, metadata: metadata)
        let metadataURL = draftMetadataURL(for: documentURL, metadata: metadata)

        if fileManager.fileExists(atPath: contentURL.path) {
            try fileManager.removeItem(at: contentURL)
        }

        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
    }

    func removeAllDrafts(in documentsDirectory: URL) throws {
        let directory = documentsDirectory.appendingPathComponent(draftsDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    // MARK: - Helpers

    private func ensureDirectoryExists(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

private extension FileManager {
    func modificationDate(for url: URL) -> Date? {
        ((try? attributesOfItem(atPath: url.path))?[.modificationDate]) as? Date
    }
}
