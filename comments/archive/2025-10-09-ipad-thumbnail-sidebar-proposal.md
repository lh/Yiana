# iPad Thumbnail Sidebar Design Proposal

**Date**: 2025-10-09
**Status**: Design Exploration
**Context**: Replacing modal page management sheet with persistent sidebar on iPad

---

## Problem Statement

Current page management uses a modal sheet (swipe-up gesture) on all platforms. This works well on iPhone but feels suboptimal on iPad where:
- iPad has more screen real estate
- Users might want to see thumbnails while viewing pages
- Modal sheets interrupt the reading flow

## Proposed Solution

**iPad-only enhancement**: Toggleable thumbnail sidebar alongside main PDF view.

### Core Design

```
┌─────────────────────────────────────────────────────┐
│  [≡] Document Title                    [⚙️] [Share] │
├───────────────┬─────────────────────────────────────┤
│               │                                     │
│  ┌─────────┐  │                                     │
│  │ Page 1  │  │                                     │
│  │  [img]  │  │        Main PDF View                │
│  └─────────┘  │      (Current Page)                 │
│               │                                     │
│  ┌─────────┐  │                                     │
│  │ Page 2  │◀─│                                     │
│  │  [img]  │  │                                     │
│  └─────────┘  │                                     │
│               │                                     │
│  ┌─────────┐  │                                     │
│  │ Page 3  │  │                                     │
│  │  [img]  │  │                                     │
│  └─────────┘  │                                     │
│      ...      │                                     │
└───────────────┴─────────────────────────────────────┘
   Thumbnail         Main Content Area
   Sidebar (180pt)   (remaining width)
```

### Platform Behavior

- **iPad (regular horizontal size class)**: Sidebar available
- **iPhone / iPad compact**: Keep existing modal sheet (swipe-up)
- **macOS**: TBD (could use sidebar or keep existing approach)

### Toggle Mechanism

**Option A: Toolbar button**
- Add button in navigation bar (left side, near hamburger menu)
- Icon: Grid/thumbnail icon
- Tap to show/hide sidebar

**Option B: Gesture + button**
- Swipe from right edge → reveal sidebar
- Button in toolbar to toggle
- Sidebar can be "pinned" to stay visible

**Preference**: Option B (gesture + button) - feels more iPad-native

### Settings Integration

Add to `SettingsView` under "Page Management" section:
- **Thumbnail sidebar position**: Left / Right (default: Left)
- **Auto-hide sidebar**: On / Off (default: Off)
- **Thumbnail size**: Small / Medium / Large

---

## Proposed Interactions

### 1. Basic Navigation ✅ (from your spec)

- **Single tap**: Navigate to that page
- **Current page indicator**: Border highlight or background color

### 2. Page Selection ✅ (from your spec)

- **Double tap**: Select page (shows checkmark overlay)
- **Multi-select mode**: After first double-tap, subsequent single taps toggle selection
- **Exit multi-select**: Tap "Done" button or tap empty space

### 3. Page Reordering ✅ (from your spec)

- **Long press**: Enter drag mode
- **Drag up/down**: Reorder within thumbnail list
- **Drop**: Commit new order
- **Visual feedback**: Page lifts, others shift to show drop target

### 4. Additional Actions (Proposals)

#### Option 1: Context Menu on Long Press
Instead of (or in addition to) drag-to-reorder:

**Long press → Context menu**:
- Move to Top
- Move to Bottom
- Duplicate Page
- Delete Page
- Extract as New Document
- Rotate Page (90°, 180°, 270°)
- Insert Blank Page After
- **Or**: "Reorder" option that enters drag mode

**Trade-off**:
- ✅ More actions available
- ❌ Conflicts with drag-to-reorder gesture
- **Suggestion**: Use long press for context menu, add dedicated "Reorder" mode via toolbar button

#### Option 2: Swipe Actions

**Swipe left on thumbnail**:
- Delete (red background)
- More... (shows context menu)

**Swipe right on thumbnail**:
- Duplicate
- Share

**Trade-off**:
- ✅ Quick access to common actions
- ✅ iOS-native pattern
- ⚠️ Limited to 2-3 actions per swipe direction
- ❌ Might conflict with sidebar scroll in tight spaces

#### Option 3: Toolbar When Selection Active

When pages are selected (via double-tap):
- Show toolbar at bottom of sidebar with actions:
  - Delete (trash icon)
  - Duplicate (two squares icon)
  - Move (up/down arrows - shows move mode)
  - Extract (export icon - creates new document)
  - Share (share sheet)

**Trade-off**:
- ✅ Clear, discoverable actions
- ✅ Doesn't conflict with gestures
- ✅ Can show multiple actions simultaneously
- **Recommendation**: This feels most iPad-appropriate

### 5. Search/Filter Within Sidebar

**Search bar at top of sidebar**:
- Filter by page number ("Page 5")
- Filter by OCR content on page
- Filter by page type (scanned vs text page)
- Filter by provisional status (draft pages)

**Use case**: Finding specific page in large document (50+ pages)

**Trade-off**:
- ✅ Very useful for large documents
- ⚠️ Adds complexity
- **Suggestion**: Implement in v2 (not initial release)

### 6. Quick Actions Bar (Persistent)

At bottom of sidebar, always-visible quick actions:
- **[+]** Add page (scan/text/import)
- **[Select]** Enter multi-select mode
- **[Sort]** Change thumbnail order (date added, page number, custom)

**Trade-off**:
- ✅ Common actions always accessible
- ❌ Uses vertical space
- **Suggestion**: Use only if actions are frequently needed

### 7. Thumbnail Preview on Hover (iPad with pointer)

When using iPad with trackpad/mouse:
- **Hover over thumbnail**: Show larger preview in popover
- **Benefit**: Quick preview without navigating away

**Trade-off**:
- ✅ Nice enhancement for pointer users
- ⚠️ Requires pointer support
- **Suggestion**: Low priority, add if easy to implement

### 8. Drag-and-Drop to/from Sidebar

**Drag page thumbnail out of sidebar**:
- Creates new document from that page
- Or: Share/export that page

**Drag PDF/image into sidebar**:
- Insert at drop position
- Import as new page

**Trade-off**:
- ✅ Very powerful, iPad-native
- ⚠️ Complex to implement
- **Suggestion**: Phase 2 feature

---

## Interaction Priority Recommendations

### Phase 1 (MVP for sidebar)
1. ✅ **Single tap to navigate**
2. ✅ **Double tap to select (multi-select mode)**
3. ✅ **Toolbar when selection active** (delete, duplicate, share)
4. ✅ **Long press for context menu** (with "Reorder" option)
5. ✅ **Dedicated "Reorder" mode** (entered via toolbar or context menu)

### Phase 2 (Enhancements)
6. 🟡 **Swipe actions** (left: delete, right: duplicate)
7. 🟡 **Search/filter bar** (for large documents)
8. 🟡 **Drag-and-drop import** (drag images/PDFs into sidebar)

### Phase 3 (Polish)
9. 🟢 **Hover preview** (pointer support)
10. 🟢 **Quick actions bar** (if user feedback requests it)
11. 🟢 **Drag to export** (drag thumbnail out to share/create doc)

---

## Gesture Conflict Analysis

| Gesture | Current Use | Sidebar Use | Conflict? | Resolution |
|---------|-------------|-------------|-----------|------------|
| Single tap | N/A | Navigate to page | No | ✅ Clear |
| Double tap | PDF zoom | Select page | **Yes** | Only in sidebar area |
| Long press | N/A | Context menu | No | ✅ Clear |
| Swipe up | Show page grid | Scroll thumbnails | **Yes** | Disable swipe-up when sidebar visible |
| Swipe down | Dismiss grid | Scroll thumbnails | **Yes** | Disable swipe-down when sidebar visible |
| Swipe left/right | Navigate pages | Optional actions | **Maybe** | Test with users |
| Pinch | PDF zoom | N/A | No | Only in main view |

**Key insight**: Disable existing swipe-up/down gestures when sidebar is visible (they become redundant).

---

## Visual Design Considerations

### Thumbnail Rendering
- **Size**: 150pt × 200pt (aspect ratio of typical page)
- **Border**: Current page gets 2pt border in accent color
- **Shadow**: Subtle drop shadow (0.5pt)
- **Spacing**: 12pt between thumbnails
- **Loading**: Show skeleton/placeholder while rendering

### Selection State
- **Selected**: Checkmark in top-right corner, blue overlay (20% opacity)
- **Provisional (draft)**: Yellow border + "DRAFT" badge
- **Current page**: Blue border (2pt)

### Sidebar Dimensions
- **Width**: 180pt (fixed, or user-adjustable in settings?)
- **Minimum width**: 150pt (if adjustable)
- **Maximum width**: 250pt (if adjustable)
- **Divider**: 1pt line between sidebar and main view, draggable to resize?

### Animation
- **Show/hide**: 0.3s ease-in-out slide animation
- **Page navigation**: Smooth scroll to bring current page into view
- **Reorder**: Smooth position transitions when pages shift

### Accessibility
- **VoiceOver**: Each thumbnail is labeled "Page N, [type]"
- **Dynamic Type**: Thumbnail size respects accessibility text size settings?
- **High Contrast**: Border and selection state clearly visible

---

## Implementation Considerations (Not Code, Just Notes)

### State Management
- `showThumbnailSidebar: Bool` in DocumentViewModel
- `sidebarPosition: ThumbnailSidebarPosition` (.left / .right) in settings
- `selectedPages: Set<Int>` for multi-select
- `isReorderMode: Bool` for drag mode

### Performance
- **Lazy loading**: Render thumbnails on-demand as user scrolls
- **Caching**: Cache rendered thumbnails in memory
- **Background rendering**: Generate thumbnails on background thread
- **Memory pressure**: Release cached thumbnails when low memory

### SwiftUI Layout
- Use `HStack` with sidebar and main view
- Sidebar uses `ScrollView` with `LazyVStack` for thumbnails
- Main view is existing `PDFViewer`
- Conditional rendering based on size class

### Persistence
- Save sidebar visibility state per-document?
- Or global setting for all documents?
- **Recommendation**: Global setting, faster to implement

---

## Open Questions for Discussion

### 1. Sidebar Visibility Default
- **Option A**: Hidden by default, user must toggle
- **Option B**: Visible by default on iPad
- **Your preference?**

### 2. Sidebar Position Default
- **Option A**: Left (you suggested this)
- **Option B**: Right
- **Rationale for left?** Reading direction? App navigation typically on left?

### 3. Reordering Mechanism
- **Option A**: Long press → immediate drag mode
- **Option B**: Long press → context menu with "Reorder" option → enters drag mode
- **Option C**: Toolbar button "Edit" → enters reorder mode (all pages become draggable)
- **Your preference?**

### 4. Multi-Select Entry
- **Option A**: Double tap (your suggestion)
- **Option B**: Long press + "Select" in context menu
- **Option C**: Toolbar "Select" button
- **Option D**: Combination of A + C (double tap or toolbar button)
- **Your preference?**

### 5. Conflicting Gestures
- If sidebar is visible, should main PDF view still support:
  - Swipe left/right for page navigation? (might conflict with sidebar reveal gesture)
  - Double tap to zoom? (might be confusing if sidebar uses double-tap for select)
- **Recommendation**: Keep main view gestures unchanged, only add sidebar gestures within sidebar bounds

### 6. Provisional Pages in Sidebar
- Show draft pages in sidebar with indicator?
- Show draft pages in separate section?
- Show draft pages at bottom with divider?
- **Your preference?**

### 7. Sync with Existing Page Grid
- Keep existing page grid (swipe-up) as fallback?
- Remove page grid entirely when sidebar is implemented?
- **Recommendation**: Keep grid as fallback for iPhone, remove grid gesture on iPad when sidebar is visible

---

## Comparison with Existing Page Grid

| Feature | Current (Modal Grid) | Proposed (Sidebar) |
|---------|---------------------|-------------------|
| **Visibility** | Modal, covers content | Persistent, alongside content |
| **Activation** | Swipe up | Toolbar button or swipe from edge |
| **Navigation** | Tap to jump | Tap to jump |
| **Multi-select** | Tap "Select" button | Double tap |
| **Delete** | Select + trash button | Select + trash button (toolbar) |
| **Reorder** | Long press + drag | Long press → drag (or toolbar "Edit") |
| **Dismissal** | Swipe down or tap outside | Toolbar button or auto-hide |
| **Screen space** | Full screen when active | 180pt always (if pinned) |
| **Context** | Disconnected from reading | Connected, see both simultaneously |

**Advantages of sidebar**:
- ✅ Non-modal, less disruptive
- ✅ See thumbnails while reading
- ✅ Quick page navigation without losing context
- ✅ Better use of iPad screen space
- ✅ Feels more "pro" for iPad

**Advantages of grid**:
- ✅ Larger thumbnails (full screen)
- ✅ See more pages at once (grid vs list)
- ✅ Simpler implementation
- ✅ Works on all platforms

---

## Next Steps (Your Decision)

1. **Review this proposal** - Which interactions make sense?
2. **Prioritize features** - What's MVP vs Phase 2?
3. **Clarify open questions** - Sidebar defaults, gesture preferences
4. **Approve design direction** - Then we can create implementation plan
5. **Consider mockups** - Would visual mockups help? (I can describe in detail for designer)

---

## Alternative Approaches Considered

### Alt 1: Floating Thumbnail Panel
Instead of fixed sidebar, use floating panel that can be:
- Repositioned anywhere on screen
- Resized by user
- Hidden/shown with button

**Trade-offs**:
- ✅ More flexible
- ❌ More complex to implement
- ❌ Requires more UI chrome (resize handles, position controls)

### Alt 2: Split View with Page Grid
Keep grid but show it side-by-side instead of modal:
- Tap button → Grid slides in from bottom
- Grid takes bottom 40% of screen
- Main view takes top 60%

**Trade-offs**:
- ✅ Larger thumbnails than sidebar
- ❌ Awkward aspect ratio for reading
- ❌ Horizontal space on iPad wasted

### Alt 3: Drawer That Expands
Collapsed state: Thin strip with mini thumbnails
Expanded state: Full sidebar with regular thumbnails

**Trade-offs**:
- ✅ Two levels of detail
- ⚠️ More complex interaction model
- **Could be Phase 2 enhancement**

---

## Related Patterns in Other Apps

**PDF Expert** (iPad):
- Sidebar with thumbnails on left
- Always visible in split view mode
- Tap to navigate, swipe to delete

**GoodNotes** (iPad):
- Sidebar with page thumbnails
- Draggable to reorder
- Context menu on long press

**Apple Files** (iPad):
- Sidebar for navigation
- Toggle button in toolbar
- Resizable by dragging divider

**Adobe Acrobat** (iPad):
- Thumbnail panel (bottom sheet)
- Can pin to side
- Swipe actions on thumbnails

**Recommendation**: Follow Apple Files pattern - it's most native to iPadOS.

---

**Ready for your feedback!** What resonates? What would you change? What should we prioritize?
