# macOS Copy/Cut/Paste Support Plan

**Status:** Draft – awaiting scheduling

**Goal:** Enable the same page copy/cut/paste workflow that now exists on iOS to function in the macOS app. Today the mac build is read-only: it can copy pages (because the new payload helper reads the PDF data) but `cut` and `paste` throw errors. This plan describes the minimal set of changes required to make mac documents editable while staying consistent with the iOS implementation.

---

## 1. Current State & Gaps

| Area | iOS (works) | macOS (current) |
| --- | --- | --- |
| `DocumentViewModel` | Full implementation (mutations, autosave, provisional pages) | Stub (copy only, `cut`/`paste` throw errors) |
| UI entry point | `DocumentEditView` presents `PageManagementView` and saves changes | `DocumentReadView` is a viewer; still passes old bindings |
| Document layer | `NoteDocument` (UIDocument) returns/accepts PDF data | `NoteDocument` (NSDocument) already reads/writes but the view-model doesn’t call it |
| Clipboard pipeline | Shared via `PageClipboard` | Same pipeline available, but no writer |
| Tests | Coverage in `PageClipboardTests` and `DocumentViewModelPageOperationsTests` | No mac-specific coverage |

Key issues:
1. mac `DocumentViewModel` must grow equivalent mutation APIs (`pdfData` updates, metadata updates, save support).
2. `DocumentReadView` needs to instantiate and keep a mac-capable view-model and present `PageManagementView(viewModel: …)` as iOS does.
3. Saving on mac must go through `NoteDocument` (NSDocument) so iCloud/local edits persist.
4. We need a strategy for documents opened read-only (file locked, network share).

---

## 2. Proposed Architecture

### 2.1 Shared Core
- Extract common copy/cut/paste logic into extensions that compile for both platforms.
- Keep platform-specific pieces (`UIDocument` vs `NSDocument`, autosave triggers) protected behind `#if os(iOS)` / `#if os(macOS)` blocks.
- Ensure the mac view-model publishes `@Published var pdfData` and `displayPDFData` just like iOS so SwiftUI bindings stay aligned.

### 2.2 mac DocumentViewModel Roadmap
1. Construct the view-model with a `NoteDocument` (NSDocument) instance.
2. Mirror the methods introduced on iOS:
   - `copyPages(atZeroBasedIndices:)`
   - `cutPages(atZeroBasedIndices:)` (removes pages and marks `hasChanges`)
   - `insertPages(from:at:)`
   - `ensureDocumentIsAvailable()` (for mac check `.isLocked`, `.fileModificationDate` etc.)
3. Hook `save()` to call `noteDocument.save(to:for:completionHandler:)` so edits persist.
4. Manage undo by plugging into `document.undoManager` if feasible (optional nice-to-have).

### 2.3 DocumentReadView Changes
- Instantiate `DocumentViewModel(document: NoteDocument)` when the mac reader opens a file.
- Present `PageManagementView(viewModel: viewModel, …)` behind a toolbar/command (same sheet approach iOS uses).
- Provide UI for copy/cut/paste commands (menu items + keyboard shortcuts).
- Display alerts when operations fail (leverage the view-model errors).

### 2.4 File Access / iCloud Safety
- NSDocument already coordinates file access. Ensure we call `noteDocument.performAsynchronousFileAccess` when writing large updates to avoid UI stalls.
- Decide what to do if the document is locked (present a read-only banner and disable cut/paste commands).

---

## 3. Implementation Steps

1. **Reconcile the ViewModel**
   - Move the shared logic in `DocumentViewModel.swift` into a base extension group (no functional changes for iOS).
   - Replace the mac stub with a full-featured class:
     ```swift
     #if os(macOS)
     final class DocumentViewModel: ObservableObject {
         @Published var pdfData: Data?
         @Published private(set) var displayPDFData: Data?
         private let noteDocument: NoteDocument
         // … copy/cut/paste methods mirroring iOS …
     }
     #endif
     ```
   - Implement `save()` to call `noteDocument.save(to:for:completionHandler:)` and update metadata.

2. **Update DocumentReadView**
   - Store `@StateObject private var viewModel: DocumentViewModel`.
   - Replace manual PDF handling with bindings to the view-model (similar to iOS `DocumentEditView`).
   - Add toolbar button “Manage Pages…” which sets `activeSheet = .pageManagement`.

3. **Wire PageManagementView**
   - Ensure the initializer under mac builds has `viewModel: DocumentViewModel`. The existing sheet call now passes the mac view-model.
   - Enable copy/cut/paste buttons (the shared SwiftUI already handles both platforms).

4. **Clipboard + Undo**
   - For cut operations, store `sourceDataBeforeCut` and expose “Restore Cut” in a small `Alert`/banner until paste occurs.
   - Optional: integrate with mac Undo (nice if time permits).

5. **Saving & Autosave**
   - On mac we rely on manual save/auto-save. After paste or cut, mark `hasChanges = true` and call `scheduleAutoSave()` equivalent.
   - If autosave is disabled (user preference), surface a “Unsaved Changes” indicator.

6. **Read-Only Handling**
   - If the file is marked read-only (no write permission), disable cut/paste UI and show “This document is opened read-only” message.

7. **Testing**
   - Add unit tests covering mac-specific view-model operations (guard with `#if os(macOS)`).
   - Create a UI test that opens a sample mac document, runs through copy/paste, and verifies page count.

---

## 4. Effort & Risk

- **Effort:** Medium. Most logic already exists; the work is in plumbing mac `DocumentViewModel` and saving.
- **Risks:**
  1. NSDocument save conflicts when multiple windows edit the same file.
  2. Clipboard operations must not clobber real clipboard data inadvertently.
  3. Read-only vs writable detection needs to be robust so we don’t promise edits that can’t be saved.

Mitigations: rely on NSDocument’s built-in conflict resolution, test with iCloud docs, provide clear UI messaging for read-only cases.

---

## 5. Deliverables Checklist

- [ ] Shared cut/copy/paste logic usable on mac.
- [ ] mac `DocumentViewModel` can mutate and save PDF/metadata.
- [ ] `DocumentReadView` offers the page management sheet.
- [ ] Cut/copy/paste commands active only when permissions allow.
- [ ] Automated tests (unit + basic UI) for mac path.
- [ ] Documentation/release note noting mac now supports editing pages.

Once this plan is approved we can break it into two PRs: (1) refactor view-model/common logic, (2) UI integration + tests.
