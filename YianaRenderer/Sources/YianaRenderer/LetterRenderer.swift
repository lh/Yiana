import Foundation

// MARK: - Public Types

/// A rendered letter PDF for one recipient.
public struct RenderedLetter: Sendable {
    public let recipientRole: String
    public let recipientName: String
    public let pdfData: Data
    public let filename: String
}

/// Sender configuration for letter rendering.
public struct SenderInfo: Codable, Sendable {
    public var name: String
    public var credentials: String
    public var role: String
    public var department: String
    public var hospital: String
    public var address: [String]
    public var phone: String
    public var email: String
    public var secretary: SecretaryInfo?

    public struct SecretaryInfo: Codable, Sendable {
        public var name: String
        public var phone: String
        public var email: String
    }
}

/// Patient information for letter rendering.
public struct PatientInfo: Codable, Sendable {
    public var name: String
    public var dob: String
    public var mrn: String
    public var address: [String]
    public var phones: [String]
}

/// Recipient information for letter rendering.
public struct RecipientInfo: Codable, Sendable {
    public var role: String
    public var source: String
    public var name: String
    public var practice: String?
    public var address: [String]
}

/// All data needed to render a letter.
public struct LetterRenderInput: Sendable {
    public var sender: SenderInfo
    public var patient: PatientInfo
    public var recipients: [RecipientInfo]
    public var body: String
    public var yianaTarget: String
    public var letterId: String

    public init(
        sender: SenderInfo, patient: PatientInfo,
        recipients: [RecipientInfo], body: String,
        yianaTarget: String, letterId: String
    ) {
        self.sender = sender
        self.patient = patient
        self.recipients = recipients
        self.body = body
        self.yianaTarget = yianaTarget
        self.letterId = letterId
    }
}

// MARK: - Renderer

/// Renders clinical letters to PDF using Typst.
public final class LetterRenderer: Sendable {

    public init() {}

    /// Render a letter for all recipients.
    /// Returns one PDF per recipient.
    public func render(input: LetterRenderInput) throws -> [RenderedLetter] {
        let templateData = try loadTemplate()
        var results: [RenderedLetter] = []

        for (index, recipient) in input.recipients.enumerated() {
            let isPatientCopy = recipient.role == "to"

            let data: [String: Any] = [
                "sender": encodeSender(input.sender),
                "patient": encodePatient(input.patient),
                "recipient": encodeRecipient(recipient),
                "all_recipients": input.recipients.map { encodeRecipient($0) },
                "body": input.body,
                "is_patient_copy": isPatientCopy,
                "recipient_index": index,
            ]

            let dataJSON = try JSONSerialization.data(withJSONObject: data)
            let dataString = String(data: dataJSON, encoding: .utf8) ?? "{}"

            let inputs: [String: Any] = ["data": dataString]
            let pdfData = try TypstBridge.compile(template: templateData, inputs: inputs)

            let filename = buildFilename(
                patient: input.patient,
                recipient: recipient
            )

            results.append(RenderedLetter(
                recipientRole: recipient.role,
                recipientName: recipient.name,
                pdfData: pdfData,
                filename: filename
            ))
        }

        return results
    }

    // MARK: - Private

    private func loadTemplate() throws -> Data {
        guard let url = Bundle.module.url(forResource: "letter", withExtension: "typ") else {
            throw TypstError.invalidTemplate
        }
        return try Data(contentsOf: url)
    }

    private func buildFilename(patient: PatientInfo, recipient: RecipientInfo) -> String {
        let nameParts = patient.name
            .replacingOccurrences(of: "Mr ", with: "")
            .replacingOccurrences(of: "Mrs ", with: "")
            .replacingOccurrences(of: "Ms ", with: "")
            .replacingOccurrences(of: "Miss ", with: "")
            .replacingOccurrences(of: "Dr ", with: "")
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }

        let surname = nameParts.last ?? "Unknown"
        let firstName = nameParts.count > 1 ? nameParts.dropLast().joined(separator: "_") : ""
        let base = firstName.isEmpty ? surname : "\(surname)_\(firstName)"
        let mrn = patient.mrn.isEmpty ? "" : "_\(patient.mrn)"

        let suffix: String
        switch recipient.role {
        case "to":
            suffix = "_patient_copy"
        case "hospital_records":
            suffix = "_hospital_records"
        default:
            let recipientName = sanitize(recipient.name)
            suffix = "_to_\(recipientName)"
        }

        return "\(base)\(mrn)\(suffix).pdf"
    }

    private func sanitize(_ name: String) -> String {
        name.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private func encodeSender(_ s: SenderInfo) -> [String: Any] {
        var dict: [String: Any] = [
            "name": s.name,
            "credentials": s.credentials,
            "role": s.role,
            "department": s.department,
            "hospital": s.hospital,
            "address": s.address,
            "phone": s.phone,
            "email": s.email,
        ]
        if let sec = s.secretary {
            dict["secretary"] = [
                "name": sec.name,
                "phone": sec.phone,
                "email": sec.email,
            ]
        }
        return dict
    }

    private func encodePatient(_ p: PatientInfo) -> [String: Any] {
        [
            "name": p.name,
            "dob": p.dob,
            "mrn": p.mrn,
            "address": p.address,
            "phones": p.phones,
        ]
    }

    private func encodeRecipient(_ r: RecipientInfo) -> [String: Any] {
        var dict: [String: Any] = [
            "role": r.role,
            "source": r.source,
            "name": r.name,
            "address": r.address,
        ]
        if let practice = r.practice {
            dict["practice"] = practice
        }
        return dict
    }
}
