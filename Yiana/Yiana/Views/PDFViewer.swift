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
        // Common configuration for both platforms
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        #if os(iOS)
        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.pageShadowsEnabled = true
        // Don't use page view controller with continuous scrolling
        pdfView.usePageViewController(false, withViewOptions: nil)
        #else
        pdfView.backgroundColor = NSColor.windowBackgroundColor
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
            DispatchQueue.main.async {
                self.totalPages = document.pageCount
                self.currentPage = 0
            }
        }
    }
    
    private func updatePDFView(_ pdfView: PDFView) {
        // Only update if the PDF data has changed
        if pdfView.document?.dataRepresentation() != pdfData {
            if let document = PDFDocument(data: pdfData) {
                // Remember current page if document exists
                let previousPage = pdfView.currentPage
                let previousPageIndex = pdfView.document?.index(for: previousPage ?? document.page(at: 0)!) ?? 0
                
                pdfView.document = document
                
                DispatchQueue.main.async {
                    self.totalPages = document.pageCount
                    // Try to restore previous page position, or stay within bounds
                    let pageToShow = min(previousPageIndex, document.pageCount - 1)
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
    }
}

// Platform-specific type alias for ViewRepresentable
#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#else
typealias ViewRepresentable = NSViewRepresentable
#endif