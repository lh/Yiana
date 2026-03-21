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
        // Find prime GP
        let primeGP = addresses.first {
            $0.isPrime == true && $0.typedAddressType == .gp
        }

        if let p = primePatient {
            patientName = p.fullName ?? "Unknown Patient"
            patient = LetterPatient(
                name: p.fullName ?? "",
                dob: p.dateOfBirth ?? "",
                mrn: "",
                address: [p.addressLine1, p.addressLine2, p.city, p.postcode]
                    .compactMap { $0 }.filter { !$0.isEmpty },
                phones: [p.phoneHome, p.phoneWork, p.phoneMobile]
                    .compactMap { $0 }.filter { !$0.isEmpty }
            )

            // Patient is always the primary recipient (To)
            recipients.append(LetterRecipient(
                role: "to",
                source: "patient",
                name: p.fullName ?? "",
                address: [p.addressLine1, p.addressLine2, p.city, p.postcode]
                    .compactMap { $0 }.filter { !$0.isEmpty }
            ))
        }

        if let gp = primeGP {
            gpName = gp.gpName ?? "Unknown GP"
            // GP is always CC
            recipients.append(LetterRecipient(
                role: "cc",
                source: "gp",
                name: gp.gpName ?? "",
                practice: gp.gpPractice,
                address: [gp.gpAddress, gp.gpPostcode]
                    .compactMap { $0 }.filter { !$0.isEmpty }
            ))
        }

        // Implicit hospital_records recipient — render service uses this
        // to produce the PDF that InjectWatcher appends to the document
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

    /// Save and request rendering.
    func sendToPrint() async {
        await saveDraft()
        guard let id = letterId, errorMessage == nil else { return }

        do {
            let draft = try await Task.detached { [repository] in
                let drafts = try repository.listDrafts()
                return drafts.first { $0.letterId == id }
            }.value

            guard var draftToRender = draft else {
                errorMessage = "Draft not found after save"
                return
            }

            try await Task.detached { [repository] in
                try repository.requestRender(&draftToRender)
            }.value
            status = .renderRequested
        } catch {
            errorMessage = "Send failed: \(error.localizedDescription)"
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
        canSave && status == .draft
    }
}
