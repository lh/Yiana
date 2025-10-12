# iPad PDF Viewing Improvements Proposal

**Status:** Proposal
**Priority:** Medium
**Estimated Time:** 4-5 hours
**Date:** October 2025

---

## Problem Statement

The current iPad PDF viewer defaults to full-page view, which is suboptimal for reading text-heavy documents. While users can pinch to zoom to page width, this breaks the gesture navigation system:

1. **Gesture conflicts**: When zoomed to page width, horizontal swipes are needed for panning, conflicting with page navigation swipes
2. **Reading experience**: Most PDF documents are meant to be read at page width with vertical scrolling
3. **Swipe-up conflict**: The swipe-up gesture for page organizer conflicts with vertical scrolling needs

The iPhone experience works well, but the iPad's larger screen presents unique challenges and opportunities.

---

## Proposed Solution

### Core Changes

Implement a **Page Width Reading Mode** for iPad with the following characteristics:

1. **Default to page width** for text-heavy documents (user configurable)
2. **Vertical scrolling only** - no horizontal panning
3. **Horizontal swipes** always navigate between pages
4. **Alternative page organizer triggers** (replacing swipe-up in this mode)

### Gesture Map

#### In Page Width Mode (New Default)
| Gesture | Action |
|---------|--------|
| **Swipe Left/Right** | Navigate to next/previous page |
| **Swipe Up/Down** | Scroll vertically within current page |
| **Tap Page Indicator** | Open page organizer |
| **Pinch Out** | Zoom in for closer inspection |
| **Pinch In (past page bounds)** | Open page organizer |
| **Three-finger Tap** | Open page organizer (iPad system gesture style) |
| **Double Tap** | Toggle between page width and fit page |

#### In Fit Page Mode (Current Default)
| Gesture | Action |
|---------|--------|
| **Swipe Left/Right** | Navigate to next/previous page |
| **Swipe Up** | Open page organizer (no conflict as no scrolling needed) |
| **Pinch** | Zoom in/out |
| **Double Tap** | Toggle to page width mode |

---

## Implementation Details

### 1. Add View Mode Setting

```swift
enum PDFViewMode: String, CaseIterable {
    case fitPage = "Fit Page"
    case fitWidth = "Fit Width"

    var description: String {
        switch self {
        case .fitPage: return "Shows entire page (better for slides/images)"
        case .fitWidth: return "Fits to width (better for reading text)"
        }
    }
}
```

### 2. Modify PDFKitView

Add properties to control default zoom and gesture behavior:

```swift
class PDFKitView: UIViewRepresentable {
    @Binding var viewMode: PDFViewMode
    let isIPad = UIDevice.current.userInterfaceIdiom == .pad

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()

        // Set default zoom based on mode
        if isIPad {
            switch viewMode {
            case .fitPage:
                pdfView.autoScales = true
                pdfView.maxScaleFactor = 4.0
                pdfView.minScaleFactor = 0.5
            case .fitWidth:
                pdfView.autoScales = false
                // Set to page width on load
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                configureForPageWidth(pdfView)
            }
        }

        configureGestures(for: pdfView)
        return pdfView
    }

    private func configureForPageWidth(_ pdfView: PDFView) {
        // Calculate scale to fit width
        guard let page = pdfView.currentPage else { return }
        let pageRect = page.bounds(for: .mediaBox)
        let viewWidth = pdfView.bounds.width
        let scale = viewWidth / pageRect.width
        pdfView.scaleFactor = scale * 0.95 // Slight margin
    }
}
```

### 3. Gesture Configuration

```swift
private func configureGestures(for pdfView: PDFView) {
    // Remove default swipe up if in page width mode
    if viewMode == .fitWidth {
        // Disable swipe-up for page organizer
        removeSwipeUpGesture(from: pdfView)

        // Add three-finger tap for page organizer
        let tripleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(handleTripleFingerTap))
        tripleTap.numberOfTouchesRequired = 3
        pdfView.addGestureRecognizer(tripleTap)

        // Pinch past boundaries opens organizer
        configurePinchGesture(for: pdfView)
    }

    // Horizontal swipes always work for page nav
    configurePageNavigationSwipes(for: pdfView)
}
```

### 4. Settings Integration

Add to user preferences:

```swift
class PDFViewingSettings: ObservableObject {
    @AppStorage("defaultPDFViewMode") var defaultViewMode: PDFViewMode = .fitPage
    @AppStorage("autoDetectTextDocuments") var autoDetectText: Bool = true

    func suggestedMode(for document: PDFDocument) -> PDFViewMode {
        guard autoDetectText else { return defaultViewMode }

        // Simple heuristic: if first page has >500 characters, probably text-heavy
        if let firstPage = document.page(at: 0),
           let text = firstPage.string,
           text.count > 500 {
            return .fitWidth
        }

        return defaultViewMode
    }
}
```

### 5. Updated Page Indicator

The page indicator (already updated to blue corner badge) becomes more important as the primary trigger for page organizer in page width mode:

```swift
private var pageIndicator: some View {
    Text("\(currentPage + 1)/\(totalPages)")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.85))
        )
        .padding(.trailing, 16)
        .padding(.bottom, 20)
        .onTapGesture {
            showIndicator()
            onRequestPageManagement?() // Primary way to access organizer
        }
        .overlay(
            // Visual hint for tap target in page width mode
            viewMode == .fitWidth ?
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.7))
                    .offset(x: -3, y: 0)
                : nil
        )
}
```

---

## User Interface Changes

### Settings Screen Addition

Add a new section in Settings:

```
PDF Viewing (iPad)
├─ Default View Mode: [Fit Page | Fit Width]
├─ Auto-Detect Text Documents: [Toggle]
└─ Double-Tap Action: [Toggle Zoom | Toggle Mode]
```

### Visual Feedback

1. **Mode indicator**: Small icon in toolbar showing current mode
2. **Gesture hints**: First-time tutorial showing available gestures
3. **Page indicator enhancement**: Subtle grid icon when in page width mode

---

## Migration & Compatibility

1. **Default behavior**: Existing users stay on Fit Page mode (no breaking change)
2. **First-run detection**: New users get prompted to choose preferred mode
3. **Document memory**: Remember last used mode per document type
4. **iPhone unchanged**: These changes only affect iPad

---

## Testing Plan

### Functional Tests
- [ ] Page width mode correctly fits content
- [ ] Vertical scrolling works smoothly
- [ ] Horizontal swipes navigate pages at all zoom levels
- [ ] Page organizer accessible via all alternate methods
- [ ] Mode switching via double-tap
- [ ] Settings persistence

### Edge Cases
- [ ] Very wide PDFs (landscape orientation)
- [ ] Single page documents
- [ ] Documents with mixed orientations
- [ ] Zoom interactions during mode switches
- [ ] Memory management with large PDFs

### User Experience Tests
- [ ] Gesture discovery (are alternatives intuitive?)
- [ ] Reading flow improvement measurement
- [ ] Accidental page turns frequency
- [ ] Speed of accessing page organizer

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Users can't find page organizer** | High | Clear visual hints, first-run tutorial |
| **Gesture conflicts remain** | Medium | Extensive testing, edge zone detection |
| **Performance with large PDFs** | Medium | Lazy rendering, viewport optimization |
| **Breaking muscle memory** | Low | Keep fit page as option, clear mode indicator |

---

## Success Metrics

1. **Reduced pinch-to-zoom actions** in reading sessions
2. **Faster reading speed** (pages per minute)
3. **Fewer accidental page navigations**
4. **Increased usage of page organizer** (via tap)
5. **Positive user feedback** on reading experience

---

## Future Enhancements

After initial implementation:

1. **Continuous vertical scrolling** - Scroll through all pages vertically
2. **Smart zoom** - Remember zoom level per document
3. **Reading position memory** - Return to exact scroll position
4. **Column detection** - Auto-detect multi-column layouts
5. **Reflow mode** - Extract and reflow text for optimal reading

---

## Implementation Priority

### Phase 1 (Core - 3 hours)
1. Implement PDFViewMode enum and settings
2. Modify PDFKitView for page width default
3. Configure basic gesture handling

### Phase 2 (Gestures - 1 hour)
1. Implement three-finger tap
2. Add pinch-to-organizer
3. Update page indicator tap zone

### Phase 3 (Polish - 1 hour)
1. Add settings UI
2. Create mode indicators
3. Implement auto-detection
4. Add first-run experience

---

## Decision Required

Before proceeding with implementation, please confirm:

1. **Default mode preference**: Should new iPad users default to page width?
2. **Gesture priority**: Is losing swipe-up acceptable if we have good alternatives?
3. **Auto-detection**: Should we auto-detect document types or always respect user setting?
4. **iPhone changes**: Confirm iPhone should remain unchanged

This proposal provides a reading-optimized experience for iPad while maintaining the current functionality as an option.