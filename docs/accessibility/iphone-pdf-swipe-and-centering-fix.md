# iPhone PDF Swipe Gestures and Page Centering Fix

## Session Context

Working on fixing iPhone PDF viewer issues reported by user through video recordings. The Read tool in current session cannot read video files (.mp4, .mov) - getting "binary file" errors even though this has worked in previous sessions.

## Issues Being Fixed

### Issue 1: Pages Not Centered After Navigation
**User Report**: "After the first page the pages are not centered properly"

**Root Cause**: The `centerPDFContent()` function was only called during initial document load, not after swipe navigation.

**Fix Applied**: Modified `swipeLeft` and `swipeRight` handlers to call `centerPDFContent()` in the completion handler after page navigation.

**Code Changes** (in `/Users/rose/Code/Yiana/Yiana/Yiana/Views/PDFViewer.swift`):
```swift
// swipeLeft handler (line ~918-927)
UIView.transition(with: targetPDFView,
                duration: 0.25,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: {
    targetPDFView.goToNextPage(nil)
}, completion: { _ in
    // Re-center content after navigation completes
    self.parent.centerPDFContent(in: targetPDFView, coordinator: self)
})

// swipeRight handler (line ~962-971) - same pattern
```

**Status**: ✅ Implemented and committed to `untested` branch (commit 876a33d)

### Issue 2: Panning Triggers Page Navigation
**User Report**: "If I try and pan them to fit then they slide to the next page"

**Root Cause**: At fit-to-screen zoom, horizontal swipe gestures are intercepting pan attempts. Even though zoom detection exists, if content is not actually wider than viewport, there's nothing to pan, so any horizontal gesture becomes a swipe.

**Fix Applied**: Added zoom-level detection to swipeLeft/swipeRight handlers. Only allows page navigation when at fit-to-screen zoom (within 10% tolerance).

**Code Changes**:
```swift
// In both swipeLeft and swipeRight (lines ~890-900, ~934-944)
let currentScale = targetPDFView.scaleFactor
let fitScale = targetPDFView.scaleFactorForSizeToFit
let tolerance: CGFloat = 0.10
let isAtFitZoom = abs(currentScale - fitScale) < tolerance

guard isAtFitZoom else {
    pdfDebug("swipeLeft/Right ignored: zoomed in (scale=\(currentScale) fit=\(fitScale))")
    return
}
```

**Status**: ✅ Implemented and committed to `untested` branch (commit f059e1f)

**Potential Remaining Issue**: If content at fit-zoom is narrower than viewport, there's still no panning possible, so gestures may still trigger navigation when user expects to pan. May need additional check:
```swift
// Pseudo-code for potential additional fix
func isContentPannable(in pdfView: PDFView) -> Bool {
    guard let scrollView = findScrollView(in: pdfView) else { return false }
    return scrollView.contentSize.width > scrollView.bounds.width ||
           scrollView.contentSize.height > scrollView.bounds.height
}
```

## Previous Related Work

### Earlier iPhone Issues Fixed
1. **Page indicator not visible** - Fixed with UUID-based trigger mechanism
2. **Page indicator disappearing after double-tap** - Same UUID trigger fix
3. **Swipe gestures only working when manually zoomed** - Fixed by adding gestures to scroll view
4. **Double-page jump on swipe** - Fixed with 300ms debouncing

See conversation summary for full details on these fixes.

## Git Branch Status

**Branch**: `untested` (created from `refactor/HIG`)
**Remote**: https://github.com/lh/Yiana/tree/untested

**Commits**:
1. `f059e1f` - Fix swipe gestures to only work at fit-to-screen zoom
2. `876a33d` - Add page centering after swipe navigation

**How to test**:
```bash
git checkout untested
git pull origin untested
# Build and run on iPhone
```

## Testing Needed

User has video recordings showing:
1. Original issue: `/Users/rose/Downloads/ScreenRecording_10-20-2025 18-44-16_1.MP4`
2. After first fix: `/Users/rose/Downloads/ScreenRecording_10-20-2025 18-51-27_1.mov` (or .MP4)
3. Mac recording: `/Users/rose/Downloads/temp-screenshots/Screen Recording 2025-10-21 at 07.15.16.mov`

**Need to verify**:
- [ ] Pages are centered after swiping to page 2, 3, etc.
- [ ] When zoomed in, can pan freely without triggering page changes
- [ ] At fit-to-screen zoom, swipe left/right navigates pages normally
- [ ] Page indicator shows after navigation and zoom changes

## Key Code Locations

**Main file**: `/Users/rose/Code/Yiana/Yiana/Yiana/Views/PDFViewer.swift`

**Functions modified**:
- `Coordinator.swipeLeft(_:)` - Line ~887-929
- `Coordinator.swipeRight(_:)` - Line ~931-973
- `centerPDFContent(in:coordinator:)` - Line ~389-423 (already existed, now called from swipe handlers)

**Related functions** (for context):
- `applyFitToHeight(_:coordinator:)` - Line ~443-496
- `applyFitToWidth(_:coordinator:)` - Line ~431-440
- `handleLayout(for:)` - Line ~358-388

## Debug Logging

Debug logging is currently ENABLED. Look for:
- `swipeLeft/Right ignored: zoomed in` - Zoom detection working
- `📍 centerPDFContent: mode=... setting offset to ...` - Centering being applied
- All logging uses `pdfDebug()` which only logs in DEBUG builds

## Next Steps for New Session

1. **View user's video recordings** to see current behavior
2. **Determine if additional fixes needed**:
   - If panning still triggers navigation at fit-zoom, add content-size check
   - If centering still wrong, investigate `centerPDFContent()` calculation
3. **Test on actual iPhone device** (not just simulator)
4. **Consider cleanup**:
   - Remove debug logging before merging
   - Update documentation
   - Merge `untested` → `refactor/HIG` when verified

## Technical Background

### PDF Viewer Architecture
- SwiftUI wrapper around PDFKit's PDFView
- Uses `UIViewRepresentable` on iOS
- Coordinator pattern for gesture handling and state management
- Manual zoom control (autoScales disabled)
- Single page display mode with horizontal direction

### Zoom Modes
- `FitMode.height` - Fit to viewport height (portrait default)
- `FitMode.width` - Fit to viewport width (landscape default)
- `FitMode.manual` - User has zoomed/panned

### Gesture System
- Swipe left/right - Page navigation (at fit zoom only)
- Swipe up - Page management view (at fit zoom only)
- Swipe down - Metadata view (at fit zoom only)
- Double-tap - Cycle between fit-height, fit-width, manual zoom
- Pinch - Manual zoom (handled by PDFView's scroll view)
- Pan - Manual positioning (when zoomed in or content larger than viewport)

### Centering Logic
At fit-to-height zoom:
- Center both horizontally and vertically
- Uses scroll view's contentOffset

At fit-to-width zoom:
- Center horizontally, top-align vertically
- Prevents vertical centering which would show white space

## Session History

This work is part of larger HIG (Human Interface Guidelines) refactor branch. Previous sessions have addressed:
- Accessibility improvements
- DocumentReadView component extraction
- macOS toolbar refinements
- Page management improvements

Current branch started from: `refactor/HIG` at commit `5a14f44`
