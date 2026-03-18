# Session Handoff — 2026-03-18

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 1.1 Session 2 (Complete)
- Implemented `RegistrationFormExtractor` in Swift, porting Python's `SpireFormExtractor`
- 10 steps: detection, MRN, patient name, DOB, postcode, phones, GP name, GP practice, validation, assembly
- Two deliberate improvements over Python:
  - Full GP name capture after Doctor/Dr (Python only captured single word)
  - Dropped "Medical" from GP section boundary (Python truncated practice names containing "Medical")
- Fixed `rejectsNonFormText` test — Anderson_Noah fixture has pages 5 & 6, not page 1
- All tests pass: 12 fixture tests + 6 field tests + 1 rejection test + 4 cascade tests = 23 pass
- Both iOS and macOS build clean

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed (`/check` passes)
- **Package tests:** `cd YianaExtraction && swift test` — 23 pass, 36 red (form + label extractors not yet implemented)
- **Clean working tree** (except `.serena/project.yml` and `nhs_lookup.db.bak`)

## What's Next: Session 3

**Implement NLPExtractor + FallbackExtractor** following `docs/phase-1.1-plan.md` Session 3:

1. `NLPExtractor` — unifies Python's form-based and label-based extractors using NLTagger + NSDataDetector
2. `FallbackExtractor` — postcode regex + surrounding context for unstructured text
3. Target: 15 form tests + 21 label tests green (36 currently red)
4. Form detection heuristic: text with field labels ("Name:", "Address:") → method "form", confidence 0.8; address block format → method "label", confidence 0.7

### After Session 3
- Phase 1.2: NHS lookup in Swift (GRDB)
- Phase 1.3: Wire into Yiana app
- Phase 1.4: Parallel validation against all 1441 real documents

## Key Files

| File | Purpose |
|------|---------|
| `docs/consolidation-plan.md` | Master plan with checkboxes |
| `docs/phase-1.1-plan.md` | Phase 1.1 overview (Sessions 1 & 2 complete) |
| `docs/phase-1.1-session2-plan.md` | Session 2 implementation plan (done) |
| `YianaExtraction/Sources/YianaExtraction/Extractors/RegistrationFormExtractor.swift` | Implemented this session |
| `AddressExtractor/spire_form_extractor.py` | Python source that was ported |

## Known Issues
- PII leaks easily — 3 incidents during Phase 0 (all caught and fixed)
- Synthetic test corpus is partially circular (Phase 1.4 parallel run provides real coverage)
- `feature/worklist-integration` branch from prior session still exists (2 commits, may need merging to main)
