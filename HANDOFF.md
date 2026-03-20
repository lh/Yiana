# Session Handoff — 2026-03-20

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 1.2: NHS/ODS Lookup in Swift (d9b99c9)
- `NHSLookupService` with GRDB, 25 test cases + 1 integration

### Phase 1.3: Wire Into Yiana (4849897)
- `DocumentExtractionService`, all 4 OCR trigger points wired
- Manual testing on real document confirmed end-to-end on iOS + macOS

### Phase 1.4: Parallel Validation (b6d14e0)
- `yiana-extract` CLI tool for batch extraction from OCR JSON
- `migration/compare_extraction.py` comparison harness
- Validated 1,440 documents (4,500+ pages) against Python, zero errors
- Three extractor fixes based on comparison data:
  - `extractDate`: hyphen separators + 2-digit years
  - `RegistrationFormExtractor`: GP postcode + address extraction
  - All extractors: city/town extraction from address blocks

### Validation Results (final run)
| Field | Match | Swift-better | Python-better |
|-------|-------|-------------|---------------|
| postcode | 97.6% | 0.1% | 0.4% |
| patient.name | 74.8% | 9.8% | 0.4% |
| gp.postcode | 8.5% | 1.7% | 0% |
| city | 62.6% | 0.8% | 22.4% |
| NHS candidates | 1.5% | 31.0% | 0% |
| DOB | 22.2% | 12.0% | 7.4% |

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** 88/88 pass
- **Validation:** 1,440/1,440 documents compared, zero errors

## Open Design Questions

### iCloud Override Race Condition
When user edits an override on device A and device B re-extracts before sync, the override is lost. Fix: separate override file. Must be done before Phase 1.5. See `docs/phase-1.3-plan.md`.

### Extraction Learning from Overrides
Manual address corrections should feed back as training signal to improve extraction. Logged in memory `project_extraction_learning`. Backend pipeline work, not app UI change.

## What's Next

### Phase 1.5: Retire Python Extraction on Devon
- Implement separate override file (iCloud race fix)
- Stop Python extraction LaunchAgent
- Verify app works standalone

## Key Files

| File | Purpose |
|------|---------|
| `YianaExtraction/Sources/YianaExtractCLI/main.swift` | CLI extraction tool |
| `migration/compare_extraction.py` | Comparison harness (no PII) |
| `docs/phase-1.4-plan.md` | Validation plan |

## Known Issues
- 22.4% city python_better — remaining gap from county-boundary regex approach
- 15% patient name "different" — case/formatting disagreements, needs investigation
- 7.4% DOB python_better — unusual date formats
- `feature/worklist-integration` branch from prior session still exists
