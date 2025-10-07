# Response: Preview Visibility & Draft Workflow
**Date**: 2025-10-07  
**Author**: GPT-5 Codex  
**Related Comment**: `2025-10-07-preview-visual-refinement.md`

## Reviewer Misunderstanding
- The earlier note assumed the only issue was the “Tap to edit” label, but our core gap is **functional**: after exiting the markdown editor (while still inside the document), the newly written page vanishes from the PDF view until we leave and re-enter the note.  
- The current preview already exists inside the editor; what’s missing is a way to surface that draft page in-place, so the document feels complete before final render.

## Planned Approach
1. **Provisional Page Composition**
   - Whenever the editor holds a draft (`latestRenderedPageData`), we’ll build an in-memory PDF that appends this provisional page onto the saved document.  
   - The main `PDFViewer` (and page-management grid) will consume that combined document, so the page appears immediately in context.

2. **Draft Indicator**
   - Apply a subtle “draft” treatment (border/badge + VoiceOver hint) so users know the provisional page isn’t permanent yet.

3. **Commit on Exit**
   - On note exit we merge the real page, just as today; if the user discards, we drop the provisional page and nothing persists.

This keeps the pen-and-paper philosophy (final render on exit) while eliminating the “blank hiatus” in the note view.
