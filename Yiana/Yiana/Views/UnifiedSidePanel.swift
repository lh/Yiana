#if os(macOS)
import SwiftUI
import PDFKit

enum PanelTab: String, CaseIterable {
    case pages
    case addresses
    case compose
    case ocr
    case metadata
}

struct UnifiedSidePanel: View {
    let document: NoteDocument?
    let pdfDocument: PDFDocument?
    @Binding var selectedTab: PanelTab
    @Binding var currentPage: Int
    @Binding var navigateToPage: Int?
    let refreshTrigger: UUID
    let onRequestPageManagement: (() -> Void)?

    private var showAddressesTab: Bool {
        AddressRepository.isDatabaseAvailable
    }

    private var documentId: String {
        document?.metadata.title ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Pages").tag(PanelTab.pages)
                if showAddressesTab {
                    Text("Addresses").tag(PanelTab.addresses)
                }
                Text("Compose").tag(PanelTab.compose)
                Text("Text").tag(PanelTab.ocr)
                Text("Metadata").tag(PanelTab.metadata)
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch selectedTab {
            case .pages:
                pagesThumbnails
            case .addresses:
                ScrollView {
                    AddressesView(documentId: documentId)
                        .padding()
                }
            case .compose:
                ScrollView {
                    ComposeTab(documentId: documentId)
                        .padding()
                }
            case .ocr:
                if let document {
                    ScrollView {
                        OCRView(document: document, isLoading: .constant(false)) {}
                            .padding()
                    }
                }
            case .metadata:
                if let document {
                    ScrollView {
                        MetadataView(document: document)
                            .padding()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Pages Thumbnails

    @ViewBuilder
    private var pagesThumbnails: some View {
        if let pdfDocument, pdfDocument.pageCount > 0 {
            let pageIndices = Array(0..<pdfDocument.pageCount)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(pageIndices, id: \.self) { pageIndex in
                            sidebarThumbnail(for: pageIndex)
                                .id(pageIndex)
                        }
                    }
                    .padding()
                    .id(refreshTrigger)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Page thumbnails")
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
            onRequestPageManagement?()
        }
        .onTapGesture(count: 1) {
            navigateToPage = pageIndex
        }
    }
}
#endif
