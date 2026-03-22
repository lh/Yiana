#if os(macOS)
import SwiftUI
import PDFKit

struct ComposeTab: View {
    let documentId: String
    @State private var viewModel = ComposeViewModel()
    @State private var hasLoaded = false
    @StateObject private var repository = AddressRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recipient summary
            if !viewModel.patientName.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        recipientRow("To", viewModel.patientName)
                        if !viewModel.gpName.isEmpty {
                            recipientRow("CC", viewModel.gpName)
                        }
                    }
                    .padding(4)
                }
            }

            // Body text
            Text("Letter Body")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $viewModel.bodyText)
                .font(.body)
                .frame(minHeight: 150)
                .border(Color(NSColor.separatorColor), width: 1)

            // Status and actions
            HStack {
                statusBadge
                Spacer()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Action buttons
            HStack {
                if viewModel.status == .rendered {
                    Button("New Letter") {
                        viewModel.newLetter()
                    }
                }

                Button("Generate Letter") {
                    Task { await viewModel.sendToPrint() }
                }
                .disabled(!viewModel.canSend || viewModel.isSaving)
                .buttonStyle(.borderedProminent)
            }

            // Rendered PDF actions
            renderedPDFActions
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            // Cache iCloud URL on main thread — returns nil from Task.detached
            LetterRepository.shared.cacheContainerURL()
            SenderConfigService.shared.cacheContainerURL()
            let docId = documentId
            let addresses = await Task.detached { [repository] in
                (try? await repository.addresses(forDocument: docId)) ?? []
            }.value
            viewModel.initFromDocument(documentId: documentId, addresses: addresses)
            await viewModel.loadExistingDraft()
        }
    }

    private func recipientRow(_ role: String, _ name: String) -> some View {
        HStack(spacing: 6) {
            Text(role)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(name)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var renderedPDFActions: some View {
        if viewModel.status == .rendered {
            let pdfs = viewModel.getRenderedPDFs()
            if !pdfs.isEmpty {
                Divider()
                ForEach(pdfs, id: \.lastPathComponent) { url in
                    HStack {
                        Button(pdfLabel(url)) {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.link)
                    }
                }
                Button("Print All") {
                    printRenderedPDFs(pdfs)
                }
            }
        }
    }

    private func pdfLabel(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        if name.hasSuffix("_patient_copy") { return "Patient copy" }
        if name.hasSuffix("_hospital_records") { return "Hospital records" }
        if name.contains("_to_") {
            let parts = name.components(separatedBy: "_to_")
            if let recipient = parts.last {
                return "To: " + recipient.replacingOccurrences(of: "_", with: " ")
            }
        }
        return name
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = switch viewModel.status {
        case .draft: ("Draft", .secondary)
        case .renderRequested: ("Rendering...", .orange)
        case .rendered: ("Ready", .green)
        }
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(color)
        }
    }

    private func printRenderedPDFs(_ urls: [URL]) {
        guard let first = urls.first,
              let pdfDoc = PDFDocument(url: first) else { return }
        let printInfo = NSPrintInfo.shared
        let operation = pdfDoc.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true)
        operation?.runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }
}
#endif
