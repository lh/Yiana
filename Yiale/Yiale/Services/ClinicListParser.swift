import Foundation

enum ClinicListParser {
    /// Parse pasted clinic list text into shared work list items.
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
    static func parse(_ text: String) -> [SharedWorkListItem] {
        let blocks = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let now = ISO8601DateFormatter().string(from: Date())
        let namePattern = #/^(.+?),\s*(.+?)\s*\((\w+),\s*(\d+)\)$/#

        var items: [SharedWorkListItem] = []
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

            items.append(SharedWorkListItem(
                id: mrnLine,
                mrn: mrnLine,
                surname: surname,
                firstName: firstName,
                gender: gender,
                age: age,
                doctor: doctor,
                source: "clinic_list",
                added: now
            ))
        }
        return items
    }
}
