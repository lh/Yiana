//
//  PDFViewer.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit
import OSLog

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
    @State private var indicatorTrigger: UUID = UUID() // Used to trigger indicator show
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
                   indicatorTrigger: $indicatorTrigger,
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
            .onChange(of: indicatorTrigger) { _, _ in
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

#if DEBUG
private let pdfViewerLog = Logger(subsystem: "com.vitygas.yiana", category: "PDFViewer")
private func pdfDebug(_ message: String) {
    pdfViewerLog.debug("\(message, privacy: .public)")
}
#else
private func pdfDebug(_ message: String) {}
#endif

#if os(iOS)
final class SizeAwarePDFView: PDFView {
    var onLayout: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.size)
    }
}
#else
final class SizeAwarePDFView: PDFView {
    var onLayout: ((CGSize) -> Void)?

    override func layout() {
        super.layout()
        onLayout?(bounds.size)
    }
}
#endif

struct PDFKitView: ViewRepresentable {
    let pdfData: Data
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var navigateToPage: Int?
    @Binding var zoomAction: PDFZoomAction?
    @Binding var fitMode: FitMode
    @Binding var indicatorTrigger: UUID
    let onRequestPageManagement: (() -> Void)?
    let onRequestMetadataView: (() -> Void)?

    #if os(iOS)
    func makeUIView(context: Context) -> PDFView {
        let pdfView = SizeAwarePDFView()
        context.coordinator.isInitialLoad = true
        pdfDebug("makeUIView: preparing new PDFView; mainThread=\(Thread.isMainThread)")
        configurePDFView(pdfView, context: context)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.pdfView = pdfView
        let signature = pdfData.count
        let previousSignature = context.coordinator.pdfDataSignature ?? -1
        let boundsSize = pdfView.bounds.size
        let currentScale = pdfView.scaleFactor
        pdfDebug("updateUIView start: signature=\(signature) previous=\(previousSignature) awaitingFit=\(context.coordinator.awaitingInitialFit) bounds=\(boundsSize) scale=\(currentScale)")
        guard context.coordinator.pdfDataSignature != signature else {
            // No document change, skip to navigation/zoom handling
            if let document = pdfView.document {
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
            return
        }

        // Document signature changed - new document to load
        context.coordinator.pdfDataSignature = signature
        context.coordinator.lastReportedPageIndex = nil

        guard let document = PDFDocument(data: pdfData) else {
            // Document load failed
            pdfView.document = nil
            DispatchQueue.main.async {
                self.totalPages = 0
                self.currentPage = 0
                context.coordinator.isReloadingDocument = false
                context.coordinator.awaitingInitialFit = false
                pdfDebug("updateUIView async: document failed to load; resetting state")
            }
            return
        }

        // Document loaded successfully
        pdfDebug("updateUIView detected new document; pageCount=\(document.pageCount)")
        context.coordinator.isReloadingDocument = true
        context.coordinator.awaitingInitialFit = true
        DispatchQueue.main.async {
            let pageCount = document.pageCount
            let clamped = max(0, min(self.currentPage, pageCount - 1))
            pdfView.document = nil
            pdfView.document = document
            pdfDebug("updateUIView async: document assigned; clampedPage=\(clamped) awaitingFit=\(context.coordinator.awaitingInitialFit)")

            #if os(iOS)
            pdfView.documentView?.setNeedsDisplay()
            #else
            pdfView.documentView?.needsDisplay = true
            #endif
            pdfView.layoutDocumentView()

            // iOS: Always use fit-to-width for natural vertical scrolling with top-alignment
            // User can double-tap to toggle to fit-to-height if desired
            // Check if bounds are valid before applying fit
            if pdfView.bounds.width > 0 && pdfView.bounds.height > 0 {
                pdfDebug("📍 Initial fit mode: fit-to-width, bounds=\(pdfView.bounds.size)")
                self.applyFitToWidth(pdfView, coordinator: context.coordinator)
                pdfDebug("📍 AFTER applyFitToWidth: scale=\(pdfView.scaleFactor) awaitingFit=\(context.coordinator.awaitingInitialFit) bounds=\(pdfView.bounds.size)")
            } else {
                // Bounds not ready yet, leave awaitingInitialFit=true so layout observer handles it
                pdfDebug("📍 Bounds not ready (0.0, 0.0), deferring fit-to-width to layout observer")
            }

            // THEN navigate to page with correct scale already set
            document.page(at: clamped).map { page in
                pdfView.go(to: page)
                context.coordinator.lastReportedPageIndex = clamped
            }

            self.totalPages = pageCount
            if self.currentPage != clamped {
                self.currentPage = clamped
            }
            context.coordinator.isReloadingDocument = false
            pdfDebug("updateUIView async: finished initial document setup; awaitingFit=\(context.coordinator.awaitingInitialFit)")
        }
    }
    #else
    func makeNSView(context: Context) -> PDFView {
        let pdfView = SizeAwarePDFView()
        context.coordinator.isInitialLoad = true
        pdfDebug("makeNSView: preparing new PDFView; mainThread=\(Thread.isMainThread)")
        configurePDFView(pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.pdfView = pdfView
        let signature = pdfData.count
        let previousSignature = context.coordinator.pdfDataSignature ?? -1
        let boundsSize = pdfView.bounds.size
        let currentScale = pdfView.scaleFactor
        pdfDebug("updateNSView start: signature=\(signature) previous=\(previousSignature) awaitingFit=\(context.coordinator.awaitingInitialFit) bounds=\(boundsSize) scale=\(currentScale)")
        guard context.coordinator.pdfDataSignature != signature else {
            // No document change, skip to navigation/zoom handling
            if let document = pdfView.document {
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
            return
        }

        // Document signature changed - new document to load
        context.coordinator.pdfDataSignature = signature
        context.coordinator.lastReportedPageIndex = nil

        guard let document = PDFDocument(data: pdfData) else {
            // Document load failed
            pdfView.document = nil
            DispatchQueue.main.async {
                self.totalPages = 0
                self.currentPage = 0
                context.coordinator.isReloadingDocument = false
                context.coordinator.awaitingInitialFit = false
                pdfDebug("updateNSView async: document failed to load; resetting state")
            }
            return
        }

        // Document loaded successfully
        pdfDebug("updateNSView detected new document; pageCount=\(document.pageCount)")
        context.coordinator.isReloadingDocument = true
        context.coordinator.awaitingInitialFit = true
        DispatchQueue.main.async {
            let pageCount = document.pageCount
            let clamped = max(0, min(self.currentPage, pageCount - 1))
            pdfView.document = nil
            pdfView.document = document
            pdfDebug("updateNSView async: document assigned; clampedPage=\(clamped) awaitingFit=\(context.coordinator.awaitingInitialFit)")
            document.page(at: clamped).map { page in
                pdfView.go(to: page)
                context.coordinator.lastReportedPageIndex = clamped
                pdfDebug("updateNSView async: navigated to page \(clamped)")
            }
            #if os(iOS)
            pdfView.documentView?.setNeedsDisplay()
            #else
            pdfView.documentView?.needsDisplay = true
            #endif
            pdfView.layoutDocumentView()
            let applied = self.applyFitToHeight(pdfView, coordinator: context.coordinator)
            pdfDebug("updateNSView async: layoutDocumentView appliedFit=\(applied) awaitingFit=\(context.coordinator.awaitingInitialFit) bounds=\(pdfView.bounds.size)")
            self.totalPages = pageCount
            if self.currentPage != clamped {
                self.currentPage = clamped
            }
            context.coordinator.isReloadingDocument = false
            pdfDebug("updateNSView async: finished initial document setup; awaitingFit=\(context.coordinator.awaitingInitialFit)")
        }
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Zoom Helpers

    #if os(iOS)
    /// No-op on iOS when using UIPageViewController - the page controller handles all layout
    private func centerPDFContent(in pdfView: PDFView, coordinator: Coordinator) {
        // Page view controller manages content positioning
    }

    /// Top-align PDF content for fit-to-width mode (natural reading flow)
    private func topAlignContent(in pdfView: PDFView) {
        func findScrollView(in view: UIView) -> UIScrollView? {
            if let scrollView = view as? UIScrollView { return scrollView }
            for subview in view.subviews {
                if let found = findScrollView(in: subview) { return found }
            }
            return nil
        }

        guard let scrollView = findScrollView(in: pdfView) else {
            pdfDebug("topAlignContent: no scroll view found")
            return
        }

        // Set Y offset to 0 to show top of page
        let beforeOffset = scrollView.contentOffset
        var newOffset = scrollView.contentOffset
        newOffset.y = 0
        scrollView.setContentOffset(newOffset, animated: false)

        // Force layout to prevent UIPageViewController from overriding
        scrollView.layoutIfNeeded()

        let afterOffset = scrollView.contentOffset
        pdfDebug("topAlignContent: before=\(beforeOffset.y) after=\(afterOffset.y) contentSize=\(scrollView.contentSize)")
    }
    #endif

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
        coordinator.awaitingInitialFit = false

        #if os(iOS)
        // Top-align content immediately - no timing hack needed with vertical continuous scrolling
        topAlignContent(in: pdfView)
        #endif
    }
    
    @discardableResult
    private func applyFitToHeight(_ pdfView: PDFView, coordinator: Coordinator) -> Bool {
        pdfDebug("applyFitToHeight start: awaiting=\(coordinator.awaitingInitialFit) currentFit=\(coordinator.currentFitMode) bounds=\(pdfView.bounds.size)")
        let page = pdfView.currentPage ?? {
            guard let document = pdfView.document else { return nil }
            if let index = coordinator.lastReportedPageIndex,
               let candidate = document.page(at: index) {
                return candidate
            }
            return document.page(at: 0)
        }()

        guard let page else {
            pdfDebug("applyFitToHeight abort: no page; awaiting=\(coordinator.awaitingInitialFit)")
            return false
        }

        #if os(iOS)
        pdfView.layoutIfNeeded()
        let layoutFrameHeight = pdfView.safeAreaLayoutGuide.layoutFrame.height
        let viewHeight = layoutFrameHeight > 0 ? layoutFrameHeight : pdfView.bounds.height
        #else
        pdfView.layoutSubtreeIfNeeded()
        let viewHeight = pdfView.bounds.height
        #endif
        pdfDebug("applyFitToHeight using viewHeight=\(viewHeight)")
        guard viewHeight > 0 else {
            pdfDebug("applyFitToHeight abort: zero height; awaiting=\(coordinator.awaitingInitialFit)")
            return false
        }

        let pageRect = page.bounds(for: pdfView.displayBox)
        let scaleFactor = viewHeight / pageRect.height
        guard scaleFactor.isFinite, scaleFactor > 0 else {
            pdfDebug("applyFitToHeight abort: invalid scale=\(scaleFactor)")
            return false
        }

        pdfView.scaleFactor = scaleFactor
        coordinator.lastKnownScaleFactor = scaleFactor
        coordinator.currentFitMode = .height
        coordinator.lastExplicitFitMode = .height
        coordinator.awaitingInitialFit = false

        pdfDebug("applyFitToHeight success: scaleFactor=\(scaleFactor) viewHeight=\(viewHeight)")

        DispatchQueue.main.async {
            self.fitMode = .height
            let actualScale = pdfView.scaleFactor
            let matches = abs(actualScale - scaleFactor) < 0.001
            pdfDebug("⚠️ SCALE CHECK: set=\(scaleFactor) actual=\(actualScale) match=\(matches)")
        }

        return true
    }

    private func configurePDFView(_ pdfView: PDFView, context: Context) {
        // Store reference to pdfView in coordinator
        context.coordinator.pdfView = pdfView
        pdfDebug("configurePDFView: setup start autoScales=\(pdfView.autoScales) initialLoad=\(context.coordinator.isInitialLoad)")

        // Common configuration for both platforms
        // Disable autoScales to take manual control over zoom
        pdfView.autoScales = false
        
        // EXPERIMENTAL: Test vertical continuous scrolling to see if flickering issues are resolved
        // If this works well, it enables natural vertical scrolling and top-aligned fit-to-width
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = false

        #if os(iOS)
        // Use white background to match typical PDF page color
        pdfView.backgroundColor = UIColor.systemBackground
        // Disable shadows for better performance
        pdfView.pageShadowsEnabled = false

        // EXPERIMENTAL: Disable page view controller for vertical continuous scrolling
        // Page view controller conflicts with .singlePageContinuous mode
        pdfView.usePageViewController(false, withViewOptions: nil)
        pdfDebug("usePageViewController disabled for vertical scrolling test")

        // Add rendering optimizations for smoother transitions
        pdfView.interpolationQuality = .high
        pdfView.displayBox = .cropBox

        // Vertical swipe gestures removed - conflicts with vertical continuous scrolling
        // Page organizer access: tap page indicator
        // Metadata access: info icon in navigation bar

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
            context.coordinator.awaitingInitialFit = true
            
            // Set scale limits and initial zoom after document layout completes
            DispatchQueue.main.async {
                pdfView.layoutDocumentView()

                // Only set scale limits if we have a valid fit scale
                let fitScale = pdfView.scaleFactorForSizeToFit
                guard fitScale > 0 else { return }
                pdfView.minScaleFactor = fitScale * 0.5
                pdfView.maxScaleFactor = fitScale * 4.0

            }
        }

        // Only attach layout observer on macOS (iOS uses page view controller which handles layout)
        #if os(macOS)
        context.coordinator.attachLayoutObserver(to: pdfView)
        #endif
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
                    guard navigateToPage == nil && currentPageIndex > 0 && document.pageCount > 0 else { return }
                    // Adjust page index if pages were deleted before current position
                    let pageToShow = min(currentPageIndex, document.pageCount - 1)
                    document.page(at: pageToShow).map { page in
                        pdfView.go(to: page)
                        self.currentPage = pageToShow
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
        var awaitingInitialFit = false
        #if os(macOS)
        var keyEventMonitor: Any?
        var scrollEventMonitor: Any?
        #endif

        init(_ parent: PDFKitView) {
            self.parent = parent
            self.onRequestPageManagement = parent.onRequestPageManagement
            self.onRequestMetadataView = parent.onRequestMetadataView
        }

        func attachLayoutObserver(to pdfView: PDFView) {
            guard let sizeAwareView = pdfView as? SizeAwarePDFView else {
                pdfDebug("attachLayoutObserver: PDFView is not SizeAwarePDFView")
                return
            }
            pdfDebug("attachLayoutObserver: registered layout callback")
            sizeAwareView.onLayout = { [weak self, weak pdfView] _ in
                guard let self, let pdfView else { return }
                self.handleLayout(for: pdfView)
            }
        }

        func handleLayout(for pdfView: PDFView) {
            #if os(iOS)
            // On iOS, only handle layout if we're awaiting initial fit (bounds weren't ready earlier)
            guard awaitingInitialFit else { return }
            #endif

            let isLandscape = pdfView.bounds.width > pdfView.bounds.height
            pdfDebug("handleLayout: awaiting=\(awaitingInitialFit) size=\(pdfView.bounds.size) orientation=\(isLandscape ? "landscape" : "portrait") currentFit=\(currentFitMode) parentFit=\(parent.fitMode) reloading=\(isReloadingDocument)")

            if awaitingInitialFit {
                pdfDebug("handleLayout: triggering deferred fit")
                #if os(iOS)
                // iOS: Always fit-to-width
                parent.applyFitToWidth(pdfView, coordinator: self)
                #else
                // macOS: Use orientation-aware fit
                if isLandscape {
                    parent.applyFitToWidth(pdfView, coordinator: self)
                } else {
                    _ = parent.applyFitToHeight(pdfView, coordinator: self)
                }
                #endif
                return
            }

            // Reapply fit mode after layout changes (like orientation changes)
            guard !isReloadingDocument else { return }

            if currentFitMode == .height, parent.fitMode == .height {
                pdfDebug("handleLayout: maintaining height fit after layout")
                _ = parent.applyFitToHeight(pdfView, coordinator: self)
            } else if currentFitMode == .width, parent.fitMode == .width {
                pdfDebug("handleLayout: maintaining width fit after layout")
                parent.applyFitToWidth(pdfView, coordinator: self)
            }
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

            guard !isReloadingDocument else { return }
            let pageIndex = document.index(for: currentPage)
            guard lastReportedPageIndex != pageIndex else { return }
            lastReportedPageIndex = pageIndex

            DispatchQueue.main.async {
                guard self.parent.currentPage != pageIndex else { return }
                self.parent.currentPage = pageIndex
            }
        }

        #if os(iOS)
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
                    guard pdfView.canGoToPreviousPage else { break }
                    pdfView.goToPreviousPage(nil)
                    return true
                } else {
                    guard pdfView.canGoToNextPage else { break }
                    pdfView.goToNextPage(nil)
                    return true
                }
            default:
                break
            }
            return false
        }

        // macOS scroll wheel handling
        @objc func handleScrollWheel(_ event: NSEvent) {
            guard let pdfView = pdfView else { return }

            // Only handle dominant vertical scrolling without the shift modifier
            let isVerticalScroll = abs(event.deltaY) > abs(event.deltaX) && !event.modifierFlags.contains(.shift)
            guard isVerticalScroll else { return }

            if event.deltaY > 0.5 {
                // Scrolling up - previous page
                guard pdfView.canGoToPreviousPage else { return }
                pdfView.goToPreviousPage(nil)
            } else if event.deltaY < -0.5 {
                // Scrolling down - next page
                guard pdfView.canGoToNextPage else { return }
                pdfView.goToNextPage(nil)
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
            case .height:
                // From Fit Page, switch to Fit Width
                parent.applyFitToWidth(pdfView, coordinator: self)
                DispatchQueue.main.async {
                    self.parent.fitMode = .width
                }
            case .width:
                // From Fit Width, switch back to Fit Page
                parent.applyFitToHeight(pdfView, coordinator: self)
            }

            // Trigger page indicator to show after zoom change
            DispatchQueue.main.async {
                self.parent.indicatorTrigger = UUID()
            }
        }

        #if os(macOS)
        @objc func scaleChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            pdfDebug("⚠️ SCALE CHANGED: \(pdfView.scaleFactor) isInitialLoad=\(isInitialLoad) isReloading=\(isReloadingDocument) awaiting=\(awaitingInitialFit)")
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
        if let pdfView = pdfView {
            pdfDebug("⚠️ iOS ZOOM: \(pdfView.scaleFactor) isInitialLoad=\(isInitialLoad) isReloading=\(isReloadingDocument) awaiting=\(awaitingInitialFit)")
        }
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
