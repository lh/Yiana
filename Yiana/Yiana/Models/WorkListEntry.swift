//
//  WorkListEntry.swift
//  Yiana
//
//  Legacy types replaced by SharedWorkList. This file kept for migration support.

import Foundation

/// Legacy work list format (pre-unification). Used only for one-time migration.
struct LegacyWorkListEntry: Codable, Identifiable {
    let id: UUID
    var searchText: String
    var resolvedFilename: String?
    let source: String
    let added: String
    var yialeMRN: String?
}

struct LegacyYianaWorkList: Codable {
    var modified: String
    var entries: [LegacyWorkListEntry]
}
