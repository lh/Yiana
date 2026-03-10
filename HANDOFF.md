# Session Handoff — 2026-03-08

## What was completed

### Work list feature — implemented, tested, merged to main

Full work list redesign using segmented control to separate folders and work list in the sidebar. Merged to main via `0221d7a`. All phases of the plan completed including two bug fixes found during user testing.

**Bug fixes during testing:**
- Picker sheet empty on first open — switched from `.sheet(isPresented:)` to `.sheet(item:)` with `PickerData` struct (`2db8b67`)
- Duplicate entries allowed — added dedup guards to `addManual` and `addFromDocument` (`93f7358`)

### TestFlight deployments

- **Yiana** build 41 uploaded to App Store Connect (iOS + macOS) — `3796d4a`
- **Yiale** build 1 uploaded to App Store Connect (macOS only) — first-ever TestFlight submission
  - Created `Yiale/ExportOptions.plist` for uploads (`3b36405`)
  - Added `ITSAppUsesNonExemptEncryption = NO` to Yiale pbxproj (`699d290`)
  - **Status: Waiting for Apple beta review** — first macOS TestFlight build requires manual review (24-48 hours typical)

### CLAUDE.md updates

Added rules learned from work list implementation (`95ac55e`):
- `List(selection:)` owns all clicks — never mix interaction models
- `.sheet(item:)` not `.sheet(isPresented:)` for data-dependent sheets
- Deployment gotchas for Devon (launchd env, PATH)
- Debugging: simplest hypothesis first
- Session protocol: commit and push before session end

### Housekeeping

- Tracked `Yiale/Yiale.xcodeproj/project.xcworkspace/contents.xcworkspacedata` (`d585d48`)
- Added `Icon_material/` to `.gitignore`

## Files created this session

- `Yiana/Yiana/Models/WorkListEntry.swift`
- `Yiana/Yiana/Services/WorkListRepository.swift`
- `Yiana/Yiana/Services/ClinicListParser.swift`
- `Yiana/Yiana/Services/YialeSyncService.swift`
- `Yiana/Yiana/ViewModels/WorkListViewModel.swift`
- `Yiana/Yiana/Views/WorkListView.swift`
- `Yiale/ExportOptions.plist`

## Files modified this session

- `Yiana/Yiana/AppDelegate.swift` — `.yialeWorkListChanged` notification
- `Yiana/Yiana/Views/DocumentListView.swift` — segmented sidebar, environment object injection
- `Yiana/Yiana/Views/DocumentReadView.swift` — star button (macOS)
- `Yiana/Yiana/Views/DocumentEditView.swift` — star button (iPad)
- `Yiana/Yiana.xcodeproj/project.pbxproj` — build 41, new source files
- `Yiale/Yiale.xcodeproj/project.pbxproj` — export compliance flag
- `CLAUDE.md` — new rules
- `.gitignore` — Icon_material/

## Pending / needs attention

- **Yiale TestFlight review** — check App Store Connect; should clear within 24-48 hours
- **Work list end-to-end Yiale sync** — not yet tested with real Yiale data (Yiale needs to be running with `.worklist.json` output)
- **Auto-resolution on document import** — works via `.yianaDocumentsChanged` notification; verify with real documents

## Known issues

- iCloud `[ERROR] [Progress]` noise when InjectWatcher renames/deletes `.processing` file — harmless
- Transient "database is locked" on reindex after inject append — resolves on next UbiquityMonitor cycle

## Branch status

- All work merged to `main`, pushed to remote
- `feature/work-list-redesign` branch still exists (can be deleted)
- Working tree clean
