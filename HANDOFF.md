# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 3: Letter Composition (Yiale Absorption) — COMPLETE

All 9 steps completed in a single session:

| Step | Summary |
|------|---------|
| 3.1 | Deleted 4 Yiale duplicates (SharedWorkList, ClinicListParser, WorkListRepository, WorkListViewModel) |
| 3.2 | Ported LetterDraft + SenderConfig models to Yiana |
| 3.3 | Ported LetterRepository + SenderConfigService with per-service iCloud URL caching |
| 3.4 | Added searchPatients/searchPractitioners to EntityDatabase (12 new tests, 94 total) |
| 3.5-3.7 | Built simplified compose module — tab in DocumentInfoPanel, ~300 LOC instead of porting ~1100 LOC from Yiale |
| 3.8 | Integration testing — full compose-to-render-to-inject flow verified on macOS |
| 3.9 | Retired Yiale — directory removed, LETTER-MODULE-SPEC.md rewritten |

### Key design decisions made during session
- **Compose is a tab in the info panel**, not a separate view or app
- **Recipients are rules-based** (patient=To, GP=CC, hospital_records=implicit) — no manual editor
- **Body text only** — no greeting/salutation (render service handles topping/tailing)
- **Drafts list deferred** — draft status shown inline in compose tab
- **Build the simple thing**, not port Yiale's complex views (~300 LOC vs ~2400 LOC)

### Bugs found and fixed during testing
- Missing `hospital_records` implicit recipient — render service needs this to produce the inject PDF
- Missing `cacheContainerURL()` calls — iCloud URL must be cached on main thread before file I/O

### Issues logged (not fixed)
- DOB stored as DD/MM/YYYY should be ISO 8601 (post-migration improvement)
- Recipient tick boxes in AddressesView (To/CC/None per card) — future iteration
- HTML render template: leading comma when sender department is empty (cosmetic, PDF is fine)
- Document doesn't auto-reload after InjectWatcher appends PDF (requires close/reopen)
- Drafts list sidebar mode (Folders / Work List / Drafts) — future iteration

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both pass
- **Package tests:** 94 pass
- **Phase 2:** COMPLETE
- **Phase 3:** COMPLETE (all 9 steps)
- **Yiale:** RETIRED (directory removed, git preserves history)
- **Python on Devon:** OCR (Swift) and render (Python/LaTeX) services running. All other Python services stopped.
- **Watchdog:** OCR-only, running via cron every 5min

## What's Next

### Phase 4: Boss Instance Configuration

Make the Mac mini's Yiana instance the always-on "boss":
- Auto-process all unprocessed documents at startup
- Background extraction for new documents
- Entity database full rebuild on demand
- macOS login item support
- Integration hooks (file copy, email, webhooks)
- Retire server scripts (watchdog, dashboard, OCR LaunchDaemon)

Detailed plan in `docs/consolidation-plan.md` Phase 4 section.

### Remaining Phase 1.5 monitoring
- Python extraction plist still on Devon — remove after monitoring period (2026-04-04)

## Key Files

| File | Purpose |
|------|---------|
| `Yiana/Yiana/Views/Compose/ComposeTab.swift` | Compose tab view (macOS) |
| `Yiana/Yiana/ViewModels/ComposeViewModel.swift` | Compose logic — load/save/send drafts |
| `Yiana/Yiana/Views/DocumentInfoPanel.swift` | Info panel with Compose tab |
| `Yiana/Yiana/Models/LetterDraft.swift` | Letter draft model |
| `Yiana/Yiana/Services/LetterRepository.swift` | Draft CRUD + render status |
| `Yiana/Yiana/Services/SenderConfigService.swift` | Sender config loader |
| `Yiana/Yiana/Services/EntityDatabaseService.swift` | Entity DB with patient/practitioner search |
| `docs/LETTER-MODULE-SPEC.md` | Letter module spec (updated for compose-in-Yiana) |
| `docs/consolidation-plan.md` | Master consolidation plan (Phases 0-4) |
| `docs/phase-3-plan.md` | Phase 3 detailed plan with all checklists |

## Known Issues
- Python extraction plist still on Devon — remove after 2026-04-04
- `feature/worklist-integration` branch from prior session still exists
- Devon hostname: SSH config uses `Devon.local` (connection issues observed)
- 6.8% city python_better — residual gap; async postcode updater will close
- iOS has no compose access yet (info panel is macOS-only)
- Document doesn't auto-reload after InjectWatcher appends PDF
