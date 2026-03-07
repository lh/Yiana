import Foundation

struct WorkList: Codable {
    var modified: String  // ISO8601
    var items: [WorkListItem]
}

struct WorkListItem: Codable, Identifiable, Equatable {
    var id: String { mrn }
    let mrn: String
    let surname: String
    let firstName: String
    let gender: String?
    let age: Int?
    let doctor: String?
    let added: String  // ISO8601

    /// Normalized name components for matching against document filenames.
    /// Lowercased set of {surname, firstName} — order-independent.
    var nameKey: Set<String> {
        Set([surname.lowercased(), firstName.lowercased()])
    }
}
