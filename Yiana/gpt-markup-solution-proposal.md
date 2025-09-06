# Markup Proposal: PDFKit + PencilKit, Flatten-on-Save (iOS/iPadOS)

## Executive Summary

Yiana needs simple, reliable page markup: freehand ink and basic typed text, no heavy editing semantics, and no persistent, re-editable layers. This proposal replaces the QLPreviewController approach with a custom single-page markup session built from two proven building blocks: PDFKit (`PDFView`) for display and PencilKit (`PKCanvasView`) for drawing. On Save, we permanently flatten strokes and text into the chosen page and overwrite the original document. This aligns with the project’s “paper” paradigm and LEGO philosophy.

- Flatten by default: Yes (paper-like, no layered editing)
- Text styling: Minimal (single font/size; small color set)
- Save semantics: Overwrite original document (no copy)
- Scope: Implement on iOS/iPadOS first; macOS later

## Goals and Non‑Goals

Goals
- Draw freehand ink (Apple Pencil or finger).
- Add simple text anywhere on the page.
- Session-only undo (limited depth), no infinite history.
- Save flattens edits into the PDF page and replaces that page.
- Reliable on iOS 17+ (avoid QLPreviewController bugs).

Non‑Goals
- No rich shapes, selection tools, or re-editable annotations.
- No multi-page simultaneous markup session.
- No sidecar edit format or advanced annotation catalogs.

## Architecture Overview

Components
- `PDFView` (PDFKit): Renders the current PDF page (single-page mode).
- `PKCanvasView` (PencilKit): Transparent overlay for ink input using PencilKit tools.
- `TextOverlay` (lightweight): Tap-to-place text entries tracked in page coordinates.
- Toolbar (compact): Pen, Highlighter, Text, Eraser, Undo, Save, Cancel.

Flow
1. From `DocumentEditView`, user taps Markup on the current page.
2. We present a `MarkupViewController` in full-screen, rendering only that page.
3. User draws and/or places text. Undo is local to this session.
4. On Save, we flatten strokes and text into the page and merge it back into the full `PDFDocument`, then return updated `Data` to the caller.
5. `DocumentEditView` overwrites `viewModel.pdfData` and saves the `NoteDocument`.

Why this is LEGO-compliant
- Uses Apple frameworks with stable APIs (PDFKit + PencilKit).
- Small, focused controller; avoids third-party dependencies.
- Single-page scope constrains complexity and memory.

## UI and Coordinate Model

- Display Mode: `PDFView.displayMode = .singlePage`, `autoScales = true`.
- Lock zoom/pan during markup to keep a stable transform between view space and page space.
- Convert all touch points to page coordinates: `pdfView.convert(point, to: page)` and store normalized (0–1) positions relative to `page.bounds(for: .mediaBox)`.
- On flatten, reconstruct page points from normalized coords.

## Key Types (Skeletons)

```swift
// Yiana/Markup/TextAnnotation.swift (or inline inside controller)
struct TextAnnotation {
    var text: String
    var normalizedPoint: CGPoint // (x: 0..1, y: 0..1) in mediaBox space
    var color: UIColor // .black, .blue, .red, .yellow (for highlighter text?)
}

// Yiana/Markup/MarkupViewController.swift
final class MarkupViewController: UIViewController {
    // Inputs
    private let originalPDFData: Data
    private let pageIndex: Int // 0-based
    private let onComplete: (Result<Data, Error>) -> Void

    // Views
    private let pdfView = PDFView()
    private let canvasView = PKCanvasView()
    private var toolPicker: PKToolPicker?

    // State
    private var document: PDFDocument!
    private var page: PDFPage!
    private var pageBounds: CGRect = .zero
    private var textAnnotations: [TextAnnotation] = []
    private var actionStack: [() -> Void] = [] // simple session-only undo

    // Toolbar buttons: Pen, Highlighter, Text, Eraser, Undo, Save, Cancel

    init(pdfData: Data, pageIndex: Int, onComplete: @escaping (Result<Data, Error>) -> Void) throws {
        self.originalPDFData = pdfData
        self.pageIndex = pageIndex
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
        try loadDocument()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func loadDocument() throws {
        guard let doc = PDFDocument(data: originalPDFData),
              let pg = doc.page(at: pageIndex) else { throw MarkupError.invalidPDF }
        document = doc
        page = pg
        pageBounds = pg.bounds(for: .mediaBox)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPDFView()
        setupCanvasView()
        setupToolbar()
    }

    private func setupPDFView() { /* configure single page, autoscale, no scrolling */ }
    private func setupCanvasView() { /* overlay PKCanvasView matching page rect */ }
    private func setupToolbar() { /* add minimal tool UI + actions */ }

    @objc private func saveTapped() {
        do { let updated = try flattenAndMerge(); onComplete(.success(updated)) }
        catch { onComplete(.failure(error)) }
    }

    @objc private func cancelTapped() { onComplete(.failure(MarkupError.userCancelled)) }

    private func addText(at viewPoint: CGPoint) {
        // Convert to normalized page space; prompt for text; push undo closure
    }

    private func flattenAndMerge() throws -> Data {
        // 1) Create new one-page PDF with original page content
        // 2) Draw PKCanvasView strokes as vector strokes
        // 3) Draw text annotations
        // 4) Replace page in original document; return dataRepresentation()
        return Data()
    }
}

enum MarkupError: Error { case invalidPDF, userCancelled }

// Yiana/Markup/MarkupView.swift (SwiftUI bridge)
struct MarkupView: UIViewControllerRepresentable {
    let pdfData: Data
    let pageIndex: Int
    let onComplete: (Result<Data, Error>) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        // Force-try caller contract for valid pageIndex; bubble errors early if needed
        let vc = try? MarkupViewController(pdfData: pdfData, pageIndex: pageIndex, onComplete: onComplete)
        return vc ?? UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
```

## Flattening Pseudocode (Vector Ink + Text)

```swift
func flattenAndMerge() throws -> Data {
    guard let original = PDFDocument(data: originalPDFData),
          let originalPage = original.page(at: pageIndex) else { throw MarkupError.invalidPDF }

    let mediaBox = originalPage.bounds(for: .mediaBox)

    // 1) Render a new single-page PDF with original content
    let format = UIGraphicsPDFRendererFormat()
    let renderer = UIGraphicsPDFRenderer(bounds: mediaBox, format: format)
    let singlePageData = renderer.pdfData { ctx in
        ctx.beginPage()
        // Draw original PDF page
        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        originalPage.draw(with: .mediaBox, to: cgContext)

        // 2) Draw PencilKit strokes as vector
        for stroke in canvasView.drawing.strokes {
            let (path, strokeColor, width, alpha, blendMode) = makeCGPath(from: stroke, in: mediaBox)
            cgContext.saveGState()
            cgContext.setBlendMode(blendMode)
            cgContext.addPath(path)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            cgContext.setLineWidth(width)
            let (r,g,b,a) = strokeColor // premultiplied with alpha
            cgContext.setStrokeColor(red: r, green: g, blue: b, alpha: a * alpha)
            cgContext.strokePath()
            cgContext.restoreGState()
        }

        // 3) Draw text annotations
        for ta in textAnnotations {
            let p = CGPoint(x: mediaBox.minX + ta.normalizedPoint.x * mediaBox.width,
                            y: mediaBox.minY + ta.normalizedPoint.y * mediaBox.height)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: ta.color
            ]
            (ta.text as NSString).draw(at: p, withAttributes: attrs)
        }
    }

    // 4) Replace page in full document
    guard let mergedSingle = PDFDocument(data: singlePageData),
          mergedSingle.pageCount == 1, let newPage = mergedSingle.page(at: 0) else {
        throw MarkupError.invalidPDF
    }
    original.removePage(at: pageIndex)
    original.insert(newPage, at: pageIndex)
    guard let finalData = original.dataRepresentation() else { throw MarkupError.invalidPDF }
    return finalData
}

func makeCGPath(from stroke: PKStroke, in mediaBox: CGRect) -> (CGPath, (CGFloat,CGFloat,CGFloat,CGFloat), CGFloat, CGFloat, CGBlendMode) {
    // Map PKStrokePath to CGPath using interpolated points in page space.
    // Determine color/alpha and width from PKInkType (pen vs highlighter).
    // Highlighter uses multiply blending with lower alpha.
    return (CGMutablePath(), (0,0,0,1), 2.0, 1.0, .normal)
}
```

Notes
- We keep it vector by building a `CGPath` from `PKStrokePath` samples.
- Highlighter: use `.multiply` blend and alpha ~0.25–0.35.
- Line widths expressed in page points (consistent look independent of output DPI).

## Integration Points

`DocumentEditView.presentMarkup()`
- Replace the QL-based coordinator presentation with `MarkupView`.
- Inputs: `pdfData`, `currentViewedPage` (0-based), completion callback.
- On success: set `viewModel.pdfData = updatedData`; call `await viewModel.save()`.

Pseudo-diff
```swift
// Old
// markupCoordinator = try MarkupCoordinator(pdfData: pdfData, currentPageIndex: currentViewedPage) { ... }
// activeSheet = .markup

// New (conceptual)
let pageIndex = currentViewedPage
let wrapper = MarkupView(pdfData: pdfData, pageIndex: pageIndex) { result in
    switch result {
    case .success(let updated):
        Task { @MainActor in
            viewModel.pdfData = updated
            _ = await viewModel.save()
        }
    case .failure:
        break // user cancelled or error; show alert if needed
    }
}
// Present full screen sheet with wrapper
```

Migration Strategy
- Keep `MarkupCoordinator.swift` (QL) temporarily behind a feature flag for quick rollback.
- After manual validation, remove QL files and references.

## Acceptance Criteria

- User can draw lines and highlight text on a page; drawings appear on top during session.
- User can tap to place text; committed text flattens on Save.
- Save overwrites the original PDF page in place; document page count unchanged.
- Highlighter visually blends over underlying text; no black boxes or artifacts.
- Large documents (e.g., 100+ pages) maintain steady memory in markup (single page rendered).
- Coordinates remain correct at page edges and on rotated pages.

Manual Test Checklist
- Draw near all four edges; Save; verify placement in exported PDF.
- Highlight over dense text; verify readable blending.
- Add 3–5 text notes; Save; re-open; confirm positions.
- Try on a rotated/scaled page; verify alignment.
- Test on iPhone and iPad, with and without Apple Pencil.

## Risks and Mitigations

- Coordinate drift: Lock zoom/pan; store normalized points; convert with `pdfView.convert(…, to: page)`.
- Highlighter visuals: Use multiply blend with tuned alpha; avoid raster compositing.
- Stroke performance: Downsample extremely dense `PKStrokePath` with a reasonable step; cap undo stack size.
- File size growth: Vector strokes and text are small; avoid raster images; single-page rewrite.
- UX complexity: Keep toolbar minimal; default to pen; text is tap-to-place without rich editing.

## Implementation Plan (4 Days)

Day 1–2: Core controller and vector flattening
- `MarkupViewController` with `PDFView` and `PKCanvasView` overlay
- Single-page loading and stable coordinate mapping
- Save path to produce a one-page flattened PDF and page replacement

Day 3: Text tool and session undo
- Tap-to-place text; commit to `textAnnotations`
- Simple action stack for undo (remove last stroke/text)

Day 4: Integration and polish
- Wire into `DocumentEditView` flow
- Size/color presets (black/blue/red pen, yellow highlighter)
- Alerts for error/cancel; maintain 50MB guard

## File Map

- New
  - `Yiana/Markup/MarkupViewController.swift`
  - `Yiana/Markup/MarkupView.swift`
  - (Optional) `Yiana/Markup/TextAnnotation.swift`

- Updated
  - `Yiana/Yiana/Views/DocumentEditView.swift` (replace QL entry + sheet content)

- Later (cleanup)
  - Remove `Yiana/Yiana/Services/MarkupCoordinator.swift` and related QL paths

## Appendix: Stroke → CGPath Notes

Converting `PKStroke` to a `CGPath`:
- Iterate `stroke.path.interpolatedPoints(by:)` (e.g., `.uniformStep(2–3 pts)`) to sample a smooth polyline.
- Transform each view point to page space; or better: store normalized page points during capture.
- Build a `CGMutablePath` by `move` + `addLine` across points.
- Width: map `stroke.ink.inkType` to a page-space width (e.g., pen 2.0–2.5 pt; highlighter 8–12 pt).
- Color: from `stroke.ink.color`; for highlighter use `.multiply` with alpha ~0.3.

This maintains vector output and stable visual quality across zoom/export.

