# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 2.2: Wire EntityDatabase Into Yiana — COMPLETE
- `EntityDatabaseService` singleton in `Yiana/Services/EntityDatabaseService.swift`
- DB stored in `Caches/EntityDatabase/entities.db` (not iCloud)
- Ingestion hooked after extraction in `DocumentExtractionService.extractAndSave()`
- Lazy ingestion in `AddressesView.loadAddresses()` for pre-deployment documents
- `ingestAll()` method ready for boss instance (Phase 4)
- AddressCard shows "Seen in N documents" for patient and GP names (N > 1, view mode only)

### Phase 2.3: Parallel Validation — COMPLETE
- CLI `--ingest-all` mode added to yiana-extract
- 1442/1442 files ingested on Devon, zero failures
- All entity counts within 5% of Python backend (patients +1.6%, practitioners +0.5%, links +2.0%)
- Extraction count +12.7% — Swift cascade more thorough, not a discrepancy
- +2 Consultant practitioners (Python only tracked GPs)

### Phase 2.4: Retire Python Backend DB — COMPLETE
- `extraction_service.py --nhs-enrich` cron removed from Devon (ran every 2min)
- `addresses_backend.db` archived to `~/Data/archive/addresses_backend.db.2026-03-21`
- `backend_db.py --ingest` was manual, never automated

### Watchdog simplified
- Removed Extraction heartbeat check (service retired)
- Watchdog now monitors OCR service only — stops false alerts

### Process improvements
- `CLAUDE-CHANGELOG.md` created — backfilled 12 entries from project inception
- Session protocol updated: rule changes to CLAUDE.md must be logged in changelog
- Phase transition tags added for all completed phases (0 through 2.4)

### Phase 3 plan written
- `docs/phase-3-plan.md` — full inventory of 24 Yiale files (~2400 LOC)
- 9-step implementation plan with checklists
- Design decisions resolved (side-by-side compose, body-text-only editing, LaTeX rendering, separate work list and drafts)

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both pass
- **Package tests:** 82 pass
- **Phase 2:** COMPLETE (all 4 sub-phases done)
- **Phase 3:** PLANNED, not started
- **Python on Devon:** All Python services stopped/removed. Only OCR (Swift) and render (LaunchAgent) remain.
- **Watchdog:** OCR-only, running via cron every 5min

## What's Next

### Phase 3: Letter Composition (Yiale Absorption)

Start with **Step 3.1: Preparation and deduplication**.

Detailed plan at `docs/phase-3-plan.md`. Summary of steps:

1. **3.1** — Delete Yiale duplicates (SharedWorkList, WorkListRepository, ClinicListParser, WorkListViewModel)
2. **3.2** — Port models (LetterDraft, SenderConfig)
3. **3.3** — Port services (LetterRepository, SenderConfigService)
4. **3.4** — Port patient search (entity DB migration — add searchPatients())
5. **3.5** — Port compose views (9 files to Views/Compose/)
6. **3.6** — Port view models (ComposeViewModel, DraftsViewModel)
7. **3.7** — Wire into Yiana navigation (side-by-side pattern, iterative design)
8. **3.8** — Integration testing (compose-to-render-to-inject flow)
9. **3.9** — Retire Yiale

### Design decisions (resolved)
- Compose view must NOT obscure the document (side-by-side)
- Patient/GP/specialists auto-fill from document context
- User writes body text only; topping/tailing is automatic
- LaTeX rendering stays on Devon
- Work list and drafts are separate views

## Key Files

| File | Purpose |
|------|---------|
| `docs/phase-3-plan.md` | Detailed Phase 3 plan with checklists |
| `docs/consolidation-plan.md` | Master consolidation plan (Phases 0-4) |
| `docs/LETTER-MODULE-SPEC.md` | Letter architecture spec (draft JSON, directory structure, render flow) |
| `Yiale/` | Source app to be absorbed (24 files, ~2400 LOC) |
| `Yiana/Services/EntityDatabaseService.swift` | Entity DB singleton (patient/practitioner queries) |
| `Yiana/Services/InjectWatcher.swift` | Already in Yiana — appends rendered PDFs to documents |
| `CLAUDE-CHANGELOG.md` | Tracks rule changes to CLAUDE.md with reasoning |
| `scripts/yiana-watchdog.sh` | OCR-only watchdog (deployed to Devon) |

## Known Issues
- Python extraction plist still on Devon — remove after monitoring period (2026-04-04)
- `feature/worklist-integration` branch from prior session still exists
- Devon hostname: SSH config uses `Devon.local`
- 6.8% city python_better — residual gap; async postcode updater will close (future)
