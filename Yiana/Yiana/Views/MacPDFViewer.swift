//
//  MacPDFViewer.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

#if os(macOS)
import SwiftUI
import PDFKit

enum SidebarMode {
    case pages
    case addresses
}

struct MacPDFViewer: View {
    @ObservedObject var viewModel: DocumentViewModel
    var legacyPDFData: Data?  // optional fallback for read-only documents
    @Binding var isSidebarVisible: Bool
    var refreshTrigger: UUID  // force rebuild when changed

    @State private var currentPage: Int = 0
    @State private var pdfDocument: PDFDocument?
    @State private var navigateToPage: Int?
    @State private var pageInputText: String = ""
    @State private var showingPageInput = false
    @State private var zoomAction: PDFZoomAction?
    @State private var fitMode: FitMode = .width
    @State private var sidebarMode: SidebarMode = .pages
    var onRequestPageManagement: (() -> Void)?

    @AppStorage(UIVariant.storageKey) private var uiVariant: UIVariant = .current

    private var showAddressesInSidebar: Bool {
        AddressRepository.isDatabaseAvailable
    }

    // Computed property for current PDF data
    private var currentPDFData: Data? {
        viewModel.displayPDFData ?? viewModel.pdfData ?? legacyPDFData
    }

    // Get document ID for addresses
    private var documentId: String? {
        // Extract document ID from viewModel
        // This needs to match how AddressRepository expects it (filename without extension)
        // For now, use the title which typically contains the filename
        return viewModel.title
    }

    var body: some View {
        Group {
            switch uiVariant {
            case .current:
                v1Body
            case .v2:
                v2Body
            }
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

    // MARK: - V1 Body (Original)

    private var v1Body: some View {
        HSplitView {
            if isSidebarVisible {
                thumbnailSidebar(width: 250)
            }

            VStack(spacing: 0) {
                v1NavigationToolbar
                Divider()
                pdfContent
            }
        }
    }

    private var v1NavigationToolbar: some View {
        let pageCount = pdfDocument?.pageCount ?? 0
        return HStack {
            sidebarToggleButton

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            pageNavPrevButton(pageCount: pageCount)
            pageNavDisplay(pageCount: pageCount, showPagePrefix: true)
            pageNavNextButton(pageCount: pageCount)

            Spacer()

            HStack(spacing: 4) {
                zoomOutButton
                zoomInButton

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)

                fitPageButton
                fitWidthButton
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - V2 Body (Compact Toolbar)

    private var v2Body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                thumbnailSidebar(width: 120)
                Divider()
            }

            VStack(spacing: 0) {
                v2NavigationBar
                Divider()
                pdfContent
            }
        }
    }

    private var v2NavigationBar: some View {
        let pageCount = pdfDocument?.pageCount ?? 0
        return HStack(spacing: 0) {
            // Left column: sidebar toggle
            HStack {
                sidebarToggleButton
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Centre column: page navigator in pill (centred to window)
            HStack(spacing: 2) {
                pageNavPrevButton(pageCount: pageCount)
                pageNavDisplay(pageCount: pageCount, showPagePrefix: false)
                pageNavNextButton(pageCount: pageCount)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(Capsule())

            // Right column: zoom + fit toggle
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

    // MARK: - Shared Controls

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

    private var sidebarToggleButton: some View {
        Button {
            isSidebarVisible.toggle()
        } label: {
            Image(systemName: "sidebar.left")
                .foregroundColor(isSidebarVisible ? .accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
        .toolbarActionAccessibility(
            label: isSidebarVisible ? "Hide sidebar" : "Show sidebar",
            keyboardShortcut: "Control Command S"
        )
    }

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
        .help("Previous Page (← or ↑)")
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
                    .accessibilityValue("Currently on page \(currentPage + 1)")
                    .accessibilityHint("Enter a page number and press Return")
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
        .help("Next Page (→ or ↓)")
        .toolbarActionAccessibility(label: "Next page", keyboardShortcut: "Arrow right")
        .accessibilityValue("Page \(currentPage + 1) of \(pageCount)")
    }

    private var zoomOutButton: some View {
        Button {
            zoomAction = .zoomOut
        } label: {
            Image(systemName: "minus.magnifyingglass")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Zoom Out")
        .keyboardShortcut("-", modifiers: .command)
        .toolbarActionAccessibility(label: "Zoom out", keyboardShortcut: "Command minus")
    }

    private var zoomInButton: some View {
        Button {
            zoomAction = .zoomIn
        } label: {
            Image(systemName: "plus.magnifyingglass")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Zoom In")
        .keyboardShortcut("+", modifiers: .command)
        .toolbarActionAccessibility(label: "Zoom in", keyboardShortcut: "Command plus")
    }

    private var fitPageButton: some View {
        Button {
            fitMode = .height
            zoomAction = .fitToWindow
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Fit Page (⌘0)")
        .keyboardShortcut("0", modifiers: .command)
        .toolbarActionAccessibility(label: "Fit page", keyboardShortcut: "Command zero")
    }

    private var fitWidthButton: some View {
        Button {
            fitMode = .width
            zoomAction = .fitToWindow
        } label: {
            Image(systemName: "arrow.left.and.right")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Fit Width (⌘3)")
        .keyboardShortcut("3", modifiers: .command)
        .toolbarActionAccessibility(label: "Fit width", keyboardShortcut: "Command three")
    }

    /// V2 only: single toggle that cycles between fit-to-height and fit-to-width
    private var fitToggleButton: some View {
        Button {
            if fitMode == .height {
                fitMode = .width
            } else {
                fitMode = .height
            }
            zoomAction = .fitToWindow
        } label: {
            Image(systemName: fitMode == .height
                  ? "arrow.up.and.down"
                  : "arrow.left.and.right")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help(fitMode == .height ? "Fit Height (click for Fit Width)" : "Fit Width (click for Fit Height)")
        .keyboardShortcut("0", modifiers: .command)
        .toolbarActionAccessibility(label: fitMode == .height ? "Fit height" : "Fit width")
    }

    @ViewBuilder
    private func thumbnailSidebar(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Mode switcher at top (only show if addresses available)
            if showAddressesInSidebar {
                Picker("", selection: $sidebarMode) {
                    Text("Pages").tag(SidebarMode.pages)
                    Text("Addresses").tag(SidebarMode.addresses)
                }
                .pickerStyle(.segmented)
                .padding(8)
            }

            Divider()

            // Content based on mode
            switch sidebarMode {
            case .pages:
                pagesSidebarContent()
            case .addresses:
                addressesSidebarContent()
            }
        }
        .frame(width: width)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private func pagesSidebarContent() -> some View {
        if let document = pdfDocument {
            let pageIndices = Array(0..<document.pageCount)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(pageIndices, id: \.self) { pageIndex in
                            sidebarThumbnail(for: pageIndex)
                                .id(pageIndex)
                        }
                    }
                    .padding()
                    .id(refreshTrigger)  // Force refresh when trigger changes
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Page thumbnails")
                .accessibilityHint("Navigate pages using arrow keys")
                .onChange(of: currentPage) { _, newPage in
                    withAnimation {
                        scrollProxy.scrollTo(newPage, anchor: .center)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func addressesSidebarContent() -> some View {
        if let docId = documentId {
            AddressesView(documentId: docId)
                .padding(8)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No document loaded")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func sidebarThumbnail(for pageIndex: Int) -> some View {
        let page = pdfDocument?.page(at: pageIndex)
        let pageNumber = pageIndex + 1
        let isSelected = pageIndex == currentPage

        ThumbnailView(
            page: page,
            pageNumber: pageNumber,
            isSelected: isSelected
        )
        .pageThumbnailAccessibility(
            pageNumber: pageNumber,
            isSelected: isSelected,
            isCurrent: isSelected,
            isProvisional: false
        )
        .onTapGesture(count: 2) {
            guard isSidebarVisible else { return }
            onRequestPageManagement?()
        }
        .onTapGesture(count: 1) {
            guard isSidebarVisible else { return }
            navigateToPage = pageIndex
        }
    }

    private func resetPDFDocument() {
        guard let data = currentPDFData, let doc = PDFDocument(data: data) else {
            pdfDocument = nil
            return
        }
        pdfDocument = doc
        // Maintain current page position if valid
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
                    .frame(height: 120)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                                   lineWidth: isSelected ? 3 : 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 120)
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
        let thumbnailWidth: CGFloat = 150 * scale
        let pageRect = page.bounds(for: .mediaBox)
        let aspectRatio = pageRect.height / pageRect.width
        let thumbnailHeight = thumbnailWidth * aspectRatio
        let size = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
#endif
