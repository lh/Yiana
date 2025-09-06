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
        // Will be implemented in next step
        print("DEBUG PDFMarkup: Drawing gesture - tool: \(currentTool)")
    }
    
    @objc private func handleTextPlacement(_ gesture: UITapGestureRecognizer) {
        // Will be implemented in next step
        print("DEBUG PDFMarkup: Text placement at \(gesture.location(in: pdfView))")
    }
    
    // MARK: - Annotation Flattening
    
    private func flattenAnnotations() -> Data? {
        print("DEBUG PDFMarkup: Flattening \(addedAnnotations.count) annotations")
        
        // For now, just return the original document with annotations
        // Proper flattening will be implemented next
        return pdfDocument.dataRepresentation()
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