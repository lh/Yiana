import SwiftUI

@Observable
final class ComposeViewModel {
    // Patient data
    var selectedPatient: ResolvedPatient?
    var patientName: String = ""
    var patientTitle: String?
    var patientDOB: String = ""
    var patientMRN: String = ""
    var patientAddress: [String] = []
    var patientPhones: [String] = []
    var yianaTarget: String = ""

    // Recipients
    var recipients: [LetterRecipient] = []

    // Letter body
    var body: String = ""

    // State
    var showAddressConfirmation = false
    var errorMessage: String?
    var isSaving = false

    // Existing draft being edited (nil for new letters)
    private(set) var existingDraft: LetterDraft?

    private let repository = LetterRepository()
    private let addressService = AddressSearchService()

    static let availableTitles = ["Mr", "Mrs", "Ms", "Miss", "Dr", "Prof"]

    /// Populate from a resolved patient.
    func selectPatient(_ patient: ResolvedPatient) {
        selectedPatient = patient
        patientName = patient.fullName
        patientTitle = patient.title
        patientDOB = patient.dateOfBirth ?? ""
        patientMRN = patient.mrn ?? ""
        patientAddress = patient.address
        patientPhones = patient.phones
        yianaTarget = patient.yianaTarget

        // Auto-add GP as recipient if available
        recipients = []
        if let gpName = patient.gpName, !gpName.isEmpty {
            var gpAddress: [String] = []
            if let addr = patient.gpAddress, !addr.isEmpty { gpAddress.append(addr) }
            if let pc = patient.gpPostcode, !pc.isEmpty { gpAddress.append(pc) }

            recipients.append(LetterRecipient(
                role: "gp",
                source: "extracted",
                name: gpName,
                practice: patient.gpPractice,
                address: gpAddress
            ))
        }

        // Auto-add patient as recipient
        recipients.append(LetterRecipient(
            role: "patient",
            source: "extracted",
            name: patient.fullName,
            address: patient.address
        ))
    }

    /// Populate from an existing draft for editing.
    func loadDraft(_ draft: LetterDraft) {
        existingDraft = draft
        patientName = draft.patient.name
        patientTitle = draft.patient.title
        patientDOB = draft.patient.dob
        patientMRN = draft.patient.mrn
        patientAddress = draft.patient.address
        patientPhones = draft.patient.phones
        yianaTarget = draft.yianaTarget
        recipients = draft.recipients
        body = draft.body
    }

    /// Build a LetterDraft from current state.
    func buildDraft() -> LetterDraft {
        let patient = LetterPatient(
            name: patientName,
            dob: patientDOB,
            mrn: patientMRN,
            address: patientAddress,
            phones: patientPhones,
            title: patientTitle
        )

        // Always include hospital_records as an implicit recipient
        var allRecipients = recipients
        if !allRecipients.contains(where: { $0.role == "hospital_records" }) {
            allRecipients.append(LetterRecipient(
                role: "hospital_records",
                source: "implicit",
                name: "Hospital Records"
            ))
        }

        if let existing = existingDraft {
            var draft = existing
            draft.patient = patient
            draft.recipients = allRecipients
            draft.body = body
            draft.yianaTarget = yianaTarget
            draft.modified = ISO8601DateFormatter().string(from: Date())
            return draft
        } else {
            return LetterDraft.new(
                yianaTarget: yianaTarget,
                patient: patient,
                recipients: allRecipients,
                body: body
            )
        }
    }

    /// Save draft to .letters/drafts/.
    func saveDraft() async {
        isSaving = true
        defer { isSaving = false }

        let draft = buildDraft()
        do {
            try await Task.detached {
                try LetterRepository().save(draft)
            }.value
            existingDraft = draft
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Request render: saves with status=render_requested.
    func requestRender() async {
        isSaving = true
        defer { isSaving = false }

        var draft = buildDraft()
        do {
            try await Task.detached {
                try LetterRepository().requestRender(&draft)
            }.value
            existingDraft = draft
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canSave: Bool {
        !patientName.isEmpty && !patientMRN.isEmpty && !body.isEmpty
    }

    var canSend: Bool {
        canSave && !recipients.isEmpty
    }
}
