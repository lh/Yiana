# Fit Mode Rework Plan (Double-Tap + Dedicated Mac Toolbar)

**Owner:** Junior Developer  
**Reviewer:** Codex  
**Date:** 14 Oct 2025  
**Status:** Ready for implementation  

---

## Goal
Replace the current “fit width/fit height” UI with a simpler, more intuitive approach:
- **iPad/iOS:** Use double-tap to cycle between full page and full width (no on-screen buttons).
- **macOS:** Provide two explicit toolbar buttons (Fit Page, Fit Width). No overlay controls.

---

## Overview

### iPad / iPhone
1. Double-tap cycles through fit modes:
   - If in manual zoom → snap to Fit Page.
   - If at Fit Page → switch to Fit Width.
   - If at Fit Width → switch back to Fit Page.
2. No persistent on-screen toggle needed.

### macOS
1. Toolbar hosts two buttons:
   - Fit Page (⌘0)
   - Fit Width (⌘3, for example)
2. No bottom overlay or redundant capsule.

---

## Step-by-Step Tasks

### Phase 1 – Remove current overlay controls
1. Delete the iOS bottom overlay (`fitModeControl`) from `PDFViewer`.
2. Remove the associated background capsule code and helper structs.
3. Delete `fitMode` overlay references from `DocumentEditView` and `ContentView` (no segmented control needed).

### Phase 2 – Implement double-tap cycle on iOS
1. Update the coordinator’s double-tap handler:
   ```swift
   @objc func resetZoom(_ sender: Any) {
       guard let pdfView = pdfView else { return }
       let current = currentFitMode
       switch current {
       case .manual:
           parent.applyFitToHeight(pdfView, coordinator: self) // Fit page
       case .height:
           parent.applyFitToWidth(pdfView, coordinator: self)
       case .width:
           parent.applyFitToHeight(pdfView, coordinator: self)
       }
   }
   ```
2. Ensure `currentFitMode` is updated whenever we apply width/height/zoom operations.
3. Keep tracking user zoom so we know when to treat the next double-tap as “reset to page”.
4. Attach the double-tap recogniser to the embedded scroll view:
   - After `configurePDFView` sets up gestures, find the first `UIScrollView` (`pdfView.subviews.first { $0 is UIScrollView }`).
   - Add the double-tap recognizer to that scroll view instead of the PDFView.
   - Disable any existing double-tap recognisers on the scroll view.
5. Make the coordinator the gesture delegate and allow simultaneous recognition where appropriate, so pinch/scroll continue to work.

### Phase 3 – Mac toolbar adjustments
1. In `MacPDFViewer`, keep fit controls in the toolbar only.
2. Present two buttons with explicit icons/text:
   - Fit Page (icon `arrow.up.left.and.arrow.down.right` + “Fit Page” label)
   - Fit Width (`rectangle.expand.horizontal` + “Fit Width” label)
3. Wire buttons to call `zoomAction = .fitToWindow` after setting `fitMode = .height` (page) or `.width`.
4. Add keyboard shortcuts:
   - Fit Page → ⌘0 (already present)
   - Fit Width → ⌘3 (new)

### Phase 4 – Clean up state management
1. Ensure `lastExplicitFitMode` remains accurate for both platforms.
2. Reset `fitMode` to `.height` when a document reloads.
3. Verify `currentFitMode` and `lastExplicitFitMode` stay in sync.

---

## Acceptance Criteria
- Double-tap on iPad cycles Page → Width → Page, regardless of prior zoom adjustments.
- No fit mode buttons overlap the action bar on iPad.
- macOS toolbar presents two clear buttons (Fit Page, Fit Width) and no bottom overlay.
- Keyboard shortcuts work (⌘0, ⌘3).
- Double-click on macOS continues to reset to the current fit mode.

---

## Testing Checklist
- [ ] iPad: Double-tap from manual zoom snaps to Fit Page.
- [ ] iPad: Double-tap from Fit Page switches to Fit Width.
- [ ] iPad: Double-tap from Fit Width switches back to Fit Page.
- [ ] Mac: Fit Page and Fit Width buttons operate correctly.
- [ ] Mac: ⌘0 and ⌘3 shortcuts work.
- [ ] Mac: No bottom overlay appears.
- [ ] Pinch/keyboard zoom still work and update the manual state.

---

## Deliverables
1. Updated `PDFViewer.swift`, `MacPDFViewer.swift`, `DocumentEditView.swift`, `ContentView.swift`.
2. Updated coordinator logic for double-tap handling.
3. Screenshots/gif demonstrating the new behaviour on both platforms.

Once implemented, this replaces the redundant overlay and improves usability across platforms.***
