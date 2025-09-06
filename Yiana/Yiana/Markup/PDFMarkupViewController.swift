//
//  PDFMarkupViewController.swift
//  Yiana
//
//  PDF markup using PDFKit with reliable Save functionality
//

import UIKit
import PDFKit

#if os(iOS)

/// Tool types for markup
enum MarkupTool {
    case pen
    case text
    case eraser
}

/// Ink colors available
enum InkColor {
    case black
    case red
    case blue
    
    var uiColor: UIColor {
        switch self {
        case .black: return .black
        case .red: return .red
        case .blue: return .blue
        }
    }
}

/// View controller for PDF markup using PDFKit
class PDFMarkupViewController: UIViewController {
    
    // MARK: - Properties
    
    private let originalPDFData: Data
    private let pageIndex: Int
    private let completion: (Result<Data, Error>) -> Void
    
    private var pdfDocument: PDFDocument!
    private var currentPage: PDFPage!
    private var pdfView: PDFView!
    
    // Toolbar and tools
    private var toolbar: UIToolbar!
    private var currentTool: MarkupTool = .pen
    private var currentColor: InkColor = .black
    
    // Annotation tracking
    private var currentInkAnnotation: PDFAnnotation?
    private var inkPath: UIBezierPath?
    private var addedAnnotations: [PDFAnnotation] = []
    
    // Gesture recognizers
    private var drawingGestureRecognizer: UIPanGestureRecognizer!
    private var textGestureRecognizer: UITapGestureRecognizer!
    
    // MARK: - Initialization
    
    init(pdfData: Data, pageIndex: Int, completion: @escaping (Result<Data, Error>) -> Void) {
        self.originalPDFData = pdfData
        self.pageIndex = pageIndex
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        
        // Set modal presentation style
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // Load PDF document
        guard loadPDFDocument() else {
            completion(.failure(MarkupError.invalidPDF))
            dismiss(animated: true)
            return
        }
        
        setupNavigationBar()
        setupPDFView()
        setupToolbar()
        setupGestureRecognizers()
    }
    
    // MARK: - Setup Methods
    
    private func loadPDFDocument() -> Bool {
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
    
    private func setupNavigationBar() {
        // Create navigation bar
        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Create navigation item with buttons
        let navItem = UINavigationItem(title: "Markup Page \(pageIndex + 1)")
        
        // Cancel button (always visible and working!)
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Save button (always visible and working!)
        navItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        navBar.setItems([navItem], animated: false)
    }
    
    private func setupPDFView() {
        pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemGray6
        
        // Display the single page
        let singlePageDocument = PDFDocument()
        singlePageDocument.insert(currentPage, at: 0)
        pdfView.document = singlePageDocument
        
        view.addSubview(pdfView)
        
        // Position below navigation bar and above toolbar
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
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
        
        // Create toolbar items
        let penButton = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain,
            target: self,
            action: #selector(penToolSelected)
        )
        penButton.tintColor = currentTool == .pen ? .systemBlue : .label
        
        let textButton = UIBarButtonItem(
            image: UIImage(systemName: "textformat"),
            style: .plain,
            target: self,
            action: #selector(textToolSelected)
        )
        textButton.tintColor = currentTool == .text ? .systemBlue : .label
        
        let eraserButton = UIBarButtonItem(
            image: UIImage(systemName: "eraser"),
            style: .plain,
            target: self,
            action: #selector(eraserToolSelected)
        )
        eraserButton.tintColor = currentTool == .eraser ? .systemBlue : .label
        
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // Color buttons
        let blackButton = createColorButton(color: .black)
        let redButton = createColorButton(color: .red)
        let blueButton = createColorButton(color: .blue)
        
        toolbar.setItems([
            penButton, spacer,
            textButton, spacer,
            eraserButton, spacer,
            blackButton, spacer,
            redButton, spacer,
            blueButton
        ], animated: false)
    }
    
    private func createColorButton(color: InkColor) -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.backgroundColor = color.uiColor
        button.layer.cornerRadius = 15
        button.layer.borderWidth = currentColor == color ? 3 : 1
        button.layer.borderColor = UIColor.systemGray.cgColor
        
        button.addTarget(self, action: #selector(colorSelected(_:)), for: .touchUpInside)
        button.tag = color.hashValue
        
        return UIBarButtonItem(customView: button)
    }
    
    private func setupGestureRecognizers() {
        // Drawing gesture
        drawingGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleDrawing(_:)))
        drawingGestureRecognizer.delegate = self
        
        // Text placement gesture
        textGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTextPlacement(_:)))
        textGestureRecognizer.delegate = self
        
        updateGestureRecognizers()
    }
    
    private func updateGestureRecognizers() {
        // Remove all gesture recognizers
        pdfView.gestureRecognizers?.forEach { pdfView.removeGestureRecognizer($0) }
        
        // Add appropriate recognizer based on current tool
        switch currentTool {
        case .pen:
            pdfView.addGestureRecognizer(drawingGestureRecognizer)
        case .text:
            pdfView.addGestureRecognizer(textGestureRecognizer)
        case .eraser:
            pdfView.addGestureRecognizer(drawingGestureRecognizer)
        }
    }
    
    // MARK: - Tool Selection
    
    @objc private func penToolSelected() {
        currentTool = .pen
        updateGestureRecognizers()
        updateToolbarSelection()
    }
    
    @objc private func textToolSelected() {
        currentTool = .text
        updateGestureRecognizers()
        updateToolbarSelection()
    }
    
    @objc private func eraserToolSelected() {
        currentTool = .eraser
        updateGestureRecognizers()
        updateToolbarSelection()
    }
    
    @objc private func colorSelected(_ sender: UIButton) {
        // Determine which color was selected based on tag
        if sender.tag == InkColor.black.hashValue {
            currentColor = .black
        } else if sender.tag == InkColor.red.hashValue {
            currentColor = .red
        } else if sender.tag == InkColor.blue.hashValue {
            currentColor = .blue
        }
        updateToolbarSelection()
    }
    
    private func updateToolbarSelection() {
        // Update toolbar item tints to show selection
        guard let items = toolbar.items else { return }
        
        // Update tool selection
        items[0].tintColor = currentTool == .pen ? .systemBlue : .label
        items[2].tintColor = currentTool == .text ? .systemBlue : .label
        items[4].tintColor = currentTool == .eraser ? .systemBlue : .label
        
        // Update color selection
        for item in items {
            if let button = item.customView as? UIButton {
                if button.tag == InkColor.black.hashValue {
                    button.layer.borderWidth = currentColor == .black ? 3 : 1
                } else if button.tag == InkColor.red.hashValue {
                    button.layer.borderWidth = currentColor == .red ? 3 : 1
                } else if button.tag == InkColor.blue.hashValue {
                    button.layer.borderWidth = currentColor == .blue ? 3 : 1
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func saveTapped() {
        print("DEBUG PDFMarkup: Save button tapped")
        
        // Flatten annotations and save
        if let flattenedData = flattenAnnotations() {
            completion(.success(flattenedData))
            dismiss(animated: true)
        } else {
            let alert = UIAlertController(
                title: "Save Error",
                message: "Failed to save markup. Please try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func cancelTapped() {
        print("DEBUG PDFMarkup: Cancel button tapped")
        
        // Confirm if there are changes
        if !addedAnnotations.isEmpty {
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
    
    // MARK: - Gesture Handlers
    
    @objc private func handleDrawing(_ gesture: UIPanGestureRecognizer) {
        guard let page = pdfView.currentPage else { return }
        
        let locationInView = gesture.location(in: pdfView)
        let locationOnPage = pdfView.convert(locationInView, to: page)
        
        switch currentTool {
        case .pen:
            handlePenDrawing(gesture: gesture, at: locationOnPage, on: page)
        case .eraser:
            handleEraser(at: locationOnPage, on: page)
        default:
            break
        }
    }
    
    private func handlePenDrawing(gesture: UIPanGestureRecognizer, at point: CGPoint, on page: PDFPage) {
        switch gesture.state {
        case .began:
            // Start a new ink annotation
            let bounds = CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)
            let inkAnnotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            inkAnnotation.color = currentColor.uiColor
            
            // Initialize the path
            inkPath = UIBezierPath()
            inkPath?.move(to: point)
            
            // Create the ink paths array for PDFAnnotation
            let path = UIBezierPath()
            path.move(to: point)
            inkAnnotation.add(path)
            
            page.addAnnotation(inkAnnotation)
            currentInkAnnotation = inkAnnotation
            addedAnnotations.append(inkAnnotation)
            
            print("DEBUG PDFMarkup: Started ink annotation at \(point)")
            
        case .changed:
            guard let annotation = currentInkAnnotation else { return }
            
            // For ink annotations, we need to recreate the path
            inkPath?.addLine(to: point)
            
            // Remove old annotation and add updated one
            page.removeAnnotation(annotation)
            
            // Calculate new bounds
            var bounds = annotation.bounds
            bounds = bounds.union(CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2))
            
            // Create new annotation with updated path
            let newAnnotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            newAnnotation.color = currentColor.uiColor
            if let path = inkPath {
                newAnnotation.add(path)
            }
            
            page.addAnnotation(newAnnotation)
            currentInkAnnotation = newAnnotation
            
            // Update our tracking
            if let index = addedAnnotations.firstIndex(of: annotation) {
                addedAnnotations[index] = newAnnotation
            }
            
            // Force redraw
            pdfView.setNeedsDisplay()
            
        case .ended, .cancelled:
            currentInkAnnotation = nil
            inkPath = nil
            print("DEBUG PDFMarkup: Ended ink annotation")
            
        default:
            break
        }
    }
    
    private func handleEraser(at point: CGPoint, on page: PDFPage) {
        // Find annotation at point and remove it
        for annotation in page.annotations {
            if annotation.bounds.contains(point) {
                page.removeAnnotation(annotation)
                if let index = addedAnnotations.firstIndex(of: annotation) {
                    addedAnnotations.remove(at: index)
                }
                pdfView.setNeedsDisplay()
                print("DEBUG PDFMarkup: Erased annotation at \(point)")
                break
            }
        }
    }
    
    @objc private func handleTextPlacement(_ gesture: UITapGestureRecognizer) {
        guard let page = pdfView.currentPage else { return }
        
        let locationInView = gesture.location(in: pdfView)
        let locationOnPage = pdfView.convert(locationInView, to: page)
        
        // Create text input field
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemBackground
        textField.placeholder = "Enter text"
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to view at tap location
        view.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: locationInView.x),
            textField.centerYAnchor.constraint(equalTo: view.topAnchor, constant: locationInView.y),
            textField.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        // Become first responder
        textField.becomeFirstResponder()
        
        // Handle text completion
        textField.addAction(UIAction { [weak self, weak textField] _ in
            guard let self = self,
                  let text = textField?.text,
                  !text.isEmpty else {
                textField?.removeFromSuperview()
                return
            }
            
            // Create text annotation
            let textBounds = CGRect(x: locationOnPage.x, y: locationOnPage.y - 20, width: 200, height: 40)
            let textAnnotation = PDFAnnotation(bounds: textBounds, forType: .freeText, withProperties: nil)
            textAnnotation.contents = text
            textAnnotation.font = UIFont.systemFont(ofSize: 16)
            textAnnotation.fontColor = self.currentColor.uiColor
            textAnnotation.color = UIColor.clear // Background color
            
            page.addAnnotation(textAnnotation)
            self.addedAnnotations.append(textAnnotation)
            
            // Remove text field
            textField?.removeFromSuperview()
            
            // Force redraw
            self.pdfView.setNeedsDisplay()
            
            print("DEBUG PDFMarkup: Added text annotation: \(text)")
            
        }, for: .editingDidEndOnExit)
    }
    
    // MARK: - Annotation Flattening
    
    private func flattenAnnotations() -> Data? {
        print("DEBUG PDFMarkup: Flattening \(addedAnnotations.count) annotations")
        
        guard let page = pdfDocument.page(at: pageIndex) else {
            print("DEBUG PDFMarkup: Failed to get page at index \(pageIndex)")
            return nil
        }
        
        // Get the page bounds
        let pageBounds = page.bounds(for: .mediaBox)
        
        // Create a new PDF with the flattened content
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        
        let flattenedPageData = pdfRenderer.pdfData { context in
            context.beginPage()
            
            // Draw the original page with annotations
            // This automatically includes all annotations as they're part of the page
            UIGraphicsPushContext(context.cgContext)
            page.draw(with: .mediaBox, to: context.cgContext)
            UIGraphicsPopContext()
        }
        
        // Create a new PDF document from the flattened page
        guard let flattenedPageDoc = PDFDocument(data: flattenedPageData),
              let flattenedPage = flattenedPageDoc.page(at: 0) else {
            print("DEBUG PDFMarkup: Failed to create flattened page")
            return nil
        }
        
        // Replace the page in the original document
        pdfDocument.removePage(at: pageIndex)
        pdfDocument.insert(flattenedPage, at: pageIndex)
        
        // Return the complete document
        let finalData = pdfDocument.dataRepresentation()
        print("DEBUG PDFMarkup: Successfully flattened page \(pageIndex + 1)")
        
        return finalData
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PDFMarkupViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our gestures to work with PDFView's built-in gestures
        return false
    }
}

// MARK: - Error Types

extension PDFMarkupViewController {
    enum MarkupError: LocalizedError {
        case invalidPDF
        case userCancelled
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return "Invalid PDF document"
            case .userCancelled:
                return "Markup cancelled"
            case .saveFailed:
                return "Failed to save markup"
            }
        }
    }
}

#endif