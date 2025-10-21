# PDF Page Transition Tier 1 Plan

**Author:** Codex  
**Owner:** Junior Developer  
**Date:** 21 Oct 2025  
**Status:** Ready for implementation  

---

## Objective
Eliminate the visible “shake” during PDF page swipes on iOS by replacing the current cross-dissolve with a snapshot fade, deferring page re-centering until PDFKit finishes layout, and adding light logging so we can verify timing behaviour. This covers the Tier 1 approach agreed with the team; no Tier 2/3 work should begin until this experiment is evaluated.

---

## Background
- Current swipe handler (`Views/PDFViewer.swift`, coordinator methods `swipeLeft` / `swipeRight`) wraps `goToNextPage` in a 0.25 s `.transitionCrossDissolve`.
- The completion block calls `centerPDFContent`, which runs while PDFKit is still updating its internal scroll view. The result is a snap once the transition finishes.
- Both analysis tracks concluded that we need clearer feedback plus a guaranteed wait for PDFKit’s layout to settle before applying centering.
- Success will be measured by replaying the frame-capture workflow; any residual shake escalates us to Tier 2 (`usePageViewController`).

---

## Scope
1. Implement snapshot-fade transition and delayed centering in `Views/PDFViewer.swift`.
2. Add temporary debug logging around layout timing to validate the delay.
3. Document how to run verification captures.

No other behaviour (zoom gestures, metadata swipes, macOS build) should change.

---

## Implementation Steps

### Phase 0 – Preparation
1. Open `Views/PDFViewer.swift`.
2. Locate the `Coordinator` class and `swipeLeft` / `swipeRight` handlers (around lines 880–970).
3. Add a `pdfDebug` tag string constant near the top if missing; reuse existing `pdfDebug`.
4. Create an instance helper on `PDFKitView` (inside `#if os(iOS)` so macOS builds ignore it):
   ```swift
   private func snapshot(of pdfView: PDFView) -> UIImage?
   ```
   - Render `pdfView.layer` into a `UIGraphicsImageRenderer` with `format.scale = UIScreen.main.scale`.
   - Return the image; keep it `nil` safe.

### Phase 1 – Replace Cross-Dissolve With Snapshot Fade
1. In each swipe handler, remove the `UIView.transition` block.
2. Before changing the page:
   - Guard that `let snapshot = parent.snapshot(of: targetPDFView)` succeeds. If it fails, log a `pdfDebug("Snapshot unavailable, falling back to immediate transition")`, call the `goTo*Page` function straight away, and still schedule the delayed centering so we retain the layout fix.
   - Create an `UIImageView(frame: targetPDFView.bounds)` named `overlay`, assign the snapshot image, set `overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]`, and add it as a subview on top of the PDFView.
3. Animate the overlay using the shared constant (e.g. `snapshotFadeDuration`). The fade starts immediately so the user sees progress, while the delayed centering (Phase 2) occurs mid-fade when the overlay is already mostly transparent:
   ```swift
   UIView.animate(withDuration: snapshotFadeDuration, animations: {
       overlay.alpha = 0.0
   })
   ```
4. Immediately call the appropriate `goTo*Page` right after adding the overlay (outside the animation closure). This swaps the underlying PDF content while the snapshot fades out.

### Phase 2 – Deferred Centering
1. Right after `goTo*Page`, schedule centering with a short delay constant (e.g. `pdfLayoutSettleDelay`):
   ```swift
   DispatchQueue.main.asyncAfter(deadline: .now() + pdfLayoutSettleDelay) {
       self.parent.centerPDFContent(in: targetPDFView, coordinator: self)
   }
   ```
   - The PDFView should remain at alpha 1.0 the whole time; only the overlay fades.
   - Remove the existing call to `centerPDFContent` in the old completion block.
2. Remove the overlay inside the fade completion block to guarantee it is detached even if the delayed centering short-circuits. (By the time centering fires—≈60 ms in—the overlay is partially transparent but still present, which softens any final adjustment before it disappears at ~120 ms.)
3. Update `lastSwipeTime` after passing the `isAtFitZoom` guard but before capturing the snapshot. This keeps the debounce window tied to successfully accepted swipes.
4. Keep the existing haptic feedback firing at the same moment (right after the gesture is accepted) so tactile cues remain unchanged.

### Phase 3 – Temporary Logging
1. Inside `centerPDFContent`, add one log at the top:
   ```swift
   pdfDebug("centerPDFContent start: contentSize=\(scrollView.contentSize) offset=\(scrollView.contentOffset)")
   ```
2. Add another log immediately after computing `targetOffset`:
   ```swift
   pdfDebug("centerPDFContent target: \(targetOffset)")
   ```
3. In `SizeAwarePDFView.onLayout` callback (`handleLayout`), log `pdfView.bounds` and `scrollView.contentSize` on iOS so we can confirm when they stabilise. Keep these logs inside `#if DEBUG` or use `pdfDebug` (already DEBUG-only).
4. Do not add persistent analytics; this logging is temporary and can be removed once Tier 1 is validated.

### Phase 4 – Clean-Up Hooks
1. Ensure the overlay removal occurs on `DispatchQueue.main` to avoid UIKit threading warnings.
2. Verify gesture recognisers still return early when zoomed in (existing `isAtFitZoom` guard).
3. Confirm the `navigateToPage` path (`handleNavigation`) does not use the snapshot overlay; this Tier handles swipe gestures only.

---

## Verification Checklist
- [ ] Build succeeds on iOS (Debug).
- [ ] Swipe between pages at fit-to-screen zoom:
  - The previous page fades out quickly.
  - The new page is visible immediately underneath.
  - No lateral or vertical snap occurs after the fade completes.
- [ ] Swipe while zoomed in:
  - Gestures are ignored as before (since `isAtFitZoom` guard still applies).
- [ ] Run the original frame capture workflow (export simulator recording → `ffmpeg -i` to frames) and inspect frames 5–100 around a transition; the document should remain centered with no double movement.
- [ ] Review Xcode debug console for `pdfDebug` output to confirm layout settles before centering runs.

---

## Handoff Notes
- Keep the snapshot fade and delay constants (`0.12` seconds fade, `60 ms` delay) in file-level `private let` constants so we can tweak quickly after testing.
- Suggested naming: `private let snapshotFadeDuration: TimeInterval = 0.12` and `private let pdfLayoutSettleDelay: TimeInterval = 0.060`.
- Once Tier 1 is validated, remove the added logging. If shake persists, escalate to Tier 2 plan (enable `usePageViewController`) instead of further delay tuning.
- Document any observed residual motion in `docs/implementation-plans/archive/` so we have a paper trail when deciding on Tier 2.
- All new logic lives under the existing `#if os(iOS)` guards in the coordinator; macOS keyboard/scroll navigation remains untouched.
