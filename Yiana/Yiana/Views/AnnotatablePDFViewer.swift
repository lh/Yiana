//
//  AnnotatablePDFViewer.swift
//  Yiana
//
//  A PDF viewer with annotation capabilities for markup mode
//  Based on MacPDFViewer but adds gesture handling for annotations
//

#if os(macOS)
import SwiftUI
import PDFKit

/// PDF viewer with annotation support for markup mode
struct AnnotatablePDFViewer: View {
    let pdfData: Data
    let annotationViewModel: AnnotationViewModel
    @State private var currentPage: Int = 0
    @State private var showingSidebar = true
    @State private var pdfDocument: PDFDocument?
    @State private var navigateToPage: Int?
    @State private var pageInputText: String = ""
    @State private var showingPageInput = false
    
    var body: some View {
        HSplitView {
            if showingSidebar {
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
                                .onTapGesture {
                                    navigateToPage = pageIndex
                                }
                                .id(pageIndex)
                            }
                        }
                        .padding()
                    }
                    .frame(width: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .onChange(of: currentPage) { newPage in
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
                            showingSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(showingSidebar ? "Hide Sidebar" : "Show Sidebar")
                    
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
                    
                    // Annotation status
                    if annotationViewModel.hasUnsavedAnnotations {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.orange)
                            Text("Unsaved changes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Annotatable PDF viewer
                AnnotatablePDFKitView(
                    pdfData: pdfData,
                    annotationViewModel: annotationViewModel,
                    navigateToPage: $navigateToPage,
                    currentPage: $currentPage
                )
            }
        }
        .task {
            if let document = PDFDocument(data: pdfData) {
                await MainActor.run {
                    pdfDocument = document
                    annotationViewModel.setCurrentPage(document.page(at: 0))
                }
            }
        }
        .onChange(of: annotationViewModel.documentNeedsReload) { needsReload in
            if needsReload {
                // Clear the reload flag
                annotationViewModel.documentNeedsReload = false
                
                // Reload the PDF document from disk to show flattened content
                Task {
                    await reloadPDFDocument()
                }
            }
        }
        .onExitCommand {
            if showingPageInput {
                showingPageInput = false
                pageInputText = ""
            }
        }
    }
    
    // MARK: - Document Reload
    
    @MainActor
    private func reloadPDFDocument() async {
        // Reload the PDF data from the document URL if available
        guard let documentURL = annotationViewModel.documentURL else { return }
        
        do {
            // Handle security-scoped access if bookmark is available
            var isAccessing = false
            if let bookmark = annotationViewModel.documentBookmark {
                var isStale = false
                if let securityScopedURL = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    isAccessing = securityScopedURL.startAccessingSecurityScopedResource()
                }
            }
            
            defer {
                if isAccessing {
                    documentURL.stopAccessingSecurityScopedResource()
                }
            }
            
            let reloadedData = try Data(contentsOf: documentURL)
            if let document = PDFDocument(data: reloadedData) {
                pdfDocument = document
                // Reset to first page or try to maintain current page
                let pageToShow = min(currentPage, document.pageCount - 1)
                if pageToShow >= 0, let page = document.page(at: pageToShow) {
                    annotationViewModel.setCurrentPage(page)
                }
            }
        } catch {
            print("Error reloading PDF document: \(error)")
        }
    }
}

/// NSViewRepresentable wrapper for PDFView with annotation support
struct AnnotatablePDFKitView: NSViewRepresentable {
    let pdfData: Data
    let annotationViewModel: AnnotationViewModel
    @Binding var navigateToPage: Int?
    @Binding var currentPage: Int
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        context.coordinator.isInitialLoad = true
        configurePDFView(pdfView, context: context)
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if !context.coordinator.isInitialLoad {
            updatePDFView(pdfView)
        }
        handleNavigation(pdfView)
        context.coordinator.isInitialLoad = false
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, annotationViewModel)
    }
    
    private func configurePDFView(_ pdfView: PDFView, context: Context) {
        // Store reference to pdfView in coordinator
        context.coordinator.pdfView = pdfView
        
        // Common configuration
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.displaysPageBreaks = false
        pdfView.backgroundColor = NSColor.white
        pdfView.pageShadowsEnabled = false
        
        // Add annotation gesture recognizers
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        clickGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(clickGesture)
        
        let doubleClickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        doubleClickGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(doubleClickGesture)
        
        let dragGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDrag(_:)))
        dragGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(dragGesture)
        
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
            annotationViewModel.setCurrentPage(document.page(at: 0))
        }
    }
    
    private func updatePDFView(_ pdfView: PDFView) {
        // Only update if document has actually changed
        if pdfView.document == nil || pdfView.document?.dataRepresentation() != pdfData {
            if let document = PDFDocument(data: pdfData) {
                let currentPageIndex = pdfView.currentPage != nil ? 
                    pdfView.document?.index(for: pdfView.currentPage!) ?? 0 : 0
                
                pdfView.document = document
                pdfView.layoutDocumentView()
                
                DispatchQueue.main.async {
                    if navigateToPage == nil && currentPageIndex > 0 && document.pageCount > 0 {
                        let pageToShow = min(currentPageIndex, document.pageCount - 1)
                        if let page = document.page(at: pageToShow) {
                            pdfView.go(to: page)
                            self.currentPage = pageToShow
                        }
                    }
                }
            }
        }
    }
    
    private func handleNavigation(_ pdfView: PDFView) {
        if let pageIndex = navigateToPage,
           let document = pdfView.document,
           pageIndex >= 0 && pageIndex < document.pageCount,
           let page = document.page(at: pageIndex) {
            pdfView.go(to: page)
            annotationViewModel.setCurrentPage(page)
            DispatchQueue.main.async {
                self.currentPage = pageIndex
                self.navigateToPage = nil
            }
        }
    }
    
    class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var parent: AnnotatablePDFKitView
        let annotationViewModel: AnnotationViewModel
        weak var pdfView: PDFView?
        var isInitialLoad = true
        private var isDragging = false
        private var dragStartPoint: CGPoint = .zero
        
        init(_ parent: AnnotatablePDFKitView, _ annotationViewModel: AnnotationViewModel) {
            self.parent = parent
            self.annotationViewModel = annotationViewModel
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }
            
            let pageIndex = document.index(for: currentPage)
            annotationViewModel.setCurrentPage(currentPage)
            
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            print("DEBUG: Click gesture triggered")
            print("DEBUG: Selected tool = \(String(describing: annotationViewModel.selectedTool))")
            
            guard let selectedTool = annotationViewModel.selectedTool else {
                print("DEBUG: No tool selected, ignoring click")
                return
            }
            
            guard let pdfView = gesture.view as? PDFView else {
                print("DEBUG: Could not get PDFView from gesture")
                return
            }
            
            let location = gesture.location(in: pdfView)
            print("DEBUG: Click location = \(location)")
            
            guard let page = pdfView.page(for: location, nearest: true) else {
                print("DEBUG: Could not find page for location")
                return
            }
            
            let pagePoint = pdfView.convert(location, to: page)
            print("DEBUG: Page point = \(pagePoint)")
            
            // Create annotation based on tool type
            if selectedTool == .text {
                print("DEBUG: Creating text annotation")
                let annotation = annotationViewModel.createAnnotation(at: pagePoint, on: page)
                print("DEBUG: Created annotation: \(String(describing: annotation))")
            }
        }
        
        @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let pagePoint = pdfView.convert(location, to: page)
            
            // Check if we double-clicked on an existing text annotation
            for annotation in page.annotations {
                if annotation.type == "FreeText" && annotation.bounds.contains(pagePoint) {
                    print("DEBUG: Double-clicked on text annotation, attempting to edit")
                    
                    // Show an alert dialog for text input as a workaround
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Edit Text Annotation"
                        alert.informativeText = "Enter new text:"
                        alert.addButton(withTitle: "OK")
                        alert.addButton(withTitle: "Cancel")
                        
                        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                        inputTextField.stringValue = annotation.contents ?? ""
                        alert.accessoryView = inputTextField
                        
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            annotation.contents = inputTextField.stringValue
                            print("DEBUG: Updated annotation text to: \(inputTextField.stringValue)")
                        }
                    }
                    return
                }
            }
        }
        
        @objc func handleDrag(_ gesture: NSPanGestureRecognizer) {
            print("DEBUG: Drag gesture state = \(gesture.state.rawValue)")
            print("DEBUG: Selected tool = \(String(describing: annotationViewModel.selectedTool))")
            
            guard let selectedTool = annotationViewModel.selectedTool else {
                print("DEBUG: No tool selected, ignoring drag")
                return
            }
            
            guard let pdfView = gesture.view as? PDFView else {
                print("DEBUG: Could not get PDFView from drag gesture")
                return
            }
            
            switch gesture.state {
            case .began:
                let location = gesture.location(in: pdfView)
                print("DEBUG: Drag began at \(location)")
                dragStartPoint = location
                isDragging = true
                
            case .ended:
                if isDragging {
                    let endLocation = gesture.location(in: pdfView)
                    print("DEBUG: Drag ended at \(endLocation)")
                    
                    guard let page = pdfView.page(for: dragStartPoint, nearest: true) else {
                        print("DEBUG: Could not find page for drag start point")
                        return
                    }
                    
                    let startPagePoint = pdfView.convert(dragStartPoint, to: page)
                    let endPagePoint = pdfView.convert(endLocation, to: page)
                    print("DEBUG: Page points: start = \(startPagePoint), end = \(endPagePoint)")
                    
                    // Create annotation for drag-based tools
                    if selectedTool == .highlight || selectedTool == .underline || selectedTool == .strikeout {
                        print("DEBUG: Creating drag annotation with tool \(selectedTool)")
                        let annotation = annotationViewModel.createAnnotation(from: startPagePoint, to: endPagePoint, on: page)
                        print("DEBUG: Created drag annotation: \(String(describing: annotation))")
                    }
                }
                isDragging = false
                dragStartPoint = .zero
                
            default:
                break
            }
        }
        
        // MARK: - NSGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
            // Allow simultaneous gestures so PDFView can still handle scrolling/zooming
            return true
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
            // Only handle gestures when a tool is selected
            let shouldBegin = annotationViewModel.selectedTool != nil
            print("DEBUG: gestureRecognizerShouldBegin = \(shouldBegin), selectedTool = \(String(describing: annotationViewModel.selectedTool))")
            return shouldBegin
        }
    }
}

#endif