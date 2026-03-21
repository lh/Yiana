# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 3.1: Deduplication — COMPLETE
- Deleted 4 Yiale duplicates: SharedWorkList, ClinicListParser, WorkListRepository, WorkListViewModel
- All had Yiana equivalents (equal or superset)
- Noted: Yiale has `replaceClinicList()` (replace-all semantics); Yiana only has merge. Logged for future.

### Phase 3.2: Port Models — COMPLETE
- `LetterDraft.swift` (LetterStatus, LetterPatient, LetterRecipient, LetterDraft) to `Yiana/Models/`
- `SenderConfig.swift` (Secretary, SenderConfig) to `Yiana/Models/`
- Pure data types, no changes needed

### Phase 3.3: Port Services — COMPLETE
- `LetterRepository.swift` to `Yiana/Services/` — singleton, per-service iCloud URL caching
- `SenderConfigService.swift` to `Yiana/Services/` — same pattern
- Replaced `ICloudContainer.shared` with Yiana's existing pattern (no central singleton)

### Phase 3.4: Patient Search — COMPLETE
- Added `searchPatients(query:limit:)` and `searchPractitioners(query:limit:)` to EntityDatabase
- LIKE on normalized name, DOB, or practice name; ordered by document_count DESC
- 12 new tests, 94 total pass

### Phase 3.5-3.7: Compose Module — COMPLETE (simplified)
- **Redesigned** instead of porting 9 Yiale views (~1100 LOC → ~300 LOC new)
- `ComposeViewModel.swift` — auto-fills patient (To) and GP (CC) from prime addresses, loads existing drafts, saves/sends via LetterRepository
- `ComposeTab.swift` — text area + status badge + save/send/print (macOS only)
- Added "Compose" tab to `DocumentInfoPanel` alongside Addresses/Metadata/OCR/Debug
- Recipients are rules-based (patient=To, GP=CC), body is markdown/plain text blob
- Deferred: PatientSearchView, RecipientEditor, DraftsListView, DraftDetailView, iOS compose, recipient tick boxes

### Design decisions made during session
- Compose replaces the info panel area (addresses are redundant once compose starts)
- No recipient editor — rules-based for now, tick boxes in AddressesView later
- No drafts list — draft status shown inline in compose tab
- Body text only — no greeting/salutation (render service handles topping/tailing)
- Build the simple thing, not port Yiale's complex views

### Improvements logged (not implemented)
- DOB stored as DD/MM/YYYY should be ISO 8601 (post-migration fix)
- Recipient tick boxes in AddressesView (To/CC/None per card)
- Drafts list sidebar mode (Folders / Work List / Drafts)

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both pass
- **Package tests:** 94 pass (82 existing + 12 new search tests)
- **Phase 2:** COMPLETE
- **Phase 3:** Steps 3.1-3.7 COMPLETE, Steps 3.8-3.9 remaining
- **Python on Devon:** All Python services stopped/removed. Only OCR (Swift) and render (LaunchAgent) remain.
- **Watchdog:** OCR-only, running via cron every 5min

## What's Next

### Step 3.8: Integration Testing

Manual verification of the compose-to-render-to-inject flow:
1. Open a document with extracted addresses → Compose tab → type body → Save Draft
2. Verify JSON appears in `.letters/drafts/`
3. Send to Print → verify `render_requested` status in JSON
4. Wait for Devon render service → verify PDF in `.letters/rendered/{letterId}/`
5. Verify InjectWatcher appends rendered PDF to document
6. Test on macOS (compose tab is macOS-only currently)

### Step 3.9: Retire Yiale

- Confirm all compose features work in Yiana
- Archive `Yiale/` directory
- Update CLAUDE.md and LETTER-MODULE-SPEC.md
- Remove Yiale.xcodeproj from any workspace references

## Key Files

| File | Purpose |
|------|---------|
| `Yiana/Yiana/Views/Compose/ComposeTab.swift` | Compose tab view (macOS) |
| `Yiana/Yiana/ViewModels/ComposeViewModel.swift` | Compose logic — load/save/send drafts |
| `Yiana/Yiana/Views/DocumentInfoPanel.swift` | Info panel with Compose tab added |
| `Yiana/Yiana/Models/LetterDraft.swift` | Letter draft model (ported from Yiale) |
| `Yiana/Yiana/Services/LetterRepository.swift` | Draft CRUD + render status (ported from Yiale) |
| `Yiana/Yiana/Services/SenderConfigService.swift` | Sender config loader (ported from Yiale) |
| `YianaExtraction/Sources/.../EntityDatabase.swift` | Patient/practitioner search methods |
| `docs/phase-3-plan.md` | Detailed Phase 3 plan with checklists |
| `docs/consolidation-plan.md` | Master consolidation plan (Phases 0-4) |

## Known Issues
- Python extraction plist still on Devon — remove after monitoring period (2026-04-04)
- `feature/worklist-integration` branch from prior session still exists
- Devon hostname: SSH config uses `Devon.local`
- 6.8% city python_better — residual gap; async postcode updater will close (future)
- iOS has no compose access yet (info panel is macOS-only)
- `LetterRepository.cacheContainerURL()` and `SenderConfigService.cacheContainerURL()` must be called from main thread before use — not yet wired into app startup
