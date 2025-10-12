# macOS Copy/Cut/Paste Implementation — Code Review Notes

**Date:** 12 Oct 2025  
**Reviewer:** Codex (GPT-5)  
**Scope:** Changes on `feature/page-copy-paste` enabling macOS page transfer support.

---

## Key Findings
- **Blocked page updates in reader UI:** `DocumentReadView` still feeds the main `MacPDFViewer` from the local `@State pdfData` (`Yiana/Yiana/Views/DocumentReadView.swift:119`), while the sheet now mutates `viewModel.pdfData` (`Yiana/Yiana/Views/DocumentReadView.swift:169-176`). No observer syncs the two, so post-cut/paste the primary reader continues rendering the pre-edit PDF.
- **NSDocument save type mismatch:** macOS `DocumentViewModel.save()` calls `document.save(to:ofType:for:)` with `"com.vitygas.yianazip"` (`Yiana/Yiana/ViewModels/DocumentViewModel.swift:625`). The project’s declared document type is `UTType.yianaDocument.identifier` (`com.vitygas.yiana.document`), so the save can throw and surface “Failed to save” errors.
- **Clipboard clearing nukes everything:** `PageClipboard.clear()` clears the entire macOS pasteboard whenever we discard a cut payload (`Yiana/Yiana/Services/PageClipboard.swift:156-195`). If a user copies text after cutting pages, pasting pages will unexpectedly erase that unrelated clipboard entry.
- **Tests only certify legacy macOS stub:** `DocumentViewModelPageOperationsMacOSTests` still instantiate the read-only initializer, so the new document-backed flow has zero coverage. A regression like the missing sync above would pass the suite unnoticed.

---

## Suggested Fixes
1. Bind the reader view to the live model (`viewModel.$pdfData` or `displayPDFData`) so edits are reflected immediately, and keep the legacy fallback for raw PDFs.
2. Use `document.fileType ?? UTType.yianaDocument.identifier` (or `NoteDocument.readableTypes`) in the macOS save call, and return `true` when no changes need saving to match the iOS semantics.
3. Replace the macOS clipboard clearing with `pasteboard.setData(Data(), forType:)` so we touch only our custom UTI; keep the in-memory payload clearing as-is.
4. Add macOS tests that run against `DocumentViewModel(document:)`, covering cut, paste, undo, and save to guard against regressions in the new path.

---

## What Went Well
- Reused the iOS logic for operations and undo rather than reimplementing it.
- DocumentReadView now holds onto the real `NoteDocument`, unlocking save/undo once the sync issue is fixed.
- Menu command wiring and read-only banner deliver the planned UX improvements.

---

## Follow-Up
- Address the blockers above, then re-run `xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentViewModelPageOperationsTests`.
- Once the new tests are in place, expand manual smoke testing (cut/copy between multiple windows, autosave timing, pasteboard behaviour after cross-app copies).
