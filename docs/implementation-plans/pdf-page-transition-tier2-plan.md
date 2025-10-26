# PDF Page Transition Tier 2 Plan

**Author:** Codex  
**Owner:** Junior Developer  
**Date:** 21 Oct 2025  
**Status:** Ready for implementation  

---

## Objective
Adopt PDFKit’s built-in `UIPageViewController` integration so Apple manages horizontal paging animations for us. This eliminates the wobble still present after Tier 1 by removing all manual centering, snapshot fades, and custom swipe transitions on iOS, while preserving existing zoom and accessory gestures.

---

## Background
- Tier 1 (snapshot fade + delayed centering) reduced but did not remove page shake; PDFKit continued to relayout and drift the content mid-transition.
- PDFKit provides a native page-paging controller (`usePageViewController`) that keeps content centred and handles the animation stack internally.
- Our current setup (`displayMode = .singlePage`, manual centring, custom swipe gestures) now fights with the framework, so we need to hand control back to PDFKit and simplify our coordinator.

---

## Scope
1. Enable `usePageViewController` for iOS PDFView instances with a horizontal page stack.
2. Remove custom left/right swipe gesture recognisers, snapshot logic, and `centerPDFContent` usage on iOS navigation.
3. Keep existing up/down gestures (page management / metadata) and zoom behaviour intact.
4. Ensure macOS behaviour is unchanged.

---

## Implementation Steps

### Phase 0 – Clean Up Tier 1 additions
1. Revert the snapshot overlay code added for Tier 1 in `Coordinator.swipeLeft` / `swipeRight` so those handlers exist only if we still need them (we will delete them in the next phase). If Tier 1 code is still present locally, remove any `UIImageView` overlay creation, fade constants, and delayed centering.
2. Remove the Tier 1 logging statements introduced in `centerPDFContent` and `handleLayout` once the new paging is in place; they will produce noise after we stop calling those methods during swipes.

### Phase 1 – Enable Page View Controller Paging
1. In `configurePDFView(_:, context:)` under `#if os(iOS)`:
   - Confirm `pdfView.displayMode` is `.singlePage` (already set today but re-assert for clarity).
   - Set `pdfView.displayDirection = .horizontal`.
   - Call:
     ```swift
     pdfView.usePageViewController(true, withViewOptions: [
         UIPageViewController.OptionsKey.interPageSpacing: pageSpacing
     ])
     ```
     Add a file-private constant at the top of the iOS section:
     ```swift
     private let pageSpacing: CGFloat = 12
     ```
     so we can tweak spacing later.
   - After the call, log once:
     ```swift
     pdfDebug("usePageViewController enabled: \(pdfView.usesPageViewController)")
     ```
   - Guard the `attachLayoutObserver(to:)` invocation so it only runs on macOS or when `usesPageViewController` is `false`. On iOS with paging enabled we should skip the observer entirely.
2. Confirm `pdfView.autoScales` remains `false` and we still apply our manual `applyFitToHeight/Width` after documents load so zoom preferences continue to work. The page controller will animate between already-scaled pages.

### Phase 2 – Remove Competing Swipe Handling
1. Delete the `UISwipeGestureRecognizer` setup for `.left` and `.right` inside `configurePDFView`. The page controller ships with its own pan gestures; keeping ours causes double navigation and fighting animations.
2. Retain the `.up` and `.down` swipe recognisers (page management / metadata) since the page controller doesn’t supply those.
3. Delete `Coordinator.swipeLeft(_:)` and `Coordinator.swipeRight(_:)` implementations entirely. Remove the haptic helper inline with them; if we want to revisit haptics later we can recover the code from Git history.
4. Remove the `swipeDebounceInterval` and `lastSwipeTime` properties since debounce is no longer required.

### Phase 3 – Simplify Centering Logic
1. Update `centerPDFContent` to be a no-op on iOS:
   ```swift
   #if os(iOS)
   private func centerPDFContent(in pdfView: PDFView, coordinator: Coordinator) { return }
   #endif
   ```
   Keep the existing macOS implementation under `#else`.
2. Remove references to `centerPDFContent` from iOS call sites: `handleNavigation`, `updateUIView`/`makeUIView` follow-up blocks, `handleLayout`’s iOS branch, and the iOS-only branches in `resetZoom`. Mac remains untouched.
3. In `handleLayout`, add `guard !pdfView.usesPageViewController else { return }` at the very top so we bail before logging or recomputing fit when paging is active. (Still run the rest of the method on macOS or if paging is disabled.)

### Phase 4 – Navigation Actions
1. Verify that programmatic navigation (`navigateToPage` binding, keyboard shortcuts) still works. The page controller responds to `pdfView.go(to:)`, so we should keep using that call, but ensure it runs on the main thread.
2. With manual centering removed, update `handleNavigation` to simply:
   - Guard the page index.
   - Call `DispatchQueue.main.async { pdfView.go(to: page) }` to guarantee execution on the main queue (the surrounding async block can be simplified accordingly).
   - Update `currentPage`/`navigateToPage` inside that async block as we do today.
3. Keep the page indicator logic unchanged; the `currentPage` binding will update via `Coordinator.pageChanged`.

### Phase 5 – Validation Hooks
1. Ensure `pdfDebug` now logs `usePageViewController enabled: true` when the viewer is created.
2. Ensure no compile warnings remain about unused properties or methods after removing the swipe code.

---

## Verification Checklist
- [ ] Build succeeds on iOS and macOS.
- [ ] On an iPhone simulator, swipe between pages: the animation should be a native horizontal slide, with zero wobble/jump before/during/after the animation.
- [ ] Up/down swipes still present their respective actions (page management and metadata).
- [ ] Programmatic navigation (`navigateToPage`) jumps to the correct page without visual drift.
- [ ] Pinch zoom and fit mode cycling continue to function; after zooming out, the page controller still animates smoothly.
- [ ] macOS build retains its existing keyboard/scroll page handling (no regressions).
- [ ] Console log shows `usePageViewController enabled: true` for iOS instances.
- [ ] No leftover debug logging from Tier 1 remains.
- [ ] Confirm no extra gestures fire when swiping (no double navigation); a quick manual test is enough—no additional logging is required unless issues appear.

---

## Handoff Notes
- With the page controller managing layout, any future custom animation work should sit on top of `UIPageViewController` rather than reintroducing manual scroll offset adjustments.
- Keep the old `centerPDFContent` implementation tucked under `#if os(macOS)`—we still need it on desktop.
- Archive any removed Tier 1 logic (snapshot fade instructions, etc.) in `docs/implementation-plans/archive/` if we want to preserve historical context.
- Once this lands, re-run the frame-capture workflow to confirm there is zero shake before considering the issue closed.
