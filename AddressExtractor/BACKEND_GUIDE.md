# Address Backend Database Guide

## What This Is

A learning system that ingests per-document JSON files from the Yiana app's extraction pipeline, deduplicates patients and practitioners across ~1,400 documents, and learns from manual corrections to improve over time.

**Files:** `backend_db.py` (all logic), `backend_schema.sql` (table definitions)

## Architecture

```
iOS/macOS App (Swift)
  ├── Creates .yianazip documents
  ├── Reads .addresses/*.json (AddressRepository.swift)
  └── Writes user corrections to overrides[] in .addresses/*.json
                    ↕ iCloud Sync
Mac mini "Devon" (Python)
  1. YianaOCRService    .yianazip → .ocr_results/*.json
  2. extraction_service  .ocr_results/*.json → .addresses/*.json (pages[])
  3. backend_db.py       .addresses/*.json → addresses_backend.db (READ-ONLY access to JSON)
```

**Key principle:** `backend_db.py` reads `.addresses/` files for ingestion. It can write back an `enriched` key containing canonical data from the backend DB. The Swift app owns `overrides[]`, the extraction service owns `pages[]`, and the backend DB owns `enriched`.

## Data Ownership

| Data | Owner | Written By | Read By |
|------|-------|-----------|---------|
| `.yianazip` | Swift app | Swift app | YianaOCRService |
| `.ocr_results/*.json` | YianaOCRService | YianaOCRService | extraction_service.py |
| `.addresses/*.json` `pages[]` | extraction_service | extraction_service | Swift app, backend_db.py |
| `.addresses/*.json` `overrides[]` | Swift app | Swift app | extraction_service (preserves), backend_db.py |
| `.addresses/*.json` `enriched` | backend_db.py | backend_db.py (`--enrich`) | Swift app, extraction_service (preserves) |
| `addresses_backend.db` | backend_db.py | backend_db.py | backend_db.py (enrichment queries) |

## How Patient Identity Works

### Priority: Filename > OCR

Patient-level documents are named `Surname_Firstname_DDMMYY.json`. This is far more reliable than OCR-extracted names, which often contain form labels ("Date of birth"), town names ("Surrey"), or other noise.

**The rule:** Only filename-parsed patients create patient entities. If the filename doesn't match `Surname_Firstname_DDMMYY`, no patient resolution is attempted. OCR-extracted patient names are stored verbatim in `extractions` (with `patient_id = NULL`) but never create patient entities on their own.

**Why this matters:** OCR-extracted "patient names" from non-patient files are often form labels ("Date of birth"), street names ("Peter Lane"), or sentence fragments. Trusting only filename-derived identity eliminates all junk patient entries.

### Filename Parsing Rules

Standard pattern: `Surname_Firstname_DDMMYY.json`

Handles:
- Hyphenated names: `Anderson-Dixon_Anthony_200461.json`
- Apostrophes (straight and curly): `O'Neill_Peter_111144.json`
- Trailing text after DOB: `Abel_Andrew_170462 DNA.json`
- Spacing issues: `Brady_Michael _280348.json`, `Gaby__Shirley_120545.json`

Does NOT handle (no patient entity created):
- No DOB: `Heather_Susan.json`
- Multi-part surnames: `Morales_Torres_Maria_220664.json`
- Non-patient files: `Bad referrals.json`, `receipt.json`

These files still have their OCR data stored in `extractions` with `patient_id = NULL`. If the filename parser is extended later, they'll be picked up on re-ingestion.

Year pivot: `>= 26` → 1900s, `< 26` → 2000s (so `120400` = 12/04/2000).

### Deduplication

- **Patients:** `full_name_normalized + date_of_birth` as dedup key
- **Practitioners:** `full_name_normalized + type` as dedup key
- **Name normalization:** lowercase, strip titles (Mr/Mrs/Dr/etc), remove non-alpha except hyphens/apostrophes, collapse whitespace

## The Learning Feedback Loop

```
1. User corrects OCR error in Yiana app
   └── Override written to .addresses/Foo_Bar_010180.json overrides[]

2. backend_db.py ingests the file
   ├── Applies override to get effective values (for entity resolution)
   ├── Compares override fields vs original page fields
   ├── Records each diff in corrections table
   │     e.g. patient.full_name: "zwertlik" → "Czwertlik"
   └── Name corrections → name_aliases table
         e.g. "adrian zwertlik" → "adrian czwertlik" (patient)

3. Future ingestion of ANY document
   └── _resolve_patient tries direct lookup
       └── If not found, checks name_aliases for canonical name
           └── Retries lookup with canonical → finds existing patient
               (no duplicate created)
```

**The loop is closed:** corrections feed into aliases, aliases feed into entity resolution.

## Corrections and Common Issues

### What Gets Recorded

Field-level diffs between original OCR extraction and user override. Each differing field becomes a row in `corrections`:

```
document_id | page_number | field_name            | original_value                        | corrected_value
------------|-------------|-----------------------|---------------------------------------|----------------
Czwertlik.. | 1           | patient.full_name     | Adrian zwertlik                       | Adrian Czwertlik
Czwertlik.. | 1           | patient.phones.mobile | 0746022400107460224001RH105AZ         | 07460224001
Czwertlik.. | 1           | address.city          | Date of birth                         | Crawley
Kelly_Si..  | 1           | patient.phones.mobile | 0741351240107413512401CR53RD           | 07413512401
```

### What Does NOT Get Recorded

- Cleared fields (override sets to empty string) — not a learnable correction
- Fields where override matches original — no diff to record

### Common Issues Register (`--corrections`)

The report automatically detects three patterns:

1. **Value concatenation** — OCR merging adjacent form fields. Example: phone number + postcode read as one string. Detected when original contains corrected value plus extra junk.

2. **Form label contamination** — field labels extracted as values. Example: "Date of birth" appearing as the city. Detected by matching against known label strings.

3. **Name OCR errors** — character-level misreads. Example: "zwertlik" vs "Czwertlik". Detected when name fields have similar-length values that differ.

These patterns grow as more corrections accumulate.

## Schema Overview

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `documents` | One row per JSON file | document_id, json_hash (idempotency) |
| `patients` | Deduplicated patients | full_name_normalized, date_of_birth (dedup key) |
| `practitioners` | Deduplicated GPs/specialists | full_name_normalized, type (dedup key) |
| `extractions` | Raw per-page OCR data (verbatim) | document_id, page_number, address_type |
| `patient_documents` | Which patients in which docs | patient_id, document_id |
| `patient_practitioners` | Patient-GP relationships | patient_id, practitioner_id, document_count |
| `corrections` | Field-level diffs from overrides | field_name, original_value, corrected_value |
| `name_aliases` | Learned name mappings | alias, canonical, entity_type |

## Enrichment Write-Back

The `--enrich` flag writes canonical data from the backend DB back into `.addresses/*.json` files under an `enriched` key.

### Structure

```json
"enriched": {
  "enriched_at": "2026-02-13T10:00:00.000000Z",
  "patient": {
    "full_name": "Andrew Abel",
    "date_of_birth": "17/04/1962",
    "source": "filename",
    "document_count": 3
  },
  "practitioners": [
    {
      "name": "Dr John Smith",
      "type": "GP",
      "practice": "The Health Centre",
      "document_count": 45
    }
  ]
}
```

### Rules

- Only files with a filename-parsed patient get `enriched.patient`
- Files with resolved practitioners get `enriched.practitioners`
- Files with neither get no `enriched` key
- Skips write if enriched content hasn't changed (ignoring timestamp)
- Uses atomic write (temp file + replace)

### Priority in Swift App

When the app resolves addresses: **override > page > enriched**. Enriched data only fills nil/empty fields — it never overwrites existing data from extraction or user overrides.

### Content Hash Strategy

Ingestion uses `content_hash()` which parses JSON, removes the `enriched` key, then hashes the remaining content deterministically. This means:
- Running `--enrich` doesn't invalidate ingestion hashes
- Running `--ingest` after `--enrich` skips unchanged files (0 processed)
- Only changes to `pages[]`, `overrides[]`, or other extraction data trigger re-ingestion

One-time cost: switching from `file_hash()` to `content_hash()` changes hash format, causing a full re-ingestion on first run (~15 min on Devon).

### Preservation

Both the extraction service and Swift app preserve `enriched` during their writes:
- `extraction_service.py` reads and re-writes existing `enriched` when re-extracting
- Swift's `DocumentAddressFile` includes `enriched: EnrichedData?` as a Codable property, automatically round-tripping through encode/decode

## CLI Usage

```bash
# Ingest (default action) — idempotent, skips unchanged files
python3 backend_db.py --ingest

# Ingest then enrich — writes canonical data back to JSON files
python3 backend_db.py --enrich

# Show statistics
python3 backend_db.py --stats

# Show potential patient duplicates
python3 backend_db.py --merge-candidates

# Show corrections, aliases, and common issues
python3 backend_db.py --corrections

# Show top practitioners / patient-GP links
python3 backend_db.py --top-practitioners
python3 backend_db.py --top-links

# Custom paths
python3 backend_db.py --db-path /Users/devon/Data/addresses_backend.db --addresses-dir /path/to/.addresses

# Verbose logging
python3 backend_db.py -v --enrich
```

## Design Decisions

### Why filename over OCR for patient identity?
OCR extraction from scanned forms frequently misreads field labels, addresses, and dates as patient names. The filename is manually assigned and far more reliable. 98.6% of files parse successfully.

### Why a separate `enriched` key instead of modifying `pages[]`?
Clear ownership boundaries prevent circular dependencies. `pages[]` is owned by the extraction service, `overrides[]` by the Swift app, and `enriched` by the backend DB. Each component reads all three but only writes its own. No conflict resolution needed.

### Why not a separate table for filename patients?
No need — the filename patient is resolved through the same `_resolve_patient` path as OCR patients. It's just called first, with higher-quality input. Keeps the model simple.

### Why store raw OCR data in extractions?
The `extractions` table preserves exactly what OCR found, even when it's wrong. This is essential for: (a) debugging extraction quality, (b) computing corrections, (c) training future models.

### Why skip cleared fields in corrections?
When an override clears a field (sets to empty), that's cleanup, not a learnable pattern. "The city was wrong" is learnable; "I deleted the garbage in line_2" is not.

## Current Numbers (as of 2026-02-09)

| Metric | Count |
|--------|-------|
| Documents | 1,401 |
| Patients (deduplicated) | 1,409 |
| Practitioners (all GP) | 388 |
| Patient-GP links | 894 |
| Corrections | 5 |
| Name aliases | 1 |

## Future Phases

4. **Advanced learning** — LLM few-shot from corrections, confidence recalibration
5. **Practitioner alias learning** — same feedback loop for GP names
