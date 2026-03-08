//
//  WorkListEntry.swift
//  Yiana
//

import Foundation

enum WorkListEntrySource: String, Codable {
    case yiale
    case manual
    case document
}

struct WorkListEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var searchText: String
    var resolvedFilename: String?
    let source: WorkListEntrySource
    let added: String
    var yialeMRN: String?

    var displayText: String {
        resolvedFilename?.replacingOccurrences(of: "_", with: " ") ?? searchText
    }
}

struct YianaWorkList: Codable {
    var modified: String
    var entries: [WorkListEntry]
}
