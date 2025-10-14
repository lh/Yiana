# Copy/Cut/Paste Pages Between Documents – Internal Plan

**Status:** Parked until post-MVP  
**Primary Goals**
- Allow users to copy or cut selected pages in the sorter and paste them into another document.
- Keep implementation additive (no format changes, no new sync surface).

---

## External Review Recap

The outside plan (see `comments/2025-10-12-copy-pages-between-documents.md`) surfaces a number of useful points:

- ✅ **Serialise pages as a temporary PDF** – re-using `PDFDocument.dataRepresentation()` is the simplest and most durable payload.
- ✅ **Keep selection logic in `PageManagementView`** – the current `selectedPages` state is sufficient.
- ✅ **Pasteboard-based transfer** – `NSPasteboard`/`UIPasteboard` provide cross-document transport with no shared app state.
- ⚠️ **Missing metadata** – we still need to know whether the payload came from a cut operation, and which document it originated from if we want optimistic removal/undo.
- ⚠️ **Cut semantics** – immediate removal risks data loss if the paste never happens. We should either (a) keep pages hidden until paste completes, or (b) leave the source untouched and rely on `removePages` after paste succeeds.

Overall: the suggested approach is sound, but we will add a lightweight metadata wrapper so we can track cut vs copy without relying solely on clipboard state.

---

## Proposed Approach

### 1. Payload Format

- Create a small `PageClipboardPayload` struct:
  ```swift
  struct PageClipboardPayload: Codable {
      let sourceDocumentID: UUID?
      let operation: Operation // .copy or .cut
      let pdfData: Data
      let pageCount: Int
      let createdAt: Date
  }
  ```
- Payload is archived as `Data` and written to:
  - macOS: `NSPasteboard.general` under custom UTI `com.vitygas.yiana.pages`
  - iOS: `UIPasteboard.general` with the same UTI (fallback to `public.data` for compatibility)
- Maintain an in-process cache (`PageClipboard.shared`) so we can recover the payload even if the system pasteboard is cleared (useful for “Restore Cut Pages”).

### 2. ViewModel Extensions

`DocumentViewModel` gains:

```swift
func extractPages(at indices: [Int]) throws -> Data
func insertPages(from data: Data, at index: Int?) async throws
```

- Extraction builds a temporary `PDFDocument`, copies the selected pages, and returns `dataRepresentation()`.
- Insertion converts the incoming data back into `PDFDocument`, inserts pages at the requested index (defaults to end), updates `pdfData`, `displayPDFData`, `pageCount`, and `modified`.

### 3. Pasteboard Manager

`PageClipboard` coordinator (shared between platforms) handles:
- Setting/reading the clipboard payload.
- Tracking cut operations (so we can remove or restore the source pages once paste is confirmed).
- Exposing convenience flags (`canPaste`, `isCutPayload`, etc.) for UI enable/disable.

### 4. UI Integration (PageManagementView)

- Add Copy, Cut, Paste buttons (toolbar on macOS, bottom toolbar/contextual menu on iOS).
- Keyboard shortcuts on macOS (`⌘C`, `⌘X`, `⌘V`) via `.commands`.
- Paste inserts pages after the last selected destination page (or at the end if nothing selected).
- When pasting a cut payload, remove the pages from the source document **after** successful insertion; if paste fails or clipboard is cleared, provide “Undo Cut” from the clipboard cache.

### 5. Save & OCR Behaviour

- After paste, the destination document will automatically be marked dirty (`modified` timestamp). OCR service will treat the updated document as new, so the pasted pages gain OCR metadata naturally.
- Source document removal (cut) already flows through existing `removePages`.

---

## Edge Cases & Handling

| Scenario | Handling |
| --- | --- |
| Clipboard overwritten before paste | Paste button disabled; for cut, show “Restore Cut Pages” action from cached payload. |
| Multiple paste operations from same payload | Allow (copy semantics); for cut we mark payload as “consumed” after first paste. |
| Large selections (>50 pages) | Show confirmation; optionally split into chunks to avoid memory spikes. |
| Pasting into same document | Works (insert after last selected page or append). Avoid double-removals by checking document ID. |
| App backgrounded | Clipboard stays valid; we rely on cached payload if the OS clears it. |

---

## Implementation Steps (When Scheduled)

1. **Scaffolding**
   - Add `PageClipboardPayload` and `PageClipboard`.
   - Add custom UTI strings to shared constants.
2. **ViewModel updates**
   - Implement `extractPages` / `insertPages`.
   - Ensure metadata (`modified`, `pageCount`) updates correctly.
3. **UI changes**
   - Add Copy/Cut/Paste buttons, shortcuts, and state handling in `PageManagementView`.
   - Provide paste insertion UI (e.g., highlight drop position or use context menu).
4. **Cut workflow**
   - Defer removal until paste completes.
   - Add “Restore Cut Pages” command driven by cached payload.
5. **Testing**
   - Same-document copy/paste.
   - Cross-document copy/paste (macOS & iPad).
   - Cut + abort scenario (restore works).
   - Clipboard overwritten scenario.
   - Large page selections.

Estimated effort remains similar to the external review (≈2 days), but staged so we can land copy/paste first and enable cut later if we need more polish.

---

## Future Enhancements (Optional)

- Drag-and-drop between document windows on macOS.
- Support pasting pages from external PDFs (basic PDF import).
- Show source document and page count in a paste preview tooltip.
- Log analytics (count of pasted pages, frequency of cut vs copy) once we release the feature.

---

## Decision

Defer implementation until after MVP. When we pick it up, follow the plan above (PDF payload with metadata, `PageClipboard` manager, additive UI changes). No foundational refactor is required; changes live entirely in `PageManagementView`, `DocumentViewModel`, and a small shared pasteboard helper. ***
