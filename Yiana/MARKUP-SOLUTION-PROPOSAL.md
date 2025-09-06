# Custom Markup Solution Proposal for Yiana

## Executive Summary

After extensive testing, we've identified that Apple's QLPreviewController has a critical bug (FB14376916) in iOS 17+ where markup buttons become non-tappable after drawing. This proposal outlines a custom markup solution using PDFView with drawing and text overlays that will provide reliable, predictable markup functionality aligned with Yiana's "ink on paper" philosophy.

## Problem Statement

The current QLPreviewController-based implementation fails because:
- iOS 17 bug makes the "Done" button non-tappable after any markup
- No programmatic way to trigger save
- Multiple workaround attempts have failed
- Users cannot reliably save their annotations

## Proposed Solution: Custom Markup View

### Core Technology Stack
- **PDFView**: Display the PDF page
- **UIView overlay**: Capture drawing and text input
- **UIBezierPath**: Store drawing paths
- **UILabel/CATextLayer**: Render text annotations
- **Core Graphics**: Flatten annotations onto PDF

### Architecture

```
MarkupViewController
├── PDFView (displays single page)
├── DrawingOverlayView (transparent overlay)
│   ├── Drawing paths (UIBezierPath array)
│   └── Text annotations (position + string array)
├── Toolbar
│   ├── Color selector (black, red, blue)
│   ├── Mode toggle (draw/text)
│   ├── Undo button
│   └── Done button
└── Text input handler (UITextField)
```

### User Workflow

1. **Enter Markup Mode**
   - User taps markup button
   - Single PDF page loads in custom view
   - Toolbar appears at top

2. **Drawing Mode**
   - User draws with finger or Apple Pencil
   - Smooth path rendering with selected color
   - Real-time visual feedback

3. **Text Mode**
   - User taps anywhere on page
   - Text field appears at tap location
   - Keyboard shows for input
   - Text renders at position when done

4. **Save**
   - User taps "Done"
   - All annotations flatten onto PDF page
   - Returns merged PDF to document

### Implementation Details

#### 1. Drawing System
```swift
class DrawingOverlayView: UIView {
    var paths: [(path: UIBezierPath, color: UIColor)] = []
    var currentPath: UIBezierPath?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentPath = UIBezierPath()
        currentPath?.lineWidth = 2.0
        // Start drawing
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Add points to current path
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        // Render all paths
    }
}
```

#### 2. Text Annotation System
```swift
struct TextAnnotation {
    let text: String
    let position: CGPoint
    let color: UIColor
    let fontSize: CGFloat = 16
}

class TextInputHandler {
    func addTextAt(point: CGPoint) {
        // Show text field
        // Store annotation
        // Update display
    }
}
```

#### 3. PDF Flattening
```swift
func flattenAnnotations(onto pdfPage: PDFPage) -> Data? {
    UIGraphicsBeginPDFContext(...)
    
    // Draw original PDF page
    pdfPage.draw(with: .mediaBox, to: context)
    
    // Draw all paths
    for (path, color) in paths {
        color.setStroke()
        path.stroke()
    }
    
    // Draw all text
    for annotation in textAnnotations {
        annotation.render(in: context)
    }
    
    UIGraphicsEndPDFContext()
    return pdfData
}
```

### Features

#### Phase 1 - MVP (1 week)
- [x] Single page PDF display
- [x] Black ink drawing
- [x] Tap to add text
- [x] Done button (saves permanently)
- [x] Cancel button (discards changes)

#### Phase 2 - Enhanced (Optional)
- [ ] Color picker (red, blue, black)
- [ ] Undo last action
- [ ] Line thickness selector
- [ ] Eraser tool

### Advantages Over QLPreviewController

| Aspect | QLPreviewController | Custom Solution |
|--------|-------------------|-----------------|
| Reliability | Broken in iOS 17+ | Full control, no bugs |
| Save mechanism | Unreliable | Guaranteed to work |
| Features | All or nothing | Exactly what we need |
| Memory usage | Heavy | Lightweight |
| Complexity | Hidden complexity | Transparent, maintainable |
| User experience | Confusing save | Clear, predictable |

### Technical Considerations

#### Memory Management
- Only load single page (already implemented)
- Drawing paths are lightweight
- Text annotations minimal memory
- Flatten immediately on save

#### Performance
- Native UIView drawing is fast
- No complex PDF annotation objects
- Direct rendering to context

#### Compatibility
- Works on iOS 14+
- No dependency on broken APIs
- Future-proof solution

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| Drawing performance | Limit path points, optimize rendering |
| Text positioning | Snap to grid, provide visual guides |
| Color accuracy | Use standard PDF color space |
| File size increase | Minimal - paths and text are small |

### Implementation Timeline

**Day 1-2**: Core structure
- Create MarkupViewController
- Set up PDFView with single page
- Basic toolbar

**Day 3-4**: Drawing system
- Touch handling
- Path rendering
- Color selection

**Day 5-6**: Text system
- Tap to place text
- Keyboard handling
- Text rendering

**Day 7**: Integration
- Flatten to PDF
- Connect to document system
- Testing

**Total: 1 week for production-ready MVP**

### Migration Path

1. Keep existing MarkupCoordinator interface
2. Replace QLPreviewController with MarkupViewController
3. No changes needed to DocumentEditView
4. Existing single-page extraction still used

### Success Criteria

- ✅ User can draw on PDF page
- ✅ User can add text annotations
- ✅ Save always works (100% reliability)
- ✅ Annotations are permanently flattened
- ✅ No memory issues with large PDFs
- ✅ Works on iOS 14+

### Conclusion

This custom solution provides exactly what Yiana needs: simple, reliable markup that follows the "ink on paper" philosophy. By building our own implementation, we avoid iOS bugs, reduce complexity, and deliver a better user experience. The one-week timeline is realistic and the solution is maintainable long-term.

### Next Steps

1. Approve this proposal
2. Archive current QLPreviewController attempts
3. Begin implementation of custom MarkupViewController
4. Test with real users
5. Ship reliable markup feature

## Appendix: Code Examples

### Example: Complete Drawing Cycle
```swift
// User draws
func handlePan(_ gesture: UIPanGestureRecognizer) {
    let point = gesture.location(in: self)
    
    switch gesture.state {
    case .began:
        startNewPath(at: point)
    case .changed:
        addPoint(point)
    case .ended:
        finalizePath()
    default:
        break
    }
}

// Save to PDF
func saveMarkup() {
    guard let pdfPage = currentPage else { return }
    
    let renderer = UIGraphicsPDFRenderer(bounds: pdfPage.bounds(for: .mediaBox))
    let data = renderer.pdfData { context in
        context.beginPage()
        
        // Draw original PDF
        pdfPage.draw(with: .mediaBox, to: context.cgContext)
        
        // Draw annotations
        drawingView.renderAnnotations(to: context.cgContext)
    }
    
    // Return flattened PDF
    completion(.success(data))
}
```

### Example: Text Annotation
```swift
func addTextAnnotation(at point: CGPoint) {
    let textField = UITextField()
    textField.center = point
    
    textField.becomeFirstResponder()
    
    textField.onReturn = { text in
        let annotation = TextAnnotation(
            text: text,
            position: point,
            color: .black
        )
        self.textAnnotations.append(annotation)
        self.setNeedsDisplay()
    }
}
```