import Foundation

enum LetterStatus: String, Codable {
    case draft
    case renderRequested = "render_requested"
    case rendered
}

struct LetterPatient: Codable {
    var name: String
    var dob: String
    var mrn: String
    var address: [String]
    var phones: [String]
    var title: String?

    init(name: String, dob: String, mrn: String, address: [String] = [], phones: [String] = [], title: String? = nil) {
        self.name = name
        self.dob = dob
        self.mrn = mrn
        self.address = address
        self.phones = phones
        self.title = title
    }
}

struct LetterRecipient: Codable, Identifiable {
    var id: UUID = UUID()
    var role: String
    var source: String
    var name: String
    var practice: String?
    var address: [String]

    init(role: String, source: String, name: String, practice: String? = nil, address: [String] = []) {
        self.role = role
        self.source = source
        self.name = name
        self.practice = practice
        self.address = address
    }

    private enum CodingKeys: String, CodingKey {
        case role, source, name, practice, address
    }
}

struct LetterDraft: Codable, Identifiable {
    var id: String { letterId }

    var letterId: String
    var created: String
    var modified: String
    var status: LetterStatus
    var yianaTarget: String
    var patient: LetterPatient
    var recipients: [LetterRecipient]
    var body: String
    var renderRequest: String?

    private enum CodingKeys: String, CodingKey {
        case letterId = "letter_id"
        case created
        case modified
        case status
        case yianaTarget = "yiana_target"
        case patient
        case recipients
        case body
        case renderRequest = "render_request"
    }

    static func new(
        yianaTarget: String,
        patient: LetterPatient,
        recipients: [LetterRecipient],
        body: String
    ) -> LetterDraft {
        let now = ISO8601DateFormatter().string(from: Date())
        return LetterDraft(
            letterId: UUID().uuidString.lowercased(),
            created: now,
            modified: now,
            status: .draft,
            yianaTarget: yianaTarget,
            patient: patient,
            recipients: recipients,
            body: body
        )
    }
}
