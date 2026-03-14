# Session Handoff — 2026-03-14

## What was completed

### iPad sidebar inline page editing — implemented, merged, deployed

Replaced the PageManagementView sheet on iPad with direct inline editing in the thumbnail sidebar. The sheet remains for iPhone (no sidebar available).

**Interaction model:**
- **Nav mode (default):** Tap navigates to page, double-tap enters edit mode selecting that page
- **Edit mode:** Tap toggles selection (checkmark badge), long-press + drag to reorder (native iOS List `.onMove`), compact icon toolbar at top for cut/copy/paste/duplicate/delete, Done to exit
- **PDFViewer page indicator tap:** On iPad, shows sidebar + enters edit mode. On iPhone, opens PageManagementView sheet (unchanged)

**Architecture change:** The sidebar previously used `ScrollView` + `LazyVStack` with `.onDrag`/`.onDrop` (system drag-and-drop API via `NSItemProvider`). This caused two problems: (1) long-press conflicted with context menus, (2) items would visually lift and elastic-back because the drop wasn't completing properly. Switched to `List` + `ForEach` + `.onMove(perform:)` which gives native iOS reorder — grab handle, smooth displacement animation, proper placement.

**Files changed:**
- `DocumentViewModel.swift` — added `movePages(from:to:)` using `IndexSet`/`Int` (standard `Array.move` API)
- `ThumbnailSidebarView.swift` — `SidebarEditAction` enum, edit mode toolbar, `List` with `.onMove`, selection badges, cut dimming
- `DocumentEditView.swift` — new state for sidebar editing, `handleSidebarEditAction` dispatcher, updated tap/double-tap callbacks, iPad vs iPhone routing for page management, removed dead sidebar-hide-on-sheet code

### TestFlight deployment

Build 43 uploaded to App Store Connect (iOS + macOS). Branch `sidebar-inline-editing` merged to main via fast-forward.

## Lessons learned

### Use native List `.onMove` for within-list reorder, not `.onDrag`/`.onDrop`
- `.onDrag`/`.onDrop` with `NSItemProvider` is the cross-app drag-and-drop API — wrong tool for within-list reordering
- Even with an empty `NSItemProvider`, iOS shows a lift animation that elastics back when no drop completes — confusing UX
- `.onMove(perform:)` on a `ForEach` inside a `List` with `.environment(\.editMode, .constant(.active))` gives native iOS reorder: grab handle, smooth item displacement, proper drop placement
- This only works with `List`, not `ScrollView` + `LazyVStack`
- The old "iOS List rows can't be drop targets" note in MEMORY.md is about EXTERNAL drops — internal reorder via `.onMove` works fine

### Context menus and drag gestures conflict on iOS
- Long-press is used for both context menu activation and drag initiation
- If you need both, they'll fight each other — one or both will be unreliable
- Solution: choose one. For reorder, use `.onMove` (no long-press needed — List provides grab handles). Put operations in a toolbar instead of context menu

### Start with native platform mechanisms before building custom
- Three iterations of custom drag machinery (`.onDrag`/`.onDrop`, then context menu, then toolbar + drag) before landing on the native `.onMove` that iOS provides out of the box
- The user spotted the elastic-back behavior and correctly identified that the system "wanted" to do native reorder — trust that instinct

## Branch status

- All work merged to `main`, pushed to remote
- `sidebar-inline-editing` branch exists (can be deleted)
- Working tree clean (untracked: `scripts/bulk-import.sh`)

## Known issues

- iCloud `[ERROR] [Progress]` noise when InjectWatcher renames/deletes `.processing` file — harmless
- Transient "database is locked" on reindex after inject append — resolves on next UbiquityMonitor cycle
