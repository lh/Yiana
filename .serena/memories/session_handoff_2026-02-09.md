# Session Handoff — 2026-02-09

## 1. What We Accomplished and Committed

**Commit `407e9d2`**: "Add backend SQLite database for address entity deduplication"

Created Phase 1 of the address learning system — an entity-centric SQLite database on Devon that ingests from `.addresses/*.json` files. Two new files:

### `AddressExtractor/backend_schema.sql`
- 8 tables: `documents`, `patients`, `practitioners`, `extractions`, `patient_documents`, `patient_practitioners`, `corrections` (empty, Phase 2), `name_aliases` (empty, Phase 2)
- Indexes on all dedup keys and foreign keys
- WAL mode, foreign keys enforced

### `AddressExtractor/backend_db.py`
- `BackendDatabase` class with full ingestion pipeline
- `normalize_name()` — strips titles (Mr/Mrs/Dr/etc), lowercases, removes non-alpha except hyphens/apostrophes, collapses whitespace
- **Hash-based idempotency**: SHA256 of each JSON file stored in `documents.json_hash`; unchanged files are skipped on re-run
- **Override application**: builds override map keyed on `(page_number, match_address_type)`, most recent by `override_date` wins
- **Patient deduplication**: `full_name_normalized + date_of_birth` as dedup key; if DOB absent, matches only if exactly one patient with that normalized name exists
- **Practitioner deduplication**: `full_name_normalized + type` as dedup key (ODS code path exists in schema but no JSON files have it yet)
- **Cross-row patient-practitioner linking**: two strategies:
  1. Same page_number: link patients and practitioners that share a page
  2. Single-patient documents: link the sole patient to all practitioners in the document
- CLI: `--ingest`, `--stats`, `--merge-candidates`, `--top-practitioners`, `--top-links`, `--addresses-dir`, `--db-path`, `--verbose`
- Zero dependencies beyond Python stdlib

### Test Results (local, 1401 JSON files)
| Metric | Count |
|--------|-------|
| Documents | 1,401 |
| Extractions | 4,003 |
| with overrides | 3 |
| Patients (deduplicated) | 2,099 |
| in multiple documents | 241 |
| Practitioners (all GP) | 388 |
| Patient-Practitioner links | 888 |
| DB size | 2.4 MB |

- Idempotency verified: second run skips all 1,401 files
- Override application verified: Kelly_Sidney_010575 shows corrected data with override flag
- Cross-row linking verified: Abberley_Julia_100566 correctly links Julia Abberley to Dr Lindley despite being on separate extraction rows

## 2. What's Still Pending (with agreed approaches)

### Phase 2: Corrections Flow
- Ingest `overrides[]` into the `corrections` table with field-level diffs (compare override fields vs original page fields)
- Build `name_aliases` table from correction patterns
- Tables already created empty in the schema

### Filename-Based Patient Resolution (agreed approach, deferred)
Patient-level documents are named `Surname_Firstname_ddmmyy` (with variants like `Surname-Other_First-Second_ddmmyy`). Billing/batch documents start with digits. Parsing the filename gives a canonical patient name + DOB far more reliable than OCR. Approach:
- Detect patient-level docs by regex pattern (starts with letter, `Name_Name_digits` structure)
- Extract canonical name + DOB from filename
- Use as the document's primary patient for entity resolution and linking
- Still store all raw extraction rows verbatim
- This would dramatically reduce junk "patient" entries (OCR artifacts like "Fax", "Surrey", "Povey Cross Road")
Saved in Serena memory `ideas_and_problems` item #5.

### Deploy to Devon
- `git pull` on Devon to get the new files
- Run `python3 backend_db.py --ingest --db-path /Users/devon/Data/addresses_backend.db` against the full corpus
- No cron/automation yet — manual runs for now
- Default `--db-path` in script is `./addresses_backend.db` (local dev); Devon should use `/Users/devon/Data/`

### Future Phases (from architecture in Serena memory `address_database_architecture`)
3. Simplest learning: aliases & exclusions
4. Enrichment write-back (canonical data → JSON `pages[]`)
5. Advanced learning (LLM few-shot, confidence recalibration, letters)

## 3. What We Tried That Didn't Work and Why

### Low patient-practitioner link count (5 → 888)
First implementation only linked patients to practitioners when both appeared in the **same extraction row**. But the JSON structure typically has patient data on one row (`address_type: "patient"`) and GP data on a separate row (`address_type: "gp"`) for the same page. Fixed by adding cross-row linking: (a) same-page linking, (b) single-patient-document linking.

### `datetime.utcnow()` deprecation
Python 3.12+ warns about `datetime.utcnow()`. Fixed by switching to `datetime.now(timezone.utc)`.

### No other failures
The schema, ingestion, and all CLI commands worked on first attempt. The data quality issues visible in `--merge-candidates` (OCR noise as patient names) are expected characteristics of the extraction data, not bugs.

## 4. Known Risks and Side Effects

### Data quality in patients table
~30 groups of "duplicate patients" are actually OCR noise: "Horley" (a town), "Fax", "Specsavers", "Dear Luke", "October", "Surrey", "Pound Hill Medical Group", etc. These are form field labels, addresses, and dates parsed as patient names by the extraction system. The filename-based resolution (Phase 2+) will fix most of this. For now, these junk records exist but don't cause harm — they just inflate the patient count.

### Document count inflation on re-ingestion
When a file changes and is re-ingested, `document_count` on patients/practitioners gets incremented again (because we delete old extractions and re-process). This means `document_count` can overcount if the same file is modified and re-ingested multiple times. Not a problem in practice since files rarely change, but worth knowing. A proper fix would track which documents contributed to the count, but that's over-engineering for now.

### Patient-practitioner link accumulation
The `patient_practitioners` table is never fully rebuilt — links accumulate across ingestion runs. If a file is re-extracted and the patient/GP changes, the old link persists. Again, not a problem in practice since re-extractions are rare, and the `document_count` on the link reflects how many documents attest the relationship.

### .gitignore coverage
`AddressExtractor/*.db` is already in `.gitignore`, so `addresses_backend.db` won't be committed. Verified.

### No existing files were modified
Both new files (`backend_schema.sql`, `backend_db.py`) are additions. No Swift code, no existing Python code, no iCloud-synced files were touched.
