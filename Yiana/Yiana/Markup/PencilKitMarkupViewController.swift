//
//  PencilKitMarkupViewController.swift
//  Yiana
//
//  Markup using PencilKit overlay; flattens strokes into PDF on save
//

#if os(iOS)
import UIKit
import PDFKit
import PencilKit

final class PencilKitMarkupViewController: UIViewController, PKCanvasViewDelegate, UIScrollViewDelegate {

    // MARK: - Inputs
    private let originalPDFData: Data
    private let pageIndex: Int
    private let completion: (Result<Data, Error>) -> Void

    // MARK: - UI
    private var navigationBar: UINavigationBar!
    private var scrollView: UIScrollView!
    private var containerView: UIView!
    private var pdfView: PDFView!
    private var canvasView: PKCanvasView!
    private var toolPicker: PKToolPicker?
    private var didSetupToolPicker = false
    private var toolbar: UIToolbar!
    private var panButton: UIBarButtonItem!
    private var textModeButton: UIBarButtonItem!
    private var textColorButtons: [UIBarButtonItem] = [] // legacy chips (not used now)
    private var colorButton: UIBarButtonItem!
    private var toolsButton: UIBarButtonItem!
    private var cachedToolbarItems: [UIBarButtonItem] = []
    private var didSetToolbarItems = false
    // Pod UI constants
    private let podButtonHeight: CGFloat = 30
    private let podSpacing: CGFloat = 6
    private let podPadding: CGFloat = 8
    private let podCornerRadius: CGFloat = 8
    // Floating controls overlay (non-zooming)
    private var controlsOverlay: UIView!
    private var verticalPod: UIView?
    private var horizontalPod: UIView?
    private var tapOverlayView: UIView!

    // MARK: - PDF State
    private var pdfDocument: PDFDocument!
    private var currentPage: PDFPage!
    private var pageBounds: CGRect = .zero
    private var textAnnotations: [TextAnnotation] = []
    private var isTextMode: Bool = false
    private var isPanZoomEnabled: Bool = false
    private var selectedLabel: UILabel?
    private var textColor: UIColor = .systemBlue // default blue as requested
    private var didApplyInitialFit = false
    private var currentTextColorTag: Int = 1 // 0=black,1=blue,2=red,3=purple

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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        centerContainer()
        if !didApplyInitialFit {
            fitAndCenter()
            didApplyInitialFit = true
            if !didSetToolbarItems && !cachedToolbarItems.isEmpty {
                toolbar.setItems(cachedToolbarItems, animated: false)
                didSetToolbarItems = true
            }
        }
        // Ensure toolbar items are set once we have a width
        if !didSetToolbarItems && toolbar.bounds.width > 0 && !cachedToolbarItems.isEmpty {
            toolbar.setItems(cachedToolbarItems, animated: false)
            didSetToolbarItems = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Safe to set up PencilKit tool picker when we have a window
        if !didSetupToolPicker {
            setupToolPicker()
            didSetupToolPicker = true
        }
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

        // Bottom toolbar
        setupBottomToolbar()

        // Scroll view to support pan/zoom when hand tool is active
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.isScrollEnabled = false // toggled by Hand tool
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: toolbar.topAnchor)
        ])

        // Non-zooming overlay for floating controls
        controlsOverlay = PassThroughView()
        controlsOverlay.translatesAutoresizingMaskIntoConstraints = false
        controlsOverlay.backgroundColor = .clear
        view.addSubview(controlsOverlay)
        NSLayoutConstraint.activate([
            controlsOverlay.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            controlsOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsOverlay.bottomAnchor.constraint(equalTo: toolbar.topAnchor)
        ])

        // Container sized exactly to page points inside scroll view
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalToConstant: pageBounds.width),
            containerView.heightAnchor.constraint(equalToConstant: pageBounds.height)
        ])

        // PDFView shows the full document; we navigate to the target page
        pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePage
        pdfView.autoScales = false
        pdfView.isUserInteractionEnabled = false
        pdfView.backgroundColor = .white
        pdfView.displaysPageBreaks = false
        pdfView.document = pdfDocument
        if let page = pdfDocument.page(at: pageIndex) {
            pdfView.go(to: page)
        }
        containerView.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // PDFView autoScales manages its own internal scale to fit the page

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

        // Tap overlay for text placement (enabled only in text mode)
        tapOverlayView = UIView()
        tapOverlayView.translatesAutoresizingMaskIntoConstraints = false
        tapOverlayView.backgroundColor = .clear
        tapOverlayView.isUserInteractionEnabled = true
        tapOverlayView.isHidden = true
        containerView.addSubview(tapOverlayView)
        NSLayoutConstraint.activate([
            tapOverlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
            tapOverlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tapOverlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tapOverlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTextTap(_:)))
        tapOverlayView.addGestureRecognizer(tap)
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
        let saveItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        let textItem = UIBarButtonItem(title: "Aa", style: .plain, target: self, action: #selector(toggleTextMode))
        navItem.rightBarButtonItems = [saveItem, textItem]
        navigationBar.setItems([navItem], animated: false)
    }

    private func centerContainer() {
        guard let scrollView = scrollView else { return }
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    private func fitAndCenter() {
        guard let scrollView = scrollView else { return }
        scrollView.layoutIfNeeded()
        let size = scrollView.bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        let widthScale = size.width / pageBounds.width
        let heightScale = size.height / pageBounds.height
        let minScale = min(widthScale, heightScale) * 0.98
        scrollView.minimumZoomScale = max(0.1, minScale * 0.5)
        scrollView.maximumZoomScale = max(5.0, minScale * 5.0)
        scrollView.setZoomScale(minScale, animated: false)
        centerContainer()
        // Ensure internal PDF scaling matches the container
        let docBounds = pdfView.documentView?.bounds ?? .zero
        if docBounds.width > 0 {
            pdfView.scaleFactor = pageBounds.width / docBounds.width
        }
    }

    private func setupToolPicker() {
        // Ensure a window is available before showing the tool picker
        let keyWindowExists = (view.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }) != nil
        if keyWindowExists {
            let picker = PKToolPicker()
            picker.addObserver(canvasView)
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
            picker.showsDrawingPolicyControls = true
            toolPicker = picker
        }
    }

    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContainer()
        // Keep pods anchored to selected label during zoom
        if let label = selectedLabel { repositionPods(around: label) }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Reposition pods while panning
        if let label = selectedLabel { repositionPods(around: label) }
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

        // Convert PencilKit strokes into PDF ink annotations with proper bounds and relative points
        addPencilKitInkAnnotations(to: page, pageBounds: bounds)

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

            // Strokes already added as PDF annotations; drawing the page renders them.

            // Draw text labels from overlay (UIKit coordinates)
            for sub in tapOverlayView.subviews {
                guard let label = sub as? UILabel, let text = label.text else { continue }
                let p = CGPoint(x: bounds.minX + label.frame.origin.x,
                                y: bounds.minY + label.frame.origin.y)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: label.font as Any,
                    .foregroundColor: label.textColor as Any
                ]
                (text as NSString).draw(at: p, withAttributes: attrs)
            }
        }

        guard let flattenedPageDoc = PDFDocument(data: data),
              let flattenedPage = flattenedPageDoc.page(at: 0) else { return nil }
        // Build a new document to avoid in-place index shifts or mutation edge cases
        let liveIndex = pdfDocument.index(for: page)
        let target = (liveIndex >= 0) ? liveIndex : pageIndex
        let newDoc = PDFDocument()
        for i in 0..<pdfDocument.pageCount {
            let src = (i == target) ? flattenedPage : (pdfDocument.page(at: i) ?? flattenedPage)
            newDoc.insert(src, at: newDoc.pageCount)
        }
        return newDoc.dataRepresentation()
    }

    // MARK: - Bottom toolbar and text mode
    private func setupBottomToolbar() {
        toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Hand (pan/zoom) toggle
        panButton = UIBarButtonItem(image: UIImage(systemName: "hand.raised"), style: .plain, target: self, action: #selector(togglePanZoom))

        // Text mode (only in top-right nav; no bottom Aa)
        textModeButton = UIBarButtonItem(title: "Aa", style: .plain, target: self, action: #selector(toggleTextMode))

        // Single color swatch with UIMenu
        colorButton = UIBarButtonItem(image: UIImage(systemName: "circle.fill"), style: .plain, target: nil, action: nil)
        updateColorButtonAppearance()
        updateColorMenu()

        // Tools menu (Nudge + Font size + Delete) - fallback; primary nudges provided by floating pods
        let nudgeLeftAction = UIAction(title: "Left", image: UIImage(systemName: "arrow.left")) { [weak self] _ in self?.nudge(dx: -1, dy: 0) }
        let nudgeRightAction = UIAction(title: "Right", image: UIImage(systemName: "arrow.right")) { [weak self] _ in self?.nudge(dx: 1, dy: 0) }
        let nudgeUpAction = UIAction(title: "Up", image: UIImage(systemName: "arrow.up")) { [weak self] _ in self?.nudge(dx: 0, dy: -1) }
        let nudgeDownAction = UIAction(title: "Down", image: UIImage(systemName: "arrow.down")) { [weak self] _ in self?.nudge(dx: 0, dy: 1) }
        let nudgeMenu = UIMenu(title: "Nudge", options: .displayInline, children: [nudgeLeftAction, nudgeRightAction, nudgeUpAction, nudgeDownAction])

        let smallerAction = UIAction(title: "Smaller", image: UIImage(systemName: "textformat.size.smaller")) { [weak self] _ in self?.fontSmaller() }
        let largerAction = UIAction(title: "Larger", image: UIImage(systemName: "textformat.size.larger")) { [weak self] _ in self?.fontLarger() }
        let sizeMenu = UIMenu(title: "Font", options: .displayInline, children: [smallerAction, largerAction])

        let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in self?.deleteSelected() }
        let toolsMenu = UIMenu(title: "Text Tools", children: [nudgeMenu, sizeMenu, deleteAction])
        toolsButton = UIBarButtonItem(title: "Tools", style: .plain, target: nil, action: nil)
        toolsButton.menu = toolsMenu

        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        cachedToolbarItems = [
            panButton, spacer,
            colorButton, spacer,
            toolsButton
        ]
        // Defer setting items until layout to avoid zero-width contentView constraint thrash
    }

    // Legacy color chip builder removed; single color swatch with UIMenu is used instead

    @objc private func toggleTextMode() {
        isTextMode.toggle()
        tapOverlayView.isHidden = !isTextMode
        textModeButton.tintColor = isTextMode ? .systemBlue : .label
        // While in text mode, disable drawing from finger to avoid stray dots
        canvasView.isUserInteractionEnabled = !isTextMode && !isPanZoomEnabled
        tapOverlayView.isUserInteractionEnabled = isTextMode && !isPanZoomEnabled
        updatePodsVisibility()
    }

    @objc private func togglePanZoom() {
        isPanZoomEnabled.toggle()
        panButton.tintColor = isPanZoomEnabled ? .systemBlue : .label
        scrollView.isScrollEnabled = isPanZoomEnabled
        scrollView.pinchGestureRecognizer?.isEnabled = isPanZoomEnabled
        // Disable input layers while panning/zooming
        canvasView.isUserInteractionEnabled = !isPanZoomEnabled && !isTextMode
        tapOverlayView.isUserInteractionEnabled = !isPanZoomEnabled && isTextMode
        updatePodsVisibility()
    }

    private func updateTextColorSelection(selectedTag: Int) {
        currentTextColorTag = selectedTag
        switch selectedTag {
        case 0: textColor = .black
        case 1: textColor = .systemBlue
        case 2: textColor = .systemRed
        case 3: textColor = UIColor(red: 0.47, green: 0.36, blue: 0.98, alpha: 1.0)
        default: textColor = .systemBlue
        }
        // Apply color to selected label and update swatch/menu
        selectedLabel?.textColor = textColor
        updateColorButtonAppearance()
        updateColorMenu()
    }

    private func updateColorButtonAppearance() {
        colorButton.tintColor = textColor
    }

    private func updateColorMenu() {
        func action(name: String, tag: Int, color: UIColor) -> UIAction {
            let state: UIMenuElement.State = (tag == currentTextColorTag) ? .on : .off
            return UIAction(title: name, image: UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal), state: state) { [weak self] _ in
                self?.updateTextColorSelection(selectedTag: tag)
            }
        }
        let menu = UIMenu(title: "Color", children: [
            action(name: "Blue", tag: 1, color: .systemBlue),
            action(name: "Black", tag: 0, color: .black),
            action(name: "Red", tag: 2, color: .systemRed),
            action(name: "Purple", tag: 3, color: UIColor(red: 0.47, green: 0.36, blue: 0.98, alpha: 1.0))
        ])
        colorButton.menu = menu
    }

    @objc private func handleTextTap(_ gr: UITapGestureRecognizer) {
        guard isTextMode else { return }
        let point = gr.location(in: tapOverlayView)
        presentTextEntry(at: point)
    }

    private func presentTextEntry(at point: CGPoint) {
        let alert = UIAlertController(title: "Add Text", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Note"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let self = self, let text = alert.textFields?.first?.text, !text.isEmpty else { return }
            self.addTextAnnotation(text: text, atViewPoint: point)
        }))
        present(alert, animated: true)
    }

    private func addTextAnnotation(text: String, atViewPoint p: CGPoint) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 16)
        label.textColor = textColor
        label.backgroundColor = .clear
        label.sizeToFit()
        let origin = CGPoint(x: max(0, min(p.x, pageBounds.width - label.bounds.width)),
                             y: max(0, min(p.y, pageBounds.height - label.bounds.height)))
        label.frame.origin = origin
        label.isUserInteractionEnabled = true
        tapOverlayView.addSubview(label)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleLabelPan(_:)))
        label.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleLabelTap(_:)))
        label.addGestureRecognizer(tap)
        selectLabel(label)
    }

    @objc private func handleLabelTap(_ gr: UITapGestureRecognizer) {
        guard let label = gr.view as? UILabel else { return }
        selectLabel(label)
    }

    @objc private func handleLabelPan(_ gr: UIPanGestureRecognizer) {
        guard let label = gr.view as? UILabel else { return }
        if gr.state == .began { selectLabel(label) }
        let translation = gr.translation(in: tapOverlayView)
        var f = label.frame
        f.origin.x = max(0, min(f.origin.x + translation.x, pageBounds.width - f.width))
        f.origin.y = max(0, min(f.origin.y + translation.y, pageBounds.height - f.height))
        label.frame = f
        gr.setTranslation(.zero, in: tapOverlayView)
        repositionPods(around: label)
    }

    private func selectLabel(_ label: UILabel?) {
        if let prev = selectedLabel { prev.layer.borderWidth = 0 }
        selectedLabel = label
        if let label = label {
            label.layer.borderWidth = 1
            label.layer.borderColor = UIColor.systemBlue.cgColor
            showPods(around: label)
        }
        if label == nil { hidePods() }
    }

    // Nudge + font controls
    @objc private func nudgeLeftTapped() { nudge(dx: -1, dy: 0) }
    @objc private func nudgeRightTapped() { nudge(dx: 1, dy: 0) }
    @objc private func nudgeUpTapped() { nudge(dx: 0, dy: -1) }
    @objc private func nudgeDownTapped() { nudge(dx: 0, dy: 1) }
    private func nudge(dx: CGFloat, dy: CGFloat) {
        guard let label = selectedLabel else { return }
        var f = label.frame
        f.origin.x = max(0, min(f.origin.x + dx, pageBounds.width - f.width))
        f.origin.y = max(0, min(f.origin.y + dy, pageBounds.height - f.height))
        label.frame = f
        repositionPods(around: label)
    }
    @objc private func fontSmaller() { adjustFont(delta: -1) }
    @objc private func fontLarger() { adjustFont(delta: 1) }
    private func adjustFont(delta: CGFloat) {
        guard let label = selectedLabel else { return }
        let newSize = max(8, min(48, label.font.pointSize + delta))
        label.font = .systemFont(ofSize: newSize)
        label.sizeToFit()
        var f = label.frame
        f.origin.x = min(f.origin.x, pageBounds.width - f.width)
        f.origin.y = min(f.origin.y, pageBounds.height - f.height)
        label.frame = f
        repositionPods(around: label)
    }
    @objc private func deleteSelected() {
        selectedLabel?.removeFromSuperview()
        selectedLabel = nil
        hidePods()
    }

    // MARK: - Floating pods
    private func showPods(around label: UILabel) {
        if verticalPod == nil { verticalPod = makeVerticalPod() }
        if horizontalPod == nil { horizontalPod = makeHorizontalPod() }
        if let v = verticalPod, v.superview == nil { controlsOverlay.addSubview(v) }
        if let h = horizontalPod, h.superview == nil { controlsOverlay.addSubview(h) }
        repositionPods(around: label)
        updatePodsVisibility()
    }

    private func hidePods() {
        verticalPod?.removeFromSuperview()
        horizontalPod?.removeFromSuperview()
    }

    private func updatePodsVisibility() {
        let visible = isTextMode && !isPanZoomEnabled && selectedLabel != nil
        verticalPod?.isHidden = !visible
        horizontalPod?.isHidden = !visible
    }

    private func repositionPods(around label: UILabel) {
        guard let v = verticalPod, let h = horizontalPod else { return }
        // Convert label frame into overlay coordinates
        let rectInOverlay = tapOverlayView.convert(label.frame, to: controlsOverlay)
        let overlayBounds = controlsOverlay.bounds
        let pad: CGFloat = podPadding

        // Sizes
        let vDefaultHeight = podPadding + podButtonHeight*4 + podSpacing*3 + podPadding
        let vDefaultWidth: CGFloat = 48
        let hDefaultWidth = podPadding + podButtonHeight*2 + podSpacing*1 + podPadding
        let hDefaultHeight = podPadding + podButtonHeight + podPadding
        let vSize = v.bounds.size == .zero ? CGSize(width: vDefaultWidth, height: vDefaultHeight) : v.bounds.size
        let hSize = h.bounds.size == .zero ? CGSize(width: hDefaultWidth, height: hDefaultHeight) : h.bounds.size

        // Vertical pod: default right
        var vX = rectInOverlay.maxX + pad
        var vY = rectInOverlay.minY
        if vX + vSize.width > overlayBounds.maxX - pad {
            vX = rectInOverlay.minX - pad - vSize.width // flip to left
        }
        vY = min(max(pad, vY), overlayBounds.maxY - pad - vSize.height)
        v.frame = CGRect(origin: CGPoint(x: vX, y: vY), size: vSize)

        // Horizontal pod: default below
        var hX = rectInOverlay.midX - hSize.width/2
        var hY = rectInOverlay.maxY + pad
        if hY + hSize.height > overlayBounds.maxY - pad {
            hY = rectInOverlay.minY - pad - hSize.height // flip above
        }
        hX = min(max(pad, hX), overlayBounds.maxX - pad - hSize.width)
        h.frame = CGRect(origin: CGPoint(x: hX, y: hY), size: hSize)
    }

    private func makeVerticalPod() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = podSpacing
        let container = podContainer()
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: podPadding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -podPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: podPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -podPadding)
        ])

        let up = podButton(systemName: "arrow.up", tag: 0) { [weak self] in self?.nudge(dx: 0, dy: -1) }
        let larger = podButton(systemName: "textformat.size.larger", tag: 100) { [weak self] in self?.fontLarger() }
        let smaller = podButton(systemName: "textformat.size.smaller", tag: 101) { [weak self] in self?.fontSmaller() }
        let down = podButton(systemName: "arrow.down", tag: 2) { [weak self] in self?.nudge(dx: 0, dy: 1) }
        [up, larger, smaller, down].forEach { stack.addArrangedSubview($0) }
        enableRepeatIfArrow(up)
        enableRepeatIfArrow(down)
        return container
    }

    private func makeHorizontalPod() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = podSpacing
        let container = podContainer()
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: podPadding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -podPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: podPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -podPadding)
        ])

        let left = podButton(systemName: "arrow.left", tag: 3) { [weak self] in self?.nudge(dx: -1, dy: 0) }
        let right = podButton(systemName: "arrow.right", tag: 1) { [weak self] in self?.nudge(dx: 1, dy: 0) }
        [left, right].forEach { stack.addArrangedSubview($0) }
        enableRepeatIfArrow(left)
        enableRepeatIfArrow(right)
        return container
    }

    private func podContainer() -> UIView {
        // High contrast purple panel, rounded with shadow for monochrome docs
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.35, green: 0.32, blue: 0.70, alpha: 0.80)
        v.layer.cornerRadius = podCornerRadius
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.18
        v.layer.shadowRadius = 4
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        return v
    }

    // Pass-through overlay that only intercepts touches on its visible subviews (pods)
    private class PassThroughView: UIView {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            // Interact only if the touch lies within a visible, interactive subview
            for sub in subviews where !sub.isHidden && sub.alpha > 0.01 && sub.isUserInteractionEnabled {
                if sub.frame.contains(point) { return true }
            }
            return false
        }
    }

    private func podButton(systemName: String, tag: Int, tap: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        let img = UIImage(systemName: systemName)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        b.layer.cornerRadius = 6
        b.heightAnchor.constraint(equalToConstant: podButtonHeight).isActive = true
        b.tag = tag
        b.addAction(UIAction { _ in tap() }, for: .primaryActionTriggered)
        return b
    }

    // Repeat handling for arrow buttons
    private var repeatTimer: Timer?
    private var repeatTag: Int = -1
    private func enableRepeatIfArrow(_ button: UIButton) {
        guard (0...3).contains(button.tag) else { return }
        button.addTarget(self, action: #selector(repeatTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(repeatTouchEnd(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func repeatTouchDown(_ sender: UIButton) {
        repeatTag = sender.tag
        repeatTimer?.invalidate()
        // Start after a short delay, then repeat quickly
        repeatTimer = Timer.scheduledTimer(timeInterval: 0.06, target: self, selector: #selector(repeatTick), userInfo: nil, repeats: true)
        RunLoop.current.add(repeatTimer!, forMode: .common)
    }

    @objc private func repeatTouchEnd(_ sender: UIButton) {
        repeatTimer?.invalidate(); repeatTimer = nil; repeatTag = -1
    }

    @objc private func repeatTick() {
        switch repeatTag {
        case 0: nudge(dx: 0, dy: -1)
        case 1: nudge(dx: 1, dy: 0)
        case 2: nudge(dx: 0, dy: 1)
        case 3: nudge(dx: -1, dy: 0)
        default: break
        }
    }

    // MARK: - Convert PencilKit strokes into PDF annotations
    private func addPencilKitInkAnnotations(to page: PDFPage, pageBounds: CGRect) {
        let strokes = canvasView.drawing.strokes
        guard !strokes.isEmpty else { return }

        for stroke in strokes {
            // 1) Gather points in drawing (UIKit) coordinates
            var pts: [CGPoint] = []
            pts.reserveCapacity(stroke.path.count)
            for sp in stroke.path { pts.append(sp.location) }
            if pts.count < 2 { continue }

            // 2) Compute bounds in drawing coordinates
            var minX = CGFloat.greatestFiniteMagnitude
            var minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude
            for p in pts {
                minX = min(minX, p.x)
                minY = min(minY, p.y)
                maxX = max(maxX, p.x)
                maxY = max(maxY, p.y)
            }
            let width: CGFloat = (stroke.ink.inkType == .marker) ? 10.0 : 2.5
            let pad = width / 2 + 1
            minX -= pad; minY -= pad; maxX += pad; maxY += pad

            // 3) Convert bounds to PDF coordinates (flip Y)
            let pdfOrigin = CGPoint(x: minX, y: pageBounds.height - maxY)
            let pdfSize = CGSize(width: maxX - minX, height: maxY - minY)
            let annotationBounds = CGRect(origin: pdfOrigin, size: pdfSize)

            // 4) Build path relative to annotation origin (in PDF coords)
            let path = UIBezierPath()
            func relPoint(_ p: CGPoint) -> CGPoint {
                let pdfY = pageBounds.height - p.y
                return CGPoint(x: p.x - annotationBounds.minX, y: pdfY - annotationBounds.minY)
            }
            path.move(to: relPoint(pts[0]))
            for i in 1..<pts.count { path.addLine(to: relPoint(pts[i])) }

            let annotation = PDFAnnotation(bounds: annotationBounds, forType: .ink, withProperties: nil)
            annotation.color = stroke.ink.color.withAlphaComponent(stroke.ink.inkType == .marker ? 0.35 : 1.0)
            let border = PDFBorder()
            border.lineWidth = width
            annotation.border = border
            annotation.add(path)
            page.addAnnotation(annotation)
        }
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

#if os(iOS)
// MARK: - TextAnnotation model (UIKit color)
struct TextAnnotation {
    var text: String
    var normalizedPoint: CGPoint // 0..1 in UIKit page coords
    var color: UIColor
}
#endif

#endif
