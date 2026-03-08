# Session Handoff — 2026-03-08

## What was completed

### Reverted work list feature for redesign

All work list code has been removed from the Yiana app (commit `cd5340a`). Eight attempts to make click navigation work inside the macOS sidebar `List(selection:)` failed. The root cause is architectural: `List(selection:)` uses ForEach item identity as implicit `.tag()`, so clicking any work list row sets the sidebar selection binding to the item's MRN, triggering folder navigation with a bogus path and wiping the navigation stack. No row-level modifier (`.selectionDisabled()`, tag guards, async dispatch) reliably prevents this because NSTableView owns the click at the platform level.

Full diagnostic evidence preserved in `docs/work-list-navigation-failures.md`.

The inline document rename feature (`5b21e8e`, `41bd43c`) was preserved through the revert.

**Deleted files:**
- `Yiana/Yiana/Models/WorkList.swift`
- `Yiana/Yiana/Services/ClinicListParser.swift`
- `Yiana/Yiana/Services/WorkListRepository.swift`
- `Yiana/Yiana/Services/WorkListSyncService.swift`
- `Yiana/Yiana/ViewModels/WorkListViewModel.swift`
- `Yiana/Yiana/Views/WorkListPanelView.swift`

**Note:** The Yiale app still has its own work list implementation (paste import, sidebar, patient boost). That code is untouched.

## What's next: work list feature redesign

The work list needs to be reimplemented from scratch. The specification below captures what the user wants.

### Specification

**Purpose:** Quick reference to files needed in a session. Lives in the sidebar, gives one-click access to documents the user is actively working with.

**Core behaviours:**

1. **Click to open.** Clicking a work list entry opens the associated document. Must work reliably on first click, every time.

2. **Accepts ambiguity, encourages specificity.** A name may match zero, one, or several documents:
   - Zero matches: `?` icon, no action. Common for Yiale-imported names where the note hasn't been created yet.
   - One match: click opens the document directly.
   - Multiple matches: picker sheet offers a choice. Once chosen, the association is saved.

3. **Persistent association.** Once a document is associated with a work list entry (by unique match or user choice), the association survives across sessions until the entry is removed.

4. **Yiale import.** The work list accepts lists from Yiale (the letter app). These may contain names for patients not yet seen. Once a document is created for that patient, the work list should find it (re-resolve when documents change).

5. **Add from within a document.** A mechanism from inside an open document to add it to the work list, with the document already associated.

6. **Remove.** Individual entries via context menu. Clear all via confirmation dialog.

### Architectural constraint (the lesson from eight failed attempts)

**The work list must NOT be inside the macOS sidebar `List(selection:)`.** The folder List uses `List(selection: $selectedSidebarFolder)` backed by NSTableView, which owns click gestures for all rows. Work list rows need a completely different click behaviour (push onto NavigationPath, not change sidebar selection).

The macOS sidebar should be structured as:
```
VStack(spacing: 0) {
    List(selection: $selectedSidebarFolder) {
        "Documents" row
        OutlineGroup (folders)
    }
    .listStyle(.sidebar)

    Divider()

    WorkListPanelView(...)  // Outside the List
}
```

On macOS, `WorkListPanelView` should use `DisclosureGroup` (standalone), not `Section` (requires List parent).

The iPad sidebar already uses `ScrollView + LazyVStack` (not List), so the work list can sit inside it as it did before. The iPad implementation worked correctly.

### Previous implementation (for reference)

The deleted code is available in git history. Key files and their roles:
- `WorkList.swift` — `WorkListItem` model (surname, firstName, MRN, doctor, age, gender)
- `ClinicListParser.swift` — Parses pasted clinic lists (`MRN / Surname, First (Gender, Age) / Doctor`)
- `WorkListRepository.swift` — Load/save `.worklist.json` from iCloud container
- `WorkListSyncService.swift` — Watches for external changes to `.worklist.json`, re-resolves URLs when documents change
- `WorkListViewModel.swift` — Observable viewmodel with add/remove/clear/import/resolve logic
- `WorkListPanelView.swift` — SwiftUI view (Section for macOS, DisclosureGroup for iPad)

The matching logic used surname + firstName (not MRN) to find documents. MRN was only used as a dictionary key for resolved URLs.

### What the previous implementation got wrong

1. Rendered inside `List(selection:)` on macOS — the root cause of all navigation failures
2. Used `Section(isExpanded:)` which requires a List parent
3. Used `.listRowBackground` which only works inside a List
4. Eight iterations of workarounds (tag guards, async dispatch, selectionDisabled, etc.) all failed

### What the previous implementation got right

1. The model (`WorkListItem`) and parser (`ClinicListParser`) were solid
2. Name-based matching (surname + firstName) worked
3. The picker sheet for ambiguous matches worked
4. The iPad rendering (DisclosureGroup in ScrollView) worked
5. The iCloud sync via `.worklist.json` worked
6. The paste import flow worked

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
