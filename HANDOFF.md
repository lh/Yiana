# Session Handoff — 2026-02-14 (evening)

## What was completed

### V2 Document List: sidebar folder navigation (macOS)
Committed as `10750f2`. NavigationSplitView-based layout with folder tree in sidebar, documents in detail column.

### iPad sidebar
User added iPad folder sidebar between sessions — `NavigationSplitView` on regular size class, standard `NavigationStack` on iPhone. Uses `ScrollView` + `LazyVStack` (not `List`) to work around iOS UITableView drop interception. Includes `IOSFolderDropDelegate` for drag-to-folder on iPad.

### V2 promoted to default — UIVariant system removed
Committed as `1f20996`. Deleted `UIVariant.swift`, removed Cmd+Shift+U cycling, Settings picker, variant badge overlays, and all V1 body code from DocumentListView, DocumentReadView, and MacPDFViewer (~220 lines removed). Version bumped to **1.1**.

### TestFlight deployment
Build 37 (v1.1) uploaded to App Store Connect as `22a44b6`.

## Files changed this session
- **`Yiana/Yiana/Models/FolderNode.swift`** — new. Tree node struct for sidebar hierarchy.
- **`Yiana/Yiana/Services/DocumentRepository.swift`** — added `buildFolderTree()`.
- **`Yiana/Yiana/ViewModels/DocumentListViewModel.swift`** — added `folderTree`, `navigateToFolderPath()`.
- **`Yiana/Yiana/Views/DocumentListView.swift`** — V2 sidebar (macOS), iPad sidebar (iOS), removed V1 body and UIVariant switching.
- **`Yiana/Yiana/Views/DocumentReadView.swift`** — removed V1 body and UIVariant.
- **`Yiana/Yiana/Views/MacPDFViewer.swift`** — removed V1 body and UIVariant.
- **`Yiana/Yiana/Views/SettingsView.swift`** — removed Layout picker.
- **`Yiana/Yiana/YianaApp.swift`** — removed Cycle UI Variant command.
- **`Yiana/Yiana/Utilities/UIVariant.swift`** — deleted.
- **`Yiana/Yiana.xcodeproj/project.pbxproj`** — version 1.1, build 37.

## Architecture decisions
1. **NavigationSplitView for both macOS and iPad** — native resize, collapse, keyboard nav.
2. **OutlineGroup for macOS sidebar** — recursive `@ViewBuilder` functions cause opaque return type errors; OutlineGroup handles tree rendering natively.
3. **ScrollView + LazyVStack for iPad sidebar** — iOS `List` (UITableView) intercepts drop events, preventing per-row drop targets.
4. **FolderDropDelegate.currentFolderURL** — prevents self-drops (dropping into the folder you're already viewing). Shows forbidden cursor.
5. **handleInternalDrop derives path from URL** — fixed bug where concatenating `viewModel.folderPath + folderName` produced wrong paths for sidebar drops at different tree depths.

## Bug fixed
- `handleInternalDrop` was computing target path by concatenating current navigation path with folder name, which created duplicate folders when dropping from a different tree level. Now derives the relative path from the folder URL vs documents root.

## What's next
- Search behaviour in sidebar layout (scope to current folder vs global)
- Sidebar width persistence (@SceneStorage or @AppStorage)
- Empty sidebar state polish
- Idea logged: allow folders in select/bulk-delete workflow

## Known issues
None introduced this session.
