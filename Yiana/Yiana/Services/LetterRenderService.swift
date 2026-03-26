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

        // Also render envelopes
        let envelopes = try await Task.detached { [renderer] in
            try renderer.renderEnvelopes(input: input)
        }.value

        try await Task.detached { [repository] in
            let renderedDir = try repository.renderedDirectory(letterId: draft.letterId)
            let fm = FileManager.default
            try fm.createDirectory(at: renderedDir, withIntermediateDirectories: true)

            // Write letter PDFs
            for letter in rendered {
                let url = renderedDir.appendingPathComponent(letter.filename)
                try letter.pdfData.write(to: url, options: .atomic)
            }

            // Write envelope PDFs
            for envelope in envelopes {
                let url = renderedDir.appendingPathComponent(envelope.filename)
                try envelope.pdfData.write(to: url, options: .atomic)
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
            name: draft.patient.name.displayTitleCased,
            dob: draft.patient.dob,
            mrn: draft.patient.mrn,
            address: draft.patient.address.map(\.displayTitleCased),
            phones: draft.patient.phones
        )

        let recipientInfos = draft.recipients.map { r in
            RecipientInfo(
                role: r.role,
                source: r.source,
                name: r.name.displayTitleCased,
                practice: r.practice?.displayTitleCased,
                address: r.address.map(\.displayTitleCased)
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
