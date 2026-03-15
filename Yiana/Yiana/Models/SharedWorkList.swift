//
//  SharedWorkList.swift
//  Yiana
//
//  Unified work list model shared between Yiana and Yiale via .worklist.json.
//  Duplicated in both apps (no shared package).

import Foundation

struct SharedWorkList: Codable {
    var modified: String  // ISO8601
    var items: [SharedWorkListItem]
}

struct SharedWorkListItem: Codable, Identifiable, Equatable {
    let id: String          // MRN for clinic list items, UUID string for document/manual
    var mrn: String?
    var surname: String?
    var firstName: String?
    var gender: String?
    var age: Int?
    var doctor: String?
    var resolvedFilename: String?  // set by Yiana when matched to a .yianazip
    var source: String             // "clinic_list", "document", "manual"
    let added: String              // ISO8601

    /// Normalized name components for matching against patient names.
    var nameKey: Set<String> {
        var keys = Set<String>()
        if let s = surname, !s.isEmpty { keys.insert(s.lowercased()) }
        if let f = firstName, !f.isEmpty { keys.insert(f.lowercased()) }
        return keys
    }

    /// Human-readable display text.
    var displayText: String {
        if let filename = resolvedFilename {
            return filename.replacingOccurrences(of: "_", with: " ")
        }
        let parts = [surname, firstName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? id : parts.joined(separator: ", ")
    }
}
