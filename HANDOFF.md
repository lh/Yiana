# Session Handoff — 2026-03-19

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 1.1 Session 3 (Complete)
- Implemented `FormExtractor`, `LabelExtractor`, `FallbackExtractor` in Swift
- Extracted shared regex helpers into `ExtractionHelpers` (firstMatch, allMatches, firstPostcode, cleanName, extractDate)
- Refactored `RegistrationFormExtractor` to use shared helpers (removed duplicated private methods)
- Wired all 4 extractors into `ExtractionCascade`: RegistrationForm (0.9) > Form (0.8) > Label (0.7) > Fallback (0.5)
- Fixed test helpers: added `loadFirstOCRFixtureByMethod` / `loadExpectedPageByMethod` to handle fixtures where the target page isn't page 1
- Updated `FormExtractorTests` and `LabelExtractorTests` to use method-based page loading
- Direct regex port from Python (not NLTagger) — the plan originally suggested NLTagger but regex is reliable and deterministic for the clean synthetic fixtures

### Approach Deviation from Plan
The phase-1.1-plan.md described "NLPExtractor" using NLTagger + NSDataDetector. Instead, we implemented:
- `FormExtractor` — detects "Patient name:", "Address:" field labels; method="form"
- `LabelExtractor` — sliding window over name + address block + postcode; method="label"
- `FallbackExtractor` — title pattern (Mr/Mrs/Dr) + postcode anchor; method="unstructured"

This matches the Python architecture (separate form/label/unstructured extractors) and the test assertions (which require specific method values).

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** `cd YianaExtraction && swift test` — 59 pass, 0 fail
  - 23 RegistrationFormExtractor (unchanged)
  - 15 FormExtractor (new)
  - 21 LabelExtractor (new)
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
| `docs/phase-1.1-plan.md` | Phase 1.1 overview (Sessions 1-3 complete) |
| `YianaExtraction/Sources/YianaExtraction/Extractors/` | All 4 extractors + cascade |
| `YianaExtraction/Sources/YianaExtraction/Utilities/ExtractionHelpers.swift` | Shared regex helpers |

## Known Issues
- Synthetic test corpus is partially circular (Phase 1.4 parallel run provides real coverage)
- `feature/worklist-integration` branch from prior session still exists (2 commits, may need merging to main)
- FallbackExtractor has no dedicated test assertions — Fisher_Victor is a known divergence. Validated indirectly through cascade tests
