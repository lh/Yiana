#if os(macOS)
import SwiftUI
import PDFKit

struct MacPDFViewer: View {
    @ObservedObject var viewModel: DocumentViewModel
    var legacyPDFData: Data?

    @Binding var currentPage: Int
    @Binding var navigateToPage: Int?
    @Binding var pdfDocument: PDFDocument?
    var refreshTrigger: UUID

    @State private var pageInputText: String = ""
    @State private var showingPageInput = false
    @State private var zoomAction: PDFZoomAction?
    @State private var fitMode: FitMode = .width

    private var currentPDFData: Data? {
        viewModel.displayPDFData ?? viewModel.pdfData ?? legacyPDFData
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            pdfContent
        }
        .task {
            resetPDFDocument()
        }
        .onChange(of: refreshTrigger) { _, _ in
            resetPDFDocument()
        }
        .onChange(of: currentPDFData) { _, _ in
            resetPDFDocument()
        }
        .onExitCommand {
            if showingPageInput {
                showingPageInput = false
                pageInputText = ""
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        let pageCount = pdfDocument?.pageCount ?? 0
        return HStack(spacing: 0) {
            Spacer()
                .frame(maxWidth: .infinity)

            HStack(spacing: 2) {
                pageNavPrevButton(pageCount: pageCount)
                pageNavDisplay(pageCount: pageCount, showPagePrefix: false)
                pageNavNextButton(pageCount: pageCount)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
            )

            HStack {
                Spacer()
                HStack(spacing: 4) {
                    zoomOutButton
                    zoomInButton
                    fitToggleButton
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - PDF Content

    @ViewBuilder
    private var pdfContent: some View {
        if let pdfData = currentPDFData {
            PDFViewer(
                pdfData: pdfData,
                navigateToPage: $navigateToPage,
                currentPage: $currentPage,
                zoomAction: $zoomAction,
                fitMode: $fitMode
            )
        }
    }

    // MARK: - Navigation Controls

    private func pageNavPrevButton(pageCount: Int) -> some View {
        Button {
            if currentPage > 0 {
                navigateToPage = currentPage - 1
            }
        } label: {
            Image(systemName: "chevron.left")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .disabled(currentPage <= 0)
        .help("Previous Page")
        .toolbarActionAccessibility(label: "Previous page", keyboardShortcut: "Arrow left")
        .accessibilityValue("Page \(currentPage + 1) of \(pageCount)")
    }

    @ViewBuilder
    private func pageNavDisplay(pageCount: Int, showPagePrefix: Bool = true) -> some View {
        if showingPageInput {
            HStack(spacing: 4) {
                TextField("", text: $pageInputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .onSubmit {
                        if let pageNum = Int(pageInputText),
                           pageNum > 0,
                           pageNum <= pageCount {
                            navigateToPage = pageNum - 1
                        }
                        showingPageInput = false
                        pageInputText = ""
                    }
                    .accessibilityLabel("Page number")
                Text("of \(pageCount)")
                    .foregroundColor(.secondary)
            }
        } else {
            Button {
                showingPageInput = true
                pageInputText = "\(currentPage + 1)"
            } label: {
                Text(showPagePrefix ? "Page \(currentPage + 1) of \(pageCount)" : "\(currentPage + 1) of \(pageCount)")
                    .foregroundColor(.secondary)
                    .font(.system(size: showPagePrefix ? 13 : 12))
            }
            .buttonStyle(.borderless)
            .help("Click to jump to page")
            .toolbarActionAccessibility(label: "Jump to page")
        }
    }

    private func pageNavNextButton(pageCount: Int) -> some View {
        Button {
            if currentPage < pageCount - 1 {
                navigateToPage = currentPage + 1
            }
        } label: {
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .disabled(currentPage >= pageCount - 1)
        .help("Next Page")
        .toolbarActionAccessibility(label: "Next page", keyboardShortcut: "Arrow right")
        .accessibilityValue("Page \(currentPage + 1) of \(pageCount)")
    }

    // MARK: - Zoom Controls

    private var zoomOutButton: some View {
        Button { zoomAction = .zoomOut } label: {
            Image(systemName: "minus.magnifyingglass")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Zoom Out")
        .keyboardShortcut("-", modifiers: .command)
        .toolbarActionAccessibility(label: "Zoom out", keyboardShortcut: "Command minus")
    }

    private var zoomInButton: some View {
        Button { zoomAction = .zoomIn } label: {
            Image(systemName: "plus.magnifyingglass")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Zoom In")
        .keyboardShortcut("+", modifiers: .command)
        .toolbarActionAccessibility(label: "Zoom in", keyboardShortcut: "Command plus")
    }

    private var fitToggleButton: some View {
        Button {
            fitMode = fitMode == .height ? .width : .height
            zoomAction = .fitToWindow
        } label: {
            Image(systemName: fitMode == .height ? "arrow.up.and.down" : "arrow.left.and.right")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help(fitMode == .height ? "Fit Height (click for Fit Width)" : "Fit Width (click for Fit Height)")
        .keyboardShortcut("0", modifiers: .command)
        .toolbarActionAccessibility(label: fitMode == .height ? "Fit height" : "Fit width")
    }

    // MARK: - PDF Reset

    private func resetPDFDocument() {
        guard let data = currentPDFData, let doc = PDFDocument(data: data) else {
            pdfDocument = nil
            return
        }
        pdfDocument = doc
        if currentPage >= doc.pageCount {
            currentPage = max(0, doc.pageCount - 1)
        }
    }
}

struct ThumbnailView: View {
    let page: PDFPage?
    let pageNumber: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let thumbnail = generateThumbnail() {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                                   lineWidth: isSelected ? 1.5 : 0.5)
                    )
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
            }

            Text("Page \(pageNumber)")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    private func generateThumbnail() -> NSImage? {
        guard let page else { return nil }
        let scale: CGFloat = 2.0
        let thumbnailWidth: CGFloat = 250 * scale
        let pageRect = page.bounds(for: .mediaBox)
        let aspectRatio = pageRect.height / pageRect.width
        let thumbnailHeight = thumbnailWidth * aspectRatio
        let size = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
#endif
