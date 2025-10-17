# iPhone PDF Initial Zoom Fix - Implementation Plan

## Problem Statement

PDFs don't open fit-to-height on iPhone, though this works correctly on iPad and macOS. Double-tapping correctly cycles between fit-to-width and fit-to-height, proving the functionality exists but the initial rendering is wrong.

## Root Cause Analysis

### The Issue
- Initial scale on iPhone: `0.740` (wrong - page appears too zoomed in)
- Correct scale (after double-tap): `0.630`
- The difference represents ~93px of missing height calculation

### Why It Happens
The GeometryReader approach measures `availableSize=(375.0, 623.0)` **before** the PDFView has real bounds (still `0×0`). This early measurement doesn't account for the navigation bar and other chrome that will constrain the view.

### Key Evidence from Logs
```
updateUIView start: bounds=(0.0, 0.0) availableSize=(375.0, 623.0) scale=1.0
applyFitToHeight iOS: bounds=623.0 availableSize=(375.0, 623.0) using=623.0
applyFitToHeight success: scaleFactor=0.7400807792824899 viewHeight=623.0
```

When double-tap works correctly:
```
updateUIView start: bounds=(375.0, 623.0) availableSize=(375.0, 623.0) scale=0.6300403225806451
```

### The Real Problem
GeometryReader fires too early in the layout cycle. Even when PDFView's bounds settle at 603pt, this still includes overlay chrome. The **actual usable area** comes from the PDFView's internal scroll view after iOS applies `adjustedContentInset` for navigation bars.

## Solution

### Core Approach
Use the PDFView's internal scroll view's content area metrics:
```swift
let usableHeight = scrollView.bounds.height
                 - scrollView.adjustedContentInset.top
                 - scrollView.adjustedContentInset.bottom
```

This matches the post-double-tap behavior exactly.

## Implementation Steps

### Step 1: Remove All GeometryReader Code

#### Files to modify:
1. **PDFViewer.swift**
   - Remove `let availableSize: CGSize` property from `PDFViewer` struct
   - Remove `availableSize: CGSize = .zero` parameter from init
   - Remove `self.availableSize = availableSize` from init body

2. **PDFViewer.swift** (PDFKitView struct)
   - Remove `let availableSize: CGSize` property
   - Remove `availableSize` parameter from struct definition
   - Remove `context.coordinator.availableSize = availableSize` from `updateUIView`
   - Remove `context.coordinator.availableSize = availableSize` from `updateNSView`

3. **PDFViewer.swift** (Coordinator class)
   - Remove `var availableSize: CGSize = .zero` property

4. **DocumentEditView.swift**
   - Remove `GeometryReader { geometry in` wrapper (line 220)
   - Remove `let adjustedSize = ...` calculation
   - Remove `availableSize: adjustedSize` parameter from PDFViewer call
   - Restore proper indentation

5. **DocumentReadView+Components.swift**
   - Remove `GeometryReader { geometry in` wrapper
   - Remove `availableSize: geometry.size` parameters from MacPDFViewer calls
   - Restore proper indentation

6. **MacPDFViewer.swift**
   - Remove `var availableSize: CGSize = .zero` property
   - Remove `availableSize: availableSize` parameter from PDFViewer call

### Step 2: Implement Scroll View Height Detection in applyFitToHeight

Replace the iOS section in `applyFitToHeight` (around line 355-359):

**Current code:**
```swift
#if os(iOS)
pdfView.layoutIfNeeded()
let viewHeight = coordinator.availableSize.height
pdfDebug("applyFitToHeight iOS: bounds=\(pdfView.bounds.height) availableSize=\(coordinator.availableSize) using=\(viewHeight)")
#else
```

**New code:**
```swift
#if os(iOS)
pdfView.layoutIfNeeded()

// Find the deepest scroll view which has the correct content insets applied
func findDeepestScrollView(in view: UIView) -> UIScrollView? {
    var candidates: [(UIScrollView, Int)] = []

    func collect(_ view: UIView, depth: Int) {
        if let scrollView = view as? UIScrollView {
            candidates.append((scrollView, depth))
        }
        for subview in view.subviews {
            collect(subview, depth: depth + 1)
        }
    }

    collect(view, depth: 0)
    return candidates.max(by: { $0.1 < $1.1 })?.0
}

let viewHeight: CGFloat
if let scrollView = findDeepestScrollView(in: pdfView) {
    let insets = scrollView.adjustedContentInset
    let availableHeight = scrollView.bounds.height - insets.top - insets.bottom
    viewHeight = availableHeight > 0 ? availableHeight : pdfView.bounds.height
    pdfDebug("applyFitToHeight iOS: scrollView.bounds=\(scrollView.bounds.height) insets.top=\(insets.top) insets.bottom=\(insets.bottom) available=\(availableHeight) using=\(viewHeight)")
} else {
    viewHeight = pdfView.bounds.height
    pdfDebug("applyFitToHeight iOS: no scrollView found, using bounds=\(viewHeight)")
}
#else
```

### Step 3: Update handleLayout to Check for Settled Insets

In `Coordinator.handleLayout` (around line 715-733), add a check before applying initial fit:

**Current code:**
```swift
func handleLayout(for pdfView: PDFView) {
    #if os(iOS)
    let safeHeight = pdfView.safeAreaLayoutGuide.layoutFrame.height
    #else
    let safeHeight: CGFloat = 0
    #endif
    pdfDebug("handleLayout: awaiting=\(awaitingInitialFit) size=\(pdfView.bounds.size) safeHeight=\(safeHeight) currentFit=\(currentFitMode) parentFit=\(parent.fitMode) reloading=\(isReloadingDocument)")
    if awaitingInitialFit {
        pdfDebug("handleLayout: triggering deferred fit")
        _ = parent.applyFitToHeight(pdfView, coordinator: self)
        return
    }
```

**New code:**
```swift
func handleLayout(for pdfView: PDFView) {
    #if os(iOS)
    // Find scroll view to check if insets have settled
    func findDeepestScrollView(in view: UIView) -> UIScrollView? {
        var candidates: [(UIScrollView, Int)] = []

        func collect(_ view: UIView, depth: Int) {
            if let scrollView = view as? UIScrollView {
                candidates.append((scrollView, depth))
            }
            for subview in view.subviews {
                collect(subview, depth: depth + 1)
            }
        }

        collect(view, depth: 0)
        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    let scrollView = findDeepestScrollView(in: pdfView)
    let insets = scrollView?.adjustedContentInset ?? .zero
    let safeHeight = pdfView.safeAreaLayoutGuide.layoutFrame.height
    #else
    let safeHeight: CGFloat = 0
    let insets = UIEdgeInsets.zero
    #endif

    pdfDebug("handleLayout: awaiting=\(awaitingInitialFit) size=\(pdfView.bounds.size) safeHeight=\(safeHeight) insets.top=\(insets.top) insets.bottom=\(insets.bottom) currentFit=\(currentFitMode) parentFit=\(parent.fitMode) reloading=\(isReloadingDocument)")

    if awaitingInitialFit {
        #if os(iOS)
        // Only apply initial fit once the scroll view has non-zero insets (indicating chrome has settled)
        // OR if we have non-zero bounds (fallback for cases without scroll view)
        let hasSettledInsets = insets.top > 0 || insets.bottom > 0
        let hasSettledBounds = pdfView.bounds.height > 0

        if hasSettledInsets || hasSettledBounds {
            pdfDebug("handleLayout: triggering deferred fit (insets settled: \(hasSettledInsets), bounds settled: \(hasSettledBounds))")
            _ = parent.applyFitToHeight(pdfView, coordinator: self)
            return
        } else {
            pdfDebug("handleLayout: deferring fit until insets/bounds settle")
            return
        }
        #else
        pdfDebug("handleLayout: triggering deferred fit")
        _ = parent.applyFitToHeight(pdfView, coordinator: self)
        return
        #endif
    }
```

### Step 4: Test on iPhone

Build and run on iPhone simulator. Expected behavior:
- PDF should open at correct fit-to-height scale (~0.630)
- Initial scale should match double-tap scale
- Debug logs should show:
  ```
  applyFitToHeight iOS: scrollView.bounds=623.0 insets.top=XX insets.bottom=XX available=~530 using=~530
  applyFitToHeight success: scaleFactor=0.6300403225806451
  ```

## Why This Works

1. **Timing**: We wait for the scroll view's `adjustedContentInset` to be set, which happens after iOS applies all navigation bar and status bar constraints
2. **Correct metrics**: We use the scroll view's actual usable content area, not the PDFView's bounds which include chrome
3. **Matches double-tap**: The double-tap gesture uses the same settled scroll view metrics, so initial load now matches

## Rollback Plan

If this doesn't work:
1. Git revert to commit before GeometryReader was added
2. Consider alternative: Use a `.onAppear` delay of ~0.2 seconds before applying initial fit (hacky but might work)

## Related Files

- `/Users/rose/Code/Yiana/Yiana/Yiana/Views/PDFViewer.swift` - Main implementation
- `/Users/rose/Code/Yiana/Yiana/Yiana/Views/DocumentEditView.swift` - iOS entry point
- `/Users/rose/Code/Yiana/Yiana/Yiana/Views/MacPDFViewer.swift` - macOS wrapper
- `/Users/rose/Code/Yiana/Yiana/Yiana/Views/DocumentReadView+Components.swift` - macOS entry point

## Success Criteria

- [ ] PDFs open fit-to-height on iPhone (scale ~0.630)
- [ ] Initial scale matches double-tap scale
- [ ] Works on iPad (verify no regression)
- [ ] Works on macOS (verify no regression)
- [ ] Clean debug logs showing correct metrics
