import Foundation
import YianaRenderer

class LetterRenderService {
    static let shared = LetterRenderService()

    private let renderer = LetterRenderer()
    private let repository = LetterRepository.shared

    /// Render a draft locally and write PDFs to iCloud.
    /// - Rendered PDFs go to `.letters/rendered/{letterId}/`
    /// - Hospital records copy goes to `.letters/inject/{yianaTarget}_{letterId}.pdf`
    func renderAndDeliver(draft: LetterDraft, sender: SenderConfig) async throws {
        let input = buildInput(draft: draft, sender: sender)

        let rendered = try await Task.detached { [renderer] in
            try renderer.render(input: input)
        }.value

        try await Task.detached { [repository] in
            // Write all PDFs to rendered/{letterId}/
            let renderedDir = try repository.renderedDirectory(letterId: draft.letterId)
            let fm = FileManager.default
            try fm.createDirectory(at: renderedDir, withIntermediateDirectories: true)

            for letter in rendered {
                let url = renderedDir.appendingPathComponent(letter.filename)
                try letter.pdfData.write(to: url, options: .atomic)
            }

            // Copy hospital_records PDF to inject/ for InjectWatcher
            if let hospitalCopy = rendered.first(where: { $0.recipientRole == "hospital_records" }),
               let injectDir = repository.injectDirectory {
                try fm.createDirectory(at: injectDir, withIntermediateDirectories: true)
                let injectFilename = "\(draft.yianaTarget)_\(draft.letterId).pdf"
                let injectURL = injectDir.appendingPathComponent(injectFilename)
                try hospitalCopy.pdfData.write(to: injectURL, options: .atomic)
            }
        }.value
    }

    private func buildInput(draft: LetterDraft, sender: SenderConfig) -> LetterRenderInput {
        let senderInfo = SenderInfo(
            name: sender.name,
            credentials: sender.credentials,
            role: sender.role,
            department: sender.department,
            hospital: sender.hospital,
            address: sender.address,
            phone: sender.phone,
            email: sender.email,
            secretary: sender.secretary.map {
                SenderInfo.SecretaryInfo(name: $0.name, phone: $0.phone, email: $0.email)
            }
        )

        let patientInfo = PatientInfo(
            name: draft.patient.name,
            dob: draft.patient.dob,
            mrn: draft.patient.mrn,
            address: draft.patient.address,
            phones: draft.patient.phones
        )

        let recipientInfos = draft.recipients.map { r in
            RecipientInfo(
                role: r.role,
                source: r.source,
                name: r.name,
                practice: r.practice,
                address: r.address
            )
        }

        return LetterRenderInput(
            sender: senderInfo,
            patient: patientInfo,
            recipients: recipientInfos,
            body: draft.body,
            yianaTarget: draft.yianaTarget,
            letterId: draft.letterId
        )
    }
}
