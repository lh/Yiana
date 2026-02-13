# Session Handoff — 2026-02-10

## 1. What We Accomplished and Committed

Four commits, all pushed to remote and deployed to Devon:

### `73806cc` — Filename-based patient resolution
- Added `parse_patient_filename()` to extract `Surname_Firstname_DDMMYY` from JSON filenames
- Handles: hyphenated names, apostrophes (straight `'` and curly `'`), trailing text after DOB (copies, DNA markers), spacing issues (extra spaces, double underscores)
- Matches 1,342 of 1,401 files (98.6%); 59 unmatched files fall back to OCR-based resolution
- Year pivot: `>= 26` → 1900s, `< 26` → 2000s
- Modified `_ingest_file()`: when filename parses, the filename patient is the document's canonical patient. OCR-extracted names stored verbatim in `extractions` but don't create separate patient entities
- When OCR name matches filename name (normalized), address/phone updates still applied via `_update_patient_details()`
- **Result:** Patients dropped from 2,099 → 1,409 (-690 junk entries like "Fax", "Surrey", "Date of birth")
- Merge candidates dropped from 30+ noise groups → 4 real duplicates

### `2ff3251` — Corrections flow + name aliases
- After inserting each extraction with an override, computes field-level diffs between original page and override
- Each differing field → row in `corrections` table (field_name, original_value, corrected_value)
- Design choice: cleared fields (override sets to empty) are NOT recorded — not learnable patterns
- Name corrections (patient.full_name, gp.name) automatically populate `name_aliases` table via `_upsert_name_alias()`
- Added `--corrections` CLI flag and `print_corrections()` method
- Old corrections deleted on re-ingestion (alongside extractions cleanup)
- **Result:** 5 corrections captured (Czwertlik name fix, 2x phone cleanup, city label fix, GP postcode add), 1 name alias ("adrian zwertlik" → "adrian czwertlik")

### `0e6be76` — Alias feedback loop + common issues register
- Extracted `_find_patient_by_name()` as static method (used for both direct and alias lookups)
- `_resolve_patient()` now: try direct match → if not found, check `name_aliases` for canonical → retry with canonical
- Verified: "adrian zwertlik" resolves to existing patient ID 295 ("adrian czwertlik") via alias
- Enhanced `print_corrections()` with Common Issues Register detecting three pattern types:
  1. **Value concatenation** — original contains corrected + extra junk (phone+postcode merged)
  2. **Form label contamination** — original matches known form labels ("Date of birth", "Signeddate", etc.)
  3. **Name OCR errors** — name fields with similar-length differing values

### `bc0db51` — Python 3.9 compatibility
- Added `from __future__ import annotations` for Devon's Python 3.9.6 (needed for `dict | None` syntax)

### Documentation
- `AddressExtractor/BACKEND_GUIDE.md` — comprehensive human-readable guide (committed as `229eaec`)
- Serena memory `address_backend_guide` — concise reference for Claude sessions

### Deployed to Devon
- `git pull` on Devon (fast-forward from `fcbd4fa` to `bc0db51`)
- Created `/Users/devon/Data/` directory
- Ran `python3 backend_db.py --db-path /Users/devon/Data/addresses_backend.db`
- 1,401 files ingested in ~15 minutes (M1 Mac mini vs ~1 second on M4)
- Numbers match local exactly: 1,409 patients, 388 GPs, 894 links, 5 corrections, 1 alias
- DB size: 2.0MB

## 2. What's Still Pending (with agreed approaches)

### No automation yet
The ingestion is manual — run `python3 backend_db.py --db-path /Users/devon/Data/addresses_backend.db` on Devon when needed. No cron/launchd job set up. Could be added if the user wants automatic re-ingestion when JSON files change.

### Enrichment write-back (Phase 3+)
Canonical patient data from the backend DB could be written back to `.addresses/*.json` `pages[]` fields. This would improve the data the Swift app sees. Requires careful conflict resolution since JSON files are iCloud-synced. Not yet designed.

### Practitioner alias learning
The alias feedback loop currently only works for patients. The same pattern could be applied to practitioners (GP name corrections → practitioner aliases → resolve during `_resolve_practitioner`). The `name_aliases` table already supports `entity_type = 'practitioner'`.

### Advanced pattern detection
The common issues register currently detects three patterns. With more corrections, could add: statistical field error rates, extraction method correlation (which methods produce which errors), document-type-specific patterns.

## 3. What We Tried That Didn't Work and Why

### Python 3.9 on Devon
`dict | None` type hints caused syntax errors on Devon's Python 3.9.6. Fixed with `from __future__ import annotations` (makes all annotations lazy strings). Caught before deployment by checking `python3 --version` on Devon first.

### Ingestion performance on Devon
Expected ~1 second (local M4 timing), took ~15 minutes on Devon's M1. Pure CPU difference — no iCloud download issues (verified no `.icloud` placeholder files). Not a problem since subsequent runs skip unchanged files (hash-based idempotency), but worth knowing for full re-ingestion scenarios.

### No other failures
Filename parsing, corrections, alias loop, and common issues register all worked on first attempt. The 16-case unit test for `parse_patient_filename` passed cleanly.

## 4. Known Risks and Side Effects

### 59 unmatched files still produce junk patients
Files that don't match the `Surname_Firstname_DDMMYY` pattern (4.2%) still use OCR-based patient resolution. This creates ~17 junk "patients" like "Consultant Ophthalmologist", "Hospital Address", "Receipted Invoice". These come from non-patient documents (CVI certificates, receipts, handbooks) and files with malformed DOBs. Not harmful but inflates the patient count slightly.

### Alias table is small (1 entry)
The learning system has only 1 alias from 5 corrections across 2 files. It will become more useful as the user makes more corrections in the Yiana app. The infrastructure is ready.

### Re-ingestion timing on Devon
Full re-ingestion (e.g. after schema change or `--force` flag) would take ~15 minutes on Devon. Incremental runs (only changed files) are fast. If schema changes require a full rebuild, delete the DB and re-run.

### No backup of Devon DB
`/Users/devon/Data/addresses_backend.db` is not backed up or synced. It's fully rebuildable from the `.addresses/*.json` files (which ARE iCloud-synced), so data loss is inconvenient but not catastrophic.

### `address.line_2` corrections not captured
When an override clears a field (sets to empty string), it's intentionally not recorded as a correction. The rationale: "I deleted garbage from line_2" is cleanup, not a learnable pattern. If this design choice needs revisiting, the logic is in the `norm_corr` check in `_ingest_file()`.
