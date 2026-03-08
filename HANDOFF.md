# Session Handoff — 2026-03-08

## What was completed

### Work list feature reimplemented on `feature/work-list-redesign`

Four commits on the branch implement the full work list feature from the approved plan:

1. **Data layer** (`84fca92`) — `WorkListEntry` model, `WorkListRepository` (iCloud persistence), `ClinicListParser` (restored and adapted), `WorkListViewModel` (resolution, auto-resolve, Yiale merge), `YialeSyncService` (NSMetadataQuery watching `.worklist.json`)

2. **Sidebar UI** (`33b5302`) — `DocumentSidebarMode` segmented picker ("Folders" / "Work List") in both macOS and iPad sidebars. `WorkListView` using `ScrollView + LazyVStack` (not List). Folder sidebar code extracted to `folderSidebarContent` computed property. iPhone shows folders only.

3. **Star button** (`bbbc67a`) — `WorkListViewModel` injected as `@EnvironmentObject` on navigation destinations. Star button in `DocumentReadView` toolbar (macOS) and `DocumentEditView` toolbar (iPad) toggles documents in/out of work list.

4. **Polish** (`5eca8bd`) — Fixed filename stem handling to avoid double-stripping extensions on names containing dots.

### Key architectural decisions

- **Segmented control** replaces the divider approach from the previous handoff. Folders and work list never coexist — they swap the entire sidebar content.
- **Work list is completely outside `List(selection:)`** — macOS sidebar wraps both views in a VStack with the picker above. No List selection interaction.
- **Resolution via SearchIndexService** — entries search the FTS5 index. 0 matches = `?` indicator, 1 match = auto-resolve, N matches = picker sheet.
- **File format**: `.yiana-worklist.json` in iCloud Documents folder. Separate from Yiale's `.worklist.json`.
- **Yiale sync**: `YialeSyncService` watches `.worklist.json` via `NSMetadataQuery`, posts `.yialeWorkListChanged` notification. ViewModel merges by MRN — adds new, removes gone, keeps existing.

### Files created (6)
- `Yiana/Yiana/Models/WorkListEntry.swift`
- `Yiana/Yiana/Services/WorkListRepository.swift`
- `Yiana/Yiana/Services/ClinicListParser.swift`
- `Yiana/Yiana/Services/YialeSyncService.swift`
- `Yiana/Yiana/ViewModels/WorkListViewModel.swift`
- `Yiana/Yiana/Views/WorkListView.swift`

### Files modified (4)
- `Yiana/Yiana/AppDelegate.swift` — added `.yialeWorkListChanged` notification name
- `Yiana/Yiana/Views/DocumentListView.swift` — segmented picker, sidebar mode state, environment object injection
- `Yiana/Yiana/Views/DocumentReadView.swift` — star button in toolbar (macOS)
- `Yiana/Yiana/Views/DocumentEditView.swift` — star button in toolbar (iPad)

### Build status
- macOS: passes
- iOS: passes

### Branch status
- Branch: `feature/work-list-redesign` (4 commits ahead of main)
- Clean working tree (no uncommitted changes)
- Not pushed to remote

## What needs testing

1. **macOS:** segmented control switches cleanly, folder navigation unaffected
2. **macOS:** add manual entry, click, verify document opens
3. **macOS:** star button in toolbar toggles entry, reflected in work list
4. **iPad:** same as 1-3
5. **Multiple matches:** picker appears, selection persists across clicks
6. **Auto-resolution:** create entry for non-existent document name, import/create that document, verify entry auto-resolves on next `.yianaDocumentsChanged`
7. **Clear all:** wipes everything, Yiale re-sync repopulates
8. **Stale resolution:** rename a document after resolution, click entry, verify falls back to search
9. **Paste import:** macOS clipboard paste, iPad paste sheet — verify clinic list parsing

## What could need adjustment after testing

- Picker sheet sizing and presentation (may need tuning)
- Whether auto-resolve on `.yianaDocumentsChanged` is fast enough or needs debouncing
- The segmented control label ("Work List (N)") could look crowded with many entries
- Whether `NSMetadataQueryUbiquitousDocumentsScope` correctly scopes to find `.worklist.json` — may need `NSMetadataQueryUbiquitousDataScope` instead

## Known issues
- iCloud `[ERROR] [Progress]` noise when InjectWatcher renames/deletes `.processing` file — harmless
- Transient "database is locked" on reindex after inject append — resolves on next UbiquityMonitor cycle
- Untracked `Yiale/Yiale.xcodeproj/project.xcworkspace/` — auto-generated, not committed

## Devon services status
| Service | Type | Status |
|---|---|---|
| `com.vitygas.yiana-ocr` | LaunchDaemon | Running |
| `com.vitygas.yiana-extraction` | LaunchAgent | Running |
| `com.vitygas.yiana-dashboard` | LaunchAgent | Running |
| `com.vitygas.yiana-render` | LaunchAgent | Running |
