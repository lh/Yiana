//
//  MacPDFViewer.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

#if os(macOS)
import SwiftUI
import PDFKit

struct MacPDFViewer: View {
    @ObservedObject var viewModel: DocumentViewModel
    var legacyPDFData: Data? = nil  // optional fallback for read-only documents
    @Binding var isSidebarVisible: Bool
    var refreshTrigger: UUID  // force rebuild when changed
    
    @State private var currentPage: Int = 0
    @State private var pdfDocument: PDFDocument?
    @State private var navigateToPage: Int?
    @State private var pageInputText: String = ""
    @State private var showingPageInput = false
    var onRequestPageManagement: (() -> Void)? = nil
    
    // Computed property for current PDF data
    private var currentPDFData: Data? {
        viewModel.displayPDFData ?? viewModel.pdfData ?? legacyPDFData
    }
    
    var body: some View {
        HSplitView {
            if isSidebarVisible {
                // Thumbnail sidebar
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(0..<(pdfDocument?.pageCount ?? 0), id: \.self) { pageIndex in
                                ThumbnailView(
                                    page: pdfDocument?.page(at: pageIndex),
                                    pageNumber: pageIndex + 1,
                                    isSelected: pageIndex == currentPage
                                )
                                .onTapGesture(count: 2) {
                                    // Double-click to open page management
                                    guard isSidebarVisible else { return }
                                    onRequestPageManagement?()
                                }
                                .onTapGesture(count: 1) {
                                    // Single-click to navigate
                                    guard isSidebarVisible else { return }
                                    navigateToPage = pageIndex
                                }
                                .id(pageIndex)
                            }
                        }
                        .padding()
                        .id(refreshTrigger)  // Force refresh when trigger changes
                    }
                    .frame(width: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .onChange(of: currentPage) { _, newPage in
                        withAnimation {
                            scrollProxy.scrollTo(newPage, anchor: .center)
                        }
                    }
                }
            }
            
            VStack(spacing: 0) {
                // Navigation toolbar
                HStack {
                    // Toggle sidebar button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
                    
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)
                    
                    // Previous page button
                    Button(action: {
                        if currentPage > 0 {
                            navigateToPage = currentPage - 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentPage <= 0)
                    .help("Previous Page (← or ↑)")
                    
                    // Page number display and input
                    if showingPageInput {
                        HStack(spacing: 4) {
                            TextField("", text: $pageInputText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .onSubmit {
                                    if let pageNum = Int(pageInputText),
                                       pageNum > 0,
                                       pageNum <= (pdfDocument?.pageCount ?? 0) {
                                        navigateToPage = pageNum - 1
                                    }
                                    showingPageInput = false
                                    pageInputText = ""
                                }
                            Text("of \(pdfDocument?.pageCount ?? 0)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: {
                            showingPageInput = true
                            pageInputText = "\(currentPage + 1)"
                        }) {
                            Text("Page \(currentPage + 1) of \(pdfDocument?.pageCount ?? 0)")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Click to jump to page")
                    }
                    
                    // Next page button
                    Button(action: {
                        if currentPage < (pdfDocument?.pageCount ?? 1) - 1 {
                            navigateToPage = currentPage + 1
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentPage >= (pdfDocument?.pageCount ?? 1) - 1)
                    .help("Next Page (→ or ↓)")
                    
                    Spacer()
                    
                    // Zoom controls
                    HStack(spacing: 4) {
                        Button(action: {
                            // Zoom out implementation would go here
                        }) {
                            Image(systemName: "minus.magnifyingglass")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Zoom Out")
                        
                        Button(action: {
                            // Zoom to fit implementation would go here
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Fit to Window")
                        
                        Button(action: {
                            // Zoom in implementation would go here
                        }) {
                            Image(systemName: "plus.magnifyingglass")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Zoom In")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // PDF viewer - use currentPDFData instead of direct pdfData
                if let pdfData = currentPDFData {
                    PDFViewer(
                        pdfData: pdfData,
                        navigateToPage: $navigateToPage,
                        currentPage: $currentPage
                    )
                }
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
