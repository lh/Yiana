# macOS Copy/Cut/Paste Support Plan v4

**Status:** Ready for hand-off  
**Estimated Time:** 6–7 hours (single developer)  
**Priority:** High – Reach feature parity with iOS  
**Date:** October 2025  

---

## Overview

Goal: deliver full page cut/copy/paste support on macOS by upgrading the existing `DocumentViewModel` stub to use the iOS implementation patterns and wiring it to `NoteDocument`, so we reuse the clipboard service and UI that already work.

This roadmap assumes familiarity with SwiftUI, PDFKit, and the project structure described in `docs/PLAN.md`, but it avoids building new services or reimplementing clipboard logic.

---

## Anchor Points (Do Not Rebuild)
- **Clipboard logic:** `Services/PageClipboard.swift` already handles payload creation and validation. Import and call it; never duplicate clipboard code.
- **UI entry point:** `Views/PageManagementView.swift` exposes copy, cut, and paste actions and keyboard shortcuts. Honor its bindings and method signatures when updating the view model.
- **Persistence:** `Models/NoteDocument.swift` owns all macOS document read/write logic. Always propagate changes through it instead of writing files directly.
- **Reference implementation:** The iOS `DocumentViewModel` in the same file demonstrates autosave, metadata updates, undo, and save flows. Mirror its behavior, only adjusting to macOS requirements.

---

## Prerequisites
1. Build the macOS target once (`xcodebuild -scheme Yiana -destination 'platform=macOS' build`) to confirm a clean baseline.
2. Run the existing clipboard tests (`xcodebuild test -scheme Yiana -only-testing:YianaTests/PageClipboardTests`) so you know current behavior passes before edits.
3. Read the iOS `DocumentViewModel` section (`Yiana/Yiana/ViewModels/DocumentViewModel.swift:16`) to understand how autosave and metadata updates currently work.
4. Skim `PageManagementView` (`Yiana/Yiana/Views/PageManagementView.swift:420`) to see how it invokes `viewModel.cutPages` and `viewModel.insertPages`.

---

## Phase 1 — Replace macOS DocumentViewModel Stub (2–3 hours)
1. **Define structure:** Inside the `#else` block at `Yiana/Yiana/ViewModels/DocumentViewModel.swift:531`, replace the stub class with a full `@MainActor final class DocumentViewModel` that:
   - Declares `@Published` properties (`title`, `pdfData`, `isSaving`, `hasChanges`, `errorMessage`) mirroring the iOS version.
   - Stores `weak var document: NoteDocument?`, `autosaveTask`, and `autosaveDelay = 2.0`.
   - Exposes `documentID`, `displayPDFData`, `provisionalPageRange` (always `nil` for now), and `isReadOnly` using `FileManager.isWritableFile`.
2. **Initializers:**
   - Primary `init(document: NoteDocument)` to populate title, pdf data, and metadata; copy the logic that updates `document.metadata` when `title` or `pdfData` changes.
   - Secondary `init(pdfData:)` strictly for legacy test compatibility. Document in a comment that production code must call the primary initializer.
3. **Autosave:** Port `scheduleAutoSave()` from iOS, rename to `scheduleAutosave()` per plan, and ensure it:
   - Cancels any existing task.
   - Exits early unless `document?.autosavesInPlace == true` and `hasChanges` is true.
   - Sleeps for `autosaveDelay` seconds on the main actor, checks cancellation, then calls `await save()`.
4. **Save method:**
   - Update metadata (`modified`, `pageCount`) and assign `document.pdfData = pdfData`.
   - Invoke `document.save(to: document.fileURL, for: .forOverwriting, completionHandler:)`.
   - Reset `hasChanges`, propagate errors to `errorMessage`, and leave early if `document` or `hasChanges` is missing.
5. **Ensure all property setters (`title`, `pdfData`) mark `hasChanges` only when values actually change and call `scheduleAutosave()` afterward.

**Exit Criteria:** The macOS view model matches the iOS behavior feature-for-feature except for provisional pages and text-specific services.

---

## Phase 2 — Wire DocumentReadView to NoteDocument (1 hour)
1. **State management:** In `DocumentReadView` (`Yiana/Yiana/Views/DocumentReadView.swift`):
   - Replace the temporary `DocumentViewModel(pdfData:)` instance with `@State private var viewModel: DocumentViewModel?`.
   - When `loadDocument()` succeeds, instantiate `DocumentViewModel(document:)` on the main actor and assign to the state property.
2. **Bindings for PageManagementView:**
   - Inside the `.sheet` block, unwrap the view model and pass a binding to its `pdfData` (`Binding(get:set:)`), rather than the raw `pdfData` state.
   - Provide `viewModel.displayPDFData`, `viewModel.provisionalPageRange`, and `viewModel.documentID`.
   - Leave the existing fallback path for legacy/failed loads so the view still opens read-only PDFs.
3. **Error handling:** Ensure `errorMessage` and read-only fallback continue to work; do not remove legacy code paths.

**Exit Criteria:** All UI interactions now call the real view model, and the temporary macOS-only copy path is gone except for read-only files.

---

## Phase 3 — Implement Cut/Copy/Paste Operations (2 hours)
1. **Helper guard:** Add `ensureDocumentIsAvailable()` to the macOS view model to throw `PageOperationError.sourceDocumentUnavailable` or `.documentReadOnly` before any mutation.
2. **Reuse iOS logic:**
   - Port `removePages`, `copyPages`, `cutPages`, and `insertPages` from the iOS block (`DocumentViewModel.swift:320`), removing UIKit-only pieces.
   - Use `PDFDocument` APIs, sorting indices descending for removal, and wrap page insertion in `autoreleasepool {}` to minimize memory pressure.
3. **Undo integration:** Register undo operations on `document?.undoManager` before mutating:
   - Cut: store `sourceDataBeforeCut` and set action name `"Cut Pages"`.
   - Paste: capture the original `pdfData` and set action name `"Paste Pages"`.
4. **State updates:** After each operation, assign the new `pdfData`, mark `hasChanges`, and call `scheduleAutosave()`. Do not trigger manual saves elsewhere.

**Exit Criteria:** Page operations behave identically to iOS, including undo and clipboard payloads, with no new services introduced.

---

## Phase 4 — Surface Autosave & Read-Only Feedback (45 minutes)
1. **Read-only banner:** In `DocumentReadView`, show a lightweight banner (lock icon + message) when `viewModel?.isReadOnly == true`. Keep it non-blocking and scoped to the PDF view area.
2. **Save indicator:** Add a `ToolbarItem` that:
   - Shows a small `ProgressView` while `viewModel.isSaving` is true.
   - Shows an orange filled circle with “Unsaved changes” help text when `hasChanges` is true but not saving.
3. **No indicator when clean:** Hide both once `hasChanges` clears to avoid distraction.

**Exit Criteria:** Users receive immediate visual feedback about read-only state and save progress, matching the plan’s mock-up.

---

## Phase 5 — Menu Commands & Notifications (45 minutes)
1. **Command definitions:** Extend `YianaApp` (macOS only) with `.commands` that inserts “Copy Pages”, “Cut Pages”, and “Paste Pages” into `CommandGroup(after: .pasteboard)`. Use Option+Command shortcuts to avoid conflicting with text editing.
2. **Notifications:** Create `Notification.Name+PageOperations.swift` (under `Extensions/`) defining `.copyPages`, `.cutPages`, `.pastePages`.
3. **Hook into PageManagementView:** In the macOS-specific init or `onAppear`, subscribe to those notifications and forward them to `copyOrCutSelection(isCut:)` or `performPaste()`. Unsubscribe on disappear to avoid leaks.
4. **Clipboard availability:** Disable the Paste command when `PageClipboard.shared.hasPayload` is false so menu state mirrors UI availability.

**Exit Criteria:** Menu bar commands trigger the same paths as buttons, shortcuts match the spec, and there are no duplicated implementations.

---

## Phase 6 — Testing & Verification (1 hour)
1. **Unit tests:** Update or create macOS-only cases in `Yiana/YianaTests/DocumentViewModelPageOperationsTests.swift`:
   - `testCutPagesOnMacOS` ensures payload metadata, page removal, and `hasChanges`.
   - `testPastePagesOnMacOS` checks page insertion count and state updates.
   - `testSaveIntegrationOnMacOS` verifies `save()` updates `NoteDocument` metadata.
   - `testUndoRedoOnMacOS` exercises `cut` followed by undo/redo using the `undoManager`.
   Replace any “unsupported on macOS” expectations with real assertions.
2. **Test execution:** Run `xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentViewModelPageOperationsTests` locally after adding the tests.
3. **Manual QA Checklist:**
   - Copy pages between two documents.
   - Cut pages, paste elsewhere, undo, and redo.
   - Observe autosave indicator and verify it clears after the delay.
   - Open a read-only (locked) document and confirm banner plus blocked edits.
   - Validate Option+Command shortcuts in the menu.
   - Stress-test with a 100+ page PDF and repeat operations to watch for memory spikes.

**Exit Criteria:** Automated tests pass, manual checklist ticks off, and no regressions appear in unrelated suites.

---

## Risk & Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| Forgetting to use `NoteDocument` save APIs | High | Only mutate through the view model and call `document.save(...)`; code review should flag any direct file writes. |
| Missing undo registrations | Medium | Add unit test coverage for undo/redo and assert PDF data resets correctly. |
| Autosave race conditions | Medium | Keep `autosaveTask` scoped to the main actor and cancel before scheduling new saves. |
| Read-only state misdetected | Low | Cover with manual test on a locked file and guard paths through `ensureDocumentIsAvailable()`. |

---

## Rollback Strategy
1. Revert the macOS `DocumentViewModel` changes to the previous stub (preserving iOS code) if a critical regression appears.
2. Leave DocumentReadView UI polish in place; it is non-breaking even without cut/copy/paste support.
3. Document any regression findings in `docs/implementation-plans/mac-copy-paste-pages-plan-v4.md` for the next iteration.

---

## Post-Feature Follow-Ups
1. Add provisional text page support on macOS to mirror iOS (enables draft pages).
2. Implement extended selection behaviors (Shift-click, Select All).
3. Explore drag-and-drop between windows for multi-document workflows.
4. Profile large-document performance and consider background processing if needed.

---

## Sign-Off Checklist (Team Lead)
- [ ] Code review confirms reuse of shared services and zero clipboard duplication.
- [ ] Unit tests pass on CI and locally.
- [ ] Manual QA checklist completed on a macOS build.
- [ ] Documentation updated if menu shortcuts or UI change.
- [ ] Ready for release notes highlighting macOS feature parity.
