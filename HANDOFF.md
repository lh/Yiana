# Session Handoff — 2026-03-20

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 1.2: NHS/ODS Lookup in Swift (d9b99c9)
- `NHSLookupService` with GRDB — full port of Python's `NHSLookup.lookup_gp()`
- 25 test cases + 1 integration test, all passing

### Phase 1.3: Wire Extraction Into Yiana (4849897)
- `OnDeviceOCRResult` extended with per-page text/confidence
- `DocumentExtractionService` — OCR -> extraction -> NHS lookup -> atomic write
- `nhs_lookup.db` bundled in app (2.1MB)
- All 4 OCR trigger points wired
- Document ID uses `metadata.title` (filename stem) matching Python convention

### Manual Testing (2026-03-20)
Real document scanned: `Groves_Simon_250870` (Test directory, real data — do not commit).

- [x] **Scan new document on iOS** — `Extracted 1 pages` logged, patient name/DOB/phone/postcode appeared in AddressesView
- [x] **NHS candidates** — RH1 2NP lookup returned HOLMHURST MEDICAL CENTRE (H81048) + THE HOUSE PARTNERSHIP (H81030)
- [x] **macOS sees data** — extraction result synced via iCloud, AddressesView shows same data
- [x] **JSON format** — snake_case keys, correct structure, matches Python schema
- [x] **Devon parallel** — Python extraction did not re-process; iCloud-synced file coexists without conflict
- [~] **Override survival** — override added on macOS was lost when iOS re-extracted before sync completed. Code logic is correct (read-merge-write), but iCloud eventual consistency means cross-device edits can race. See "Open Design Question" below.

### Extraction Quality Issues (logged in Serena memory ideas_and_problems #9-11)
- Address lines not extracted (postcode only, no street)
- Duplicate phone numbers when source has duplicates
- GP data missed on first single-page scan, found on second 2-page scan

## Open Design Question: iCloud Override Race Condition

When user edits an override on device A and device B re-extracts before sync completes, the override is lost. The read-merge-write logic is correct — the problem is that device B's local copy of the .addresses/ file doesn't yet contain device A's override.

Options to consider:
1. **Timestamp-based merge** — compare `overrideDate` timestamps and keep the most recent, even across conflicting writes
2. **Separate override file** — write overrides to `{documentId}.overrides.json` so extraction never touches user edits
3. **Last-write-wins with notification** — detect when extraction overwrites a newer file and surface a warning
4. **Accept the limitation** — document that overrides should be made on the same device that scans, or wait for sync before re-scanning

This needs a decision before Phase 1.5 (retiring Python). During parallel operation it's low-risk since both Swift and Python write the same format.

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** 88/88 pass
- **Clean working tree** (except `.serena/project.yml` and `nhs_lookup.db.bak`)

## What's Next

### Phase 1.4: Parallel Validation
- Run Swift extraction on all 1441 documents Python has already processed
- Compare outputs field-by-field, log discrepancies
- Review: is Swift wrong, or is Swift better?

### Phase 1.5: Retire Python Extraction on Devon

## Key Files

| File | Purpose |
|------|---------|
| `Yiana/Yiana/Services/OnDeviceOCRService.swift` | Per-page OCR data |
| `Yiana/Yiana/Services/DocumentExtractionService.swift` | Extraction + NHS lookup bridge |
| `Yiana/Yiana/ViewModels/DocumentViewModel.swift` | Extraction hooks (both platforms) |
| `Yiana/Yiana/nhs_lookup.db` | Bundled NHS ODS database |
| `docs/phase-1.3-plan.md` | Detailed plan |

## Known Issues
- Python extraction on Devon still runs (intentional — parallel operation until Phase 1.5)
- `feature/worklist-integration` branch from prior session still exists
- FallbackExtractor has no dedicated test assertions — Fisher_Victor is a known divergence
