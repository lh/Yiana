# Design Notes: iPad Thumbnail Side Panel
**Date**: 2025-10-08  
**Author**: GPT-5 Codex  
**Context**: Brainstorming iPad-specific enhancements for the page management experience.

## Proposed Concept
- Add a toggle (e.g., toolbar pill or segmented control) in the iPad document view that slides in an always-visible thumbnail rail.
- Panel defaults to the right edge; per-app preference in Settings allows choosing left/right.
- iPhone keeps the current swipe-up sheet; macOS already has a wider layout, so we can consider reusing the panel there later.

## Interaction Ideas
- **Tap** thumbnail → navigate to that page (mirrors current behaviour).
- **Double tap** → select for deletion / multi-select mode (consistent with sheet).
- **Tap-and-hold + drag** → reorder pages within the rail; underlying PDF updates immediately as today.
- **Context menu (long press)** for actions: duplicate, share page, mark as favorite/bookmark, extract text, etc.
- **Swipe left on thumbnail** (optional) for quick delete or duplicate.
- **Magnet/pin icon** to lock the rail open so it resizes the main PDF view; otherwise it can auto-hide when in portrait.
- **Draft indicator** surfaces on provisional pages (reuse yellow border/badge).
- **Multi-select affordance** (e.g., Edit button in panel header) allows bulk delete or reordering using drag handles.
- **New page button** at the end of the rail for quickly adding a blank text page or initiating scan (iPad productivity pattern).
- **Scrollbar overlay** to enable fast scrubbing through large documents; could show page numbers as the user drags.
- **Zoom/pinch** within the rail to adjust thumbnail size for accessibility or precision.
- **Keyboard shortcuts** when a hardware keyboard is attached (e.g., arrow keys to change selection, cmd+delete to remove).

## Open Questions
- Should the rail show additional metadata (page numbers, annotations, warning badges)?
- Do we let the rail collapse into icons when space is tight (split-view multitasking)?
- What’s the discoverability plan for the toggle—toolbar button, settings switch, or both?
- How do we signal edit mode vs navigation mode clearly in a persistent panel?

These notes should help align on behaviour before we start prototyping the actual SwiftUI changes. Feedback welcome! 
