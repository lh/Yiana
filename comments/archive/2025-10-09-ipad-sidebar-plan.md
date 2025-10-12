# Implementation Plan: iPad Sidebar MVP (Phase 1)
**Date**: 2025-10-09  
**Author**: GPT-5 Codex  
**Branch**: feature/ipad-enhancements

## Goals
Introduce a persistent thumbnail sidebar on iPad that resizes the document view, while keeping the iPhone experience unchanged. This lays the groundwork for richer page management in later phases.

## Tasks

### 1. Sidebar Shell & Toggle
- Add `isSidebarVisible` state to the document editing screen (e.g., `DocumentEditView`).
- iPad-only toolbar button toggles the sidebar; iPhone ignores it.
- When active, lay out `PDFViewer` and the sidebar in an `HStack` so the main view shrinks instead of being overlaid.

### 2. Sidebar Component
- Create `ThumbnailSidebarView` that:
  - Accepts the combined PDF data, current page index, provisional page range, and thumbnail size.
  - Displays a `ScrollView` of thumbnail cells built with lazy image generation.
  - Highlights the current page and shows draft badges.
  - Emits callbacks for tap (navigate) and double-tap (selection in later phases).
- Cache generated thumbnails to avoid re-rendering.

### 3. Wiring & Navigation
- Extend view model or coordinator to provide current page index and provisional range.
- Hook sidebar taps into the existing `navigateToPage` binding so tapping a thumbnail jumps immediately in the PDF viewer.
- Ensure provisional pages (drafts) surface correctly via combined PDF data.

### 4. Settings Integration
- Update `SettingsView` with:
  - Sidebar position picker (left/right) stored in `TextPageLayoutSettings`.
  - Thumbnail size picker (small/medium/large) also stored in settings.
- Load and apply these preferences when building the sidebar.

### 5. Platform Handling
- Guard sidebar creation with `UIDevice.current.userInterfaceIdiom == .pad`.
- In portrait, sidebar still relies on the toggle (no auto-hide for v1).
- Existing swipe-up sheet remains available (especially for iPhone).

### 6. Polish & Accessibility
- Provide clear accessibility labels for the toggle and sidebar controls.
- Animate sidebar appearance/disappearance (e.g., `.transition(.move(edge: .trailing))`).
- Consider subtle shadow or separator to distinguish the sidebar from the main PDF view.

## Out of Scope (Future Phases)
- Multi-select, reorder, and context-menu actions (Phase 2).
- Swipe actions, quick add, search within sidebar, keyboard shortcuts, pinch-to-zoom thumbnails (Phase 2/3).
- Auto-hide behavior or icon-only mode for split view (Phase 3).

