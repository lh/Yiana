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
