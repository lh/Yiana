# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Filename-based patient identity (4b2da72)
- `ExtractionHelpers.parsePatientFilename()` parses `Surname_Firstname_DDMMYY` from document ID
- Handles hyphenated names, apostrophes, trailing text, double underscores
- `ExtractionCascade.extractDocument()` overlays filename name + DOB as canonical
- 20 new tests in `FilenameParserTests.swift`

### City extraction improvements (4b2da72)
- `cityFromPostcodeLine()` helper — strips postcode from line, uses remainder
- FormExtractor: 3rd-address-line fallback
- FallbackExtractor: now extracts city
- python_better dropped from 22.4% to 19.5%; analysis showed ~50% of remaining gap is Python extracting junk

### Phase 1.5: Override file split + Python retirement
- **Override race condition fixed:** overrides now live in `{documentId}.overrides.json`, never touched by extraction
- **Migration:** on first launch, existing overrides (21 files, 132 entries) are migrated to separate files
- **DocumentExtractionService** no longer preserves overrides — writes pages + enriched only
- **Python extraction service stopped on Devon** — `launchctl unload` performed, service no longer running or registered
- Plist and Python code preserved for rollback if needed

### SSH / Devon connectivity
- SSH key loaded into macOS Keychain
- Devon renamed; SSH config updated to `Devon.local`

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** 52/52 pass
- **Python extraction:** STOPPED on Devon (2026-03-21)
- **Override format:** split into separate `.overrides.json` files

## Monitoring Period (2 weeks from 2026-03-21)

Python extraction is stopped. Monitor that:
- Addresses still appear correctly for newly OCR'd documents (Swift in-app extraction handles this)
- Existing overrides still display correctly (migration should have handled this)
- No data loss on documents with overrides

After 2 weeks (by 2026-04-04): remove LaunchAgent plist, archive Python extraction code.

## What's Next

### Postcode -> Town Lookup (idea #13, parked)
- Static outward code -> town dictionary (~2,900 entries, ~100KB)
- Replaces OCR-based city heuristics entirely
- Logged in Serena memory `ideas_and_problems`

### Phase 2: Entity Database
- Replace `backend_db.py` with GRDB-based entity resolution in Yiana
- Test corpus ready (Phase 0.2: 30 scenarios, 55 synthetic files)
- See `docs/consolidation-plan.md` Phase 2

## Key Files

| File | Purpose |
|------|---------|
| `Yiana/Services/AddressRepository.swift` | Split read/write — main file + .overrides.json |
| `Yiana/Services/DocumentExtractionService.swift` | Extraction writes pages + enriched only |
| `YianaExtraction/Models/AddressSchema.swift` | `OverridesFile` struct for separate overrides |
| `YianaExtraction/Utilities/ExtractionHelpers.swift` | Filename parser + city helpers |
| `YianaExtraction/Extractors/ExtractionCascade.swift` | Filename overlay logic |
| `docs/consolidation-plan.md` | Phase 1.5 checkboxes ticked, decisions logged |

## Known Issues
- 19.5% city python_better — ~200 real cases; postcode lookup (idea #13) would fix
- Patient name / DOB gaps likely closed by filename parsing (not yet re-validated on Devon)
- `feature/worklist-integration` branch from prior session still exists
- Devon hostname changed: SSH config uses `Devon.local`
- Python extraction plist still on Devon — remove after monitoring period
