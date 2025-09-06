//
//  OverlayPDFMarkupViewController.swift
//  Yiana
//
//  PDF markup using a transparent overlay view to capture touches
//

import UIKit
import PDFKit

#if os(iOS)

class OverlayPDFMarkupViewController: UIViewController {
    
    // MARK: - Properties
    
    private let originalPDFData: Data
    private let pageIndex: Int
    private let completion: (Result<Data, Error>) -> Void
    
    private var pdfView: PDFView!
    private var drawingView: DrawingView!
    private var pdfDocument: PDFDocument!
    private var currentPage: PDFPage!
    
    // UI
    private var navigationBar: UINavigationBar!
    private var toolbar: UIToolbar!
    private var currentColor: UIColor = .black
    
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
        return true
    }
    
    private func setupUI() {
        setupNavigationBar()
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
    
    private func setupPDFView() {
        pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemGray6
        pdfView.isUserInteractionEnabled = false // Disable interaction so overlay gets touches
        
        // Create a document with just our page
        let singlePageDoc = PDFDocument()
        singlePageDoc.insert(currentPage, at: 0)
        pdfView.document = singlePageDoc
        
        view.addSubview(pdfView)
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44)
        ])
        
        // Scale to fit after layout
        DispatchQueue.main.async { [weak self] in
            self?.pdfView.scaleFactor = self?.pdfView.scaleFactorForSizeToFit ?? 1.0
        }
    }
    
    private func setupDrawingOverlay() {
        drawingView = DrawingView()
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        drawingView.backgroundColor = .clear
        drawingView.isOpaque = false
        drawingView.pdfView = pdfView
        drawingView.currentPage = currentPage
        
        view.addSubview(drawingView)
        
        // Match PDFView's frame exactly
        NSLayoutConstraint.activate([
            drawingView.topAnchor.constraint(equalTo: pdfView.topAnchor),
            drawingView.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor),
            drawingView.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
            drawingView.bottomAnchor.constraint(equalTo: pdfView.bottomAnchor)
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
        
        let blackButton = createColorButton(color: .black, tag: 0)
        let redButton = createColorButton(color: .red, tag: 1)
        let blueButton = createColorButton(color: .blue, tag: 2)
        let clearButton = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearTapped))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([clearButton, spacer, blackButton, spacer, redButton, spacer, blueButton, spacer], animated: false)
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
    
    // MARK: - Actions
    
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
        
        // Remove all annotations from the page
        if let page = pdfView.currentPage {
            page.annotations.forEach { page.removeAnnotation($0) }
        }
    }
    
    @objc private func saveTapped() {
        print("DEBUG: Saving with \(drawingView.lines.count) lines")
        
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
        guard let page = pdfView.currentPage else { return }
        
        // Convert each line to a PDF annotation
        for line in drawingView.lines {
            if line.points.isEmpty { continue }
            
            // Convert points from view coordinates to PDF page coordinates
            let path = UIBezierPath()
            var pdfPoints: [CGPoint] = []
            
            for point in line.points {
                let pdfPoint = pdfView.convert(point, to: page)
                pdfPoints.append(pdfPoint)
            }
            
            if pdfPoints.isEmpty { continue }
            
            // Create path
            path.move(to: pdfPoints[0])
            for i in 1..<pdfPoints.count {
                path.addLine(to: pdfPoints[i])
            }
            
            // Calculate bounds with padding
            let bounds = path.bounds.insetBy(dx: -5, dy: -5)
            
            // Create ink annotation
            let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            annotation.color = line.color
            annotation.add(path)
            
            page.addAnnotation(annotation)
        }
        
        print("DEBUG: Added \(drawingView.lines.count) annotations to PDF")
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

// MARK: - DrawingView

class DrawingView: UIView {
    
    struct Line {
        var points: [CGPoint] = []
        var color: UIColor = .black
    }
    
    var lines: [Line] = []
    private var currentLine: Line?
    var strokeColor: UIColor = .black
    
    weak var pdfView: PDFView?
    weak var currentPage: PDFPage?
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(2.0)
        
        // Draw all completed lines
        for line in lines {
            guard line.points.count > 1 else { continue }
            
            context.setStrokeColor(line.color.cgColor)
            
            context.move(to: line.points[0])
            for i in 1..<line.points.count {
                context.addLine(to: line.points[i])
            }
            context.strokePath()
        }
        
        // Draw current line
        if let current = currentLine, current.points.count > 1 {
            context.setStrokeColor(current.color.cgColor)
            
            context.move(to: current.points[0])
            for i in 1..<current.points.count {
                context.addLine(to: current.points[i])
            }
            context.strokePath()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let point = touch.location(in: self)
        
        currentLine = Line(points: [point], color: strokeColor)
        
        print("DEBUG: Touch began at \(point)")
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let point = touch.location(in: self)
        currentLine?.points.append(point)
        
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var line = currentLine else { return }
        
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        line.points.append(point)
        
        lines.append(line)
        currentLine = nil
        
        setNeedsDisplay()
        
        print("DEBUG: Touch ended, total lines: \(lines.count)")
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentLine = nil
        setNeedsDisplay()
    }
    
    func clear() {
        lines.removeAll()
        currentLine = nil
        setNeedsDisplay()
    }
}

// MARK: - Error Types

extension OverlayPDFMarkupViewController {
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