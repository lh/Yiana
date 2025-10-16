//
//  PDFViewer.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit

/// PDF zoom actions that can be triggered programmatically
enum PDFZoomAction {
    case zoomIn
    case zoomOut
    case fitToWindow
}

/// SwiftUI wrapper for PDFKit's PDFView
/// Works on both iOS and macOS with platform-specific adjustments
struct PDFViewer: View {
    let pdfData: Data
    @Binding var navigateToPage: Int?
    @Binding var currentPage: Int
    @Binding var zoomAction: PDFZoomAction?
    @State private var totalPages = 0
    @State private var showPageIndicator = true
    @State private var hideIndicatorTask: Task<Void, Never>?
    @Binding var fitMode: FitMode
    @State private var lastExplicitFitMode: FitMode = .height
    let onRequestPageManagement: (() -> Void)?
    let onRequestMetadataView: (() -> Void)?

    init(pdfData: Data,
         navigateToPage: Binding<Int?> = .constant(nil),
         currentPage: Binding<Int> = .constant(0),
         zoomAction: Binding<PDFZoomAction?> = .constant(nil),
         fitMode: Binding<FitMode> = .constant(.height),
         onRequestPageManagement: (() -> Void)? = nil,
         onRequestMetadataView: (() -> Void)? = nil) {
        self.pdfData = pdfData
        self._navigateToPage = navigateToPage
        self._currentPage = currentPage
        self._zoomAction = zoomAction
        self._fitMode = fitMode
        self._lastExplicitFitMode = State(initialValue: fitMode.wrappedValue == .manual ? .height : fitMode.wrappedValue)
        self.onRequestPageManagement = onRequestPageManagement
        self.onRequestMetadataView = onRequestMetadataView
    }

    var body: some View {
        PDFKitView(pdfData: pdfData,
                   currentPage: $currentPage,
                   totalPages: $totalPages,
                   navigateToPage: $navigateToPage,
                   zoomAction: $zoomAction,
                   fitMode: $fitMode,
                   onRequestPageManagement: onRequestPageManagement,
                   onRequestMetadataView: onRequestMetadataView)
            .overlay(alignment: .bottomTrailing) {
                if totalPages > 1 {
                    pageIndicator
                        .opacity(showPageIndicator ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showPageIndicator)
                }
            }
            .onChange(of: fitMode) { _, newValue in
                switch newValue {
                case .width, .height:
                    lastExplicitFitMode = newValue
                case .manual:
                    break
                }
            }
            .onAppear {
                scheduleHideIndicator()
            }
            .onChange(of: currentPage) { _, _ in
                showIndicator()
            }
            .onChange(of: navigateToPage) { _, _ in
                showIndicator()
            }
            .onTapGesture(count: 1) { _ in
                // If tapped in bottom-right corner area, show indicator
                // This is handled in PDFKitView tap handling
            }
    }

    private var pageIndicator: some View {
        Text("\(currentPage + 1)/\(totalPages)")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.85))
            )
            .padding(.trailing, 16)
            .padding(.bottom, 20)
            .onTapGesture {
                // Keep indicator visible and maybe show page management
                showIndicator()
                onRequestPageManagement?()
            }
    }

    private func showIndicator() {
        showPageIndicator = true
        scheduleHideIndicator()
    }

    private func scheduleHideIndicator() {
        // Cancel any existing hide task
        hideIndicatorTask?.cancel()

        // Schedule new hide after 3 seconds
        hideIndicatorTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                await MainActor.run {
                    showPageIndicator = false
                }
            }
        }
    }
}

/// UIViewRepresentable/NSViewRepresentable wrapper for PDFView
// Fit mode for manual zoom control
enum FitMode: Hashable {
    case width
    case height
    case manual
}

struct PDFKitView: ViewRepresentable {
    let pdfData: Data
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var navigateToPage: Int?
    @Binding var zoomAction: PDFZoomAction?
    @Binding var fitMode: FitMode
    let onRequestPageManagement: (() -> Void)?
    let onRequestMetadataView: (() -> Void)?

    #if os(iOS)
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        context.coordinator.isInitialLoad = true
        configurePDFView(pdfView, context: context)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.pdfView = pdfView
        let signature = pdfData.count
        if context.coordinator.pdfDataSignature != signature {
            context.coordinator.pdfDataSignature = signature
            context.coordinator.lastReportedPageIndex = nil
            if let document = PDFDocument(data: pdfData) {
                context.coordinator.isReloadingDocument = true
                DispatchQueue.main.async {
                    let pageCount = document.pageCount
                    let clamped = max(0, min(self.currentPage, pageCount - 1))
                    pdfView.document = nil
                    pdfView.document = document
                    if let page = document.page(at: clamped) {
                        pdfView.go(to: page)
                        context.coordinator.lastReportedPageIndex = clamped
                    }
                    #if os(iOS)
                    pdfView.documentView?.setNeedsDisplay()
                    #else
                    pdfView.documentView?.needsDisplay = true
                    #endif
                    DispatchQueue.main.async {
                        pdfView.layoutDocumentView()
                    }
                    self.totalPages = pageCount
                    if self.currentPage != clamped {
                        self.currentPage = clamped
                    }
                    context.coordinator.isReloadingDocument = false
                }
            } else {
                pdfView.document = nil
                DispatchQueue.main.async {
                    self.totalPages = 0
                    self.currentPage = 0
                    context.coordinator.isReloadingDocument = false
                }
            }
        } else if let document = pdfView.document {
            let pageCount = document.pageCount
            if totalPages != pageCount {
                DispatchQueue.main.async {
                    self.totalPages = pageCount
                    let clamped = max(0, min(self.currentPage, pageCount - 1))
                    if self.currentPage != clamped {
                        self.currentPage = clamped
                    }
                }
            }
            context.coordinator.isReloadingDocument = false
        }
        handleNavigation(pdfView, coordinator: context.coordinator)
        handleZoom(pdfView, coordinator: context.coordinator)
        context.coordinator.isInitialLoad = false
    }
    #else
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        context.coordinator.isInitialLoad = true
        configurePDFView(pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.pdfView = pdfView
        let signature = pdfData.count
        if context.coordinator.pdfDataSignature != signature {
            context.coordinator.pdfDataSignature = signature
            context.coordinator.lastReportedPageIndex = nil
            if let document = PDFDocument(data: pdfData) {
                context.coordinator.isReloadingDocument = true
                DispatchQueue.main.async {
                    let pageCount = document.pageCount
                    let clamped = max(0, min(self.currentPage, pageCount - 1))
                    pdfView.document = nil
                    pdfView.document = document
                    if let page = document.page(at: clamped) {
                        pdfView.go(to: page)
                        context.coordinator.lastReportedPageIndex = clamped
                    }
                    #if os(iOS)
                    pdfView.documentView?.setNeedsDisplay()
                    #else
                    pdfView.documentView?.needsDisplay = true
                    #endif
                    DispatchQueue.main.async {
                        pdfView.layoutDocumentView()
                        // Apply initial fit-to-page and sync coordinator state
                        self.applyFitToHeight(pdfView, coordinator: context.coordinator)
                        context.coordinator.currentFitMode = .height
                        context.coordinator.lastExplicitFitMode = .height
                        self.fitMode = .height
                    }
                    self.totalPages = pageCount
                    if self.currentPage != clamped {
                        self.currentPage = clamped
                    }
                    context.coordinator.isReloadingDocument = false
                }
            } else {
                pdfView.document = nil
                DispatchQueue.main.async {
                    self.totalPages = 0
                    self.currentPage = 0
                    context.coordinator.isReloadingDocument = false
                }
            }
        } else if let document = pdfView.document {
            let pageCount = document.pageCount
            if totalPages != pageCount {
                DispatchQueue.main.async {
                    self.totalPages = pageCount
                    let clamped = max(0, min(self.currentPage, pageCount - 1))
                    if self.currentPage != clamped {
                        self.currentPage = clamped
                    }
                }
            }
            context.coordinator.isReloadingDocument = false
        }
        handleNavigation(pdfView, coordinator: context.coordinator)
        handleZoom(pdfView, coordinator: context.coordinator)
        context.coordinator.isInitialLoad = false
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Zoom Helpers
    
    private func applyFitToWindow(_ pdfView: PDFView, coordinator: Coordinator) {
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        coordinator.lastKnownScaleFactor = pdfView.scaleFactor
    }
    
    private func applyFitToWidth(_ pdfView: PDFView, coordinator: Coordinator) {
        guard let page = pdfView.currentPage else { return }
        let pageRect = page.bounds(for: pdfView.displayBox)
        let viewWidth = pdfView.bounds.width
        let scaleFactor = viewWidth / pageRect.width
        pdfView.scaleFactor = scaleFactor
        coordinator.lastKnownScaleFactor = scaleFactor
        coordinator.currentFitMode = .width
        coordinator.lastExplicitFitMode = .width
    }
    
    private func applyFitToHeight(_ pdfView: PDFView, coordinator: Coordinator) {
        guard let page = pdfView.currentPage else { return }
        let pageRect = page.bounds(for: pdfView.displayBox)
        let viewHeight = pdfView.bounds.height
        let scaleFactor = viewHeight / pageRect.height
        pdfView.scaleFactor = scaleFactor
        coordinator.lastKnownScaleFactor = scaleFactor
        coordinator.currentFitMode = .height
        coordinator.lastExplicitFitMode = .height
    }

    private func configurePDFView(_ pdfView: PDFView, context: Context) {
        // Store reference to pdfView in coordinator
        context.coordinator.pdfView = pdfView

        // Common configuration for both platforms
        // Disable autoScales to take manual control over zoom
        pdfView.autoScales = false
        
        // Use single page mode to eliminate scrolling artifacts
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.displaysPageBreaks = false

        #if os(iOS)
        // Use white background to match typical PDF page color
        pdfView.backgroundColor = UIColor.systemBackground
        // Disable shadows for better performance
        pdfView.pageShadowsEnabled = false
        // Don't use page view controller - it causes glitches
        // pdfView.usePageViewController(true, withViewOptions: nil)
        // Add rendering optimizations for smoother transitions
        pdfView.interpolationQuality = .high
        pdfView.displayBox = .cropBox

        // Add swipe gestures for page navigation
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeLeft(_:)))
        swipeLeft.direction = .left
        pdfView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeRight(_:)))
        swipeRight.direction = .right
        pdfView.addGestureRecognizer(swipeRight)

        // Add upward swipe for page management
        let swipeUp = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeUp(_:)))
        swipeUp.direction = .up
        pdfView.addGestureRecognizer(swipeUp)

        // Add downward swipe for metadata/address view
        let swipeDown = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeDown(_:)))
        swipeDown.direction = .down
        pdfView.addGestureRecognizer(swipeDown)

        // Recursively attach our double-tap recognizer to each scroll view so it fires on iPad
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.resetZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator

        func collectScrollViews(in view: UIView, depth: Int = 0, store: inout [(UIScrollView, Int)]) {
            if let scrollView = view as? UIScrollView {
                store.append((scrollView, depth))
            }
            for subview in view.subviews {
                collectScrollViews(in: subview, depth: depth + 1, store: &store)
            }
        }

        var scrollViewCandidates: [(UIScrollView, Int)] = []
        collectScrollViews(in: pdfView, store: &scrollViewCandidates)

        let targetScrollView = scrollViewCandidates.max(by: { $0.1 < $1.1 })?.0

        for (scrollView, _) in scrollViewCandidates {
            if scrollView === targetScrollView {
                scrollView.delegate = context.coordinator
                scrollView.addGestureRecognizer(doubleTap)

                scrollView.gestureRecognizers?
                    .compactMap { $0 as? UITapGestureRecognizer }
                    .filter { $0 !== doubleTap && $0.numberOfTapsRequired == 2 }
                    .forEach { recognizer in
                        recognizer.require(toFail: doubleTap)
                    }
            } else {
                scrollView.gestureRecognizers?
                    .compactMap { $0 as? UITapGestureRecognizer }
                    .filter { $0.numberOfTapsRequired == 2 }
                    .forEach { recognizer in
                        recognizer.isEnabled = false
                    }
            }
        }

        if targetScrollView == nil {
            pdfView.addGestureRecognizer(doubleTap)
        }

        // Also ensure any remaining double-tap recognizers on the PDFView itself yield to ours
        pdfView.gestureRecognizers?
            .compactMap { $0 as? UITapGestureRecognizer }
            .filter { $0.numberOfTapsRequired == 2 && $0 !== doubleTap }
            .forEach { other in
                other.require(toFail: doubleTap)
            }

#else
        // Use white background to match typical PDF page color
        pdfView.backgroundColor = NSColor.white

        // Add double-click gesture to reset zoom
        let doubleClick = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.resetZoom(_:)))
        doubleClick.numberOfClicksRequired = 2
        pdfView.addGestureRecognizer(doubleClick)

        // Set up keyboard navigation (only if not already set)
        if context.coordinator.keyEventMonitor == nil {
            context.coordinator.keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if context.coordinator.handleKeyDown(event) {
                    return nil // Event was handled, don't propagate
                }
                return event
            }
        }

        // Set up scroll wheel navigation (only if not already set)
        if context.coordinator.scrollEventMonitor == nil {
            context.coordinator.scrollEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                // Only handle if the PDFView is the first responder
                if pdfView.window?.firstResponder == pdfView {
                    context.coordinator.handleScrollWheel(event)
                }
                return event
            }
        }
        
        // Observe scale changes on macOS
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scaleChanged(_:)),
            name: NSNotification.Name.PDFViewScaleChanged,
            object: pdfView
        )
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
            // Defer state updates to avoid "modifying state during view update" warning
            DispatchQueue.main.async {
                self.totalPages = document.pageCount
                self.currentPage = 0
            }

            // Set the document
            pdfView.document = document
            context.coordinator.pdfDataSignature = pdfData.hashValue
            
            // Set scale limits and initial zoom after document layout completes
            DispatchQueue.main.async {
                pdfView.layoutDocumentView()
                
                // Only set scale limits if we have a valid fit scale
                let fitScale = pdfView.scaleFactorForSizeToFit
                if fitScale > 0 {
                    pdfView.minScaleFactor = fitScale * 0.5
                    pdfView.maxScaleFactor = fitScale * 4.0
                    
                    // Apply initial fit after document is loaded
                    if context.coordinator.isInitialLoad {
                        self.applyFitToHeight(pdfView, coordinator: context.coordinator)
                    }
                }
            }
        }
    }

    private func updatePDFView(_ pdfView: PDFView) {
        // Only update if document has actually changed
        if pdfView.document == nil || pdfView.document?.dataRepresentation() != pdfData {
            if let document = PDFDocument(data: pdfData) {
                // Get current position before updating
                let currentPageIndex = pdfView.currentPage != nil ?
                    pdfView.document?.index(for: pdfView.currentPage!) ?? 0 : 0

                pdfView.document = document
                // Call layoutDocumentView to reduce flashing
                pdfView.layoutDocumentView()

                DispatchQueue.main.async {
                    self.totalPages = document.pageCount

                    // If we had pages and still have pages, try to maintain position
                    // BUT ONLY if we don't have a pending navigation request
                    if navigateToPage == nil && currentPageIndex > 0 && document.pageCount > 0 {
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
    }

    private func handleNavigation(_ pdfView: PDFView, coordinator: Coordinator) {
        guard !coordinator.isReloadingDocument else { return }
        guard let pageIndex = navigateToPage,
              let document = pdfView.document,
              pageIndex >= 0 && pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else { return }

        if let current = pdfView.currentPage,
           document.index(for: current) == pageIndex {
            DispatchQueue.main.async {
                self.navigateToPage = nil
            }
            return
        }
        pdfView.go(to: page)
        DispatchQueue.main.async {
            if self.currentPage != pageIndex {
                self.currentPage = pageIndex
            }
            coordinator.lastReportedPageIndex = pageIndex
            self.navigateToPage = nil  // Clear navigation request
        }
    }

    private func handleZoom(_ pdfView: PDFView, coordinator: Coordinator) {
        guard let action = zoomAction else { return }

        switch action {
        case .zoomIn:
            pdfView.zoomIn(nil)
            coordinator.lastKnownScaleFactor = pdfView.scaleFactor
            coordinator.currentFitMode = .manual
            // Sync with parent's fitMode binding
            DispatchQueue.main.async {
                self.fitMode = .manual
            }
        case .zoomOut:
            pdfView.zoomOut(nil)
            coordinator.lastKnownScaleFactor = pdfView.scaleFactor
            coordinator.currentFitMode = .manual
            // Sync with parent's fitMode binding
            DispatchQueue.main.async {
                self.fitMode = .manual
            }
        case .fitToWindow:
            // Use the parent's fitMode binding to determine which fit to apply
            switch fitMode {
            case .width:
                applyFitToWidth(pdfView, coordinator: coordinator)
            case .height:
                applyFitToHeight(pdfView, coordinator: coordinator)
            case .manual:
                let target = coordinator.lastExplicitFitMode
                switch target {
                case .width:
                    applyFitToWidth(pdfView, coordinator: coordinator)
                case .height, .manual:
                    applyFitToHeight(pdfView, coordinator: coordinator)
                }
                DispatchQueue.main.async {
                    self.fitMode = target
                }
            }
        }

        // Clear the action after processing
        DispatchQueue.main.async {
            self.zoomAction = nil
        }
    }

    class Coordinator: NSObject {
        var parent: PDFKitView
        weak var pdfView: PDFView?
        var isInitialLoad = true
        var onRequestPageManagement: (() -> Void)?
        var onRequestMetadataView: (() -> Void)?
        var pdfDataSignature: Int?
        var lastReportedPageIndex: Int?
        var isReloadingDocument = false
        // Zoom tracking state
        var lastKnownScaleFactor: CGFloat?
        var currentFitMode: FitMode = .height
        var lastExplicitFitMode: FitMode = .height
        #if os(macOS)
        var keyEventMonitor: Any?
        var scrollEventMonitor: Any?
        #endif

        init(_ parent: PDFKitView) {
            self.parent = parent
            self.onRequestPageManagement = parent.onRequestPageManagement
            self.onRequestMetadataView = parent.onRequestMetadataView
        }

        deinit {
            #if os(macOS)
            if let monitor = keyEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = scrollEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            #endif
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }

            if isReloadingDocument { return }
            let pageIndex = document.index(for: currentPage)
            if lastReportedPageIndex == pageIndex { return }
            lastReportedPageIndex = pageIndex

            DispatchQueue.main.async {
                if self.parent.currentPage != pageIndex {
                    self.parent.currentPage = pageIndex
                }
            }
        }

        #if os(iOS)
        @objc func swipeLeft(_ gesture: UISwipeGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            if pdfView.canGoToNextPage {
                // Haptic feedback for premium feel
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()

                // Simple fade transition
                UIView.transition(with: pdfView,
                                duration: 0.25,
                                options: [.transitionCrossDissolve, .allowUserInteraction],
                                animations: {
                    pdfView.goToNextPage(nil)
                }, completion: nil)
            }
        }

        @objc func swipeRight(_ gesture: UISwipeGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            if pdfView.canGoToPreviousPage {
                // Haptic feedback for premium feel
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()

                // Simple fade transition
                UIView.transition(with: pdfView,
                                duration: 0.25,
                                options: [.transitionCrossDissolve, .allowUserInteraction],
                                animations: {
                    pdfView.goToPreviousPage(nil)
                }, completion: nil)
            }
        }

        @objc func swipeUp(_ gesture: UISwipeGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }

            // Check if PDF is at fit-to-screen zoom level
            // PDFView's autoScales property means double-tap automatically fits
            // We can check if the scale is approximately the scaleFactorForSizeToFit
            let currentScale = pdfView.scaleFactor
            let fitScale = pdfView.scaleFactorForSizeToFit

            // Allow some tolerance for floating point comparison
            let tolerance: CGFloat = 0.10
            let isAtFitZoom = abs(currentScale - fitScale) < tolerance

            if isAtFitZoom {
                // Only trigger page management when at fit zoom
                onRequestPageManagement?()
            }
        }

        @objc func swipeDown(_ gesture: UISwipeGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }

            // Check if PDF is at fit-to-screen zoom level
            let currentScale = pdfView.scaleFactor
            let fitScale = pdfView.scaleFactorForSizeToFit

            // Allow some tolerance for floating point comparison
            let tolerance: CGFloat = 0.10
            let isAtFitZoom = abs(currentScale - fitScale) < tolerance

            if isAtFitZoom {
                // Only trigger metadata view when at fit zoom
                // Haptic feedback for premium feel
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()

                onRequestMetadataView?()
            }
        }
        #else
        // macOS keyboard event handling
        @objc func handleKeyDown(_ event: NSEvent) -> Bool {
            guard let pdfView = pdfView else { return false }

            switch event.keyCode {
            case 123: // Left arrow
                if pdfView.canGoToPreviousPage {
                    pdfView.goToPreviousPage(nil)
                    return true
                }
            case 124: // Right arrow
                if pdfView.canGoToNextPage {
                    pdfView.goToNextPage(nil)
                    return true
                }
            case 49: // Space
                if event.modifierFlags.contains(.shift) {
                    if pdfView.canGoToPreviousPage {
                        pdfView.goToPreviousPage(nil)
                        return true
                    }
                } else {
                    if pdfView.canGoToNextPage {
                        pdfView.goToNextPage(nil)
                        return true
                    }
                }
            default:
                break
            }
            return false
        }

        // macOS scroll wheel handling
        @objc func handleScrollWheel(_ event: NSEvent) {
            guard let pdfView = pdfView else { return }

            // Only handle horizontal scrolling or vertical with shift
            if abs(event.deltaY) > abs(event.deltaX) && !event.modifierFlags.contains(.shift) {
                // Vertical scroll - navigate pages
                if event.deltaY > 0.5 {
                    // Scrolling up - previous page
                    if pdfView.canGoToPreviousPage {
                        pdfView.goToPreviousPage(nil)
                    }
                } else if event.deltaY < -0.5 {
                    // Scrolling down - next page
                    if pdfView.canGoToNextPage {
                        pdfView.goToNextPage(nil)
                    }
                }
            }
        }

        #endif

        // MARK: - Zoom Gesture Handlers

        @objc func resetZoom(_ sender: Any) {
            guard let pdfView = pdfView else { return }
            
            // Implement cycling behavior for iOS double-tap:
            // Manual zoom → Fit Page (height)
            // Fit Page → Fit Width
            // Fit Width → Fit Page
            switch currentFitMode {
            case .manual:
                // From manual zoom, snap to Fit Page
                parent.applyFitToHeight(pdfView, coordinator: self)
                DispatchQueue.main.async {
                    self.parent.fitMode = .height
                }
            case .height:
                // From Fit Page, switch to Fit Width
                parent.applyFitToWidth(pdfView, coordinator: self)
                DispatchQueue.main.async {
                    self.parent.fitMode = .width
                }
            case .width:
                // From Fit Width, switch back to Fit Page
                parent.applyFitToHeight(pdfView, coordinator: self)
                DispatchQueue.main.async {
                    self.parent.fitMode = .height
                }
            }
        }

        #if os(macOS)
        @objc func scaleChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            // Treat scale changes after load as manual zoom
            if !isInitialLoad && !isReloadingDocument {
                lastKnownScaleFactor = pdfView.scaleFactor
                currentFitMode = .manual
                // Sync with parent's fitMode binding
                DispatchQueue.main.async {
                    self.parent.fitMode = .manual
                }
            }
        }
        #endif

    }
}

// MARK: - UIScrollViewDelegate for iOS zoom tracking
#if os(iOS)
extension PDFKitView.Coordinator: UIScrollViewDelegate, UIGestureRecognizerDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Track user zoom on iOS
        if !isInitialLoad && !isReloadingDocument, let pdfView = pdfView {
            lastKnownScaleFactor = pdfView.scaleFactor
            currentFitMode = .manual
            // Sync with parent's fitMode binding
            DispatchQueue.main.async {
                self.parent.fitMode = .manual
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
#endif

// Platform-specific type alias for ViewRepresentable
#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#else
typealias ViewRepresentable = NSViewRepresentable
#endif
