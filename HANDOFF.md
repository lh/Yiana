# Session Handoff — 2026-03-19

## Branch
`consolidation/v1.1` — not yet pushed.

## What Was Done This Session

### Phase 1.2: NHS/ODS Lookup in Swift
- Added GRDB dependency (v7.7+) to `YianaExtraction/Package.swift`
- Created `GPPractice` GRDB record type (internal to package)
- Implemented `NHSLookupService` — full port of Python's `NHSLookup.lookup_gp()`:
  - Exact postcode matching (normalised UK format)
  - District-level fallback with hint-based scoring
  - Auto-select on single strong match (score <= 7, gap > 2)
  - Name hint reordering for exact matches
  - Stop word filtering for both name and address hints
- Bundled `nhs_lookup.db` and `test_cases.json` in test fixtures
- 25 parameterised test cases covering:
  - 15 exact match single practice
  - 3 exact match multiple practices
  - 2 exact match with hint reordering
  - 2 district fallback with hint
  - 2 district fallback without hint (returns empty)
  - 1 invalid postcode
- Added integration test: extraction output feeds into NHS lookup
- Ticked Phase 1.2 checkboxes in `docs/consolidation-plan.md`

### Phase 1.2 is complete
- **88 test cases pass** (62 existing + 25 NHS lookup + 1 integration)
- Both iOS and macOS build clean
- No new dependencies beyond GRDB (already approved and used in main app)

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** `cd YianaExtraction && swift test` — 88 test cases pass, 0 fail
- **Uncommitted changes:** new files + Package.swift edit (ready to commit)

## What's Next

### Phase 1.3: Wire Into Yiana
1. Bundle `nhs_lookup.db` as app resource (not just test fixture)
2. Wire `ExtractionCascade` + `NHSLookupService` into the app
3. Replace Python extraction pipeline calls with Swift-native extraction

### After Phase 1.3
- Phase 1.4: Parallel validation against all 1441 real documents
- Phase 1.5: Retire Python extraction on Devon

## Key Files

| File | Purpose |
|------|---------|
| `YianaExtraction/Package.swift` | Added GRDB dependency |
| `YianaExtraction/Sources/.../Models/GPPractice.swift` | GRDB record (internal) |
| `YianaExtraction/Sources/.../Services/NHSLookupService.swift` | NHS postcode lookup |
| `YianaExtraction/Tests/.../NHSLookupTests.swift` | 25 test cases |
| `YianaExtraction/Tests/.../Fixtures/nhs_lookup/` | DB + test case fixtures |
| `docs/consolidation-plan.md` | Phase 1.2 checkboxes ticked |

## Known Issues
- Synthetic test corpus is partially circular (Phase 1.4 parallel run provides real coverage)
- `feature/worklist-integration` branch from prior session still exists (2 commits, may need merging to main)
- FallbackExtractor has no dedicated test assertions — Fisher_Victor is a known divergence
- Optician lookup not ported (no test cases, not exercised in production)
