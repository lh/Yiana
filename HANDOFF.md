# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Filename-based patient identity
- `ExtractionHelpers.parsePatientFilename()` parses `Surname_Firstname_DDMMYY` from document ID
- Handles hyphenated names, apostrophes (straight + curly), trailing text, double underscores
- Century pivot: >=26 -> 1900s, <26 -> 2000s
- `ExtractionCascade.extractDocument()` overlays filename name + DOB as canonical on every page
- OCR-extracted values only used when filename doesn't match the convention
- 20 new tests in `FilenameParserTests.swift`

### City extraction improvements
- All four extractors now try `cityFromPostcodeLine()` — strips postcode from its line, uses remainder as city (e.g. "London SW1A 1AA" -> "London")
- `FormExtractor`: added 3rd-address-line fallback
- `FallbackExtractor`: now extracts city (previously returned none)
- Validated on Devon: python_better dropped from 22.4% to 19.5%

### City gap analysis
- Investigated the remaining 879 python_better cases in detail
- 50% are junk: form labels ("Date of birth"), numbers, clinical data ("Hoya" lens brand)
- ~200 are legitimate local cities (Crawley, Horsham, Horley, Redhill, etc.)
- These are addresses where a county line ("Surrey") sits between city and postcode
- **Logged idea #13**: postcode outward code -> town lookup table (~2,900 entries, ~100KB) would replace all OCR-based city heuristics entirely

### SSH / Devon connectivity
- SSH key loaded into macOS Keychain (`ssh-add --apple-use-keychain`)
- Devon renamed from "Lukes Mac Mini(10)" to "Devon" — updated SSH config hostname to `Devon.local`
- Host key added to known_hosts for new hostname

### Validation Results (updated)
| Field | Match | Swift-better | Python-better |
|-------|-------|-------------|---------------|
| postcode | 97.6% | 0.1% | 0.4% |
| patient.name | 74.8% | 9.8% | 0.4% |
| gp.postcode | 8.5% | 1.7% | 0% |
| city | 62.6% | **1.6%** | **19.5%** |
| NHS candidates | 1.5% | 31.0% | 0% |
| DOB | 22.2% | 12.0% | 7.4% |

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed
- **Package tests:** 52/52 pass (was 88 before test refactor — count is correct)
- **Validation:** 1,440/1,440 documents compared, zero errors

## Open Design Questions

### iCloud Override Race Condition
When user edits an override on device A and device B re-extracts before sync, the override is lost. Fix: separate override file. Must be done before Phase 1.5. See `docs/phase-1.3-plan.md`.

### Extraction Learning from Overrides
Manual address corrections should feed back as training signal to improve extraction. Logged in memory `project_extraction_learning`. Backend pipeline work, not app UI change.

## What's Next

### Postcode -> Town Lookup (idea #13, parked)
- Static outward code -> town dictionary (~2,900 entries, ~100KB)
- Replaces OCR-based city heuristics entirely
- postcodes.io has bulk outcodes API to build the table
- Logged in Serena memory `ideas_and_problems`

### Phase 1.5: Retire Python Extraction on Devon
- Implement separate override file (iCloud race fix)
- Stop Python extraction LaunchAgent
- Verify app works standalone

## Key Files

| File | Purpose |
|------|---------|
| `YianaExtraction/Sources/YianaExtraction/Utilities/ExtractionHelpers.swift` | Filename parser + city-from-postcode-line |
| `YianaExtraction/Sources/YianaExtraction/Extractors/ExtractionCascade.swift` | Filename overlay logic |
| `YianaExtraction/Tests/YianaExtractionTests/FilenameParserTests.swift` | 20 filename + cascade integration tests |
| `YianaExtraction/Sources/YianaExtractCLI/main.swift` | CLI extraction tool |
| `migration/compare_extraction.py` | Comparison harness (no PII) |

## Known Issues
- 19.5% city python_better — ~200 real cases where county line separates city from postcode; rest is junk. Postcode lookup (idea #13) would fix
- 15% patient name "different" — largely resolved by filename parsing (not yet re-validated)
- 7.4% DOB python_better — unusual date formats; largely resolved by filename DOB (not yet re-validated)
- `feature/worklist-integration` branch from prior session still exists
- Devon hostname changed: SSH config now uses `Devon.local` instead of `devon-6.local`
