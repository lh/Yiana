# Session Handoff — 2026-03-07

## What was completed

### Clinic Work List — Yiale paste import + patient boost

Added a clinic work list feature to Yiale. Users paste a clinic list (copied from a web page) the evening before a session. Parsed patients appear in the sidebar and are prioritized in patient search.

**New files:**
- `Yiale/Yiale/Models/WorkList.swift` — `WorkList`, `WorkListItem` (Codable, MRN as ID, `nameKey` for matching)
- `Yiale/Yiale/Services/ClinicListParser.swift` — Static parser for `MRN / Surname, First (Gender, Age) / Doctor` blocks
- `Yiale/Yiale/Services/WorkListRepository.swift` — Load/save/clear `.worklist.json`, atomic writes, follows `LetterRepository` pattern
- `Yiale/Yiale/ViewModels/WorkListViewModel.swift` — `@Observable`, load/import/replace/remove/clear, file I/O via `Task.detached`
- `Yiale/Yiale/Views/ClinicListImportSheet.swift` — Paste sheet with live preview, Import (merge) and Replace buttons

**Edited files:**
- `ICloudContainer.swift` — Added `workListURL` (`.worklist.json`, dot-prefixed, invisible to Yiana)
- `AddressSearchService.swift` — `findPatient(for:)` and `workListPatients(items:)` matching by normalized name
- `DraftsListView.swift` — Clinic List section with count, Clear toolbar button, `SidebarItem` enum tags
- `PatientSearchView.swift` — Work list suggestions when search empty, boost in search results, clipboard badge
- `ContentView.swift` — `SidebarItem` enum replacing `String?` selection, wires work list VM + import sheet

**Key decisions and learnings:**
- **MRN is unreliable as a matching key.** Document IDs use `Surname_Firstname_ddmmyy`, not MRN. Matching is by normalized name: `WorkListItem.nameKey` is `Set<String>` of lowercased `{surname, firstName}`, matched as a subset of `ResolvedPatient.fullName` word tokens. Order-independent.
- **macOS `List(selection:)` swallows all click gestures** — neither `.onTapGesture` nor `Button(.plain)` fire their actions inside it. Fix: use typed `SidebarItem` enum with `.tag()` on every row, route via `onChange(of: sidebarSelection)`. Three iterations to get this right.
- **Sidebar selection needs a typed enum, not `String?`** — work list patients and drafts are different item types. `SidebarItem.workListPatient(mrn)` vs `.draft(letterId)` ensures each click produces a distinct value for SwiftUI change detection.

**Storage:**
- `.worklist.json` in iCloud container `Documents/` (dot-prefixed = hidden from Yiana's document browser)
- Syncs via iCloud automatically
- No server interaction — entirely Yiale-side

**Commits:**
- `e9f5011` — Initial implementation (5 new files, 5 edits)
- `37de778` — Fix click routing (SidebarItem enum)
- `3f3bab3` — Name-based matching, clear button, Xcode project settings

### Xcode project modernization (applied via Xcode recommendation dialog)
- Dead code stripping enabled (target + project)
- Development team inherited from project settings
- Sandbox/Hardened Runtime entitlements migrated to build settings
- String Catalog symbol generation enabled

## What's in progress
Nothing actively in progress.

## What's next

### Yiana sync prioritization for work list patients
- Yiana should prioritize iCloud sync for documents matching work list patients
- **Must be invisible to Yiana users who don't have Yiale set up** — if `.worklist.json` doesn't exist, no behavior change
- Approach: Yiana reads `.worklist.json` from the iCloud container (if present), matches document filenames against work list names, and prioritizes download/sync for those documents
- Document filenames follow `Surname_Firstname_ddmmyy.yianazip` — can match against `WorkListItem.surname` + `WorkListItem.firstName`
- Consider: should Yiana re-check the work list periodically, or only on app launch?
- The `WorkList` and `WorkListItem` models are in Yiale — Yiana will need its own copy or a shared package

### Other pending
- End-to-end Yiale test with real clinic session
- Yiale iOS/iPadOS adaptation
- Cleanup of superseded components

## Known issues
- iCloud `[ERROR] [Progress]` noise when InjectWatcher renames/deletes `.processing` file — harmless
- Transient "database is locked" on reindex after inject append — resolves on next UbiquityMonitor cycle
- `AddressSearch` loads twice on work list patient click (once eagerly in ContentView, once in PatientSearchView `.task {}`) — redundant but harmless, could deduplicate later
- Untracked `Yiale/Yiale.xcodeproj/project.xcworkspace/` — auto-generated, not committed

## Devon services status
| Service | Type | Status |
|---|---|---|
| `com.vitygas.yiana-ocr` | LaunchDaemon | Running |
| `com.vitygas.yiana-extraction` | LaunchAgent | Running |
| `com.vitygas.yiana-dashboard` | LaunchAgent | Running |
| `com.vitygas.yiana-render` | LaunchAgent | Running |
