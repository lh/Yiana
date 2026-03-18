# Session Handoff — 2026-03-17

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Consolidation Planning
- Architecture doc: `docs/consolidation-architecture.md`
- Master plan: `docs/consolidation-plan.md` (phased, with checkboxes)
- Migration directory: `migration/` with fixtures, generators, validators, notes
- Mac mini becomes "boss instance" running same Yiana binary, not separate daemons

### Phase 0: Baseline Tests (All Complete)
- **0.1 Extraction** — 53 docs, synthetic OCR inputs, scrubbed address outputs. Validator: 53/53 pass, 13 known divergences documented. Limitations: partially circular, no unstructured coverage.
- **0.2 Entity Resolution** — 30 scenarios, 55 synthetic files, 30/30 pass. Found 3 bugs in Python (logged to post-migration improvements).
- **0.3 NHS Lookup** — 25 cases from real ODS data, 25/25 pass. Tied to current nhs_lookup.db snapshot.
- **0.4 Yiale Inventory** — Full feature/data contract inventory with redacted screenshots.
- **Review** — Critical review of all Phase 0 work. Fixed: PHI in screenshots (purged from git history), added limitation notes, NHS staleness warning.

### Phase 1.1 Session 1 (Complete)
- Created `YianaExtraction` Swift package
- Moved address schema types from app to package (Option C)
- Stub extractors, cascade API, test helpers
- 53 fixture pairs in package test bundle
- 4 cascade tests pass, 48 extractor tests red
- Both iOS and macOS build with package imported

### Phase 1.1 Session 2 (Planned)
- Detailed plan: `docs/phase-1.1-session2-plan.md`

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both succeed (`/check` passes)
- **Package tests:** `cd YianaExtraction && swift test` — 4 pass, 48 red
- **Clean working tree** (except `.serena/project.yml` and `nhs_lookup.db.bak`)

## What's Next: Session 2

**Implement RegistrationFormExtractor** following `docs/phase-1.1-session2-plan.md`:

1. Edit only `YianaExtraction/Sources/YianaExtraction/Extractors/RegistrationFormExtractor.swift`
2. Use `NSRegularExpression` (package targets macOS 12+, can't use Swift Regex)
3. 10 steps: detection → MRN → name → DOB → postcode → phones → GP name → GP practice → validation → assembly
4. Two deliberate deviations from Python:
   - Capture full GP name after "Doctor/Dr" (Python only captures one word)
   - Drop "Medical" from GP section boundary (Python truncates practice names)
5. Target: 12 registration form tests + 6 field-specific tests green
6. Run `swift test` after each step, `/check` at the end

### After Session 2
- Session 3: NLPExtractor + FallbackExtractor (NLTagger + NSDataDetector)
- Phase 1.2: NHS lookup in Swift (GRDB)
- Phase 1.3: Wire into Yiana app
- Phase 1.4: Parallel validation against all 1441 real documents

## Key Files

| File | Purpose |
|------|---------|
| `docs/consolidation-plan.md` | Master plan with checkboxes |
| `docs/phase-1.1-plan.md` | Phase 1.1 overview |
| `docs/phase-1.1-session2-plan.md` | Session 2 implementation plan |
| `migration/notes/post-migration-improvements.md` | 5 deferred fixes |
| `migration/notes/yiale-feature-inventory.md` | Yiale feature inventory |
| `YianaExtraction/` | New Swift package (source of truth for address schema types) |
| `AddressExtractor/spire_form_extractor.py` | Python code being ported |

## Known Issues
- PII leaks easily — 3 incidents during Phase 0 (all caught and fixed)
- Synthetic test corpus is partially circular (Phase 1.4 parallel run provides real coverage)
- `feature/worklist-integration` branch from prior session still exists (2 commits, may need merging to main)
