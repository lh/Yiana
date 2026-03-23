import Foundation

@Observable
class ComposeViewModel {
    var bodyText: String = ""
    var status: LetterStatus = .draft
    var letterId: String?
    var isSaving: Bool = false
    var errorMessage: String?

    // Auto-filled from document context (read-only display)
    var patientName: String = ""
    var gpName: String = ""
    var documentId: String = ""

    // Private state for building the draft
    private var patient: LetterPatient?
    private var recipients: [LetterRecipient] = []

    private let repository = LetterRepository.shared

    /// Initialize from a document's extracted addresses.
    /// Auto-selects prime patient (To) and prime GP (CC).
    func initFromDocument(documentId: String, addresses: [ExtractedAddress]) {
        self.documentId = documentId

        // Find prime patient
        let primePatient = addresses.first {
            $0.isPrime == true && $0.typedAddressType == .patient
        }

        if let p = primePatient {
            patientName = p.fullName ?? "Unknown Patient"
            patient = LetterPatient(
                name: p.fullName ?? "",
                dob: p.dateOfBirth ?? "",
                mrn: p.mrn ?? "",
                address: [p.addressLine1, p.addressLine2, p.city, p.postcode]
                    .compactMap { $0 }.filter { !$0.isEmpty },
                phones: [p.phoneHome, p.phoneWork, p.phoneMobile]
                    .compactMap { $0 }.filter { !$0.isEmpty }
            )
        }

        // Build recipients from verified address cards with recipient roles
        for addr in addresses where addr.isDismissed != true && addr.isPrime == true {
            let role = addr.recipientRole ?? "none"
            guard role != "none" else { continue }

            if addr.typedAddressType == .patient {
                recipients.append(LetterRecipient(
                    role: role,
                    source: "patient",
                    name: addr.fullName ?? "",
                    address: [addr.addressLine1, addr.addressLine2, addr.city, addr.postcode]
                        .compactMap { $0 }.filter { !$0.isEmpty }
                ))
            } else if addr.typedAddressType == .gp {
                if gpName.isEmpty { gpName = addr.gpName ?? "Unknown GP" }
                recipients.append(LetterRecipient(
                    role: role,
                    source: "gp",
                    name: addr.gpName ?? "",
                    practice: addr.gpPractice,
                    address: [addr.gpAddress, addr.gpPostcode]
                        .compactMap { $0 }.filter { !$0.isEmpty }
                ))
            }
        }

        // Implicit hospital_records recipient
        recipients.append(LetterRecipient(
            role: "hospital_records",
            source: "implicit",
            name: "Hospital Records"
        ))
    }

    /// Load an existing draft for this document, if one exists.
    func loadExistingDraft() async {
        let captured = documentId
        guard !captured.isEmpty else { return }

        let drafts = await Task.detached { [repository] in
            try? repository.listDrafts()
        }.value ?? []

        if let existing = drafts.first(where: { $0.yianaTarget == captured }) {
            letterId = existing.letterId
            bodyText = existing.body
            status = existing.status

            // Update recipient display from the draft
            if !existing.patient.name.isEmpty {
                patientName = existing.patient.name
            }
            let gpRecipient = existing.recipients.first { $0.role == "cc" && $0.source == "gp" }
            if let gp = gpRecipient {
                gpName = gp.name
            }

            // Check if rendered
            if status == .renderRequested {
                let rendered = repository.renderedOutputExists(letterId: existing.letterId)
                if rendered {
                    status = .rendered
                }
            }
        }
    }

    /// Save the current state as a draft.
    func saveDraft() async {
        guard !isSaving else { return }
        guard let patient else {
            errorMessage = "No patient selected"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let draft: LetterDraft
        if let existingId = letterId {
            let now = ISO8601DateFormatter().string(from: Date())
            draft = LetterDraft(
                letterId: existingId,
                created: now,
                modified: now,
                status: .draft,
                yianaTarget: documentId,
                patient: patient,
                recipients: recipients,
                body: bodyText
            )
        } else {
            draft = LetterDraft.new(
                yianaTarget: documentId,
                patient: patient,
                recipients: recipients,
                body: bodyText
            )
            letterId = draft.letterId
        }

        let draftToSave = draft
        do {
            try await Task.detached { [repository] in
                try repository.save(draftToSave)
            }.value
            status = .draft
            errorMessage = nil
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    /// Save and render locally via Typst.
    func sendToPrint() async {
        await saveDraft()
        guard let id = letterId, errorMessage == nil else { return }

        let sender: SenderConfig
        do {
            let loaded = try await Task.detached {
                try SenderConfigService.shared.load()
            }.value
            guard let s = loaded else {
                errorMessage = "Sender config not found"
                return
            }
            sender = s
        } catch {
            errorMessage = "Failed to load sender config: \(error.localizedDescription)"
            return
        }

        status = .renderRequested

        do {
            let draft = try await Task.detached { [repository] in
                let drafts = try repository.listDrafts()
                return drafts.first { $0.letterId == id }
            }.value

            guard let draftToRender = draft else {
                errorMessage = "Draft not found after save"
                return
            }

            try await LetterRenderService.shared.renderAndDeliver(
                draft: draftToRender,
                sender: sender
            )
            status = .rendered
        } catch {
            errorMessage = "Render failed: \(error.localizedDescription)"
            status = .draft
        }
    }

    /// Get rendered PDF URLs for the current draft.
    func getRenderedPDFs() -> [URL] {
        guard let id = letterId else { return [] }
        return (try? repository.renderedPDFs(letterId: id)) ?? []
    }

    var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && patient != nil
    }

    var canSend: Bool {
        canSave && (status == .draft || status == .rendered)
    }

    /// Reset for a new letter, keeping patient/recipient context.
    func newLetter() {
        bodyText = ""
        letterId = nil
        status = .draft
        errorMessage = nil
    }
}
