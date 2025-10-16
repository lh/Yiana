# PDFView Zoom Behaviour Fix Plan

**Author:** Codex  
**Owner:** Junior Developer  
**Date:** 14 Oct 2025  
**Status:** Ready for implementation  

---

## Objective
Make pinch-to-zoom and double-tap behaviour consistent on both iOS and macOS by taking manual control over `PDFView` scaling. This eliminates the current “bounce back to fit” issue caused by `autoScales`.

---

## Current Issues
- `pdfView.autoScales = true` in `PDFViewer.configurePDFView` conflicts with user-driven zoom.
- Pinch zoom fails until the user triggers a keyboard shortcut (which implicitly disables `autoScales`).
- Double-tap gesture to reset zoom is missing.

---

## High-Level Approach (Option A from analysis)
1. Disable `autoScales` after the initial fit.
2. Manually set the initial `scaleFactor` to `scaleFactorForSizeToFit`.
3. Track user-initiated zoom so fit-to-window can be re-applied on demand.
4. Add double-tap/double-click to reset to fit-to-window.

---

## Step-by-Step Tasks

### Phase 0 – Fit Mode Controls (iPad + Mac)
Add user-facing controls so people can switch between fit-to-width and fit-to-height without breaking the manual zoom flow.

1. **UI Placement**
   - iPad: add a segmented control (Fit Width / Fit Height) at the bottom of the `PDFViewer` overlay or inside the toolbar, using `.controlSize(.small)` to keep it subtle.
   - macOS: add two toolbar buttons (or a single segmented control) with icons (e.g. `rectangle.expand.vertical` / `rectangle.expand.horizontal`). Provide keyboard shortcuts (Command-1 for Fit Width, Command-2 for Fit Height).

2. **State Management**
   - Introduce an enum `FitMode { case width, height, manual }` stored in the coordinator.
   - Selecting a fit mode calls the appropriate helper: `applyFitToWidth`, `applyFitToHeight`.
   - Any manual pinch/keyboard zoom switches state to `.manual`.

3. **Implementation Steps**
   - Add helper functions similar to `applyFitToWindow`, but using the `pdfView.bounds` ratio to compute scale: `scaleFactorForSizeToFitWidth/Height` (derive by dividing bounds width/height by pageRect).
   - Update double-tap and Command-0 to default to the currently selected fit mode (if `.manual`, default to `.height`).
   - Persist the last selected fit mode in UserDefaults if desired so the app remembers the preference per device.

4. **Testing**
   - [ ] Toggle fit mode on iPad with toolbar control.
   - [ ] Toggle fit mode on macOS via segmented control and shortcuts.
   - [ ] Verify pinch zoom switches mode to manual and does not override the fit selection.


### Phase 1 – Prepare State & Helpers
1. **Add Coordinator State Flags**
   ```swift
   class Coordinator: NSObject {
       var hasUserZoomed = false
       var lastKnownScaleFactor: CGFloat?
   }
   ```
2. **Add Helper Methods in `PDFKitView`**
   ```swift
   private func applyFitToWindow(_ pdfView: PDFView, coordinator: Coordinator) {
       pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
       coordinator.lastKnownScaleFactor = pdfView.scaleFactor
       coordinator.hasUserZoomed = false
   }
   ```

### Phase 2 – Update `configurePDFView`
1. Replace `pdfView.autoScales = true` with:
   ```swift
   pdfView.autoScales = false
   applyFitToWindow(pdfView, coordinator: context.coordinator)
   ```
2. Set appropriate scale limits (if not already set):
   ```swift
   pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit * 0.5
   pdfView.maxScaleFactor = pdfView.scaleFactorForSizeToFit * 4.0
   ```
3. Ensure `applyFitToWindow` is called after each document load (inside `handleNavigation` or after setting `pdfView.document` when `isInitialLoad` is true).

### Phase 3 – Capture User Zoom Events
1. **Add Gesture Delegate Hooks**
   - iOS: Implement `UIScrollViewDelegate` on the coordinator (PDFView’s scroll view). Set `scrollViewDidZoom` to mark `hasUserZoomed = true` and remember current scale.
   - macOS: Observe `PDFView.scaleFactor` via KVO or override `magnify(with:)` in a subclass (simpler: add `NotificationCenter` observer for `PDFViewScaleChanged`).
2. Update `handleZoom(_:)` (keyboard zoom actions) to set `hasUserZoomed = true` and store `lastKnownScaleFactor`.

### Phase 4 – Add Double-Tap / Double-Click Gesture
1. **iOS**
   ```swift
   let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.resetZoom(_:)))
   doubleTap.numberOfTapsRequired = 2
   pdfView.addGestureRecognizer(doubleTap)
   ```
2. **macOS**
   ```swift
   let doubleClick = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.resetZoom(_:)))
   doubleClick.numberOfClicksRequired = 2
   pdfView.addGestureRecognizer(doubleClick)
   ```
3. Coordinator handler:
   ```swift
   @objc func resetZoom(_ sender: Any) {
       guard let pdfView else { return }
       parent.applyFitToWindow(pdfView, coordinator: self)
   }
   ```

### Phase 5 – Window Resize (Optional Nice-to-Have)
1. macOS: listen to `NSView.frameDidChangeNotification` on `pdfView` or its container.
2. Decide whether to keep current scale or re-fit:
   - If `hasUserZoomed == false`, keep calling `applyFitToWindow`.
   - If user has zoomed, keep scale constant relative to new size (`pdfView.scaleFactor = lastKnownScaleFactor`).

---

## Acceptance Criteria
- Pinch-to-zoom works immediately on load without bouncing.
- Keyboard zoom and pinch gestures remain in sync (`hasUserZoomed` flag true after manual zoom).
- Double-tap/double-click resets to fit-to-window on all platforms.
- Command-0 (fit to window) still works (implement using `applyFitToWindow`).
- No regressions in page navigation or accessibility.

---

## Testing Checklist
- [ ] iOS pinch zoom in/out works on first interaction.
- [ ] macOS trackpad pinch and mouse scroll-zoom work without bounce.
- [ ] Command-+, Command--, Command-0 still function.
- [ ] Double-tap (iOS) and double-click (macOS) reset zoom.
- [ ] Zoom level persists when switching pages and after reload.
- [ ] Window resize (macOS) retains expected behaviour (auto-fit when untouched, maintain scale when user-zoomed).

---

## Notes & Future Enhancements
- Consider exposing a “Fit to Width” vs “Fit to Height” toggle if users request it later.
- Evaluate adding visual feedback (HUD) when zoom resets.
- If optional Phase 5 is deferred, document the behaviour so QA knows zoom isn’t auto-reset on resize.

---

Follow this plan step-by-step, commit in logical chunks (configuration changes, gesture additions, testing tweaks), and include before/after GIFs if possible for reviewer clarity.***
