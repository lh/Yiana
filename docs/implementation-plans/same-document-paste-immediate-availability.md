# Same-Document Paste – Immediate Availability Fix

**Date:** 13 Oct 2025  
**Status:** Ready for implementation  
**Author:** Codex  
**Platforms:** iOS, iPadOS, macOS

---

## Problem
After landing the same-document paste support, users must close and reopen the page organiser before the **Paste** button enables. The clipboard payload exists, but the toolbar never re-evaluates `PageClipboard.shared.hasPayload` until the view is recreated.

---

## Root Cause

1. `PageManagementView` queries `PageClipboard.shared.hasPayload` directly inside the toolbar.  
2. For copy operations we leave `selectedPages` untouched and `cutPageIndices` stays `nil`, so no view state changes after `PageClipboard.shared.setPayload(payload)` completes.  
3. Without a state change SwiftUI does not re-render the toolbar, so the `.disabled(!PageClipboard.shared.hasPayload)` modifier continues to use the old value (`false`).  
4. Re-entering the organiser rebuilds the view, picks up the new clipboard state, and the button activates—hence the observed workaround.

---

## Solution Overview
Make the organiser react to clipboard updates explicitly:

1. Track clipboard state in `@State` inside `PageManagementView`.
2. Update that state whenever we set or clear the payload (copy, cut, paste, restore).
3. Optionally, hook `PageClipboard` to post a notification on any change so other views can stay in sync later.

This will cause SwiftUI to re-render immediately after a copy and enable the Paste button without exiting the sheet.

---

## Implementation Steps (est. 1.5 h)

### Step 1 – Introduce Clipboard State
- In `PageManagementView`, add:
  ```swift
  @State private var clipboardHasPayload = PageClipboard.shared.hasPayload
  ```
- Replace every `PageClipboard.shared.hasPayload` check in the toolbar with `clipboardHasPayload`.

### Step 2 – Update State on Operations
- After `PageClipboard.shared.setPayload(payload)` (inside `copyOrCutSelection`), set `clipboardHasPayload = true`.
- After `PageClipboard.shared.clear()` (paste with `.cut`, restore cut pages), set `clipboardHasPayload = PageClipboard.shared.hasPayload` (usually false, but defer to helper).
- When the organiser appears (`.onAppear { ... }`), refresh `clipboardHasPayload` in case the user copied elsewhere beforehand.

### Step 3 – Optional Notification Hook (future-safe)
- In `PageClipboard`, post `Notification.Name.pageClipboardDidChange` from `setPayload` and `clear`.
- In `PageManagementView`, add `.onReceive(NotificationCenter.default.publisher(for: .pageClipboardDidChange)) { _ in clipboardHasPayload = PageClipboard.shared.hasPayload }`.
- This guards against clipboard changes triggered outside the organiser (e.g., copy in a different window).

---

## Testing Checklist
- [ ] Copy pages, keep organiser open → Paste button enables immediately.
- [ ] Cut pages, Paste button enables (and clears after paste/restoration).
- [ ] Paste into same document multiple times without closing organiser.
- [ ] Cross-document copy/paste still works (clipboard state updates when entering organiser).
- [ ] macOS, iPadOS, iOS organisers all reflect clipboard changes instantly.

---

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| State falls out of sync with real pasteboard | Keep the optional notification hook; refresh `clipboardHasPayload` on `onAppear`. |
| Future refactors forget to update state | Encapsulate `setPayload`/`clear` calls in helper methods inside `PageManagementView`. |

---

Implementing the state update removes the need to reopen the organiser and aligns behaviour with user expectations of the clipboard.***
