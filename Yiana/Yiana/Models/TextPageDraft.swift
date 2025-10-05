//
//  TextPageDraft.swift
//  Yiana
//
//  Model for text page drafts that will be rendered to PDF
//

import Foundation

/// Represents a text page draft that will be rendered to PDF
struct TextPageDraft: Codable {
    /// The markdown text content
    var text: String

    /// When the draft was created
    let created: Date

    /// When the draft was last modified
    var lastModified: Date

    /// Optional session identifier for future multi-page support
    let sessionId: String

    init(text: String = "", sessionId: String? = nil) {
        self.text = text
        self.created = Date()
        self.lastModified = Date()
        self.sessionId = sessionId ?? UUID().uuidString
    }

    mutating func updateText(_ newText: String) {
        self.text = newText
        self.lastModified = Date()
    }
}