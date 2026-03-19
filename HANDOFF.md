# Session Handoff — 2026-03-19

## Branch
`consolidation/v1.1` — not yet pushed (2 uncommitted changes from this session).

## What Was Done This Session

### Phase 1.2: NHS/ODS Lookup in Swift (committed: d9b99c9)
- `NHSLookupService` with GRDB — full port of Python's `NHSLookup.lookup_gp()`
- 25 test cases + 1 integration test, all passing

### Phase 1.3: Wire Extraction Into Yiana (uncommitted)
- **Per-page OCR data:** Extended `OnDeviceOCRResult` with `pages: [PageResult]` array (1-based page numbers, per-page text + confidence). Backwards-compatible — existing `fullText`/`confidence` unchanged.
- **nhs_lookup.db bundled:** Copied into `Yiana/Yiana/` directory for auto-inclusion in both iOS and macOS targets (2.1MB).
- **DocumentExtractionService:** New singleton service that:
  - Takes OCR results, builds `ExtractionInput` per page
  - Runs `ExtractionCascade.extractDocument()`
  - Enriches GP entries via `NHSLookupService.lookupGP()` with practice/name hints
  - Read-merge-writes to preserve user overrides and backend enrichment
  - Atomic writes to `.addresses/{documentTitle}.json`
  - All errors logged, never thrown
- **Wired into all 4 OCR trigger points:**
  1. iOS `DocumentViewModel.init` (line ~72)
  2. macOS `DocumentViewModel.init` (line ~814)
  3. `ContentView.performOCROnImportedDocument` (line ~295)
  4. `DocumentEditView` scan completion (line ~981)
- **Document ID:** Uses `metadata.title` (filename stem), matching Python convention and what `AddressRepository` callers pass.

### Phase 1.3 plan written
- `docs/phase-1.3-plan.md` — detailed 3-session plan (sessions 1-3 all done in one pass)

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** 88/88 pass (unchanged from Phase 1.2)
- **Uncommitted:** Phase 1.3 files ready to commit

## What's Next

### Remaining for Phase 1.3
- [ ] Manual test: scan document on device, verify addresses appear in AddressesView

### Phase 1.4: Parallel Validation
- Run Swift extraction on all 1441 documents Python has already processed
- Compare outputs field-by-field, log discrepancies

### Phase 1.5: Retire Python Extraction on Devon

## Key Files

| File | Purpose |
|------|---------|
| `Yiana/Yiana/Services/OnDeviceOCRService.swift` | Added per-page OCR data |
| `Yiana/Yiana/Services/DocumentExtractionService.swift` | New — extraction + NHS lookup bridge |
| `Yiana/Yiana/ViewModels/DocumentViewModel.swift` | Hooked extraction after OCR (both platforms) |
| `Yiana/Yiana/ContentView.swift` | Hooked extraction after import OCR |
| `Yiana/Yiana/Views/DocumentEditView.swift` | Hooked extraction after scan |
| `Yiana/Yiana/nhs_lookup.db` | Bundled NHS ODS database |
| `docs/phase-1.3-plan.md` | Detailed plan |
| `docs/consolidation-plan.md` | Phase 1.3 checkboxes ticked |

## Known Issues
- Manual end-to-end test not yet done (needs device or simulator with iCloud)
- Python extraction on Devon still runs (intentional — parallel operation until Phase 1.5)
- `feature/worklist-integration` branch from prior session still exists
- FallbackExtractor has no dedicated test assertions — Fisher_Victor is a known divergence
