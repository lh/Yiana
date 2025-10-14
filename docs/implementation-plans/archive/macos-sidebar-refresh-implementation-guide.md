# macOS Sidebar Refresh – Implementation Guide

**Status:** Ready for development  
**Audience:** Junior developer  
**Date:** 12 Oct 2025  

---

## Goal

Fix the macOS document reader so page edits performed in the organiser (copy/cut/paste/reorder/delete) immediately refresh the thumbnail sidebar, and the sidebar hides while the organiser is visible. The final behaviour should match this flow:

1. User double-clicks a thumbnail → organiser opens and sidebar hides.
2. User edits pages and presses **Done** → organiser closes, sidebar reappears, thumbnails show the new order.

This guide walks you through the required code changes step-by-step.

---

## Key Files

- `Yiana/Yiana/Views/DocumentReadView.swift`
- `Yiana/Yiana/Views/MacPDFViewer.swift`
- `Yiana/Yiana/Views/PageManagementView.swift`
- `Yiana/Yiana/ViewModels/DocumentViewModel.swift` (for any helper methods if needed)

---

## Phase 1 – Update `MacPDFViewer` to Observe the View Model

### 1.1 Change the API
- Modify `MacPDFViewer` so it receives the macOS `DocumentViewModel` instead of a raw `Data`.
    ```swift
    struct MacPDFViewer: View {
        @ObservedObject var viewModel: DocumentViewModel
        var legacyPDFData: Data? = nil  // optional fallback
        @Binding var isSidebarVisible: Bool
        var refreshTrigger: UUID  // force rebuild when changed
        ...
    }
    ```
- Remove the existing `let pdfData: Data` property.

### 1.2 Provide a Computed PDF
- Replace uses of the old `pdfData` with something like:
    ```swift
    private var currentPDFData: Data? {
        viewModel.displayPDFData ?? viewModel.pdfData ?? legacyPDFData
    }
    ```

### 1.3 Rebuild the Thumbnail Source When Data Changes
- Remove the cached `@State private var pdfDocument`. Instead, compute the `PDFDocument` inside the view body (or store it in `@State` keyed by `refreshTrigger`).
    ```swift
    @State private var pdfDocument: PDFDocument?
    
    .onChange(of: refreshTrigger) { _ in
        resetPDFDocument()
    }
    .onChange(of: currentPDFData) { _, _ in
        resetPDFDocument()
    }
    
    private func resetPDFDocument() {
        guard let data = currentPDFData, let doc = PDFDocument(data: data) else {
            pdfDocument = nil
            return
        }
        pdfDocument = doc
    }
    ```
- Call `resetPDFDocument()` in `.task` so the initial render has a document. The `refreshTrigger` lets the parent force a rebuild even if the data bytes are the same.

### 1.4 Replace Local Sidebar State
- Remove the internal `@State private var showingSidebar = true`. Use the injected `isSidebarVisible` binding to control visibility.
- Where the previous toggle button flipped `showingSidebar`, change it to update `isSidebarVisible`.

### 1.5 Guard Thumbnail Taps When Hidden
- Wrap single-click and double-click handlers with `guard isSidebarVisible else { return }` so gestures ignore hidden state.

---

## Phase 2 – Manage Sidebar Visibility in `DocumentReadView`

### 2.1 Track Sidebar State and Refresh Trigger
- Add to the macOS view:
    ```swift
    @State private var isSidebarVisible = true
    @State private var sidebarWasVisibleBeforeOrganiser = true
    @State private var sidebarRefreshID = UUID()
    ```

### 2.2 Pass Bindings to `MacPDFViewer`
- Update the instantiation to:
    ```swift
    MacPDFViewer(
        viewModel: viewModel,
        legacyPDFData: pdfData,
        isSidebarVisible: $isSidebarVisible,
        refreshTrigger: sidebarRefreshID
    )
    ```

### 2.3 Hook the Organiser Presentation
- When setting `showingPageManagement = true`, stash the current sidebar state and hide it:
    ```swift
    sidebarWasVisibleBeforeOrganiser = isSidebarVisible
    isSidebarVisible = false
    showingPageManagement = true
    ```
- Do this both in the toolbar button and inside `onRequestPageManagement` passed to `MacPDFViewer`.

---

## Phase 3 – Add an `onDismiss` Callback to `PageManagementView`

### 3.1 Extend the View
- Modify the signature to include an optional closure:
    ```swift
    var onDismiss: (() -> Void)? = nil
    ```
- Call `onDismiss?()` whenever the organiser closes:
    - Inside the Done button’s action (before setting `isPresented = false`).
    - In an `.onChange(of: isPresented)` handler when it transitions to `false` (covers Escape key, programmatic close).

### 3.2 Use the Callback in `DocumentReadView`
- Pass a closure that restores the sidebar and bumps the refresh ID:
    ```swift
    PageManagementView(
        ...,
        onDismiss: {
            isSidebarVisible = sidebarWasVisibleBeforeOrganiser
            sidebarRefreshID = UUID()
        }
    )
    ```
- After refreshing, optional: call `Task { await viewModel.save() }` or trigger `viewModel.pdfData = viewModel.pdfData` if we need to re-sync metadata (not always required).

---

## Phase 4 – Optional Enhancements

1. **Visual Cue:** While the organiser is open, render the sidebar with `.opacity(0.3)` and `.allowsHitTesting(false)` so users know it’s inactive.
2. **Command Handling:** Disable menu shortcuts (`Copy Pages`, etc.) while the sidebar is hidden by checking `isSidebarVisible` inside `MacPDFViewer`.

---

## Testing Checklist

- [ ] Double-click thumbnail → organiser opens, sidebar hides.
- [ ] Delete/reorder pages, click Done → organiser closes, sidebar reappears with new order.
- [ ] Cut/paste multiple times; confirm thumbnails stay in sync.
- [ ] Escape key inside organiser closes it and triggers the same refresh.
- [ ] Opening a read-only document keeps the sidebar visible, organiser stays read-only (no crash).
- [ ] Existing macOS unit tests (`xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentViewModelPageOperationsTests`) still pass.

---

## Gotchas & Tips

- **Avoid `id(viewModel.pdfData)`**: large PDFs are expensive to hash. Use the separate `sidebarRefreshID` instead.
- **Be careful with `@State` vs `@Binding`:** after moving visibility into `DocumentReadView`, remove the old `showingSidebar` state to prevent desync.
- **Legacy PDFs:** When no view model is available (legacy read-only flow), continue to pass the raw data through the `legacyPDFData` parameter and set `isSidebarVisible` to `true`.
- **Logging:** While testing, add prints inside the organiser’s `onDismiss` to verify the refresh closure runs for every exit path.

Follow these steps and commit in logical chunks (one per phase) so code review is straightforward. Reach out if anything is unclear before editing the shared view model.***
