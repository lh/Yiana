//
//  PDFViewer.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit

/// SwiftUI wrapper for PDFKit's PDFView
/// Works on both iOS and macOS with platform-specific adjustments
struct PDFViewer: View {
    let pdfData: Data
    @State private var currentPage = 0
    @State private var totalPages = 0
    
    var body: some View {
        PDFKitView(pdfData: pdfData, currentPage: $currentPage, totalPages: $totalPages)
            .overlay(alignment: .bottom) {
                if totalPages > 1 {
                    pageIndicator
                }
            }
    }
    
    private var pageIndicator: some View {
        HStack {
            Text("Page \(currentPage + 1) of \(totalPages)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(15)
        }
        .padding()
    }
}

/// UIViewRepresentable/NSViewRepresentable wrapper for PDFView
struct PDFKitView: ViewRepresentable {
    let pdfData: Data
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    
    #if os(iOS)
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        configurePDFView(pdfView, context: context)
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        updatePDFView(pdfView)
    }
    #else
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        configurePDFView(pdfView, context: context)
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        updatePDFView(pdfView)
    }
    #endif
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func configurePDFView(_ pdfView: PDFView, context: Context) {
        // Store reference to pdfView in coordinator
        context.coordinator.pdfView = pdfView
        
        // Common configuration for both platforms
        pdfView.autoScales = true
        // Use single page mode to eliminate scrolling artifacts
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        
        #if os(iOS)
        // Use white background to match typical PDF page color
        pdfView.backgroundColor = UIColor.white
        // Disable shadows for better performance
        pdfView.pageShadowsEnabled = false
        // Use page view controller for smooth page transitions
        pdfView.usePageViewController(true, withViewOptions: nil)
        
        // Add swipe gestures for page navigation
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeLeft(_:)))
        swipeLeft.direction = .left
        pdfView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeRight(_:)))
        swipeRight.direction = .right
        pdfView.addGestureRecognizer(swipeRight)
        #else
        // Use white background to match typical PDF page color
        pdfView.backgroundColor = NSColor.white
        #endif
        
        // Set up notifications for page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        

        
        // Load the PDF
        if let document = PDFDocument(data: pdfData) {
            pdfView.document = document
            // Call layoutDocumentView to reduce initial flashing
            pdfView.layoutDocumentView()
            DispatchQueue.main.async {
                self.totalPages = document.pageCount
                self.currentPage = 0
            }
        }
    }
    
    private func updatePDFView(_ pdfView: PDFView) {
        // Always update when called - the SwiftUI update mechanism handles change detection
        if let document = PDFDocument(data: pdfData) {
            // Get current position before updating
            let currentPageIndex = pdfView.currentPage != nil ? 
                pdfView.document?.index(for: pdfView.currentPage!) ?? 0 : 0
            // Store current view position
            let documentView = pdfView.documentView
            #if os(iOS)
            let currentCenter = documentView?.bounds.origin ?? .zero
            #else
            let currentCenter = documentView?.visibleRect.origin ?? .zero
            #endif
            
            #if os(macOS)
            // More aggressive approach for macOS to reduce blinking
            pdfView.document = nil
            #endif
            
            pdfView.document = document
            // Call layoutDocumentView to reduce flashing
            pdfView.layoutDocumentView()
            
            DispatchQueue.main.async {
                self.totalPages = document.pageCount
                
                // If we had pages and still have pages, try to maintain position
                if currentPageIndex > 0 && document.pageCount > 0 {
                    // Adjust page index if pages were deleted before current position
                    let pageToShow = min(currentPageIndex, document.pageCount - 1)
                    if let page = document.page(at: pageToShow) {
                        pdfView.go(to: page)
                        self.currentPage = pageToShow
                    }
                }
            }
        }
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitView
        weak var pdfView: PDFView?
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }
            
            let pageIndex = document.index(for: currentPage)
            
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
        
        #if os(iOS)
        @objc func swipeLeft(_ gesture: UISwipeGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            if pdfView.canGoToNextPage {
                pdfView.goToNextPage(nil)
            }
        }
        
        @objc func swipeRight(_ gesture: UISwipeGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            if pdfView.canGoToPreviousPage {
                pdfView.goToPreviousPage(nil)
            }
        }
        #endif

    }
}

// Platform-specific type alias for ViewRepresentable
#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#else
typealias ViewRepresentable = NSViewRepresentable
#endif