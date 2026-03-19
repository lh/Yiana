# Session Handoff — 2026-03-19

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

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** 88/88 pass
- **Clean working tree** (except `.serena/project.yml` and `nhs_lookup.db.bak`)

## Manual Testing Required

Before Phase 1.4, these need hands-on verification:

- [ ] **Scan a new document on iOS** — after OCR completes, open AddressesView and confirm extracted addresses appear (patient name, address, GP info)
- [ ] **Verify NHS candidates appear** — for a document with a GP postcode that exists in the NHS DB, check that `nhs_candidates` entries show in the GP section of AddressesView
- [ ] **Re-scan an existing document that has user overrides** — confirm overrides survive re-extraction (override data should not be lost)
- [ ] **Import a .yianazip on macOS** — open the document, check AddressesView shows extracted data
- [ ] **Check .addresses/ file on disk** — after extraction, verify the JSON file exists in iCloud `.addresses/` with correct snake_case keys, matching the Python output format
- [ ] **Verify Python extraction still works in parallel** — Devon should still process documents independently; both Swift and Python output should coexist without conflict (they write the same filename, so whichever runs last wins — this is expected during parallel operation)

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
