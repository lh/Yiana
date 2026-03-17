# Consolidation Plan of Campaign

## Status: Proposal (2026-03-16)

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

### 0.4 Letter Composition Baseline (Yiale)

- [ ] Document Yiale's current feature set (views, flows, data dependencies)
- [ ] Screenshot key screens for UX reference
- [ ] List all data Yiale reads from iCloud (`.addresses/`, `.worklist.json`,
  `.letters/`)
- [ ] List all data Yiale writes to iCloud
- [ ] Identify Yiale features that are actually used vs speculative

**Deliverable:** Yiale feature inventory with data contract documentation.

---

## Phase 1: Swift Extraction Engine

**Goal:** Replace Python extraction pipeline with Swift, running inside Yiana.
Python continues to run on Devon in parallel.

### 1.1 Extraction Service Swift Package

- [ ] Create `YianaExtraction` Swift package (local, like YianaDocumentArchive)
- [ ] Define `ExtractionResult` protocol matching `.addresses/*.json` schema
- [ ] Write tests FIRST for each extractor, using Phase 0 corpus:

  ```
  test_registration_form_extraction()     — 10 cases
  test_form_based_extraction()     — 15 cases
  test_label_based_extraction()    — 10 cases
  test_unstructured_extraction()   — 10 cases
  test_edge_cases()                — 5 cases
  ```

- [ ] Implement extractors to pass tests:
  - `RegistrationFormExtractor` — pattern matching for structured registration forms
  - `NLPExtractor` — NLTagger (person names, places) + NSDataDetector
    (addresses, phone numbers, dates)
  - `FallbackExtractor` — postcode regex + surrounding context
- [ ] Write integration test: OCR JSON in → `.addresses/*.json`-compatible out
- [ ] Confirm output format matches existing schema exactly (field names,
  nesting, types, date formats)

**Test gate:** all 50 corpus cases produce output matching Python's output
(or demonstrably better — log differences for review).

### 1.2 NHS/ODS Lookup in Swift

- [ ] Write tests FIRST using Phase 0.3 corpus (20 cases)
- [ ] Bundle `nhs_lookup.db` as app resource
- [ ] Implement `NHSLookupService` using GRDB:
  - Exact postcode match
  - District-level fallback with scoring
  - Auto-select on single strong match
- [ ] Confirm results match Python's NHSLookup class

**Test gate:** all 20 lookup cases match expected results.

### 1.3 Wire Into Yiana

- [ ] Add post-OCR hook in document pipeline: after `OnDeviceOCRService`
  completes, run extraction
- [ ] Write extracted data to `.addresses/` in existing JSON format
- [ ] Preserve existing override/enriched data (read-merge-write)
- [ ] Atomic writes (temp + rename, matching existing pattern)
- [ ] Test: scan a document → OCR completes → addresses appear in AddressesView
  without Mac mini involvement

**Test gate:** end-to-end test with a synthetic document. Build passes on both
iOS and macOS (`/check`).

### 1.4 Parallel Validation

- [ ] Run Swift extraction on all documents that Python has already processed
- [ ] Compare outputs field-by-field
- [ ] Log discrepancies with document ID and field name
- [ ] Review discrepancies: is Swift wrong, or is Swift better?
- [ ] Fix genuine regressions; document genuine improvements (but do not
  act on improvements yet)

**Test gate:** Swift matches or exceeds Python on >= 95% of fields across all
documents. Remaining 5% reviewed and accepted.

### 1.5 Retire Python Extraction

- [ ] Stop `com.vitygas.yiana-extraction` LaunchAgent on Devon
- [ ] Monitor for 2 weeks: are addresses still appearing correctly?
- [ ] Remove LaunchAgent plist
- [ ] Archive Python extraction code (don't delete from git history)

---

## Phase 2: Entity Database

**Goal:** Replace `backend_db.py` with GRDB-based entity resolution in Yiana.

### 2.1 Entity Database Schema (GRDB)

- [ ] Write tests FIRST using Phase 0.2 corpus (30 cases)
- [ ] Define GRDB records:
  - `Patient` (id, normalised name, DOB, canonical name)
  - `Practitioner` (id, normalised name, type, ODS code, canonical name)
  - `DocumentEntity` (document ↔ patient/practitioner links)
  - `Extraction` (raw per-page results, verbatim)
- [ ] Implement:
  - `EntityDatabase` service class
  - `resolvePatient(name:, dob:)` — normalise + dedup
  - `resolvePractitioner(name:, type:, odsCode:)` — normalise + dedup
  - `ingestAddressFile(url:)` — parse JSON, resolve entities, store links
  - `statistics()` — counts matching backend_db.py --stats output
- [ ] Filename parsing: `parse_filename_dob()` port (Surname_Firstname_DDMMYY)

**Test gate:** 30 entity resolution cases match expected outcomes. Statistics
on full dataset match Python's output (patient count, practitioner count,
link count within 5%).

### 2.2 Wire Into Yiana

- [ ] After extraction completes, call `EntityDatabase.ingestAddressFile()`
- [ ] Entity DB stored locally (not in iCloud — same as search index)
- [ ] Boss instance: full entity DB across all documents
- [ ] Regular instances: entity DB for documents the user has viewed
  (lazy ingestion)
- [ ] AddressesView: show enriched data from entity DB (canonical names,
  cross-document links)

**Test gate:** build passes both platforms. Entity DB populates correctly
from extraction output.

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
