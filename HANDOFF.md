# Session Handoff — 2026-03-19

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 1.1 Completion: Integration Tests
- Added `loadAllOCRPages` helper to `TestHelpers.swift` — loads all pages from an OCR fixture as `[ExtractionInput]`
- Added 3 integration tests to `CascadeTests.swift`:
  1. `fullDocumentExtraction` — parameterized over 3 fixtures (Jones_Clara 5-page mixed methods, Chase_Iris 3-page all-label, Underwood_Quinn 1-page label). Verifies documentId, schemaVersion, and method matching for pages with non-empty names
  2. `outputJSONHasSnakeCaseKeys` — runs real extraction, encodes to JSON, verifies all keys are snake_case (no camelCase leakage)
  3. `extractionOutputRoundTrips` — encodes real extraction output, decodes back, verifies all fields match
- Ticked remaining Phase 1.1 checkboxes in `docs/consolidation-plan.md`

### Phase 1.1 is complete
- **62 test cases pass** (59 existing + 3 new integration tests)
- All extractors implemented: RegistrationForm, Form, Label, Fallback
- Output schema confirmed compatible with Python and app decoder

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** `cd YianaExtraction && swift test` — 62 test cases pass, 0 fail
- **Clean working tree** (except `.serena/project.yml` and `nhs_lookup.db.bak`)

## What's Next

### Phase 1.2: NHS/ODS Lookup in Swift
1. Write tests using Phase 0.3 corpus (25 cases)
2. Bundle `nhs_lookup.db` as app resource
3. Implement `NHSLookupService` using GRDB (exact postcode, district fallback, hint scoring)
4. Confirm results match Python

### After Phase 1.2
- Phase 1.3: Wire extraction + lookup into Yiana app
- Phase 1.4: Parallel validation against all 1441 real documents
- Phase 1.5: Retire Python extraction on Devon

## Key Files

| File | Purpose |
|------|---------|
| `docs/consolidation-plan.md` | Master plan with checkboxes |
| `docs/phase-1.1-plan.md` | Phase 1.1 overview (all sessions complete) |
| `YianaExtraction/Sources/YianaExtraction/Extractors/` | All 4 extractors + cascade |
| `YianaExtraction/Sources/YianaExtraction/Utilities/ExtractionHelpers.swift` | Shared regex helpers |
| `YianaExtraction/Tests/YianaExtractionTests/CascadeTests.swift` | Integration tests |

## Known Issues
- Synthetic test corpus is partially circular (Phase 1.4 parallel run provides real coverage)
- `feature/worklist-integration` branch from prior session still exists (2 commits, may need merging to main)
- FallbackExtractor has no dedicated test assertions — Fisher_Victor is a known divergence
