# Sidebar Iteration 2 Review
**Date**: 2025-10-09

## Observations
- After deleting pages (keeping only a newly created page), the main viewer showed the correct page but the sidebar still displayed a deleted page until the app was restarted.
- Indicates a potential sync issue between `DocumentViewModel`'s page data and the sidebar thumbnail refresh.
- Possible causes: cached PDFDocument not updated, `updateSidebarDocument` not invoked on delete, or off-by-one index.

## Action Items
- Investigate sidebar-document refresh after deletion; ensure provisional manager and display data are updated.
- Consider forcing sidebar reload (set `sidebarDocument` to nil then rebuild) after page removal.
- Verify selection state resets and page counts post-delete/duplicate adjust correctly without restart.
