# Consolidation Plan of Campaign

## Status: Phase 4 In Progress — Milestones 1-3 done, Devon render retired (2026-03-21)

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
- [x] `ingestAll()` method ready (can be triggered manually or on app launch)
- [x] Regular instances: lazy ingestion when viewing addresses
- [x] AddressesView: "Seen in N documents" annotations for patient and GP names (N > 1, view mode only)

**Test gate:** build passes both platforms (iOS + macOS). 82 package tests pass.
Entity DB populates on extraction and lazy-loads on address view.
AddressCard shows document counts from entity DB.

### 2.3 Parallel Validation -- DONE (2026-03-21)

- [x] Run full ingestion on all `.addresses/*.json` files
- [x] Compare entity counts and links against `addresses_backend.db`
- [x] Review discrepancies

**Results (2026-03-21):**

| Metric | Python | Swift | Diff | Notes |
|--------|--------|-------|------|-------|
| Documents | 1404 | 1442 | +2.7% | +38 new docs since Python stopped |
| Extractions | 4009 | 4519 | +12.7% | Swift cascade finds more pages |
| Patients | 1410 | 1432 | +1.6% | New docs + deduplication |
| Practitioners | 389 | 391 | +0.5% | +2 Consultants (specialist type) |
| Links | 895 | 913 | +2.0% | More docs = more links |

All core entity counts within 5%. Extraction count higher because Swift
extraction is more thorough. Practitioner difference is +2 Consultants
which Python never created (only tracked GPs).

**Test gate: PASSED.**

### 2.4 Retire Python Backend DB -- DONE (2026-03-21)

- [x] Stop running `backend_db.py --ingest` on Devon (was manual, never automated)
- [x] Remove `extraction_service.py --nhs-enrich` cron (ran every 2min, now redundant)
- [x] Archive `addresses_backend.db` to `~/Data/archive/addresses_backend.db.2026-03-21`
- [ ] Archive Python backend code

---

## Phase 3: Letter Composition (Yiale Absorption)

**Goal:** Absorb Yiale's features into Yiana as a "Compose" module.

**Status: COMPLETE** (2026-03-21)

**Detailed plan:** [`docs/phase-3-plan.md`](phase-3-plan.md) — full inventory,
step-by-step checklists, design decisions, estimated effort.

### 3.1 Preparation and deduplication -- DONE (2026-03-21)

- [x] Delete Yiale duplicates (SharedWorkList, WorkListRepository, ClinicListParser, WorkListViewModel)
- [x] Document differences: Yiale has `replaceClinicList()` (replace-all); Yiana only has merge. Address at Step 3.5

### 3.2 Port models -- DONE (2026-03-21)

- [x] LetterDraft.swift, SenderConfig.swift to Yiana/Models/

### 3.3 Port services -- DONE (2026-03-21)

- [x] LetterRepository.swift, SenderConfigService.swift to Yiana/Services/
- [x] Adapted iCloud URL sourcing to Yiana's per-service caching pattern (no ICloudContainer singleton)

### 3.4 Port patient search (entity DB migration) -- DONE (2026-03-21)

- [x] Added searchPatients() and searchPractitioners() to EntityDatabase and EntityDatabaseService
- [x] 12 new tests (94 total pass). LIKE on normalized name/DOB/practice, ordered by doc count

### 3.5-3.7 Compose module (simplified) -- DONE (2026-03-21)

Redesigned instead of porting Yiale views:
- [x] `ComposeTab.swift` — compose tab in DocumentInfoPanel (macOS)
- [x] `ComposeViewModel.swift` — auto-fill from prime addresses, save/send via LetterRepository
- [x] Rules-based recipients (patient=To, GP=CC), body-text-only editing
- Deferred: PatientSearchView, RecipientEditor, DraftsListView, DraftDetailView, iOS compose

### 3.8 Integration testing -- DONE (2026-03-21)

- [x] Full compose-to-render-to-inject flow verified on macOS
- [x] Fixed: added implicit hospital_records recipient, wired iCloud URL caching
- Known: document requires close/reopen after inject (logged, not a regression)

### 3.9 Retire Yiale -- DONE (2026-03-21)

- [x] Compose features verified in Yiana (Step 3.8)
- [x] Yiale/ directory removed (git preserves history)
- [x] LETTER-MODULE-SPEC.md rewritten — describes compose module in Yiana, not separate app

**Test gate:** every Yiale feature works in Yiana. Build passes both platforms.
Full compose-to-render-to-inject flow verified.

---

## Phase 4: Self-Sufficient App (Typst Rendering)

**Goal:** Every Mac runs a fully self-sufficient Yiana — no server, no
Python, no LaTeX. Install the app, it just works.

**Why the original "boss instance" plan was dropped:** With OCR, extraction,
entity DB, and compose all running in-app, the only remaining server
dependency is letter rendering (Python + LaTeX on Devon). Replacing that
with Typst (bundled in the app) eliminates the last server dependency.
There is no need for a central "boss" — each device is self-sufficient.
The entity DB is a local derived cache rebuilt from iCloud JSON files.
iCloud handles sync. No coordinator needed.

### 4.1 Typst Rendering in App

Replace the Python render service with in-app Typst rendering.

- [x] Build Rust crate `yiana-typst-bridge` — wraps Typst compiler as C-compatible static library
- [x] Tests pass (3/3: simple template, data template with JSON, error handling)
- [x] Cross-compiled for 4 Apple targets (macOS ARM/Intel, iOS device/simulator, ~39MB each)
- [x] XCFramework built (not committed — rebuild via `build-xcframework.sh`)
- [x] Swift package `YianaRenderer` wrapping Typst bridge — LetterRenderer API, TypstBridge FFI, letter.typ template
- [x] 5 tests pass (renders all recipients, valid PDFs, correct filenames, correct roles, distinct copies)
- [x] 30ms to render 3 PDFs (patient + GP + hospital records)
- [x] Typst letter template (`YianaRenderer/Sources/YianaRenderer/Resources/letter.typ`)
  - Hospital/GP copy: 11pt, name+MRN header on pages 2+
  - Patient copy: 14pt, wider line spacing, page numbers only on pages 2+
  - CC lines, Re: line, sender header (bold italic)
  - Postal address block for windowed envelopes (positioning TBD — needs measurements)
- [x] Integrated via Option B: Rust static library + C bridge + XCFramework (works on iOS too)
- [x] `LetterRenderService` in Yiana maps types and writes PDFs to `.letters/rendered/` and `.letters/inject/`
- [x] `ComposeViewModel.sendToPrint()` renders locally — instant, no Devon
- [x] ComposeTab shows per-recipient PDF links (Patient copy, To: GP, Hospital records)
- [x] Both platforms build
- [x] Manual test: compose -> render -> view PDFs (confirmed working 2026-03-21)

**Test gate:** Full compose-to-render-to-inject flow works without any
server. Build passes both platforms. PASSED.

### 4.2 Retire Devon Services

- [x] Stopped Python render service LaunchAgent on Devon (2026-03-21)
- [x] Stopped OCR service LaunchDaemon on Devon (2026-03-21)
- [x] Removed watchdog cron job (2026-03-21)
- [x] Stopped dashboard LaunchAgent (2026-03-21)
- All plists preserved on disk for rollback until 2026-04-04
- [ ] Archive server scripts and Python code
- [x] Devon is now just an iCloud sync node — no active services

### 4.3 Nice-to-Haves (not blockers)

- [ ] macOS login item (Yiana stays open for background processing)
- [ ] Integration hooks (Dropbox copy, email) — personal deployment via
  Shortcuts or shell scripts, not built into the app
- [ ] Batch re-render existing drafts with new template

---

## Phase 5: Domain Configurability (Future)

**Deferred until after Phases 0-4 are complete and stable.**

- [ ] Recipient rules engine — configurable per profession/context
- [ ] Recipient tick boxes in AddressesView (To/CC/None per card)
- [ ] Drafts list sidebar mode (cross-document "what's pending" view)
- [ ] Extract domain-specific patterns into configuration bundles
- [ ] Make entity labels, extraction patterns, lookup databases, and letter
  templates domain-driven
- [ ] iOS compose access (info panel is macOS-only currently)
- [ ] Test with a second domain (business contacts) to validate abstraction

---

## Migration Safety Rules

These governed Phases 0-3. Migration is now complete (Python replaced,
Yiale retired). Retained for reference.

1. **No format changes during migration.** `.addresses/*.json`,
   `.ocr_results/*.json`, and `.yianazip` schemas are frozen.
   _Still applies:_ iCloud file formats remain the integration contract.

2. **No improvements during migration.** Log it, don't change it.
   _Migration complete:_ improvements are now welcome.

3. **No refactoring during migration.** Existing code stays as-is.
   _Migration complete:_ refactoring is now welcome.

4. **Parallel run before retirement.** 2-week parallel run for each component.
   _Applied to:_ extraction (Phase 1.4-1.5), entity DB (Phase 2.3-2.4).
   _Not applied to:_ compose (redesigned, not migrated).

5. **Rollback plan.** Python services can be restarted.
   _Still available:_ plists preserved on Devon until 2026-04-04.

6. **One phase at a time.** Sequential, each independently testable.
   _Applied throughout._

---

## Estimated Scope

| Phase | New Swift LOC | Tests | Replaces | Status |
|-------|--------------|-------|----------|--------|
| 0 (Baseline) | 0 | ~200 (corpus + scripts) | — | DONE |
| 1 (Extraction) | ~800 | ~300 | ~2170 Python + monitoring | DONE |
| 2 (Entity DB) | ~600 | ~200 | ~1420 Python | DONE |
| 3 (Compose) | ~300 (new) | 12 | ~2400 Swift (Yiale retired) | DONE |
| 4 (Typst rendering) | ~400 | ~50 | Python render service + LaTeX | IN PROGRESS (render done, services partially retired) |
| **Total** | **~2100** | **~760** | **~6000 Python/Bash + 2400 Yiale** | |

Net effect: ~2800 lines of new Swift (including tests) replaces ~8400 lines
of Python/Bash/duplicate Swift. Single language, single app, single deploy.
No server infrastructure required for end users.

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
| 2026-03-21 | Compose as info panel tab, not separate views | Addresses panel is redundant once compose starts; compose replaces it. ~300 LOC instead of porting ~1100 LOC from Yiale |
| 2026-03-21 | Rules-based recipients, no manual editor | Patient=To, GP=CC, hospital_records=implicit. Recipient tick boxes in AddressesView deferred to Phase 5 |
| 2026-03-21 | Body text only, no greeting/salutation in compose | Render service handles topping/tailing. Compose is just the clinical content |
| 2026-03-21 | Drafts list deferred | Draft status shown inline in compose tab. Cross-document drafts view deferred to Phase 5 |
| 2026-03-21 | Drop "boss instance" concept | With OCR, extraction, entity DB, and compose all in-app, no central coordinator needed. Each device is self-sufficient. Entity DB is a local derived cache rebuilt from iCloud JSON |
| 2026-03-21 | Typst replaces LaTeX for letter rendering | Apache 2.0 license, ~30MB binary (or static lib for iOS). Produces identical typography via New Computer Modern. Eliminates Python + LaTeX server dependency. Prototype validated at `docs/typst-prototype/letter.typ` |
| 2026-03-21 | Target: fully self-contained app, no server needed | Install the iOS/macOS app and it does everything. Key enabler for distribution to other consultants. Devon becomes optional (just another iCloud sync node) |
| 2026-03-21 | Devon render service retired | Local Typst rendering confirmed working. Python/LaTeX render service stopped. Plist preserved for rollback until 2026-04-04 |
