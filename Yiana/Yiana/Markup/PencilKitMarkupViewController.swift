//
//  PencilKitMarkupViewController.swift
//  Yiana
//
//  Markup using PencilKit overlay; flattens strokes into PDF on save
//

import UIKit
import PDFKit
import PencilKit

#if os(iOS)

final class PencilKitMarkupViewController: UIViewController, PKCanvasViewDelegate {

    // MARK: - Inputs
    private let originalPDFData: Data
    private let pageIndex: Int
    private let completion: (Result<Data, Error>) -> Void

    // MARK: - UI
    private var navigationBar: UINavigationBar!
    private var containerView: UIView!
    private var pdfView: PDFView!
    private var canvasView: PKCanvasView!
    private var toolPicker: PKToolPicker?

    // MARK: - PDF State
    private var pdfDocument: PDFDocument!
    private var currentPage: PDFPage!
    private var pageBounds: CGRect = .zero

    // MARK: - Init
    init(pdfData: Data, pageIndex: Int, completion: @escaping (Result<Data, Error>) -> Void) {
        self.originalPDFData = pdfData
        self.pageIndex = pageIndex
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        setupToolPicker()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        centerContainer()
    }

    // MARK: - Setup
    private func setupPDF() -> Bool {
        guard let doc = PDFDocument(data: originalPDFData),
              pageIndex >= 0, pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex) else { return false }
        pdfDocument = doc
        currentPage = page
        pageBounds = page.bounds(for: .mediaBox)
        return true
    }

    private func setupUI() {
        setupNavigationBar()

        // Container sized exactly to page points
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 12),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: pageBounds.width),
            containerView.heightAnchor.constraint(equalToConstant: pageBounds.height)
        ])

        // PDFView shows only this page
        pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePage
        pdfView.autoScales = false
        pdfView.isUserInteractionEnabled = false
        pdfView.backgroundColor = .white
        let single = PDFDocument()
        single.insert(currentPage, at: 0)
        pdfView.document = single
        containerView.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // Scale PDF content to fill (1.0 means 1pt == 1pt in container)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let docBounds = self.pdfView.documentView?.bounds ?? .zero
            let scale = self.pageBounds.width / max(1.0, docBounds.width)
            self.pdfView.scaleFactor = scale
        }

        // PencilKit canvas overlay
        canvasView = PKCanvasView()
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = self
        containerView.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
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
        navItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        navigationBar.setItems([navItem], animated: false)
    }

    private func centerContainer() {
        // Add horizontal margins by adjusting constraints (already centered via centerX)
        // Vertical centering below nav bar via additional top space handled by layout
    }

    private func setupToolPicker() {
        if let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            let picker = PKToolPicker()
            picker.addObserver(canvasView)
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
            picker.showsDrawingPolicyControls = true
            toolPicker = picker
        }
    }

    // MARK: - Actions
    @objc private func cancelTapped() {
        completion(.failure(MarkupError.userCancelled))
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        guard let data = flattenAnnotations() else {
            completion(.failure(MarkupError.saveFailed))
            dismiss(animated: true)
            return
        }
        completion(.success(data))
        dismiss(animated: true)
    }

    // MARK: - Flattening
    private func flattenAnnotations() -> Data? {
        guard let page = pdfDocument.page(at: pageIndex) else { return nil }
        let bounds = page.bounds(for: .mediaBox)

        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext

            // Draw original page (flip to PDF coord system)
            cg.saveGState()
            cg.translateBy(x: 0, y: bounds.height)
            cg.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()

            // Draw PencilKit overlay as image in view coords
            // Use scale 1.0 to match page points; canvasView == page size
            let image = canvasView.drawing.image(from: canvasView.bounds, scale: 1.0)
            image.draw(in: bounds)
        }

        guard let flattenedPageDoc = PDFDocument(data: data),
              let flattenedPage = flattenedPageDoc.page(at: 0) else { return nil }
        pdfDocument.removePage(at: pageIndex)
        pdfDocument.insert(flattenedPage, at: pageIndex)
        return pdfDocument.dataRepresentation()
    }
}

extension PencilKitMarkupViewController {
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

