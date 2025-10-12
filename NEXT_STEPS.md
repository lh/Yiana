# Next Steps: Copy/Paste Pages Between Documents

**Branch:** `feature/page-copy-paste`
**Status:** ✅ IMPLEMENTED
**Actual Time:** ~8 hours

---

## Current Implementation Plan

The detailed implementation plan is available at:
- `comments/2025-10-12-copy-pages-between-documents.md` (comprehensive analysis)
- `docs/nice-to-have/copy-pages-between-documents-plan.md` (concise plan)

## Feature Overview

**User Story:**
> "I can select one or several page(s) in the sorter (PageManagementView), copy or cut, and then paste into a new document via its sorter."

## Key Points

✅ **No major refactor required** - existing architecture supports this feature well

### What Works in Our Favor:
- PDFPage copying already implemented and used throughout codebase
- Page selection infrastructure exists in PageManagementView
- Pasteboard APIs available on iOS/macOS
- Clean document architecture (UIDocument/NSDocument)

### What We Need to Add:
1. **PagePasteboardManager service** (~200 lines)
   - Serialize PDFPages as PDF data for clipboard
   - Handle copy/cut/paste operations
   - Track operation state

2. **UI Buttons in PageManagementView**
   - Copy button (when pages selected)
   - Cut button (when pages selected)
   - Paste button (when clipboard has data)

3. **Document ID Passing**
   - Pass document UUID to PageManagementView
   - Track cut source for proper deletion

## Implementation Approach

**Recommended:** PDF Data Serialization
- Create temporary PDFDocument with selected pages
- Store as standard PDF on clipboard
- Extract pages when pasting

## Platform Support Status

### iOS/iPadOS ✅
- **Copy:** Fully supported
- **Cut:** Fully supported with restore option
- **Paste:** Fully supported

### macOS ⚠️ (Limited Support)
- **Copy:** ✅ Supported (read-only operation)
- **Cut:** ❌ Not supported (requires document modification)
- **Paste:** ❌ Not supported (requires document modification)

**Note:** macOS currently has read-only document support. Full cut/paste functionality will be added when macOS document editing is implemented.

## Known Limitations

1. **macOS:** Copy-only support due to read-only DocumentViewModel
2. **Conflict Detection:** Currently logs conflicts but doesn't block operations (monitoring phase)
3. **Page Limit:** Maximum 200 pages per operation to prevent memory issues
- Uses native APIs, no custom serialization

## Phase 1 MVP Features:
- ✅ Copy selected pages to clipboard
- ✅ Paste pages from clipboard (at end of document)
- ✅ Visual feedback (buttons appear/disappear)
- ✅ Works between documents

## Phase 2 Enhancements:
- Cut pages (with optimistic removal)
- Paste at specific insertion point
- Keyboard shortcuts (Cmd+C, Cmd+V on macOS)
- Undo support

## Files to Modify:

1. **Create:** `Yiana/Yiana/Services/PagePasteboardManager.swift`
2. **Modify:** `Yiana/Yiana/Views/PageManagementView.swift`
3. **Update:** Document ID passing in DocumentViewModel

## Testing Checklist:

- [ ] Copy single page
- [ ] Copy multiple pages
- [ ] Paste within same document
- [ ] Paste to different document
- [ ] Cut and paste (verify removal from source)
- [ ] Large page count handling (50+ pages)
- [ ] App backgrounding with clipboard data
- [ ] Clipboard interference from other apps

## Risk Mitigations:

1. **Large page counts:** Add warning if > 50 pages selected
2. **Cut without paste:** Option A keeps pages in source until paste completes
3. **Clipboard interference:** Check validity before showing paste button
4. **OCR metadata:** Document that pasted pages need re-OCR (acceptable)

---

## Quick Start Commands:

```bash
# Verify we're on the feature branch
git branch --show-current

# Start implementing (follow plan in comments/)
# 1. Create PagePasteboardManager.swift
# 2. Update PageManagementView.swift
# 3. Add toolbar buttons
# 4. Test cross-document operations
```

---

**Last Updated:** 2025-10-12
**Ready to Code:** ✅ Yes
