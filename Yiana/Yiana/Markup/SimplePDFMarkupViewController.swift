//
//  SimplePDFMarkupViewController.swift
//  Yiana
//
//  Simplified PDF markup using proven patterns from reference implementations
//

#if os(iOS)

import UIKit
import PDFKit

class SimplePDFMarkupViewController: UIViewController {
    
    // MARK: - Properties
    
    private let originalPDFData: Data
    private let pageIndex: Int
    private let completion: (Result<Data, Error>) -> Void
    
    private var pdfView: PDFView!
    private var pdfDocument: PDFDocument!
    private var currentPage: PDFPage!
    
    // Drawing state
    private var currentPath: UIBezierPath?
    private var currentAnnotation: PDFAnnotation?
    private var allPaths: [UIBezierPath] = []
    
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
        
        // Show full document and navigate to the target page to avoid moving pages
        pdfView.document = pdfDocument
        pdfView.go(to: currentPage)
        
        view.addSubview(pdfView)
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44)
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
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([spacer, blackButton, spacer, redButton, spacer, blueButton, spacer], animated: false)
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
    
    // MARK: - Touch Handling (Key Implementation)
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let page = pdfView.currentPage else { return }
        
        let locationInView = touch.location(in: pdfView)
        let locationOnPage = pdfView.convert(locationInView, to: page)
        
        // Start a new path
        currentPath = UIBezierPath()
        currentPath?.lineWidth = 2.0
        currentPath?.lineCapStyle = .round
        currentPath?.lineJoinStyle = .round
        currentPath?.move(to: locationOnPage)
        
        print("DEBUG: Started drawing at \(locationOnPage)")
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let page = pdfView.currentPage,
              let path = currentPath else { return }
        
        let locationInView = touch.location(in: pdfView)
        let locationOnPage = pdfView.convert(locationInView, to: page)
        
        // Add to path
        path.addLine(to: locationOnPage)
        
        // Remove old annotation if exists
        if let oldAnnotation = currentAnnotation {
            page.removeAnnotation(oldAnnotation)
        }
        
        // Create new annotation with the complete path
        // Key insight: Create NEW annotation each time, don't modify existing
        let bounds = path.bounds.insetBy(dx: -5, dy: -5)
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = currentColor
        
        // Create a copy of the path for the annotation
        let pathCopy = UIBezierPath(cgPath: path.cgPath)
        annotation.add(pathCopy)
        
        page.addAnnotation(annotation)
        currentAnnotation = annotation
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let path = currentPath else { return }
        
        // Save the completed path
        allPaths.append(path)
        
        // Reset current drawing state
        currentPath = nil
        currentAnnotation = nil
        
        print("DEBUG: Ended drawing, total paths: \(allPaths.count)")
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Clean up if touch was cancelled
        if let annotation = currentAnnotation,
           let page = pdfView.currentPage {
            page.removeAnnotation(annotation)
        }
        currentPath = nil
        currentAnnotation = nil
    }
    
    // MARK: - Actions
    
    @objc private func colorSelected(_ sender: UIButton) {
        switch sender.tag {
        case 0: currentColor = .black
        case 1: currentColor = .red
        case 2: currentColor = .blue
        default: currentColor = .black
        }
        
        // Update button borders
        toolbar.items?.forEach { item in
            if let button = item.customView as? UIButton {
                button.layer.borderWidth = button.tag == sender.tag ? 3 : 1
            }
        }
    }
    
    @objc private func saveTapped() {
        // Flatten and save
        if let flattenedData = flattenAnnotations() {
            completion(.success(flattenedData))
            dismiss(animated: true)
        } else {
            showError("Failed to save markup")
        }
    }
    
    @objc private func cancelTapped() {
        if !allPaths.isEmpty {
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

// MARK: - Error Types

extension SimplePDFMarkupViewController {
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
