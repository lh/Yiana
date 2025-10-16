# DocumentReadView Refactor Plan (Type-Checking Stability)

**Owner:** Junior Developer  
**Reviewer:** Codex  
**Date:** 14 Oct 2025  
**Status:** Ready for execution  

---

## Goal
Refactor `DocumentReadView` so the Swift compiler can type-check it reliably and the view follows our new SwiftUI composition standards. The refactor must preserve existing behaviour (toolbar actions, page management entry, info panel, read-only banner).

---

## Current Pain Points
- `body` mixes toolbar, sidebar triggers, PDF display, and status logic in one large expression.
- Inline optional checks (`viewModel?.…`) and nested overlays create deep generic chains.
- Accessibility modifiers live directly on complex views, increasing expression depth.

---

## High-Level Approach
1. Break `DocumentReadView` into four focused subviews:
   - `DocumentReadToolbar`
   - `DocumentReadContent`
   - `DocumentReadStatusBar` (if needed)
   - `ReadOnlyBanner`
2. Move derived state (titles, metadata, read-only flag) into private computed properties.
3. Pass data and callbacks explicitly between parent and child views (no shared mutation inside subviews).
4. Apply accessibility helpers in subviews rather than the main body.

---

## Step-by-Step Tasks

### Phase 1 – Pre-Refactor Setup
1. **Create Outline:** Sketch the current UI sections and note the state each needs (title, read-only flag, `showingPageManagement`, etc.).
2. **Add TODO markers:** In the current file, mark each section (banner, toolbar, content, info) to ensure nothing is missed.

### Phase 2 – Extract Banner & Toolbar
1. **ReadOnlyBanner**
   - Create a `ReadOnlyBanner` struct taking `isReadOnly: Bool`.
   - Move the existing banner `HStack` inside this struct.
   - Use `.documentRowAccessibility` or a simple `.accessibilityLabel` via helper if needed.
   - Replace inline banner in `DocumentReadView` with `ReadOnlyBanner(isReadOnly: viewModel?.isReadOnly ?? false)`.

2. **DocumentReadToolbar**
   - Create a new view with parameters:
     ```swift
     struct DocumentReadToolbar: View {
         let title: String
         let isReadOnly: Bool
         let onManagePages: () -> Void
         let onExport: () -> Void
         let onToggleInfo: () -> Void
         let isInfoVisible: Bool
         // optionally pass sidebar state if needed
     }
     ```
   - Move the toolbar `HStack` and button logic here.
   - Replace direct button actions with callbacks (passed from parent).
   - Apply `toolbarActionAccessibility` inside this view.

### Phase 3 – Extract Content View
1. **DocumentReadContent**
   - Create a view that receives `viewModel: DocumentViewModel?`, `pdfData: Data?`, `isSidebarVisible: Binding<Bool>`, `sidebarWasVisibleBeforeOrganiser: Binding<Bool>`, etc. (only pass the minimum required).
   - Move the MacPDFViewer setup into this subview.
   - Precompute optional values (`let viewModel = viewModel`) before building the tree.
   - Use a `switch`-style structure: loading, error, pdf content, placeholder.

2. **Optional:** Introduce smaller components within content if it’s still large (e.g. `DocumentReadInfoPanel`).

### Phase 4 – Clean Parent View
1. Replace the original body with:
   ```swift
   var body: some View {
       VStack(spacing: 0) {
           ReadOnlyBanner(isReadOnly: isReadOnly)
           DocumentReadToolbar(...)
           DocumentReadContent(...)
       }
       .sheet(...)
       .alert(...)
       .task { await loadDocument() }
   }
   ```
2. Ensure all state mutations (e.g., `showingPageManagement`) remain in the parent; subviews call closures.

### Phase 5 – Finalise & Polish
1. **Accessibility:** Verify each subview uses our helper methods rather than raw modifiers.
2. **Code Style:** Remove any now-unused imports or state properties.
3. **Documentation:** Add short comments explaining each subview’s responsibility.

---

## Acceptance Criteria
- `DocumentReadView` compiles without type-checking warnings.
- The toolbar, page management entry, export, and info panel behaviour match the current implementation.
- Accessibility cues (labels, hints, announcements) still fire.
- New subviews reside in the same file unless the file becomes too large (then create a `DocumentReadView+Components.swift` companion).

---

## Testing Checklist
- [ ] Build macOS and iOS targets (ensure no type-check errors).
- [ ] Manually test toolbar buttons and info panel toggle.
- [ ] Open Page Management from toolbar and via sidebar double-click.
- [ ] Run VoiceOver on macOS/iOS to confirm announcements still occur.
- [ ] SwiftLint (`swiftlint lint --strict`) passes with no new warnings.

---

## Deliverables
1. Updated `DocumentReadView.swift` with extracted components.
2. Any new component structs (banner, toolbar, content) and supporting helper functions.
3. Completed testing checklist with notes in the PR description.

When submitting the PR, reference `discussion/2025-10-14-swiftui-typecheck-instability-v3.md` to show the work addresses the top priority item.***
