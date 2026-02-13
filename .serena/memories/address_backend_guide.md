# Address Backend Database — Session Guide

## Quick Reference
- **Files:** `AddressExtractor/backend_db.py` + `backend_schema.sql`
- **Human guide:** `AddressExtractor/BACKEND_GUIDE.md`
- **DB location (Devon):** `/Users/devon/Data/addresses_backend.db`
- **DB location (local dev):** `./addresses_backend.db` or `/tmp/*.db` for testing

## How Patient Identity Works
1. **Filename parsing** (`parse_patient_filename`) extracts Surname_Firstname_DDMMYY — covers 98.6% of files
2. Filename patient is resolved FIRST via `_resolve_patient`, added to `seen_patients`
3. OCR-extracted patient names stored verbatim in `extractions` but don't create entities when filename patient exists
4. Files that don't parse (59 of 1401) fall back to OCR-based patient resolution

## The Learning Feedback Loop
```
User correction in app → overrides[] in JSON
  → backend_db.py computes field-level diffs → corrections table
  → Name corrections → name_aliases table
  → _resolve_patient checks aliases before creating new entities
```
**The loop is closed.** Example: "adrian zwertlik" resolves to existing "adrian czwertlik" via alias.

## Key Design Decisions
- **Filename > OCR** for patient identity (OCR produces noise like "Fax", "Surrey", "Date of birth")
- **Read-only access** to `.addresses/*.json` — no write conflicts with iCloud sync
- **Raw OCR preserved** in `extractions` table even when wrong — needed for corrections/training
- **Cleared fields skipped** in corrections — not learnable patterns
- **name_aliases consulted** during entity resolution before creating new patients

## Common Issues Register (--corrections)
Detects three pattern types:
1. **Value concatenation** — phone+postcode merged (2 cases)
2. **Form label contamination** — "Date of birth" as city (1 case)  
3. **Name OCR errors** — "zwertlik" → "Czwertlik" (1 case)
Grows automatically as user makes more corrections in the app.

## Schema (8 tables)
- `documents` — one per JSON, hash-based idempotency
- `patients` — deduped on (full_name_normalized, date_of_birth)
- `practitioners` — deduped on (full_name_normalized, type)
- `extractions` — raw per-page OCR data, verbatim
- `patient_documents`, `patient_practitioners` — M2M links
- `corrections` — field-level diffs from overrides
- `name_aliases` — learned name mappings (alias → canonical)

## CLI Flags
`--ingest` (default), `--stats`, `--merge-candidates`, `--corrections`, `--top-practitioners`, `--top-links`, `--db-path`, `--addresses-dir`, `-v`

## Current Numbers (2026-02-09)
1,401 docs → 1,409 patients, 388 GPs, 894 links, 5 corrections, 1 alias

## What's NOT Done Yet
- Deploy to Devon (git pull + run ingestion)
- Enrichment write-back (canonical data → JSON pages[])
- Practitioner alias learning
- Advanced pattern detection (needs more correction data)
