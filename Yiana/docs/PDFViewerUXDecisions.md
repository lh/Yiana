# PDF Viewer UX Architecture Decisions

**Date**: 2025-10-26
**Context**: Resolving UIPageViewController conflicts and defining natural iOS PDF viewing experience

## Decision: Files.app-style Vertical Scrolling

Based on user preferences and iOS HIG patterns, we will implement **vertical continuous scrolling** similar to Files.app, NOT horizontal page-turning like iBooks.

### Core Behaviors

#### 1. Navigation: Vertical Continuous Scroll
- **All pages arranged vertically** in a continuous scroll view
- Swipe up/down to navigate between pages naturally
- No discrete page transitions - smooth continuous scrolling
- Works identically in both fit-to-height and fit-to-width modes

#### 2. Zoom Behavior

**Double-tap zoom cycle**:
```
fit-to-height → fit-to-width → fit-to-height → fit-to-width ...
```

**Fit-to-height (default)**:
- Page fits vertically on screen
- Horizontal space may have margins
- Scroll vertically through all pages continuously

**Fit-to-width**:
- Page width fills screen width
- Content **top-aligned** (user sees top of page immediately)
- Scroll vertically through all pages continuously
- Each page is taller than screen, so vertical scrolling shows full page

**Pinch-to-zoom**:
- User can pinch-zoom to any custom level
- Next double-tap returns to fit-to-height

#### 3. Zoom Persistence
- **Zoom level persists** while scrolling through pages
- If user is at fit-to-width and scrolls to next page, next page is also fit-to-width
- Natural continuous reading experience

#### 4. Gesture Mapping

**Vertical swipes** (main interaction):
- Primary navigation through pages
- Continuous scrolling through document

**Horizontal swipes** (edge swipes for UI):
- Swipe from **left edge**: Show page organizer/thumbnails
- Swipe from **right edge**: Show metadata panel
- These are **edge swipes** starting from screen boundary, won't conflict with vertical scroll

**Double-tap**:
- Toggle between fit-to-height and fit-to-width

**Pinch**:
- Custom zoom level

## Technical Implications

### ✅ What This Solves

1. **Eliminates UIPageViewController entirely** - We don't need it for vertical scrolling
2. **No centering conflicts** - Standard UIScrollView respects contentOffset
3. **Top-alignment works naturally** - Set contentOffset.y when changing zoom
4. **Simpler architecture** - Single scroll view, no page view controller complexity
5. **Matches iOS patterns** - Consistent with Files.app and Safari PDF viewer

### 🔧 Implementation Approach

**Use PDFView with PDFDisplayMode.singlePageContinuous**:
```swift
pdfView.displayMode = .singlePageContinuous
pdfView.autoScales = false // We manage scaling manually
```

**Key components**:
- `PDFView` in `.singlePageContinuous` mode handles vertical page layout automatically
- We manage zoom levels (fit-to-height, fit-to-width, custom)
- Double-tap gesture toggles between fit modes
- Edge pan gestures reveal UI panels

**Top-alignment for fit-to-width**:
```swift
func applyFitToWidth() {
    // Calculate and apply scale
    pdfView.scaleFactor = viewWidth / pageWidth

    // Top-align: PDFView's scroll view will respect this
    if let scrollView = findScrollView(in: pdfView) {
        scrollView.contentOffset.y = 0
    }
}
```

### 📋 Migration Tasks

1. **Remove UIPageViewController** completely
2. **Set PDFView.displayMode = .singlePageContinuous**
3. **Implement double-tap gesture** for zoom toggle
4. **Implement edge pan gestures** for UI panels
5. **Simplify zoom logic** - no more fighting page view controller
6. **Update tests** to reflect vertical scrolling behavior

## Alternative Considered: Hybrid Approach

**Horizontal paging for fit-to-height, vertical scrolling for fit-to-width**

User indicated this would also be acceptable (Q6b), but it's more complex:
- Two different navigation paradigms in one view
- More code to maintain
- Less consistent with iOS patterns

**Decision**: Start with pure vertical scrolling (simpler, more iOS-native). Can revisit hybrid if user testing shows strong preference for horizontal paging.

## References

- iOS Files.app PDF viewing behavior
- iOS HIG - Document viewing patterns
- PDFKit documentation - PDFDisplayMode options
