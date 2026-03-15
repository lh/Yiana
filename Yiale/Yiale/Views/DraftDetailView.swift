import SwiftUI
import PDFKit

struct DraftDetailView: View {
    let draft: LetterDraft
    let onDismiss: () -> Void

    @State private var pdfURLs: [URL] = []
    @State private var selectedPDF: URL?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading rendered output...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if pdfURLs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No rendered PDFs found")
                        .foregroundStyle(.secondary)
                    if draft.status == .renderRequested {
                        Text("Waiting for Devon to process...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                pdfViewer
            }
        }
        .navigationTitle(draft.patient.name)
        .toolbar {
            if draft.status == .rendered && !pdfURLs.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Button {
                        printSelected()
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .disabled(selectedPDF == nil)
                    .help("Print selected PDF")
                }
                ToolbarItem(placement: .automatic) {
                    Button("Print All") {
                        printAll()
                    }
                    .help("Print all copies")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if draft.status == .rendered {
                    Button("Dismiss Letter") {
                        onDismiss()
                    }
                }
            }
        }
        .task {
            await loadPDFs()
        }
    }

    private var pdfViewer: some View {
        HSplitView {
            // PDF file list
            List(pdfURLs, id: \.self, selection: $selectedPDF) { url in
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .frame(width: 200)

            // PDF preview
            if let url = selectedPDF, let document = PDFDocument(url: url) {
                PDFPreview(document: document)
            } else {
                Text("Select a PDF to preview")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func printSelected() {
        guard let url = selectedPDF else { return }
        printPDFs([url])
    }

    private func printAll() {
        let urls = pdfURLs.filter { !$0.lastPathComponent.contains("hospital_records") }
        guard !urls.isEmpty else { return }
        printPDFs(urls)
    }

    private func printPDFs(_ urls: [URL]) {
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.scalingFactor = 1.0
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0

        let combined = PDFDocument()
        for url in urls {
            guard let doc = PDFDocument(url: url) else { continue }
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                combined.insert(page, at: combined.pageCount)
            }
        }

        guard combined.pageCount > 0,
              let window = NSApp.keyWindow else { return }

        let printOp = combined.printOperation(
            for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true
        )
        printOp?.showsPrintPanel = true
        printOp?.showsProgressPanel = true
        printOp?.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    private func loadPDFs() async {
        isLoading = true
        do {
            let letterId = draft.letterId
            let urls = try await Task.detached {
                try LetterRepository().renderedPDFs(letterId: letterId)
            }.value
            pdfURLs = urls
            selectedPDF = urls.first
        } catch {
            #if DEBUG
            print("[DraftDetail] Failed to load PDFs: \(error)")
            #endif
        }
        isLoading = false
    }
}

private struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
