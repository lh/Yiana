# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Filename-based patient identity (4b2da72)
- `ExtractionHelpers.parsePatientFilename()` parses `Surname_Firstname_DDMMYY`
- `ExtractionCascade.extractDocument()` overlays filename name + DOB as canonical
- 20 new tests in `FilenameParserTests.swift`

### City extraction improvements (4b2da72)
- `cityFromPostcodeLine()` helper across all extractors
- FormExtractor: 3rd-address-line fallback
- FallbackExtractor: now extracts city

### Phase 1.5: Override file split + Python retirement (6183d4a)
- Overrides split into `{documentId}.overrides.json` — fixes iCloud race condition
- One-time migration for 21 existing override files (132 entries)
- DocumentExtractionService writes pages + enriched only
- Python extraction service stopped on Devon (2026-03-21)

### CLI document ID fix (4e26cde)
- CLI now accepts `--document-id` flag for filename-based extraction
- Comparison script passes filename stem, matching in-app behaviour

### Postcode sector -> town lookup (2325d11)
- 254 postcode sectors mapped to towns via postcodes.io BUA data
- `PostcodeLookup.swift` — static dictionary in YianaExtraction package
- `ExtractionHelpers.townForPostcode()` used as fallback in all 4 extractors
- City python_better dropped from 22.4% to **6.8%**, swift_better up to **9.1%**

### Phase 2.1: Entity Database Schema — COMPLETE (728be19, c6e5ba9)
- **Steps 1-2:** GRDB records (8 tables), schema migration, `normalizeName()`, 21 tests
- **Steps 3-5:** `resolvePatient`, `resolvePractitioner`, `linkPatientPractitioner`,
  `ingestAddressFile` with content hash idempotency, override map, filename-based
  patient ownership, cross-row linking (same-page + single-patient document)
- 30/30 corpus scenarios pass, 82 total tests
- Architecture decision: entity DB is a local derived cache, rebuildable from iCloud JSON

### SSH / Devon
- SSH key loaded into macOS Keychain
- Devon hostname updated to `Devon.local` in SSH config

### Validation Results (final, all improvements)
| Field | Match | Swift-better | Python-better |
|-------|-------|-------------|---------------|
| postcode | 97.6% | 0.1% | 0.4% |
| patient.name | 15.8% | 9.8% | 0.4% |
| city | 65.2% | 9.1% | 6.8% |
| gp.postcode | 8.5% | 1.7% | 0% |
| DOB | 22.2% | 68.5% | 0.4% |
| NHS candidates | 1.5% | 31.0% | 0% |

Note: patient.name and DOB "different" are expected — Swift uses filename
as canonical, which is more reliable than Python's OCR-extracted values.

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** 82 pass (73 prior + 8 entity edge cases + test count growth)
- **Python extraction:** STOPPED on Devon (2026-03-21)
- **Override format:** split into separate `.overrides.json` files
- **Phase 2.1:** COMPLETE — entity database schema, resolution, and ingestion all working

## Monitoring Period (2 weeks from 2026-03-21)

Python extraction is stopped. Monitor through 2026-04-04 that:
- Addresses still appear correctly for newly OCR'd documents
- Existing overrides still display correctly
- No data loss on documents with overrides

After monitoring: remove LaunchAgent plist, archive Python extraction code.

## What's Next

### Phase 2.2: Wire Into Yiana — INGESTION COMPLETE
- EntityDatabaseService singleton in `Yiana/Services/EntityDatabaseService.swift`
- DB stored in `Caches/EntityDatabase/entities.db` (not iCloud)
- Ingestion hooked after extraction in `DocumentExtractionService.extractAndSave()`
- Lazy ingestion in `AddressesView.loadAddresses()` for pre-deployment documents
- `ingestAll()` method ready for boss instance (not auto-triggered — Phase 4)
- AddressCard shows "Seen in N documents" for patient and GP names (N > 1, view mode only)
- Queries EntityDatabaseService at load time, matches practitioners by name

### Phase 2.3: Parallel Validation -- DONE (2026-03-21)
- 1442/1442 files ingested, zero failures
- All entity counts within 5% of Python backend (patients +1.6%, practitioners +0.5%, links +2.0%)
- Extraction count +12.7% — Swift cascade is more thorough, not a discrepancy
- +2 Consultant practitioners (Python only tracked GPs)
- CLI `--ingest-all` mode added to yiana-extract for validation

### Phase 2.4: Retire Python Backend DB -- DONE (2026-03-21)
- `backend_db.py --ingest` was manual, never automated — nothing to stop
- `extraction_service.py --nhs-enrich` cron removed (ran every 2min, now redundant)
- `addresses_backend.db` archived to `~/Data/archive/addresses_backend.db.2026-03-21` (2.0MB)
- Python code stays in repo (git history); LaunchAgent plists still on Devon (stopped)

### Postcode lookup async updater (future)
- When a sector isn't in the static table, query postcodes.io live and cache
- Grows the table organically over time
- Logged in Serena memory `ideas_and_problems` (idea #13)

## Key Files

| File | Purpose |
|------|---------|
| `YianaExtraction/Services/EntityDatabase.swift` | Entity resolution, ingestion, GRDB schema (public records + queries) |
| `Yiana/Services/EntityDatabaseService.swift` | App-layer singleton — ingestDocument, ingestAll, queries |
| `YianaExtraction/Utilities/PostcodeLookup.swift` | 254-sector town lookup table |
| `YianaExtraction/Utilities/ExtractionHelpers.swift` | Filename parser, city helpers, townForPostcode |
| `YianaExtraction/Extractors/ExtractionCascade.swift` | Filename overlay logic |
| `Yiana/Services/AddressRepository.swift` | Split read/write for overrides |
| `Yiana/Services/DocumentExtractionService.swift` | Extraction writes pages + enriched only |
| `YianaExtraction/Models/AddressSchema.swift` | OverridesFile struct |
| `docs/consolidation-plan.md` | Phase 1 complete, Phase 2.1 complete, all decisions logged |

## Known Issues
- 6.8% city python_better — residual gap; async postcode updater will close
- Python extraction plist still on Devon — remove after monitoring period
- `feature/worklist-integration` branch from prior session still exists
- Devon hostname changed: SSH config uses `Devon.local`
