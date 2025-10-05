//
//  SidecarManager.swift
//  Yiana
//
//  Manages text draft storage in sidecar files alongside documents
//

import Foundation

/// Manages text page drafts stored as sidecar files
class SidecarManager {
    static let shared = SidecarManager()

    private let draftsDirectoryName = ".text-drafts"
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Draft Management

    /// Get the drafts directory URL for a given document directory
    private func draftsDirectoryURL(for documentURL: URL) -> URL {
        let documentDir = documentURL.deletingLastPathComponent()
        return documentDir.appendingPathComponent(draftsDirectoryName)
    }

    /// Get the draft file URL for a specific document
    private func draftFileURL(for documentURL: URL) -> URL {
        let documentId = documentURL.deletingPathExtension().lastPathComponent
        let draftsDir = draftsDirectoryURL(for: documentURL)
        return draftsDir.appendingPathComponent("\(documentId).md")
    }

    /// Get the metadata file URL for a specific document draft
    private func metadataFileURL(for documentURL: URL) -> URL {
        let documentId = documentURL.deletingPathExtension().lastPathComponent
        let draftsDir = draftsDirectoryURL(for: documentURL)
        return draftsDir.appendingPathComponent("\(documentId).meta")
    }

    /// Ensure the drafts directory exists
    private func ensureDraftsDirectory(for documentURL: URL) throws {
        let draftsDir = draftsDirectoryURL(for: documentURL)
        if !fileManager.fileExists(atPath: draftsDir.path) {
            try fileManager.createDirectory(at: draftsDir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    /// Save a draft for a document
    func saveDraft(_ text: String, for documentURL: URL) throws {
        try ensureDraftsDirectory(for: documentURL)
        let draftURL = draftFileURL(for: documentURL)
        try text.write(to: draftURL, atomically: true, encoding: .utf8)
    }

    /// Load a draft for a document
    func loadDraft(for documentURL: URL) -> String? {
        let draftURL = draftFileURL(for: documentURL)
        guard fileManager.fileExists(atPath: draftURL.path) else { return nil }
        return try? String(contentsOf: draftURL, encoding: .utf8)
    }

    /// Check if a draft exists for a document
    func hasDraft(for documentURL: URL) -> Bool {
        let draftURL = draftFileURL(for: documentURL)
        return fileManager.fileExists(atPath: draftURL.path)
    }

    /// Delete draft files for a document
    func deleteDraft(for documentURL: URL) throws {
        let draftURL = draftFileURL(for: documentURL)
        let metaURL = metadataFileURL(for: documentURL)

        if fileManager.fileExists(atPath: draftURL.path) {
            try fileManager.removeItem(at: draftURL)
        }
        if fileManager.fileExists(atPath: metaURL.path) {
            try fileManager.removeItem(at: metaURL)
        }

        // Clean up drafts directory if empty
        let draftsDir = draftsDirectoryURL(for: documentURL)
        if let contents = try? fileManager.contentsOfDirectory(atPath: draftsDir.path),
           contents.isEmpty {
            try? fileManager.removeItem(at: draftsDir)
        }
    }

    /// Save draft metadata (cursor position, etc.)
    func saveDraftMetadata(_ metadata: DraftMetadata, for documentURL: URL) throws {
        try ensureDraftsDirectory(for: documentURL)
        let metaURL = metadataFileURL(for: documentURL)
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        try data.write(to: metaURL)
    }

    /// Load draft metadata
    func loadDraftMetadata(for documentURL: URL) -> DraftMetadata? {
        let metaURL = metadataFileURL(for: documentURL)
        guard fileManager.fileExists(atPath: metaURL.path),
              let data = try? Data(contentsOf: metaURL) else { return nil }

        let decoder = JSONDecoder()
        return try? decoder.decode(DraftMetadata.self, from: data)
    }
}

// MARK: - Draft Metadata

struct DraftMetadata: Codable {
    let lastModified: Date
    let cursorPosition: Int?
    let scrollPosition: Double?

    init(lastModified: Date = Date(), cursorPosition: Int? = nil, scrollPosition: Double? = nil) {
        self.lastModified = lastModified
        self.cursorPosition = cursorPosition
        self.scrollPosition = scrollPosition
    }
}