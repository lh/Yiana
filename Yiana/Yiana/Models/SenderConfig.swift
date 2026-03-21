import Foundation

struct Secretary: Codable {
    var name: String
    var phone: String
    var email: String
}

struct SenderConfig: Codable {
    var name: String
    var credentials: String
    var role: String
    var department: String
    var hospital: String
    var address: [String]
    var phone: String
    var email: String
    var secretary: Secretary?
}
