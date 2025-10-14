# macOS Sidebar Refresh & Page Manager Sync Plan

**Status:** Ready for implementation  
**Priority:** High – page edits appear inconsistent  
**Date:** 12 Oct 2025  

---

## Overview

When macOS users double-click a thumbnail in the sidebar, we open `PageManagementView`, but any deletions or reorders made there do not reliably update the thumbnail strip afterward. The current implementation also leaves the sidebar visible behind the sheet, so there is no visual cue that its contents are stale. This plan tightens the data flow between `DocumentReadView`, `MacPDFViewer`, and `PageManagementView` so that:

1. Page edits immediately propagate to the sidebar thumbnails.
2. Entering the page organiser hides the sidebar to avoid conflicting affordances.
3. Leaving the organiser (via the new **Done** button) restores the sidebar and forces a refresh.

---

## Current Behaviour

- `MacPDFViewer` owns its own `@State` copy of the PDF (`Yiana/Yiana/Views/MacPDFViewer.swift:12-19`), updating it only via `.onChange(of: pdfData)` (`Yiana/Yiana/Views/MacPDFViewer.swift:188-198`).
- `DocumentReadView` feeds `MacPDFViewer` a value copy of `viewModel?.pdfData ?? pdfData` (`Yiana/Yiana/Views/DocumentReadView.swift:120-125`).
- `PageManagementView` writes back through a binding, but `MacPDFViewer` does not observe `DocumentViewModel` directly, so updates depend on the parent forwarding the data.
- The sidebar remains visible while the organiser sheet is up, so users expect it to reflect edits immediately.
- When the sheet dismisses, the sidebar often keeps the previous page order until the document is re-opened.

---

## Root Causes

1. **Stale Thumbnail State**: `MacPDFViewer` caches a `PDFDocument` (`@State private var pdfDocument`) that only refreshes when the `pdfData` value changes. Because we pass an immutable `Data` copy instead of observing the view model, SwiftUI sometimes reuses the existing state and the `onChange` never fires.
2. **No Refresh Signal on Dismiss**: `PageManagementView` simply sets `isPresented = false` (`Yiana/Yiana/Views/PageManagementView.swift:72-80`), so the parent has no hook to force a thumbnail rebuild when the organiser closes.
3. **Sidebar Visibility**: Double-clicking a thumbnail launches the organiser (`Yiana/Yiana/Views/MacPDFViewer.swift:36-43`), but we never hide the sidebar or remember to restore it when done. This leaves the stale thumbnails on-screen and masks whether a refresh occurred.

---

## Implementation Plan

### Phase 1: Make `MacPDFViewer` Observe the View Model (1.5 h)
1. Change the initializer to accept `@ObservedObject var viewModel: DocumentViewModel` instead of a raw `Data` blob. Keep an optional `legacyData` parameter for read-only fallbacks.
2. Replace the local `pdfData` with computed accessors that return `viewModel.displayPDFData ?? viewModel.pdfData` (fall back to `legacyData` only when the view model is absent).
3. Remove the cached `@State private var pdfDocument` and rebuild it directly from the latest data each render, or store it in `@StateObject` tied to `viewModel.documentID` so it regenerates when data changes.
4. Drive the thumbnail list off a lightweight `ThumbnailModel` derived from `viewModel.pdfData`, ensuring new data triggers `objectWillChange` updates automatically.
5. Expose a `refreshTrigger` parameter (UUID) that the parent can bump to force regeneration if needed (used later in Phase 3).

### Phase 2: Centralise Sidebar Visibility (1 h)
1. Promote sidebar visibility into `DocumentReadView` by adding `@State private var isSidebarVisible = true`.
2. Pass a `Binding<Bool>` into `MacPDFViewer` so the parent controls visibility; remove the internal `@State private var showingSidebar`.
3. When `onRequestPageManagement` is invoked (double-click), stash the previous sidebar state and set `isSidebarVisible = false` before presenting the sheet.

### Phase 3: Refresh on Organiser Dismiss (1 h)
1. Extend `PageManagementView` with an optional `onDismiss` closure that fires from the Done button and whenever the sheet programmatically closes.
2. In `DocumentReadView`, supply an `onDismiss` that:
   - Restores `isSidebarVisible` if it was hidden for organiser mode.
   - Updates a new `@State private var sidebarRefreshID = UUID()` that is passed to `MacPDFViewer` (Phase 1) to rebuild thumbnails.
   - Optionally calls a `viewModel.reloadPDFData()` helper (added to the macOS `DocumentViewModel`) to ensure `pdfData` and `displayPDFData` are in sync with `NoteDocument`.

### Phase 4: Update Mac Sidebar Commands (30 min)
1. Disable double-click navigation while the organiser is open by guarding `onTapGesture(count: 1)` when `isSidebarVisible` is false, so users cannot trigger conflicting actions.
2. Consider showing a subtle “Editing pages…” overlay (greyed out sidebar) to signal the sidebar will refresh on exit.

### Phase 5: Testing & Verification (1 h)
1. Add a focused unit test that simulates `viewModel.pdfData` changes and asserts `MacPDFViewer` rebuilds its thumbnail count when the refresh ID changes.
2. Manual QA:
   - Double-click thumbnail → organiser opens, sidebar hides.
   - Delete/reorder pages, press Done → sidebar reappears with new order.
   - Cut/paste pages repeatedly; confirm thumbnails stay in sync.
   - Verify read-only documents still open and the organiser refuses edits.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Thumbnail regeneration becomes expensive for large PDFs | Build thumbnails lazily (current behaviour) and throttle refreshes by only bumping `sidebarRefreshID` when the organiser actually modified pages. |
| Legacy read-only PDFs (without a `DocumentViewModel`) lose sidebar updates | Keep an optional `legacyData` path so `MacPDFViewer` can still render static PDFs without the view model. |
| Sidebar visibility state gets out of sync (e.g., organiser dismissed via Escape) | Fire the same `onDismiss` closure from `.onChange(of: isPresented)` to ensure all dismissal paths restore visibility and refresh. |

---

## Follow-Up Opportunities

- Animate sidebar hide/show to make the transition clearer.
- Surface a toast when pages have unsaved changes (leveraging the existing `viewModel.hasChanges` flag).
- Once this flow is stable, port the same organiser-dismiss refresh hook to iOS/iPadOS so both platforms share behaviour.  

This plan should eliminate the stale sidebar issue and align the macOS UX with the new organiser workflow. Once complete, rerun the macOS page operation tests to confirm no regressions in `DocumentViewModel` behaviour.***
