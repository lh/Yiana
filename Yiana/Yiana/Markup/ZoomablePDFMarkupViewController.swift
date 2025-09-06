//
//  ZoomablePDFMarkupViewController.swift
//  Yiana
//
//  PDF markup with zoom/pan support using overlay approach
//

import UIKit
import PDFKit

#if os(iOS)

class ZoomablePDFMarkupViewController: UIViewController {
    
    // MARK: - Properties
    
    private let originalPDFData: Data
    private let pageIndex: Int
    private let completion: (Result<Data, Error>) -> Void
    
    private var scrollView: UIScrollView!
    private var containerView: UIView!
    private var pdfView: PDFView!
    private var drawingView: DrawingView!
    private var pdfDocument: PDFDocument!
    private var currentPage: PDFPage!
    
    // UI
    private var navigationBar: UINavigationBar!
    private var toolbar: UIToolbar!
    private var currentColor: UIColor = .black
    private var isDrawingEnabled = true
    
    // Zoom tracking
    private var pageSize: CGSize = .zero
    
    // MARK: - Initialization
    
    init(pdfData: Data, pageIndex: Int, completion: @escaping (Result<Data, Error>) -> Void) {
        self.originalPDFData = pdfData
        self.pageIndex = pageIndex
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        guard setupPDF() else {
            completion(.failure(MarkupError.invalidPDF))
            dismiss(animated: true)
            return
        }
        
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Center and scale to fit after view appears
        centerAndScaleToFit()
    }
    
    // MARK: - Setup
    
    private func setupPDF() -> Bool {
        guard let document = PDFDocument(data: originalPDFData),
              pageIndex >= 0,
              pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else {
            return false
        }
        
        self.pdfDocument = document
        self.currentPage = page
        self.pageSize = page.bounds(for: .mediaBox).size
        return true
    }
    
    private func setupUI() {
        setupNavigationBar()
        setupScrollView()
        setupPDFView()
        setupDrawingOverlay()
        setupToolbar()
    }
    
    private func setupNavigationBar() {
        navigationBar = UINavigationBar()
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let navItem = UINavigationItem(title: "Markup Page \(pageIndex + 1)")
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        navigationBar.setItems([navItem], animated: false)
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44)
        ])
        
        // Container view to hold PDF and drawing
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: pageSize.width),
            containerView.heightAnchor.constraint(equalToConstant: pageSize.height),
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
    }
    
    private func setupPDFView() {
        pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePage
        pdfView.autoScales = false  // We handle scaling via scroll view
        pdfView.backgroundColor = .white
        pdfView.isUserInteractionEnabled = false
        
        // Create a document with just our page
        let singlePageDoc = PDFDocument()
        singlePageDoc.insert(currentPage, at: 0)
        pdfView.document = singlePageDoc
        
        containerView.addSubview(pdfView)
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Set scale factor to fill the container
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Calculate scale to make PDF fill the container view
            let scale = self.pageSize.width / (self.pdfView.documentView?.bounds.width ?? 1.0)
            self.pdfView.scaleFactor = scale
        }
    }
    
    private func setupDrawingOverlay() {
        drawingView = ZoomableDrawingView()
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        drawingView.backgroundColor = .clear
        drawingView.isOpaque = false
        
        containerView.addSubview(drawingView)
        
        NSLayoutConstraint.activate([
            drawingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            drawingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            drawingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            drawingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func setupToolbar() {
        toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        let panButton = UIBarButtonItem(
            image: UIImage(systemName: "hand.raised"),
            style: .plain,
            target: self,
            action: #selector(toggleDrawingMode)
        )
        panButton.tintColor = isDrawingEnabled ? .label : .systemBlue
        
        let blackButton = createColorButton(color: .black, tag: 0)
        let redButton = createColorButton(color: .red, tag: 1)
        let blueButton = createColorButton(color: .blue, tag: 2)
        let clearButton = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearTapped))
        let fitButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"),
            style: .plain,
            target: self,
            action: #selector(fitToScreen)
        )
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([
            panButton, spacer,
            blackButton, spacer,
            redButton, spacer,
            blueButton, spacer,
            clearButton, spacer,
            fitButton
        ], animated: false)
    }
    
    private func createColorButton(color: UIColor, tag: Int) -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.backgroundColor = color
        button.layer.cornerRadius = 15
        button.layer.borderWidth = color == currentColor ? 3 : 1
        button.layer.borderColor = UIColor.systemGray.cgColor
        button.tag = tag
        button.addTarget(self, action: #selector(colorSelected(_:)), for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }
    
    private func centerAndScaleToFit() {
        guard scrollView.bounds.size.width > 0 && scrollView.bounds.size.height > 0 else { return }
        
        let scrollViewSize = scrollView.bounds.size
        let widthScale = scrollViewSize.width / pageSize.width
        let heightScale = scrollViewSize.height / pageSize.height
        let minScale = min(widthScale, heightScale) * 0.95 // Slight padding
        
        scrollView.minimumZoomScale = minScale * 0.5
        scrollView.maximumZoomScale = max(5.0, minScale * 5.0)
        scrollView.zoomScale = minScale
        
        // Ensure the content is centered
        scrollView.contentOffset = CGPoint(
            x: (scrollView.contentSize.width - scrollView.bounds.width) / 2,
            y: (scrollView.contentSize.height - scrollView.bounds.height) / 2
        )
        
        centerContent()
    }
    
    private func centerContent() {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
    
    // MARK: - Actions
    
    @objc private func toggleDrawingMode() {
        isDrawingEnabled.toggle()
        drawingView.isUserInteractionEnabled = isDrawingEnabled
        scrollView.isScrollEnabled = !isDrawingEnabled
        scrollView.pinchGestureRecognizer?.isEnabled = !isDrawingEnabled
        
        // Update button appearance
        if let panButton = toolbar.items?.first {
            panButton.tintColor = isDrawingEnabled ? .label : .systemBlue
            panButton.image = UIImage(systemName: isDrawingEnabled ? "pencil.tip" : "hand.raised")
        }
        
    }
    
    @objc private func fitToScreen() {
        centerAndScaleToFit()
    }
    
    @objc private func colorSelected(_ sender: UIButton) {
        switch sender.tag {
        case 0: currentColor = .black
        case 1: currentColor = .red
        case 2: currentColor = .blue
        default: currentColor = .black
        }
        
        drawingView.strokeColor = currentColor
        
        // Update button borders
        toolbar.items?.forEach { item in
            if let button = item.customView as? UIButton {
                button.layer.borderWidth = button.tag == sender.tag ? 3 : 1
            }
        }
    }
    
    @objc private func clearTapped() {
        drawingView.clear()
    }
    
    @objc private func saveTapped() {
        // Add all drawn lines as annotations to the PDF page
        addDrawingAnnotationsToPDF()
        
        // Flatten and save
        if let flattenedData = flattenAnnotations() {
            completion(.success(flattenedData))
            dismiss(animated: true)
        } else {
            showError("Failed to save markup")
        }
    }
    
    @objc private func cancelTapped() {
        if !drawingView.lines.isEmpty {
            let alert = UIAlertController(
                title: "Discard Changes?",
                message: "You have unsaved markup. Are you sure you want to discard it?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
                self.completion(.failure(MarkupError.userCancelled))
                self.dismiss(animated: true)
            })
            alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
            present(alert, animated: true)
        } else {
            completion(.failure(MarkupError.userCancelled))
            dismiss(animated: true)
        }
    }
    
    // MARK: - PDF Annotation
    
    private func addDrawingAnnotationsToPDF() {
        guard let page = currentPage else { return }
        
        let pageBounds = page.bounds(for: .mediaBox)
        // Page bounds for annotation placement
        
        // Drawing coordinates: origin at top-left, Y increases downward
        // PDF coordinates: origin at bottom-left, Y increases upward
        
        for line in drawingView.lines {
            if line.points.isEmpty { continue }
            
            // First, find the bounds of the original line in drawing coordinates
            var minX = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude
            var minY = CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude
            
            for point in line.points {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
            
            // Convert bounds to PDF coordinates (flip Y)
            let pdfMinY = pageBounds.height - maxY  // maxY in drawing becomes minY in PDF
            let pdfMaxY = pageBounds.height - minY  // minY in drawing becomes maxY in PDF
            
            // Create the annotation bounds in PDF coordinates
            let annotationBounds = CGRect(
                x: minX - 5,
                y: pdfMinY - 5,
                width: (maxX - minX) + 10,
                height: (pdfMaxY - pdfMinY) + 10
            )
            
            // Create path with points relative to annotation bounds origin
            let path = UIBezierPath()
            var first = true
            
            for point in line.points {
                // Convert to PDF coordinates
                let pdfY = pageBounds.height - point.y
                // Make relative to annotation bounds
                let relativePoint = CGPoint(
                    x: point.x - annotationBounds.origin.x,
                    y: pdfY - annotationBounds.origin.y
                )
                
                if first {
                    path.move(to: relativePoint)
                    first = false
                } else {
                    path.addLine(to: relativePoint)
                }
            }
            
            // Create ink annotation
            let annotation = PDFAnnotation(bounds: annotationBounds, forType: .ink, withProperties: nil)
            annotation.color = line.color
            annotation.add(path)
            
            // Add to the page
            page.addAnnotation(annotation)
            
            // Line added with bounds and point count
        }
        
        // Successfully added annotations to PDF
    }
    
    // MARK: - Flattening
    
    private func flattenAnnotations() -> Data? {
        guard let page = pdfDocument.page(at: pageIndex) else { return nil }
        
        let pageBounds = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        
        let flattenedPageData = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            
            // Save state and flip coordinate system for PDF
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: pageBounds.height)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the page with annotations
            page.draw(with: .mediaBox, to: cgContext)
            
            cgContext.restoreGState()
        }
        
        // Create new document and replace page
        guard let flattenedPageDoc = PDFDocument(data: flattenedPageData),
              let flattenedPage = flattenedPageDoc.page(at: 0) else {
            return nil
        }
        
        pdfDocument.removePage(at: pageIndex)
        pdfDocument.insert(flattenedPage, at: pageIndex)
        
        return pdfDocument.dataRepresentation()
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIScrollViewDelegate

extension ZoomablePDFMarkupViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
    }
}

// MARK: - ZoomableDrawingView

class ZoomableDrawingView: DrawingView {
    // Inherits all functionality from DrawingView
    // Can be extended if needed for zoom-specific features
}

// MARK: - Error Types

extension ZoomablePDFMarkupViewController {
    enum MarkupError: LocalizedError {
        case invalidPDF
        case userCancelled
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidPDF: return "Invalid PDF document"
            case .userCancelled: return "Markup cancelled"
            case .saveFailed: return "Failed to save markup"
            }
        }
    }
}

#endif