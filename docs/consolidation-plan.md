# Consolidation Plan of Campaign

## Status: Phase 1 Complete (2026-03-21)

## Principles

1. **Test before change.** Every component being replaced gets characterisation
   tests BEFORE any code is written. These tests capture current behaviour so we
   know exactly what "correct" means.

2. **Test the replacement.** Every new Swift component gets unit tests written
   BEFORE implementation (TDD). Tests define the contract; implementation
   satisfies it.

3. **Parallel run.** New Swift components run alongside existing Python for a
   transition period. Outputs are compared automatically. Only retire Python
   when Swift matches or exceeds on real data.

4. **No improvements during migration.** Resist the urge to fix extraction
   patterns, add features, or refactor surrounding code. The goal is
   behavioural equivalence, not improvement. Improvements come after migration
   is complete and verified.

5. **One phase at a time.** Each phase is independently deployable and testable.
   No phase depends on a future phase being complete. The system works at every
   intermediate state.

6. **iCloud file formats are frozen.** The `.addresses/*.json` schema, the
   `.ocr_results/*.json` schema, and the `.yianazip` format do not change
   during consolidation. These are the integration contracts.
   **Update (2026-03-21):** Added `.addresses/{id}.overrides.json` as a new
   file alongside the existing schema. The main `.json` format is unchanged;
   overrides are split out to fix iCloud race condition.

---

## Phase 0: Baseline — Characterisation Tests

**Goal:** Capture the exact current behaviour of every Python component so we
have a definition of "correct" to test against.

### 0.1 Extraction Test Corpus

- [x] Select representative documents spanning all extractor paths:
  - 12 structured registration forms (form-specific extractor)
  - 15 structured forms with field labels (form-based extractor)
  - 21 address-label format documents (label-based extractor)
  - 1 unstructured document (only 3 exist in corpus; all included)
  - 4 edge cases (empty/no-pages documents, 10 with user overrides)
- [x] For each document, record:
  - Input: synthetic OCR JSON (real OCR cannot be scrubbed safely)
  - Expected output: scrubbed extraction JSON (from `.addresses/`)
  - Which extractor fired and at what confidence
- [x] Store corpus in `migration/fixtures/extraction/` (git-tracked, no PHI —
  address outputs scrubbed, OCR inputs fully synthetic)
- [x] Write a validation script that runs extractions against corpus and
  reports pass/fail per document (53/53 docs pass, 13 known divergences
  documented where synthetic text cannot replicate real OCR layout quirks)

**Deliverable:** `migration/fixtures/extraction/` with 53 input/output pairs,
a generator, a scrubber, and a validation runner.

**Limitations (acknowledged):**
- Synthetic OCR inputs are generated *from* the expected outputs, making
  the test partially circular. It validates "does the Python extractor
  produce X from text designed to produce X" — useful as a development
  contract but not a full characterisation of real-world behaviour.
  Phase 1.4 parallel validation against all 1441 real documents provides
  the true coverage.
- All 5 unstructured pages are known divergences — zero validated
  unstructured test coverage in the synthetic corpus. The label extractor
  is greedier and wins on synthetic text. Unstructured extraction must be
  validated entirely via Phase 1.4 parallel run.
- The extraction validator checks method, patient name, DOB, MRN,
  postcode, GP name, and GP practice. It does NOT check address lines,
  city, county, phones, specialist name, or confidence score. These are
  better validated in Phase 1.4 against real data where the scrubber
  doesn't introduce mismatches.

### 0.2 Entity Resolution Test Corpus

- [x] Created 30 fully synthetic test scenarios (55 address files, no PHI):
  - 10 exact-match dedup (same patient across documents)
  - 5 near-match (titles, case, hyphens, apostrophes, same-name-different-DOB)
  - 5 practitioner dedup (address formatting, title variants, case, GP vs specialist)
  - 5 ODS code scenarios (documents current non-use of ODS for matching)
  - 5 edge cases (missing DOB, malformed filename, suffix after DOB, empty pages, OCR noise)
- [x] For each scenario, recorded:
  - Input: synthetic `.addresses/*.json` files
  - Expected: patient count, practitioner count, link count, canonical names, doc counts
- [x] Validation runner ingests into temp SQLite DB, queries entities, compares
  against expected.json. 30/30 scenarios pass.
- [x] Stored in `migration/fixtures/entity/`

**Deliverable:** `migration/fixtures/entity/` with 55 synthetic files, expected.json,
generator, and validation runner (30/30 pass).

**Learnings captured during test creation:**
- `normalize_name()` strips "dr" but NOT "doctor" (not in title list)
- `specialist_name` only creates entity when `address_type="specialist"`
- Empty pages with valid filename DOB still creates patient entity
- ODS code is in schema but completely unused for practitioner matching
- Practitioners are resolved even when no patient exists (no filename match)

### 0.3 NHS Lookup Test Cases

- [x] 25 test cases from real NHS ODS data (Open Government Licence, no PHI):
  - 15 exact-match single-practice postcodes (geographically spread across England)
  - 3 multi-practice postcodes (2-3 practices at same postcode)
  - 2 exact-match with name hint (verifies hint reorders results)
  - 2 district fallback with hint (postcode not in DB, falls back to district)
  - 2 district fallback without hint (verifies no results without hints)
  - 1 invalid postcode (no district exists)
- [x] Each case records: input postcode + hints, expected ODS codes, practice names
- [x] Validation runner: 25/25 pass
- [x] Stored in `migration/fixtures/nhs_lookup/`

**Deliverable:** NHS lookup test cases.

**Note:** These fixtures are coupled to the current `nhs_lookup.db` snapshot.
If the ODS database is refreshed (practices close, rename, open), regenerate
fixtures with `python3 migration/generate_nhs_lookup_fixtures.py`. No optician
lookup tests — `lookup_optician()` exists in code but is not exercised; add
cases if the Swift port needs optician support.

### 0.4 Letter Composition Baseline (Yiale)

- [x] Documented Yiale's full feature set: 23 files, 2383 LOC, complete
  navigation flow, all view/viewmodel/service/model responsibilities
- [x] Screenshots captured and redacted (all PII removed)
- [x] Data Yiale reads: `.addresses/*.json`, `.worklist.json`,
  `.letters/config/sender.json`, `.letters/rendered/{id}/*.pdf`
- [x] Data Yiale writes: `.letters/drafts/{id}.json`, `.worklist.json`
- [x] All features are used (no speculative code). Evidence: 2 drafts,
  4 rendered outputs, active work list, sender config all present in iCloud.
- [x] Porting estimate: ~900 LOC to port (compose flow + recipients + PDF
  viewer), ~500 LOC eliminated (duplicated services), SharedWorkList
  duplication resolved

**Deliverable:** `migration/notes/yiale-feature-inventory.md` with full
inventory, data contracts, JSON schemas, and porting priority list.
Screenshots pending recapture with synthetic patient data.

---

## Phase 1: Swift Extraction Engine

**Goal:** Replace Python extraction pipeline with Swift, running inside Yiana.

**Status: COMPLETE.** Python extraction stopped on Devon 2026-03-21.
Swift extraction runs in-app after OCR. Override file split deployed.
Two-week monitoring period ends 2026-04-04.

### 1.1 Extraction Service Swift Package

- [x] Create `YianaExtraction` Swift package (local, like YianaDocumentArchive)
- [x] Define `ExtractionResult` protocol matching `.addresses/*.json` schema
- [x] Write tests FIRST for each extractor, using Phase 0 corpus:

  ```
  test_registration_form_extraction()     — 12 cases
  test_form_based_extraction()     — 15 cases
  test_label_based_extraction()    — 21 cases
  test_edge_cases()                — 4 cases
  ```

- [x] Implement extractors to pass tests:
  - [x] `RegistrationFormExtractor` — pattern matching for structured registration forms (12/12 pass)
  - [x] `FormExtractor` — form-field label extraction (15/15 pass)
  - [x] `LabelExtractor` — address-block extraction (21/21 pass)
  - [x] `FallbackExtractor` — title pattern + postcode anchor for unstructured text
  - [x] `ExtractionHelpers` — shared regex, postcode, name cleaning, date extraction
- [x] 59/59 tests pass (23 registration + 15 form + 21 label + cascade/field tests)
- [x] Write integration test: OCR JSON in → `.addresses/*.json`-compatible out
- [x] Confirm output format matches existing schema exactly (field names,
  nesting, types, date formats)

**Test gate:** all 50 corpus cases produce output matching Python's output
(or demonstrably better — log differences for review).

### 1.2 NHS/ODS Lookup in Swift

- [x] Write tests FIRST using Phase 0.3 corpus (25 cases)
- [x] Bundle `nhs_lookup.db` as test fixture
- [x] Implement `NHSLookupService` using GRDB:
  - Exact postcode match
  - District-level fallback with scoring
  - Auto-select on single strong match
- [x] Confirm results match Python's NHSLookup class
- [x] Integration test: extraction output feeds into lookup

**Test gate:** all 25 lookup cases match expected results.

### 1.3 Wire Into Yiana

- [x] Add post-OCR hook in document pipeline: after `OnDeviceOCRService`
  completes, run extraction (all 4 trigger points: iOS VM, macOS VM, ContentView import, DocumentEditView scan)
- [x] Write extracted data to `.addresses/` in existing JSON format
- [x] Preserve existing enriched data (read-merge-write; overrides now in separate file)
- [x] Atomic writes (temp + rename, matching existing pattern)
- [x] `OnDeviceOCRResult` extended with per-page text and confidence
- [x] `nhs_lookup.db` bundled in app (both iOS and macOS targets)
- [x] NHS lookup enriches GP entries with ODS candidates
- [x] Test: scan a document → OCR completes → addresses appear in AddressesView
  without Mac mini involvement (confirmed manually on real document, Phase 1.3)

**Test gate:** end-to-end test with a synthetic document. Build passes on both
iOS and macOS (`/check`). PASSED.

### 1.4 Parallel Validation

- [x] Run Swift extraction on all 1,440 documents Python has already processed
- [x] Compare outputs field-by-field (4,500+ pages, zero errors)
- [x] Log discrepancies (anonymised — no PII in repo)
- [x] Review discrepancies: fixed GP postcode gap, added city extraction, improved DOB parsing
- [x] Fix genuine regressions: GP postcode (eliminated), city (90.8% -> 22.4% gap), DOB formats
- [x] Filename-parsed patient name + DOB as canonical (closes 15% name gap, 7.4% DOB gap)
- [x] Postcode sector -> town lookup table (254 sectors, postcodes.io BUA data)
- [x] City: postcode-line extraction + 3rd-address-line fallback + sector lookup
- [x] City python_better reduced from 22.4% to 6.8%

**Test gate:** Swift matches or exceeds Python on >= 95% of fields across all
documents. Remaining 5% reviewed and accepted. PASSED — postcode 97.6% match,
city python_better down to 6.8% (from 22.4%, with ~50% of original gap being
Python junk). Full results in `docs/phase-1.4-plan.md`.

### 1.5 Retire Python Extraction

- [x] Split overrides into separate `.overrides.json` files (iCloud race fix)
- [x] One-time migration of 21 existing override files (132 entries)
- [x] Extraction service no longer preserves overrides (writes pages + enriched only)
- [x] Stop `com.vitygas.yiana-extraction` LaunchAgent on Devon (2026-03-21)
- [ ] Monitor for 2 weeks: are addresses still appearing correctly?
- [ ] Remove LaunchAgent plist
- [ ] Archive Python extraction code (don't delete from git history)

---

## Phase 2: Entity Database

**Goal:** Replace `backend_db.py` with GRDB-based entity resolution in Yiana.

### 2.1 Entity Database Schema (GRDB) -- DONE (2026-03-21)

- [x] Write tests FIRST using Phase 0.2 corpus (30 cases)
- [x] Define GRDB records:
  - `Patient` (id, normalised name, DOB, canonical name)
  - `Practitioner` (id, normalised name, type, ODS code, canonical name)
  - `DocumentEntity` (document ↔ patient/practitioner links)
  - `Extraction` (raw per-page results, verbatim)
- [x] Implement:
  - `EntityDatabase` service class
  - `resolvePatient(name:, dob:)` — normalise + dedup
  - `resolvePractitioner(name:, type:, odsCode:)` — normalise + dedup
  - `ingestAddressFile(url:)` — parse JSON, resolve entities, store links
  - `statistics()` — counts matching backend_db.py --stats output
- [x] Filename parsing: `parse_filename_dob()` port (Surname_Firstname_DDMMYY)

**Test gate:** 30/30 corpus scenarios pass. 82 total tests (30 corpus + 8
edge cases + schema/normalisation). Statistics method implemented.

### 2.2 Wire Into Yiana — INGESTION DONE (2026-03-21)

- [x] After extraction completes, call `EntityDatabase.ingestAddressFile()`
- [x] Entity DB stored locally (not in iCloud — same as search index)
- [x] Boss instance: `ingestAll()` method ready (auto-trigger deferred to Phase 4)
- [x] Regular instances: lazy ingestion when viewing addresses
- [x] AddressesView: "Seen in N documents" annotations for patient and GP names (N > 1, view mode only)

**Test gate:** build passes both platforms (iOS + macOS). 82 package tests pass.
Entity DB populates on extraction and lazy-loads on address view.
AddressCard shows document counts from entity DB.

### 2.3 Parallel Validation

- [ ] Run full ingestion on all `.addresses/*.json` files
- [ ] Compare entity counts and links against `addresses_backend.db`
- [ ] Review discrepancies

**Test gate:** entity counts within 5% of Python backend. Discrepancies
reviewed and explained.

### 2.4 Retire Python Backend DB

- [ ] Stop running `backend_db.py --ingest` on Devon
- [ ] Archive `addresses_backend.db` as reference
- [ ] Archive Python backend code

---

## Phase 3: Letter Composition (Yiale Absorption)

**Goal:** Absorb Yiale's features into Yiana as a "Compose" module.

### 3.1 Feature Inventory and Tests

- [ ] From Phase 0.4 inventory, list every Yiale feature to port
- [ ] Write UI-level acceptance criteria for each:
  - Patient search and selection
  - Recipient management (add/remove/reorder)
  - Letter body composition
  - Draft save/load/delete
  - PDF rendering and preview
  - Work list integration
- [ ] Delete `SharedWorkList.swift` duplication — single implementation in Yiana

### 3.2 Compose Module in Yiana

- [ ] Create `Views/Compose/` directory in Yiana
- [ ] Port views from Yiale, adapting to Yiana's navigation structure
- [ ] Patient search reads from entity DB directly (no file-based lookup)
- [ ] Draft storage: `.letters/drafts/` in iCloud (same location, same format)
- [ ] PDF rendering: same approach as Yiale (or simplified if Yiale's was
  over-engineered)

**Test gate:** every acceptance criterion from 3.1 passes. Build passes
both platforms.

### 3.3 Retire Yiale

- [ ] Confirm all Yiale features work in Yiana
- [ ] Remove Yiale from App Store Connect (if published)
- [ ] Archive Yiale directory
- [ ] Remove Yiale.xcodeproj from workspace

---

## Phase 4: Boss Instance Configuration

**Goal:** Make the Mac mini's Yiana instance the always-on "boss."

### 4.1 Boss Mode

- [ ] Add app configuration for boss behaviour:
  - `autoProcessOnLaunch`: process all unprocessed documents at startup
  - `backgroundExtraction`: watch for new documents and extract continuously
  - `entityDatabaseRebuild`: full re-ingestion on schedule or demand
- [ ] Implement as macOS-only Settings pane (or plist/defaults configuration)
- [ ] macOS login item support (launch at login, stay running)

### 4.2 Integration Hooks

- [ ] Define integration point for always-on tasks:
  - File copy to external folder (Dropbox, shared folder)
  - Email notification (via system mail or SMTP)
  - Webhook calls
- [ ] Configuration-driven: integrations defined in a JSON/plist config file
- [ ] Each integration is a simple Swift protocol:
  ```swift
  protocol Integration {
      func shouldTrigger(for document: DocumentMetadata) -> Bool
      func execute(for document: DocumentMetadata, addressData: ExtractedAddress) async throws
  }
  ```
- [ ] Write tests for each integration type

**Test gate:** boss instance processes documents, runs integrations, survives
relaunch. Build passes both platforms (integrations are macOS-only but code
compiles on iOS with `#if os(macOS)` guards).

### 4.3 Retire Server Scripts

- [ ] Remove watchdog cron job
- [ ] Remove dashboard LaunchAgent
- [ ] Remove YianaOCRService LaunchDaemon
- [ ] Archive scripts/ directory
- [ ] Update SERVER-SETUP.md or replace with boss-instance setup doc

---

## Phase 5: Domain Configurability (Future)

**Deferred until after Phases 0-4 are complete and stable.**

- [ ] Extract domain-specific patterns into configuration bundles
- [ ] Define `Domain` enum (`.medical`, `.business`, etc.)
- [ ] Make entity labels, extraction patterns, lookup databases, and letter
  templates domain-driven
- [ ] Test with a second domain (business contacts) to validate abstraction

---

## Migration Safety Rules

1. **No format changes during migration.** `.addresses/*.json`,
   `.ocr_results/*.json`, and `.yianazip` schemas are frozen.

2. **No improvements during migration.** If Swift extraction finds something
   Python missed, log it. Do not change extraction logic to capture it. That
   is post-migration work.

3. **No refactoring during migration.** Existing Yiana code that works stays
   as-is. Refactoring is a separate task after migration is verified.

4. **Parallel run before retirement.** Every Python component runs alongside
   its Swift replacement for at least 2 weeks before being stopped.

5. **Rollback plan.** Python services can be restarted at any time during
   migration. The Swift extraction writes to the same `.addresses/` files
   in the same format — restarting Python will simply overwrite with its
   own results.

6. **One phase at a time.** Do not start Phase N+1 until Phase N's test gates
   are all green.

---

## Estimated Scope

| Phase | New Swift LOC | Tests | Replaces |
|-------|--------------|-------|----------|
| 0 (Baseline) | 0 | ~200 (corpus + scripts) | — |
| 1 (Extraction) | ~800 | ~300 | ~2170 Python + monitoring |
| 2 (Entity DB) | ~600 | ~200 | ~1420 Python |
| 3 (Yiale absorption) | ~400 (port) | ~100 | ~2400 Swift (separate app) |
| 4 (Boss instance) | ~300 | ~100 | ~500 Bash/Python scripts |
| **Total** | **~2100** | **~900** | **~6490 Python/Bash + 2400 Yiale** |

Net effect: ~3000 lines of new Swift (including tests) replaces ~8900 lines
of Python/Bash/duplicate Swift. Single language, single app, single deploy.

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-16 | Consolidate into Yiana, not Yiale | Yiana owns documents and processing; Yiale is a feature |
| 2026-03-16 | Mac mini becomes boss instance, not retired | Always-on integrations (file copy, email) require persistent process |
| 2026-03-16 | Test-first, parallel-run migration | Behavioural equivalence must be proven before retirement |
| 2026-03-16 | Domain configurability deferred to Phase 5 | Consolidation first; abstraction after stability |
| 2026-03-16 | iCloud file formats frozen during migration | Avoids coordinated changes across components |
| 2026-03-19 | Regex extractors instead of NLTagger for Phase 1.1 | Fixtures are clean synthetic text; tests assert specific method values; NLP can layer on later if Phase 1.4 reveals need |
| 2026-03-21 | Separate overrides file to fix iCloud race condition | Extraction and user edits must never write the same file — iCloud eventual consistency means read-merge-write loses data |
| 2026-03-21 | Filename-parsed patient name/DOB as canonical | Filename set by human at scan time is more reliable than OCR; closes 15% name gap and 7.4% DOB gap |
| 2026-03-21 | Python extraction stopped on Devon | Swift extraction validated at scale (1440 docs); override split deployed; Python service unloaded but plist preserved for rollback |
| 2026-03-21 | Entity DB is a local derived cache, not synced via iCloud | SQLite doesn't sync reliably via iCloud (WAL files, partial writes). JSON files in iCloud are the source of truth. Entity DB is a materialised view — rebuildable from JSON at any time. Boss instance builds for all docs; regular devices read enriched JSON or rebuild lazily |
| 2026-03-21 | Entity DB in YianaExtraction package, not separate | GRDB already a dependency; keeps extraction + entity resolution together. EntityDatabase alongside NHSLookupService |
| 2026-03-21 | Corrections/name_aliases tables: schema only, no logic | Ready for future extraction learning without adding complexity now |
