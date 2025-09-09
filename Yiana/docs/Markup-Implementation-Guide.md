# Markup Implementation Guide (PDFKit + PencilKit)

This document explains the final, working design for Yiana’s markup on iOS, why it was hard to get right, and the trade‑offs and techniques we used to make it reliable and predictable.

## Executive Summary

- We provide simple ink and text markup with a “paper” paradigm: flattened on save, no layered history.
- We use PDFKit for display and PencilKit for drawing, with a lightweight text tool and floating, high‑contrast nudge pods for precise placement.
- Saving rebuilds a new PDF with the edited page replaced in place — no hidden index drift or duplication.

## Why This Was Hard

1) QuickLook is unreliable for markup in iOS 17+
- QLPreviewController has a known bug where markup buttons become untappable; no programmatic save.
- We replaced QL with our own PDFKit/PencilKit UI to control saving and avoid private UI paths.

2) PDFKit page semantics
- A `PDFPage` is a reference into a document. Taking a page and inserting it into another `PDFDocument` can move it (not copy by default).
- Early versions displayed a single‑page doc by inserting the page into a fresh `PDFDocument` for viewing. That moved the page out of the original document, causing index shifts and, later, duplicate pages on save.

3) Coordinate space pitfalls
- UIKit view coordinates (top‑left origin) vs PDF coordinates (bottom‑left origin) require proper flips.
- Annotations in PDFKit use a bounds + relative path model: paths must be relative to annotation bounds, not absolute page coords.

4) UI constraints and gesture conflicts
- Stuffing too many buttons into a `UIToolbar` can churn Auto Layout in compact width, stalling presentation.
- A non‑zoom overlay for on‑screen controls must pass through touches to the canvas/PDFView, or drawing stops working.

5) PencilKit tool picker timing
- Initializing PKToolPicker before the view is in a window can stall the presentation in Debug.

## Final Architecture

- Display: A `PDFView` shows the full original `PDFDocument`. We navigate to the target page and stay there.
- Drawing: `PKCanvasView` overlays the page container for ink (pen/highlighter/eraser). We use PencilKit’s tool picker.
- Text: Tap to add a `UILabel` overlay. Drag to position; floating pods provide fine nudging and size changes.
- Controls:
  - Top‑right “Aa” toggles text mode.
  - Bottom toolbar is lean: Hand (pan/zoom), Color swatch (UIMenu: Blue/Black/Red/Purple), Tools menu (fallback actions).
  - Floating pods: high‑contrast purple panels with white icons (↑/↓/←/→ and A−/A+) near the selected text.
  - Pods auto‑flip (right↔left, below↔above) and live in a non‑zooming overlay that passes through touches.
- Zoom: A `UIScrollView` wraps the page container. Hand toggle enables/disables pan/zoom to avoid conflicts with drawing/text.

## Coordinate Math (ink)

- Convert line points from drawing view to PDF coordinates: `pdfY = pageHeight − drawingY`.
- Compute the path bounds in PDF coordinates (min/max X,Y) and add small padding.
- Create a `PDFAnnotation` with `bounds = computedBounds` and add a `UIBezierPath` with points relative to `bounds.origin`.
- This ensures proper placement and no vertical shift between display and flattened output.

## Saving Strategy

- Do not edit pages in place in the original document; do not move pages for display.
- Replace by reassembly:
  1. Flatten the edited page (draw the original page into a `UIGraphicsPDFRenderer`, then draw strokes/text).
  2. Build a fresh `PDFDocument` and copy every page from the original, replacing only the target page with the flattened page.
  3. Return `newDoc.dataRepresentation()` for saving.

Why:
- Avoids in‑place mutations that can shift indices or invalidate page references.
- Guarantees page order and count remain identical, with one page replaced.

## Touch Handling and UI

- The non‑zoom overlay is a pass‑through view: it only returns `true` for touches over visible pod subviews; all other touches fall through to canvas/text overlays.
- Pods auto‑reposition on label drag (`UIPanGestureRecognizer`), scroll, or zoom.
- Pod buttons repeat on hold (fast 60–100Hz) for smooth nudging; A−/A+ adjust fonts 8–48pt.

## Performance & Stability

- Defer `PKToolPicker` setup to `viewDidAppear` once the view has a window.
- Disable `pdfView.autoScales` and set `scaleFactor` after layout to fit the page predictably under the scroll view.
- Defer `toolbar.setItems` until the toolbar has a non‑zero width on first layout to avoid unsatisfiable constraints.
- Keep the debug console clean: logs like RTIInputSystem/EmojiSearch or CoreGraphics PDF messages are benign in Debug and not present in Release.

## Debugging Tips

- If you see constraint spam on first presentation, ensure `setItems` is deferred until after layout.
- If drawing stops working after adding overlays, confirm the overlay view is pass‑through (or disable userInteraction except for pod subviews).
- If marks shift vertically: verify the Y‑flip and that the annotation path uses relative points to annotation bounds.
- To chase a CG PDF warning, temporarily set `CG_PDF_VERBOSE=1` in the scheme and re‑run.

## Test Checklist

- Pages: first, middle, last — replace and verify page count/order unchanged.
- Large docs: 100+ pages — edit multiple pages in a single session, repeated saves.
- Rotations/scales: scanned PDFs with rotations/crops — drawn ink aligns after save.
- Zoom/pan: zoom in >3×, nudge text into alignment, save, reopen.
- Repeated edits: mark, save, re‑enter, mark again, save — no drift or duplications.

## Known Trade‑offs & Future Options

- Markup is flattened: this is by design (“paper” model). We could preserve editable annotations as a future mode, but not needed now.
- Highlighter blends: native PDF annotations don’t offer multiply blend; we simulate with alpha for annotations or draw via CG for true blending if required.
- Loupe: can be added to improve fine placement while dragging text.
- Mac: PencilKit path can be ported to macOS later; for now it’s iOS only.

## Quick Reference (Do/Don’t)

- Do: Show the full `PDFDocument` in `PDFView` and navigate to the page with `go(to:)`.
- Do: Use pass‑through overlays for non‑zoom, in‑place controls.
- Do: Compute ink annotation bounds from drawing points; flip Y; make path points relative to bounds.
- Do: Reassemble a new PDF when saving to replace the page in place.
- Don’t: Move a `PDFPage` into a single‑page document for viewing.
- Don’t: Remove/insert pages in place if earlier steps may have changed references/indices.

## Appendix: Pseudocode for Safe Replacement

```
// Flatten the edited page
let flattened = renderFlattenedPage(page)

// Determine target index (favor live index, fallback to saved pageIndex)
let target = max(0, min(pdf.index(for: page), pdf.pageCount - 1))

// Reassemble document
let newDoc = PDFDocument()
for i in 0..<pdf.pageCount {
  let src = (i == target) ? flattened : pdf.page(at: i)!
  newDoc.insert(src, at: newDoc.pageCount)
}
return newDoc.dataRepresentation()
```

---

This document summarizes the lessons learned and the stable design for Yiana’s markup. If a future regression appears (e.g., duplicates, shifted ink), revisit the “Saving Strategy” and “Coordinate Math” sections first — they are the most error‑prone parts of PDFKit integrations.

