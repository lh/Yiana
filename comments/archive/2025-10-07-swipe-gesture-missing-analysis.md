# Analysis: Missing Swipe-Up Gesture on Markdown Pages
**Date**: 2025-10-07
**Issue**: Swipe-up gesture works on scanned PDF pages but not on markdown-rendered pages
**Severity**: 🟡 UX Inconsistency

## Problem Statement

**Expected behavior**: Swipe-up on any page → opens page thumbnail view
**Actual behavior**:
- ✅ Scanned PDF pages: Swipe-up works
- ❌ Markdown-rendered pages: Swipe-up does NOT work

## Root Cause Analysis

### Architecture Overview

Your app has **two different page viewing contexts**:

#### 1. Document Read/Edit View (Scanned PDFs)
**File**: `DocumentEditView.swift:144`

```swift
PDFViewer(pdfData: pdfData,
          navigateToPage: $navigateToPage,
          currentPage: $currentViewedPage,
          onRequestPageManagement: {
              activeSheet = .pageManagement  // ✅ Swipe-up triggers this
          },
          ...)
```

**Flow**:
```
User views scanned PDF page
    ↓
PDFViewer renders via PDFKitView (UIViewRepresentable)
    ↓
PDFKitView.configurePDFView() adds swipe gestures (line 230-232)
    ↓
swipeUp() gesture calls onRequestPageManagement() (line 441)
    ↓
DocumentEditView shows page management sheet ✅
```

#### 2. Text Page Editor View (Markdown Pages)
**File**: `TextPageEditorView.swift:111`

```swift
if let data = viewModel.latestRenderedPageData,
   let document = PDFDocument(data: data) {
    RenderedPagePreview(document: document)  // ❌ No gesture handling
}
```

**Flow**:
```
User views markdown-rendered PDF preview
    ↓
RenderedPagePreview renders via PDFView (UIViewRepresentable)
    ↓
makeUIView() creates PDFView with NO gesture recognizers ❌
    ↓
Swipe-up gesture → nothing happens
```

---

## The Key Difference

### PDFViewer (Scanned Pages) ✅

**File**: `PDFViewer.swift:220-237`

```swift
// PDFKitView.configurePDFView() - iOS only
#if os(iOS)
    // Add swipe gestures for page navigation
    let swipeLeft = UISwipeGestureRecognizer(...)
    let swipeRight = UISwipeGestureRecognizer(...)

    // ✅ Swipe-up for page management
    let swipeUp = UISwipeGestureRecognizer(target: context.coordinator,
                                           action: #selector(Coordinator.swipeUp(_:)))
    swipeUp.direction = .up
    pdfView.addGestureRecognizer(swipeUp)

    // Swipe-down for metadata view
    let swipeDown = UISwipeGestureRecognizer(...)
#endif
```

**Coordinator implementation**: `PDFViewer.swift:427-443`
```swift
@objc func swipeUp(_ gesture: UISwipeGestureRecognizer) {
    guard let pdfView = gesture.view as? PDFView else { return }

    // Check if PDF is at fit-to-screen zoom level
    let currentScale = pdfView.scaleFactor
    let fitScale = pdfView.scaleFactorForSizeToFit
    let isAtFitZoom = abs(currentScale - fitScale) < 0.01

    if isAtFitZoom {
        // ✅ Only trigger page management when at fit zoom
        onRequestPageManagement?()
    }
}
```

### RenderedPagePreview (Markdown Pages) ❌

**File**: `TextPageEditorView.swift:296-312`

```swift
private struct RenderedPagePreview: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        return view  // ❌ No gesture recognizers added
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
        uiView.autoScales = true
    }
}
```

**Missing**:
- ❌ No Coordinator class
- ❌ No `UISwipeGestureRecognizer` setup
- ❌ No `onRequestPageManagement` callback
- ❌ No gesture handler methods

---

## Why This Happened

### Design Context

`RenderedPagePreview` is a **live preview panel** inside the text editor, not a full-screen document viewer. It was designed for:
- Quick preview of markdown rendering
- Side-by-side editing (iPad split view)
- Inline feedback while editing

It was **intentionally kept simple** - just a minimal PDFView wrapper without interactive gestures.

### Expected vs. Actual Usage

**Original intent** (my inference):
```
TextPageEditorView
├── Editor pane (left)
└── Preview pane (right) ← Just for viewing, no interaction
```

**Your actual usage** (based on bug report):
```
User exits markdown editor
    ↓
Shows full-screen preview (temporary PDF render)
    ↓
User expects same gestures as scanned PDFs
    ↓
But RenderedPagePreview has no gestures ❌
```

---

## Solutions

### Option 1: Add Gestures to RenderedPagePreview (Quick Fix)

**Complexity**: Medium
**Time**: 1-2 hours
**Tradeoff**: Duplicates gesture code from PDFViewer

**Approach**:
1. Add Coordinator to `RenderedPagePreview`
2. Copy swipe gesture setup from `PDFKitView.configurePDFView()`
3. Add callback closure: `let onRequestPageManagement: (() -> Void)?`
4. Pass callback from `TextPageEditorView` to `RenderedPagePreview`

**Pseudo-code**:
```swift
// In TextPageEditorView.swift
private var previewPane: some View {
    if let data = viewModel.latestRenderedPageData,
       let document = PDFDocument(data: data) {
        RenderedPagePreview(
            document: document,
            onRequestPageManagement: {
                // TODO: Show page thumbnails
                // Need to add sheet/navigation to TextPageEditorView
            }
        )
    }
}

// In RenderedPagePreview
private struct RenderedPagePreview: UIViewRepresentable {
    let document: PDFDocument
    let onRequestPageManagement: (() -> Void)?

    func makeCoordinator() -> Coordinator { ... }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        // ... existing setup

        // Add swipe-up gesture
        let swipeUp = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.swipeUp(_:))
        )
        swipeUp.direction = .up
        view.addGestureRecognizer(swipeUp)

        return view
    }

    class Coordinator: NSObject {
        var parent: RenderedPagePreview

        @objc func swipeUp(_ gesture: UISwipeGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }

            let currentScale = pdfView.scaleFactor
            let fitScale = pdfView.scaleFactorForSizeToFit
            let isAtFitZoom = abs(currentScale - fitScale) < 0.01

            if isAtFitZoom {
                parent.onRequestPageManagement?()
            }
        }
    }
}
```

**Problem with this approach**:
- Where does "page management" go in TextPageEditorView context?
- TextPageEditorView is editing ONE page, not viewing multi-page document
- Page thumbnails don't make sense here (you're editing a single markdown source)

---

### Option 2: Reuse PDFViewer Instead of RenderedPagePreview (Better Architecture)

**Complexity**: Low-Medium
**Time**: 1 hour
**Tradeoff**: Cleaner, but preview might have extra UI chrome

**Approach**:
Use `PDFViewer` (which already has gestures) instead of `RenderedPagePreview` for the preview pane.

**Changes**:
```swift
// In TextPageEditorView.swift, replace:
RenderedPagePreview(document: document)

// With:
if let data = viewModel.latestRenderedPageData {
    PDFViewer(
        pdfData: data,
        onRequestPageManagement: {
            // Show page thumbnails (if multi-page)
        }
    )
}
```

**Benefits**:
- ✅ Swipe gestures work automatically
- ✅ Consistent behavior across all PDF views
- ✅ No code duplication
- ✅ Left/right swipe for multi-page markdown renders
- ✅ Swipe-down for metadata (bonus feature)

**Considerations**:
- PDFViewer includes page indicator overlay (`pageIndicator` view)
- Might show "Page 1 of 3" for multi-page markdown renders (actually useful!)
- Slightly heavier than minimal `RenderedPagePreview`

---

### Option 3: Extract Shared Gesture Component (Best Long-Term)

**Complexity**: Medium-High
**Time**: 2-3 hours
**Tradeoff**: Most maintainable, but more upfront work

**Approach**:
Create reusable gesture-aware PDF view component.

**Architecture**:
```swift
// New file: PDFViewWithGestures.swift
struct PDFViewWithGestures: UIViewRepresentable {
    let document: PDFDocument?  // or Data
    let onRequestPageManagement: (() -> Void)?
    let onRequestMetadataView: (() -> Void)?
    let enableNavigation: Bool  // Left/right swipes

    // ... gesture setup code extracted from PDFKitView
}

// Then use everywhere:
// 1. In PDFViewer → PDFViewWithGestures
// 2. In RenderedPagePreview → PDFViewWithGestures
// 3. Any future PDF views → PDFViewWithGestures
```

**Benefits**:
- ✅ Single source of truth for PDF gestures
- ✅ Consistent across entire app
- ✅ Easy to modify gesture behavior once
- ✅ Testable gesture logic

**Drawback**:
- Requires refactoring existing working code
- Higher risk of breaking scanned PDF view

---

## Recommended Solution

### 🎯 Option 2: Use PDFViewer for Preview Pane

**Why this is best for now**:
1. **Quick** - 1 hour implementation
2. **Low risk** - PDFViewer already tested and working
3. **Consistent UX** - Same gestures everywhere
4. **Bonus features** - Multi-page navigation, page indicators

**Implementation sketch**:

```swift
// In TextPageEditorView.swift:105-133
private var previewPane: some View {
    Group {
        #if os(iOS)
        if let data = viewModel.latestRenderedPageData {
            // ✅ NEW: Use PDFViewer instead of RenderedPagePreview
            PDFViewer(
                pdfData: data,
                currentPage: .constant(0),  // Or track page if needed
                onRequestPageManagement: {
                    // TODO: Decide what to do here
                    // Option A: Show page thumbnails (if multi-page)
                    // Option B: Navigate back to document edit view
                    // Option C: Show "Not available in editor" message
                },
                onRequestMetadataView: {
                    // TODO: Show metadata or dismiss editor
                }
            )
        } else if let error = viewModel.liveRenderError {
            // ... error view
        } else {
            // ... loading view
        }
        #else
        MarkdownPreview(markdown: viewModel.content)
        #endif
    }
    .background(previewBackground)
}
```

---

## Context-Specific Questions

### Q1: What should swipe-up do in TextPageEditorView?

**Scenario A: Single-page markdown**
- Markdown renders to 1 PDF page
- Swipe-up → ??? (no other pages to show)

**Options**:
1. **Do nothing** (disable gesture if only 1 page)
2. **Exit to parent** (return to document edit view showing all pages)
3. **Show metadata** (redirect to document info)

**Scenario B: Multi-page markdown**
- Markdown renders to 3 PDF pages (overflow)
- Swipe-up → Show thumbnails of those 3 pages (makes sense!)

### Q2: Is TextPageEditorView full-screen or side-by-side?

**If full-screen preview mode**:
→ Option 2 (PDFViewer) is perfect - acts like document viewer

**If split-view editing**:
→ Gestures might be distracting while editing
→ Maybe only enable gestures when NOT in edit mode

### Q3: Where does user navigate FROM to see markdown preview?

**Current flow** (based on code):
```
DocumentEditView (shows scanned PDFs)
    ↓ User taps "Text" button
TextPageEditorView (markdown editor + preview)
    ↓ User exits editor
??? What view shows the rendered text page?
```

**Key question**: Is the "temporary preview PDF" shown:
- A) Within TextPageEditorView preview pane? (side-by-side with editor)
- B) In DocumentEditView alongside scanned pages? (integrated into main view)

If **B**, then you need gestures in DocumentEditView, not TextPageEditorView!

---

## Testing Recommendations

Once implemented, test:

1. **Single-page markdown render**
   - Edit text → exit editor → swipe up
   - Expected: Contextual behavior (exit? message? nothing?)

2. **Multi-page markdown render**
   - Edit long text (forces 3+ PDF pages) → exit editor → swipe up
   - Expected: Show page thumbnails for those pages

3. **Zoom state**
   - Pinch-zoom into preview → swipe up
   - Expected: Nothing (gesture only works at fit-zoom, per existing logic)

4. **iPad split view**
   - Editor + preview side-by-side → swipe up on preview
   - Expected: Gesture works independently

5. **Navigation consistency**
   - Left/right swipes (if multi-page markdown)
   - Expected: Navigate between rendered pages

---

## Related Design Questions

### Should markdown preview feel like "editing" or "viewing"?

**If editing**:
- Preview is just feedback, not interactive
- No gestures needed
- Focus stays on editor pane

**If viewing**:
- Preview is temporary document view
- Full gesture support expected
- Should match scanned PDF UX

**My read**: Based on your bug report, users expect **viewing** behavior. They see a rendered page and intuitively try to swipe-up (learned behavior from scanned pages). The gesture should work consistently.

---

## Summary

**Root cause**: `RenderedPagePreview` is a minimal wrapper without gesture support, while `PDFViewer` (used for scanned pages) has full gesture integration.

**Quick fix**: Replace `RenderedPagePreview` with `PDFViewer` in the preview pane.

**Remaining question**: What should swipe-up DO in the markdown editor context? This depends on your UX vision:
- Exit to document view?
- Show multi-page thumbnails (if markdown overflows)?
- Show "not available" message?

**Next steps**:
1. Clarify intended UX for swipe-up in text editor
2. Implement Option 2 (PDFViewer replacement)
3. Test multi-page markdown rendering
4. Consider Option 3 (shared gesture component) for future refactor

Would you like to discuss what the swipe-up gesture SHOULD do when viewing a markdown-rendered page?
