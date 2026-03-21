import Foundation
import Testing
@testable import YianaRenderer

struct LetterRendererTests {

    private func sampleInput() -> LetterRenderInput {
        let sender = SenderInfo(
            name: "Mr Luke Herbert MBBS BSc FRCOphth",
            credentials: "FRCOphth",
            role: "Consultant Ophthalmologist",
            department: "",
            hospital: "Gatwick Park Hospital",
            address: ["Povey Cross Road", "Horley", "Surrey", "RH6 0BB"],
            phone: "0207 8849411",
            email: "referrals@vitygas.com",
            secretary: SenderInfo.SecretaryInfo(
                name: "Mrs Liz Matthews",
                phone: "020 7884 9411",
                email: "referrals@vitygas.com"
            )
        )

        let patient = PatientInfo(
            name: "Mr Fiction Fictional",
            dob: "20/05/1960",
            mrn: "0012386780",
            address: ["87 Riverside Road", "Bluehill", "RH9 5EE"],
            phones: ["07956303735"]
        )

        let recipients: [RecipientInfo] = [
            RecipientInfo(
                role: "to", source: "patient",
                name: "Mr Fiction Fictional",
                address: ["87 Riverside Road", "Bluehill", "RH9 5EE"]
            ),
            RecipientInfo(
                role: "cc", source: "gp",
                name: "Dr J Shaw", practice: "Thornton Surgery",
                address: ["12 Thornton Side", "RH1 2NP"]
            ),
            RecipientInfo(
                role: "hospital_records", source: "implicit",
                name: "Hospital Records",
                address: []
            ),
        ]

        return LetterRenderInput(
            sender: sender,
            patient: patient,
            recipients: recipients,
            body: "It was a pleasure to meet you in clinic today. Your vision measured 6/5 in both eyes. Your pressures were normal. I do not recommend any further follow-up.",
            yianaTarget: "Fictional_Fiction_200560",
            letterId: "test-letter-001"
        )
    }

    @Test func rendersAllRecipients() throws {
        let renderer = LetterRenderer()
        let results = try renderer.render(input: sampleInput())

        #expect(results.count == 3)
    }

    @Test func producesValidPDFs() throws {
        let renderer = LetterRenderer()
        let results = try renderer.render(input: sampleInput())

        for result in results {
            #expect(result.pdfData.count > 5000, "PDF should be > 5KB, got \(result.pdfData.count)")
            let prefix = Array(result.pdfData.prefix(5))
            #expect(prefix == Array("%PDF-".utf8), "Output should start with %PDF-")
        }
    }

    @Test func correctFilenames() throws {
        let renderer = LetterRenderer()
        let results = try renderer.render(input: sampleInput())

        let filenames = results.map(\.filename)
        #expect(filenames.contains(where: { $0.contains("patient_copy") }))
        #expect(filenames.contains(where: { $0.contains("hospital_records") }))
        #expect(filenames.contains(where: { $0.contains("to_Dr_J_Shaw") }))
    }

    @Test func correctRecipientRoles() throws {
        let renderer = LetterRenderer()
        let results = try renderer.render(input: sampleInput())

        let roles = Set(results.map(\.recipientRole))
        #expect(roles == Set(["to", "cc", "hospital_records"]))
    }

    @Test func allCopiesAreDistinct() throws {
        let renderer = LetterRenderer()
        let results = try renderer.render(input: sampleInput())

        // Each recipient should get a different PDF (different address blocks, font sizes)
        let sizes = results.map(\.pdfData.count)
        // At least 2 distinct sizes (patient copy differs from others)
        #expect(Set(sizes).count >= 2, "Expected distinct PDFs, got sizes: \(sizes)")
    }
}
