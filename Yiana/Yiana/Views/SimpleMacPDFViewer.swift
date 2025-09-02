//
//  SimpleMacPDFViewer.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

#if os(macOS)
import SwiftUI
import PDFKit

/// A simpler PDF viewer for Mac that avoids state update issues
struct SimpleMacPDFViewer: NSViewRepresentable {
    let pdfData: Data
    @Binding var currentPage: Int  // 1-based page number
    let searchTerm: String?  // Term to highlight
    @State private var pdfView = PDFView()
    
    func makeNSView(context: Context) -> PDFView {
        // Configure PDF view
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.backgroundColor = NSColor.white
        pdfView.displaysPageBreaks = false
        
        // Load the document
        if let document = PDFDocument(data: pdfData) {
            pdfView.document = document
            
            // Highlight search term if provided
            if let searchTerm = searchTerm, !searchTerm.isEmpty {
                highlightSearchTerm(searchTerm, in: pdfView)
            }
        }
        
        // Set up navigation and page change notifications
        context.coordinator.setupNavigation(for: pdfView, parent: self)
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Handle page navigation using our 1-based wrapper
        print("DEBUG SimpleMacPDFViewer.updateNSView: Requested page = \(currentPage)")
        if nsView.canGoToPage(number: currentPage) {
            let currentPageNum = nsView.currentPageNumber ?? 0
            print("DEBUG SimpleMacPDFViewer.updateNSView: Current page in PDF = \(currentPageNum)")
            if currentPageNum != currentPage {
                print("DEBUG SimpleMacPDFViewer.updateNSView: Navigating from page \(currentPageNum) to \(currentPage)")
                nsView.goToPage(number: currentPage)
                // Force an immediate check
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let newPage = nsView.currentPageNumber ?? 0
                    print("DEBUG SimpleMacPDFViewer.updateNSView: After navigation, now on page \(newPage)")
                }
            }
        } else {
            print("DEBUG SimpleMacPDFViewer.updateNSView: Cannot navigate to page \(currentPage) - out of bounds?")
        }
        
        // Only update document if the data has changed
        if let currentDocument = nsView.document,
           currentDocument.dataRepresentation() == pdfData {
            return // No change needed
        }
        
        // Document has changed, update it
        if let document = PDFDocument(data: pdfData) {
            nsView.document = document
            
            // Re-apply search highlighting if needed
            if let searchTerm = searchTerm, !searchTerm.isEmpty {
                highlightSearchTerm(searchTerm, in: nsView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func highlightSearchTerm(_ term: String, in pdfView: PDFView) {
        guard let document = pdfView.document else { 
            print("DEBUG highlightSearchTerm: No document")
            return 
        }
        
        print("DEBUG highlightSearchTerm: Searching for '\(term)' in PDF")
        
        // Clear any existing selections
        pdfView.clearSelection()
        pdfView.highlightedSelections = nil
        
        // Find all occurrences of the search term
        // Note: This will only work if the PDF has embedded text layers
        // Our scanned PDFs don't have text layers (embedTextLayer is disabled in OCRProcessor)
        let selections = document.findString(term, withOptions: [.caseInsensitive])
        
        print("DEBUG highlightSearchTerm: Found \(selections.count) matches")
        
        if !selections.isEmpty {
            // Highlight all found selections
            pdfView.highlightedSelections = selections
            
            // If we're on the initial page with a match, scroll to the first match on that page
            if let currentPageDoc = pdfView.currentPage,
               let _ = pdfView.currentPageNumber {
                // Find selections on the current page
                let pageSelections = selections.filter { selection in
                    selection.pages.contains { $0 == currentPageDoc }
                }
                
                // Scroll to first match on current page if exists
                if let firstMatch = pageSelections.first {
                    pdfView.setCurrentSelection(firstMatch, animate: true)
                }
            }
        } else if !term.isEmpty {
            print("WARNING: No text found in PDF. This PDF likely doesn't have embedded text layers.")
            print("         OCR results are stored separately and used for search, but highlighting won't work.")
        }
    }
    
    class Coordinator: NSObject {
        var keyMonitor: Any?
        var scrollMonitor: Any?
        var parent: SimpleMacPDFViewer?
        
        deinit {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
            NotificationCenter.default.removeObserver(self)
        }
        
        func setupNavigation(for pdfView: PDFView, parent: SimpleMacPDFViewer) {
            self.parent = parent
            
            // Listen for page changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pageChanged(_:)),
                name: .PDFViewPageChanged,
                object: pdfView
            )
            
            // Keyboard navigation using our 1-based wrapper
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak pdfView] event in
                guard let pdfView = pdfView else { return event }
                
                switch event.keyCode {
                case 123: // Left arrow
                    if pdfView.canGoToPreviousPageNumber {
                        pdfView.goToPreviousPageNumber()
                        return nil
                    }
                case 124: // Right arrow
                    if pdfView.canGoToNextPageNumber {
                        pdfView.goToNextPageNumber()
                        return nil
                    }
                case 125: // Down arrow
                    if pdfView.canGoToNextPageNumber {
                        pdfView.goToNextPageNumber()
                        return nil
                    }
                case 126: // Up arrow
                    if pdfView.canGoToPreviousPageNumber {
                        pdfView.goToPreviousPageNumber()
                        return nil
                    }
                case 49: // Space
                    if event.modifierFlags.contains(.shift) {
                        if pdfView.canGoToPreviousPageNumber {
                            pdfView.goToPreviousPageNumber()
                            return nil
                        }
                    } else {
                        if pdfView.canGoToNextPageNumber {
                            pdfView.goToNextPageNumber()
                            return nil
                        }
                    }
                default:
                    break
                }
                return event
            }
            
            // Scroll wheel navigation using our 1-based wrapper
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak pdfView] event in
                guard let pdfView = pdfView,
                      pdfView.window?.firstResponder == pdfView else { return event }
                
                if abs(event.deltaY) > abs(event.deltaX) {
                    if event.deltaY > 0.5 {
                        if pdfView.canGoToPreviousPageNumber {
                            pdfView.goToPreviousPageNumber()
                        }
                    } else if event.deltaY < -0.5 {
                        if pdfView.canGoToNextPageNumber {
                            pdfView.goToNextPageNumber()
                        }
                    }
                }
                return event
            }
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let pageNum = pdfView.currentPageNumber else { return }
            
            DispatchQueue.main.async {
                self.parent?.currentPage = pageNum  // Already 1-based from wrapper
            }
        }
    }
}

/// Mac PDF viewer with sidebar
struct EnhancedMacPDFViewer: View {
    let pdfData: Data
    let initialPage: Int?  // 1-based page number
    let searchTerm: String?  // Term to highlight in the PDF
    @State private var showingSidebar = true
    @State private var currentPage = 1  // 1-based current page
    @State private var pdfDocument: PDFDocument?
    
    init(pdfData: Data, initialPage: Int? = nil, searchTerm: String? = nil) {
        self.pdfData = pdfData
        self.initialPage = initialPage
        self.searchTerm = searchTerm
    }
    
    var body: some View {
        HSplitView {
            if showingSidebar {
                // Thumbnail sidebar
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(1...(pdfDocument?.pageCount ?? 1), id: \.self) { pageNum in
                                ThumbnailItemView(
                                    page: pdfDocument?.getPage(number: pageNum),  // Use wrapper
                                    pageNumber: pageNum,
                                    isSelected: pageNum == currentPage
                                )
                                .onTapGesture {
                                    currentPage = pageNum
                                }
                                .id(pageNum)
                            }
                        }
                        .padding()
                    }
                    .frame(width: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .onChange(of: currentPage) { _, newPage in
                        withAnimation {
                            proxy.scrollTo(newPage, anchor: .center)
                        }
                    }
                }
            }
            
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
                    if let doc = pdfDocument {
                        Text("Page \(currentPage) of \(doc.pageCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // PDF View with binding to current page
                SimpleMacPDFViewer(pdfData: pdfData, currentPage: $currentPage, searchTerm: searchTerm)
            }
        }
        .onAppear {
            loadDocument()
            // Navigate to initial page if specified
            if let page = initialPage {
                print("DEBUG EnhancedMacPDFViewer: Setting initial page to \(page) (1-based)")
                currentPage = page
            } else {
                print("DEBUG EnhancedMacPDFViewer: No initial page specified, staying on page 1")
            }
            print("DEBUG EnhancedMacPDFViewer: searchTerm = \(String(describing: searchTerm))")
        }
    }
    
    private func loadDocument() {
        if let document = PDFDocument(data: pdfData) {
            pdfDocument = document
            print("DEBUG EnhancedMacPDFViewer: Loaded PDF with \(document.pageCount) pages")
        }
    }
}

struct ThumbnailItemView: View {
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
            }
            
            Text("Page \(pageNumber)")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .padding(.horizontal, 8)
    }
    
    private func generateThumbnail() -> NSImage? {
        guard let page = page else { return nil }
        
        let pageRect = page.bounds(for: .mediaBox)
        let thumbnailWidth: CGFloat = 300
        let aspectRatio = pageRect.height / pageRect.width
        let thumbnailHeight = thumbnailWidth * aspectRatio
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        
        let image = NSImage(size: thumbnailSize)
        image.lockFocus()
        
        NSColor.white.setFill()
        NSRect(origin: .zero, size: thumbnailSize).fill()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.translateBy(x: 0, y: thumbnailSize.height)
            context.scaleBy(x: 1, y: -1)
            
            let scaleFactor = thumbnailWidth / pageRect.width
            context.scaleBy(x: scaleFactor, y: scaleFactor)
            
            page.draw(with: .mediaBox, to: context)
        }
        
        image.unlockFocus()
        return image
    }
}
#endif