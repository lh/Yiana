# iPad Sidebar Design Decisions

**Date**: 2025-10-09
**Status**: Design Approved
**Context**: Decisions made for iPad thumbnail sidebar implementation

---

## Core Decisions

### Platform Scope
✅ **iPad only** - iPhone interface remains unchanged (working well as-is)

### Default Behavior
✅ **Sidebar hidden by default** - User must toggle to reveal

### Sidebar Position
✅ **Right side by default** - Switchable to left in settings
- Makes sense for right-handed users (thumb access)
- Doesn't conflict with back navigation (left side)
- Settings option for left/right preference

### Settings Integration
Add to Settings page (alongside page size setting):
- **Thumbnail sidebar position**: Left / Right (default: Right)
- Consider also:
  - Auto-hide behavior?
  - Thumbnail size preference?

---

## Still to Decide

### 1. Multi-Select Interaction
**Options**:
- A) Double tap to enter selection mode (your original idea)
- B) Toolbar "Select" button
- C) Long press → context menu → "Select"
- D) Combination (double tap OR toolbar button)

**Question**: Which feels most natural for iPad?

### 2. Reordering Mechanism
**Options**:
- A) Long press → immediate drag mode
- B) Long press → context menu → "Reorder" option → enters drag mode
- C) Toolbar "Edit" button → all pages become draggable (iOS Photos style)
- D) Context menu includes "Move to Top" / "Move to Bottom" (no drag)

**Question**: Drag-based reordering or menu-based?

### 3. Delete Interaction
**Options**:
- A) Select pages (double tap) → toolbar trash button
- B) Swipe left on thumbnail → delete button appears
- C) Long press → context menu → "Delete"
- D) All of the above (multiple paths)

**Question**: Primary delete method?

### 4. Additional Actions
**Proposed actions** (in context menu or toolbar):
- Duplicate page
- Rotate page
- Extract as new document
- Share single page
- Insert blank page after

**Question**: Which actions are most useful? Priority order?

### 5. Provisional/Draft Pages
**How to show draft pages in sidebar**:
- A) Same position as they'll appear, with yellow border + "DRAFT" badge
- B) Separate section at bottom
- C) Floating above saved pages (always visible at top)

**Question**: How should drafts be distinguished visually?

### 6. Sidebar Toggle Method
**Options**:
- A) Toolbar button only
- B) Swipe from right edge + toolbar button
- C) Swipe from right edge only
- D) Three-finger swipe gesture

**Question**: Single method or gesture + button?

### 7. Existing Page Grid Gesture (iPad)
**When sidebar is visible**:
- A) Disable swipe-up gesture (redundant with sidebar)
- B) Keep swipe-up as alternative (shows full-screen grid)
- C) Swipe-up toggles sidebar instead

**Question**: What happens to swipe-up on iPad when sidebar exists?

---

## Implementation Phases

### Phase 1: MVP (Core Functionality)
- [ ] Sidebar component (right side, toggleable)
- [ ] Thumbnail rendering (lazy loading)
- [ ] Single tap to navigate
- [ ] Settings: position switcher (left/right)
- [ ] Current page indicator
- [ ] Show/hide animation

**Decisions needed**: Toggle method, multi-select entry

### Phase 2: Page Management
- [ ] Multi-select mode (double-tap or button)
- [ ] Delete selected pages
- [ ] Toolbar when selection active
- [ ] Long press context menu
- [ ] Basic actions (delete, duplicate, share)

**Decisions needed**: Multi-select method, delete method, which actions

### Phase 3: Advanced Features
- [ ] Reordering (drag or menu-based)
- [ ] Additional actions (rotate, extract, etc.)
- [ ] Swipe actions (optional)
- [ ] Search/filter bar (optional)

**Decisions needed**: Reorder mechanism, action priority

---

## Open Questions Summary

1. **Multi-select entry**: Double tap, toolbar button, or both?
2. **Reordering**: Drag-based, menu-based, or toolbar "Edit" mode?
3. **Delete method**: Selection + toolbar, swipe, context menu, or all?
4. **Which additional actions**: Rotate, extract, share page, insert blank?
5. **Draft page display**: Same position with badge, separate section, or floating?
6. **Toggle method**: Button only, or gesture + button?
7. **Swipe-up gesture**: Disable, keep, or repurpose when sidebar available?

---

## Next Steps

1. **Rose decides on open questions** above
2. **Create implementation plan** based on decisions
3. **Design visual mockup** (optional - text description or sketch)
4. **Implement Phase 1** (MVP)
5. **Test with iPad** before proceeding to Phase 2

---

## Notes for Implementation

### Visual Specs (Tentative)
- **Sidebar width**: 180pt (right side)
- **Thumbnail size**: 120pt × 160pt (maintains page aspect ratio)
- **Spacing**: 12pt between thumbnails
- **Current page indicator**: 2pt blue border
- **Draft indicator**: 2pt yellow border + small "DRAFT" badge

### Performance Considerations
- Lazy thumbnail rendering (only visible thumbnails)
- Cache rendered thumbnails in memory
- Background thread for thumbnail generation
- Release cache on memory warning

### Accessibility
- VoiceOver labels for each thumbnail
- Dynamic Type support for badge text
- High contrast mode for indicators

---

**Awaiting your decisions on open questions to proceed with implementation plan!**
