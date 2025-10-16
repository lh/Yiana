# PageManagementView Refactor Plan (Type-Checking Stability) — Phase 2

**Owner:** Junior Developer  
**Reviewer:** Codex  
**Date:** 14 Oct 2025  
**Status:** Ready for execution  

---

## Goal
Refactor `PageManagementView` so the Swift compiler type-checks it reliably and the view matches our composition standards. The refactor should maintain all current functionality: selection, cut/copy/paste, undo restore, macOS toolbar actions, and accessibility announcements.

---

## Current Pain Points
- `body` combines navigation stack, alerts, modals, toolbar logic, and grid layout in one expression.
- Complex toolbar groups (macOS & iOS) mix command logic with accessibility modifiers inline.
- `pageGrid` still contains nested logic (selection, gestures, overlays) and accessibility modifiers, producing deep generic stacks.
- Helper state (clipboard, selection announcements) is interwoven through the view builder.

---

## Refactor Strategy
1. Split the view into focused components:
   - `PageManagementToolbar` (platform-specific sections)
   - `PageGridView` (grid layout of thumbnails)
   - `PageThumbnailCell` (individual page presentation + gestures)
   - Optional: `PageOperationAnnouncements` for accessibility posts
2. Move data derivation (e.g., clipboard state, filtered selections) into computed properties or helper methods outside the main builder.
3. Decouple macOS/iOS toolbar configurations so each uses lightweight subviews.
4. Reuse `View+Accessibility` helpers inside subcomponents instead of stacking modifiers inline.

---

## Step-by-Step Tasks

### Phase 2.1 – Preparation
1. **Audit Current State:** List all state variables and group them by responsibility (selection, clipboard, alerts, announcements).
2. **Mark Sections:** Add temporary comments to delineate toolbar, grid, alerts, and helper methods to ensure nothing is overlooked during extraction.

### Phase 2.2 – Extract Toolbar Logic
1. **Create `PageManagementToolbar`** struct with parameters:
   ```swift
   struct PageManagementToolbar: View {
       let platform: Platform
       let selectionCount: Int
       let clipboardHasPayload: Bool
       let onCut: () -> Void
       let onCopy: () -> Void
       let onPaste: () -> Void
       let onDelete: () -> Void
       let onRestoreCut: (() -> Void)?
       let onMoveLeft: (() -> Void)?
       let onMoveRight: (() -> Void)?
   }
   ```
   - `platform` can be an enum (`.iOS`, `.macOS`) so the toolbar renders the appropriate layout without `#if` inside the view body.
   - Apply `toolbarActionAccessibility` within this view.
   - Replace the inline toolbar definitions in `PageManagementView` with this component.

2. **Clamp Platform Logic:** Initialise `PageManagementToolbar` with `.iOS` / `.macOS` inside the parent using `#if os(...)` to avoid conditional code in the component.

### Phase 2.3 – Extract Page Grid
1. **Create `PageGridView`** with inputs:
   ```swift
   struct PageGridView: View {
       let pages: [PDFPage]
       let currentPageIndex: Int
       let selectedPages: Set<Int>
       let provisionalRange: Range<Int>?
       let cutPageIndices: Set<Int>?
       let onPageTapped: (Int) -> Void
       let onPageDoubleTapped: (Int) -> Void
   }
   ```
   - Move the `ScrollView`/`LazyVGrid` into this component.
   - Handle both iOS drag/drop (behind `#if os(iOS)`) and macOS gestures inside this subview.
   - Reapply `pageThumbnailAccessibility` in the new `PageThumbnailCell`.

2. **Create `PageThumbnailCell`** struct that encapsulates:
   - Rendering the thumbnail (`PageThumbnailView` or similar).
   - Cut/provisional overlays.
   - Single/double tap gestures, separated for readability.

3. Parent `PageManagementView` now passes closures handling selection logic (`toggleSelection`, `onProvisional` etc.).

### Phase 2.4 – Clean Up Parent View
1. Simplify `PageManagementView.body` to:
   ```swift
   var body: some View {
       NavigationStack {
           PageGridView(...)
       }
       .toolbar {
           PageManagementToolbar(...).toToolbarContent()
       }
       .onAppear { loadPages() }
       // retain alerts, sheets, onReceive, etc.
   }
   ```
   - Provide helper method `toToolbarContent()` in the toolbar component to wrap it in `ToolbarItemGroup`.

2. Move `onAppear` clipboard refresh into a dedicated helper method (e.g., `refreshClipboardState()`).

3. Ensure alerts and `restoreCutPages()` remain in the parent; only UI rendering shifts to subviews.

### Phase 2.5 – Accessibility & Announcements
1. Verify the new components call `AccessibilityAnnouncer.shared.post` where appropriate (copy/cut/paste results).
2. Replace inline label/hint modifiers with the new helper functions in child views.
3. Add comments explaining where announcements occur to guide future maintenance.

---

## Acceptance Criteria
- `PageManagementView` compiles without type-checking warnings.
- Toolbar actions behave identically on iOS and macOS.
- Page selection, drag/drop (iOS), and move operations function as before.
- Accessibility labels, hints, and announcements match current behaviour.
- New subviews are small and focused; `PageManagementView.body` is shallow.

---

## Testing Checklist
- [ ] Build macOS and iOS targets (confirm no type-check errors).
- [ ] Manual smoke tests: select/cut/copy/paste/delete/move pages on both platforms.
- [ ] Drag & drop reorder (iOS) still works.
- [ ] Restore Cut works and announces completion.
- [ ] VoiceOver navigation reads page numbers/states correctly.
- [ ] `swiftlint lint --strict` returns no new warnings.

---

## Deliverables
1. Updated `PageManagementView.swift` with extracted components.
2. New component structs (`PageManagementToolbar`, `PageGridView`, `PageThumbnailCell`) and helper methods.
3. Updated documentation/comments indicating component responsibilities.
4. Testing notes summarised in the PR.

When submitting the PR, reference `discussion/2025-10-14-swiftui-typecheck-instability-v3.md` as the architectural justification.***
