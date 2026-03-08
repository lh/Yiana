//
//  ClinicListParser.swift
//  Yiana
//

import Foundation

/// Intermediate result from parsing a clinic list line block.
/// Converted to `WorkListEntry` at the call site.
struct ClinicListItem {
    let mrn: String
    let surname: String
    let firstName: String
    let gender: String?
    let age: Int?
    let doctor: String?
}

enum ClinicListParser {
    /// Parse pasted clinic list text into intermediate items.
    ///
    /// Expected format per block (separated by blank lines):
    /// ```
    /// 0012684540
    /// Pearson, Bushra (F, 59)
    /// Doctor S Crispin
    /// ```
    ///
    /// Line 1: MRN (all digits)
    /// Line 2: Surname, Firstname (Gender, Age)
    /// Line 3 (optional): Doctor name
    static func parse(_ text: String) -> [ClinicListItem] {
        let blocks = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let namePattern = #/^(.+?),\s*(.+?)\s*\((\w+),\s*(\d+)\)$/#

        var items: [ClinicListItem] = []
        for block in blocks {
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard lines.count >= 2 else { continue }

            let mrnLine = lines[0]
            guard mrnLine.allSatisfy(\.isNumber), !mrnLine.isEmpty else { continue }

            guard let match = lines[1].firstMatch(of: namePattern) else { continue }

            let surname = String(match.1)
            let firstName = String(match.2)
            let gender = String(match.3)
            let age = Int(match.4)

            let doctor: String? = lines.count >= 3 ? lines[2] : nil

            items.append(ClinicListItem(
                mrn: mrnLine,
                surname: surname,
                firstName: firstName,
                gender: gender,
                age: age,
                doctor: doctor
            ))
        }
        return items
    }

    /// Convert parsed clinic list items to work list entries.
    static func toWorkListEntries(_ items: [ClinicListItem]) -> [WorkListEntry] {
        let now = ISO8601DateFormatter().string(from: Date())
        return items.map { item in
            WorkListEntry(
                id: UUID(),
                searchText: "\(item.surname) \(item.firstName)",
                resolvedFilename: nil,
                source: .yiale,
                added: now,
                yialeMRN: item.mrn
            )
        }
    }
}
