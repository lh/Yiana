#if os(macOS)
import SwiftUI
import PDFKit

struct MacPDFMarkupView: View {
    let documentURL: URL
    let documentBookmark: Data?
    
    @StateObject private var annotationViewModel = AnnotationViewModel()
    @State private var showingInspector = false

    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(
                selectedTool: $annotationViewModel.selectedTool,
                isMarkupMode: $annotationViewModel.isMarkupMode,
                onCommit: {
                    annotationViewModel.commitAllChanges()
                },
                onRevert: {
                    annotationViewModel.revertAllChanges()
                }
            )
            .padding()
            
            HSplitView {
                MacPDFAnnotationView(
                    documentURL: documentURL,
                    viewModel: annotationViewModel,
                    needsReload: $annotationViewModel.documentNeedsReload
                )
                .frame(minWidth: 400)
                
                if annotationViewModel.isMarkupMode && showingInspector {
                    AnnotationInspector(
                        selectedTool: $annotationViewModel.selectedTool,
                        toolConfiguration: annotationViewModel.toolConfiguration
                    )
                    .frame(width: 250)
                    .transition(.move(edge: .trailing))
                }
            }
            
            statusBar
        }
        .onAppear {
            // Pass the document URL and bookmark to the view model
            annotationViewModel.documentURL = documentURL
            annotationViewModel.documentBookmark = documentBookmark
        }
    }
    
    private var statusBar: some View {
        HStack {
            if annotationViewModel.isMarkupMode {
                Label(statusText, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if annotationViewModel.isMarkupMode {
                Button(action: { withAnimation { showingInspector.toggle() } }) {
                    Image(systemName: showingInspector ? "sidebar.right" : "sidebar.left")
                        .help(showingInspector ? "Hide Inspector" : "Show Inspector")
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if annotationViewModel.hasUnsavedAnnotations {
                CommitButton(
                    hasAnnotations: annotationViewModel.hasUnsavedAnnotations,
                    onCommit: { annotationViewModel.commitAllChanges() }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var statusText: String {
        if let successMessage = annotationViewModel.successMessage {
            return successMessage
        } else if let tool = annotationViewModel.selectedTool {
            return "\(tool.rawValue) tool selected"
        } else if annotationViewModel.isMarkupMode {
            return "Select a tool to begin"
        } else {
            return "Markup mode disabled"
        }
    }
    
    private var statusIcon: String {
        if annotationViewModel.hasUnsavedAnnotations {
            return "pencil.circle.fill"
        } else if annotationViewModel.isMarkupMode {
            return "pencil.circle"
        } else {
            return "doc.text"
        }
    }
}

struct MacPDFAnnotationView: NSViewRepresentable {
    let documentURL: URL
    @ObservedObject var viewModel: AnnotationViewModel
    @Binding var needsReload: Bool

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.delegate = context.coordinator
        
        // Add gesture recognizers for markup interaction (with delegation to avoid interference)
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleClick(_:)))
        clickGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(clickGesture)
        
        let dragGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleDrag(_:)))
        dragGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(dragGesture)
        
        loadPDF(into: pdfView)
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if needsReload {
            loadPDF(into: pdfView)
            DispatchQueue.main.async { 
                needsReload = false
            }
        }
        
        if let page = pdfView.currentPage {
            viewModel.setCurrentPage(page)
        }
    }
    
    private func loadPDF(into pdfView: PDFView) {
        // Improve visibility: show page edges
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = NSColor.windowBackgroundColor

        var didStartAccess = false
        var isStale: Bool = false
        var resolvedURL: URL?
        if let bookmark = viewModel.documentBookmark,
           let resolved = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
           resolved.startAccessingSecurityScopedResource() {
            didStartAccess = true
            resolvedURL = resolved
        }

        defer {
            if didStartAccess, let resolved = resolvedURL {
                resolved.stopAccessingSecurityScopedResource()
            }
        }

        // 1) Try loading as a raw PDF file
        if let doc = PDFDocument(url: documentURL), doc.pageCount > 0 {
            // Set safe bounds before swapping the document
            pdfView.autoScales = false
            pdfView.minScaleFactor = 0.001
            pdfView.maxScaleFactor = 10.0
            pdfView.document = doc
            pdfView.displayBox = .cropBox
            pdfView.displaysPageBreaks = true
            pdfView.backgroundColor = NSColor.windowBackgroundColor
            pdfView.autoScales = true
            let fit = pdfView.scaleFactorForSizeToFit
            pdfView.minScaleFactor = min(0.001, fit)
            pdfView.maxScaleFactor = max(fit * 2.0, fit + 0.01)
            pdfView.scaleFactor = fit
            pdfView.layoutDocumentView()
            return
        }

        // 2) Try loading from data (handles sandboxed access and non-PDF containers)
        if let data = try? Data(contentsOf: documentURL) {
            // If raw PDF data
            if String(data: data.prefix(4), encoding: .ascii) == "%PDF" {
                if let doc = PDFDocument(data: data) {
                    pdfView.document = doc
                    pdfView.autoScales = true
                    return
                }
            }

            // Attempt to parse Yiana document container: metadata + 0xFF separator + PDF data
            let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
            if let sepRange = data.range(of: separator) {
                let pdfStart = sepRange.upperBound
                if pdfStart < data.count {
                    let pdfData = data.subdata(in: pdfStart..<data.count)
                    if let doc = PDFDocument(data: pdfData) {
                        // Set safe bounds before swapping the document
                        pdfView.autoScales = false
                        pdfView.minScaleFactor = 0.001
                        pdfView.maxScaleFactor = 10.0
                        pdfView.document = doc
                        pdfView.displayBox = .cropBox
                        pdfView.displaysPageBreaks = true
                        pdfView.backgroundColor = NSColor.windowBackgroundColor
                        pdfView.autoScales = true
                        let fit = pdfView.scaleFactorForSizeToFit
                        pdfView.minScaleFactor = min(0.001, fit)
                        pdfView.maxScaleFactor = max(fit * 2.0, fit + 0.01)
                        pdfView.scaleFactor = fit
                        pdfView.layoutDocumentView()
                        return
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, PDFViewDelegate, NSGestureRecognizerDelegate {
        let viewModel: AnnotationViewModel
        private var isDragging = false
        private var dragStartPoint: CGPoint = .zero
        
        init(viewModel: AnnotationViewModel) {
            self.viewModel = viewModel
            super.init()
            setupNotifications()
        }
        
        private func setupNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pageChanged(_:)),
                name: .PDFViewPageChanged,
                object: nil
            )
        }
        
        @objc private func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView, let page = pdfView.currentPage else { return }
            viewModel.setCurrentPage(page)
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard viewModel.isMarkupMode,
                  let selectedTool = viewModel.selectedTool,
                  let pdfView = gesture.view as? PDFView else { return }
            
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let pagePoint = pdfView.convert(location, to: page)
            
            // Create annotation based on tool type
            if selectedTool == .text {
                // For text tool, create annotation at click point
                _ = viewModel.createAnnotation(at: pagePoint, on: page)
            }
        }
        
        @objc func handleDrag(_ gesture: NSPanGestureRecognizer) {
            guard viewModel.isMarkupMode,
                  let selectedTool = viewModel.selectedTool,
                  let pdfView = gesture.view as? PDFView else { return }
            
            switch gesture.state {
            case .began:
                let location = gesture.location(in: pdfView)
                dragStartPoint = location
                isDragging = true
                
            case .ended:
                if isDragging {
                    let endLocation = gesture.location(in: pdfView)
                    guard let page = pdfView.page(for: dragStartPoint, nearest: true) else { return }
                    
                    let startPagePoint = pdfView.convert(dragStartPoint, to: page)
                    let endPagePoint = pdfView.convert(endLocation, to: page)
                    
                    // Create annotation for drag-based tools
                    if selectedTool == .highlight || selectedTool == .underline || selectedTool == .strikeout {
                        _ = viewModel.createAnnotation(from: startPagePoint, to: endPagePoint, on: page)
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
            // Only handle gestures when in markup mode with a selected tool
            guard viewModel.isMarkupMode, viewModel.selectedTool != nil else {
                return false
            }
            return true
        }
    }
}

struct MacPDFMarkupView_Previews: PreviewProvider {
    static var previews: some View {
        let tempURL = createTempPDF()
        
        MacPDFMarkupView(documentURL: tempURL, documentBookmark: nil)
            .frame(width: 800, height: 600)
            .onDisappear { try? FileManager.default.removeItem(at: tempURL) }
    }
    
    static func createTempPDF() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview.pdf")
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!
        pdfContext.beginPDFPage(nil)
        
        let text = "Sample PDF for preview."
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        pdfContext.textPosition = CGPoint(x: 50, y: 700)
        CTLineDraw(line, pdfContext)
        
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        try? pdfData.write(to: url)
        return url
    }
}
#endif
