# Same-Document Page Paste – Implementation Plan v2

**Date:** 13 Oct 2025  
**Status:** Ready for implementation  
**Author:** Codex review  
**Scope:** iOS, iPadOS, macOS

---

## Summary
Users cannot reliably paste pages back into the document they were copied or cut from. This affects all platforms and blocks straightforward duplication or intra-document moves. The goal is to allow:

- Copy → Paste within the same document (duplicates pages).
- Cut → Paste within the same document (moves pages to the target location).

We must fix the underlying behaviour, add regression tests, and keep cross-document behaviour unchanged.

---

## Current Behaviour (Code Review)
- `PageManagementView.performPaste` (`Yiana/Yiana/Views/PageManagementView.swift:515`) always calls `viewModel.insertPages` with the payload, then clears the clipboard when the payload came from a `.cut`.
- `DocumentViewModel.insertPages` (iOS implementation around `Yiana/Yiana/ViewModels/DocumentViewModel.swift:320`, macOS around `:744`) blindly merges `payload.pdfData` into the current document. It never looks at `payload.operation` or `payload.sourceDocumentID`, so it behaves the same whether we are pasting back into the source document or into a different one.
- `PageClipboardPayload` already carries everything we need (`sourceDocumentID`, `operation`, `cutIndices`, `sourceDataBeforeCut`).

Because we do not special-case same-document operations:
1. **Copy + Paste** often appears to do nothing: the paste happens at the end of the document, far away from the original selection. Users assume paste failed.
2. **Cut + Paste** re-inserts the removed pages at the target index, but we do not compensate for the indices that already shifted. Moving a page “down” often lands one position early.
3. We have no tests covering these scenarios, so regressions slip through.

---

## Implementation Plan

### Phase 0 – Establish Failing Coverage (1–2 h)
1. **Add unit tests** in `Yiana/YianaTests/DocumentViewModelPageOperationsTests.swift` for both platforms:
   - `testCopyPasteWithinSameDocument_appendsAtTargetIndex`.
   - `testCutPasteWithinSameDocument_movesPages`.
   - `testPasteKeepsClipboardForCopy`.
2. Each test should:
   - Build a `PageClipboardPayload` via the real `copyPages/cutPages` API.
   - Call `insertPages` (or the updated helper) with an explicit insert index (e.g., front, middle, end).
   - Assert on resulting page order using `PDFDocument` introspection.
3. Run `xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentViewModelPageOperationsTests`. Tests must fail to confirm reproductions before coding.

### Phase 1 – Teach `DocumentViewModel` About Same-Document Moves (3 h)
Apply the changes separately inside the iOS and macOS `DocumentViewModel` definitions.

1. **Add a helper** method (shared signature between platforms):
   ```swift
   private func movePagesWithinDocument(
       cutIndices: [Int],
       insertIndex: Int
   ) async throws -> Int
   ```
   - Rebuild the `PDFDocument` from `pdfData`.
   - Capture the pages at `cutIndices` (ascending order) into a temporary array.
   - Remove those pages in reverse order.
   - Adjust `insertIndex` by subtracting `count(indices < insertIndex)` so the target location is correct after removal.
   - Insert the stored pages at the adjusted index, preserving order.
   - Update `pdfData`, metadata (`pageCount`, `modified`), call `scheduleAutoSave()`, and return the number of pages moved.
   - Register undo using `document.undoManager` the same way `insertPages` currently does.

2. **Update `insertPages`**:
   ```swift
   if payload.operation == .cut,
      payload.sourceDocumentID == documentID,
      let cutIndices = payload.cutIndices {
       return try await movePagesWithinDocument(
           cutIndices: cutIndices,
           insertIndex: insertIndex ?? targetPDF.pageCount
       )
   }
   ```
   - Leave the existing code path unchanged for all other cases (copy within same document still uses `payload.pdfData`, cross-document paste behaves as today).

3. **For copy/paste UX**: ensure we *do not* clear the clipboard for `.copy`. The current code already does this; keep it that way to allow repeated duplicates.

### Phase 2 – Improve `PageManagementView` UX (2 h)
1. When the user hits **Paste**, choose an insertion index that matches their current selection:
   - If pages are selected, insert right after the last selected index.
   - Otherwise, fall back to `pages.count` (append).
   - Implement helper:
     ```swift
     private func defaultPasteDestination() -> Int {
         guard let maxSelected = selectedPages.max() else { return pages.count }
         return min(maxSelected + 1, pages.count)
     }
     ```
   - Use `defaultPasteDestination()` in `performPaste` when `insertIndex` is nil.

2. For clarity, show a temporary toast or include in the alert message when paste finishes: “Duplicated 2 pages at position 5.”

3. Preserve the existing “Restore Cut” flow (it now becomes a fallback if the user wants to undo after moving the pages).

### Phase 3 – Tests & Cross-Platform Verification (1.5 h)
1. Extend the new tests to the macOS block (same file) to cover the mac-specific view model.
2. Add UI automation steps (optional quick smoke) to `Yiana/YianaUITests` that:
   - Copy a page, open paste, and assert new page count.
   - Cut a page, paste after another, check order.
3. Manual QA checklist:
   - Duplicate a page on macOS/iPadOS/iOS (ensure paste appears near the selection).
   - Move pages via cut/paste (drag alternatives should still work).
   - Undo/redo after move and duplicate.
   - Copy from Doc A and paste into Doc B (unchanged).

---

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Miscomputing adjusted insert index for cut/paste | Pages land in wrong order | Rely on tests covering insert before/after the original selection; validate with complex selections (non-contiguous indices). |
| Undo stack regression | High | Register undo around `movePagesWithinDocument`; add a unit test asserting undo restores original order. |
| Performance for large selections | Medium | Use `autoreleasepool` when copying pages (mirror existing `insertPages` loop). |
| macOS/iOS drift | Medium | Make identical updates on both platform-specific view models and run the shared tests under both `#if` branches. |

---

## Deliverables
1. Updated `DocumentViewModel` for iOS and macOS with the new move logic.
2. Enhanced `PageManagementView` default insertion logic.
3. New unit tests (copy/cut same-document scenarios).
4. Optional: release notes update explaining that duplicate/move via paste is now supported explicitly.

Once all tests pass locally, run the full suite:
```
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme Yiana -destination 'platform=macOS'
```
and attach results when you raise the PR.***
