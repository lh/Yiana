# Address Extraction Backend Guide

**Purpose**: Developer guide for the backend address extraction pipeline and how to adapt it for other domains
**Audience**: Developers working with or adapting the extraction system
**Last Updated**: 2026-02-25

---

## Overview

The AddressExtractor is a Python-based pipeline that:
1. **Watches** OCR output directories for new documents
2. **Extracts** structured data using pattern matching + optional local LLM
3. **Deduplicates** entities across documents via a learning system
4. **Outputs** to iCloud-synced JSON files (consumed by the Swift app)
5. **Learns** from user corrections via a feedback loop

**Current domain**: UK healthcare (patients, GPs, opticians, specialists)

**Tech stack**: Python 3, SQLite, Ollama (optional, local only), watchdog

---

## Architecture: Two-Tier System

### Tier 1: Extraction Pipeline
`extraction_service.py` + `address_extractor.py`

Runs as a macOS LaunchAgent file watcher. Processes OCR JSON and produces `.addresses/*.json` files.

- **Input**: `.ocr_results/*.json` (OCR output from YianaOCRService)
- **Output**: `.addresses/*.json` (iCloud-synced, consumed by the Swift app)
- **Speed**: 10ms (pattern matching) to 3s (LLM fallback)

### Tier 2: Backend Learning System
`backend_db.py`

Reads `.addresses/*.json`, deduplicates entities, stores corrections and aliases in SQLite.

- **Input**: Same `.addresses/*.json` files
- **Database**: `addresses_backend.db` (local, not synced)
- **Operations**: Ingestion, enrichment, analytics

---

## Directory Structure

```
AddressExtractor/
├── Core Extraction
│   ├── address_extractor.py          # Main extractor, 4 methods (form/label/unstructured/spire)
│   ├── extraction_service.py         # File watcher, coordinates pipeline
│   ├── spire_form_extractor.py       # Domain-specific: Spire Healthcare forms
│   ├── llm_extractor.py              # Fallback: Local LLM via Ollama (qwen2.5:3b)
│   └── swift_integration.py          # Shell integration for Swift app
│
├── Backend Learning System
│   ├── backend_db.py                 # Entity deduplication and learning
│   ├── backend_schema.sql            # 8 tables: documents, patients, practitioners, etc.
│   └── BACKEND_GUIDE.md              # Detailed docs on the learning system
│
├── Domain-Specific Matchers
│   ├── gp_matcher.py                 # Fuzzy-match extracted GPs to NHS ODS codes
│   ├── gp_fuzzy_search.py            # Similarity scoring engine
│   ├── gp_bulk_importer.py           # Import NHS GP reference data
│   ├── optician_database.py          # Same pattern for opticians
│   ├── gp_local.db                   # Pre-loaded NHS GP practices
│   └── opticians_uk.db               # Pre-loaded opticians
│
├── Schema and Config
│   ├── backend_schema.sql            # Entity-centric schema
│   ├── com.vitygas.yiana-extraction.plist  # launchd config
│   └── requirements.txt              # Dependencies: watchdog, sqlite-utils
│
└── Testing
    ├── test_extraction.py            # Unit tests
    ├── test_system.py                # Integration tests
    └── api_output/                   # Sample extraction results
```

---

## Extraction Pipeline: Method Chain

Methods are tried in priority order. The first one that produces results wins.

### Method 1: Domain-Specific Form (confidence 0.9)
`spire_form_extractor.py`

Specialized regex patterns for Spire Healthcare Registration Forms. Highly accurate on well-OCR'd forms because the layout is consistent.

### Method 2: Generic Form (confidence 0.8)
`address_extractor.py` -> `extract_from_form()`

Pattern matching for structured forms with field labels (`Name:`, `Address:`, `Date of Birth:`).

### Method 3: Label-Based (confidence 0.7)
`address_extractor.py` -> `extract_from_label()`

For address label formats (mail merge, envelope style): name on first line, address lines, city + postcode.

### Method 4: Unstructured Fallback (confidence 0.5)
`address_extractor.py` -> `extract_unstructured()`

Uses postcode as anchor, looks for patterns nearby.

### Method 5: LLM Enhancement (variable confidence)
`llm_extractor.py`

If Ollama is available locally, uses a small model (qwen2.5:3b) to fill gaps or extract from poor-quality OCR. Data never leaves the machine.

---

## JSON Output Format

Each document gets an `.addresses/{document_id}.json` file with three sections owned by different systems:

```json
{
  "document_id": "Kelly_Sidney_010575",
  "schema_version": 2,
  "extracted_at": "2026-02-13T10:00:00Z",
  "page_count": 1,

  "pages": [
    {
      "page_number": 1,
      "address_type": "patient",
      "is_prime": true,
      "patient": {
        "full_name": "Sidney Kelly",
        "date_of_birth": "01/05/1975",
        "phones": { "home": "01234567890", "mobile": "07700900001" }
      },
      "address": {
        "line_1": "123 High Street",
        "city": "Redhill",
        "county": "Surrey",
        "postcode": "RH1 2AA"
      },
      "gp": {
        "name": "Dr Smith",
        "practice": "The Health Centre",
        "postcode": "RH1 1AA"
      },
      "extraction": { "method": "spire_form", "confidence": 0.9 }
    }
  ],

  "overrides": [],

  "enriched": {
    "enriched_at": "2026-02-13T10:30:00Z",
    "patient": { "full_name": "Sidney Kelly", "document_count": 3 },
    "practitioners": [
      { "name": "Dr John Smith", "type": "GP", "practice": "The Health Centre" }
    ]
  }
}
```

**Ownership**:
- `pages[]` -- owned by extraction_service (writes on OCR processing)
- `overrides[]` -- owned by the Swift app (writes when user corrects data)
- `enriched` -- owned by backend_db (writes on ingestion/enrichment)

**Resolution priority in Swift app**: override > page > enriched

---

## Backend Database Schema

8 tables in `backend_schema.sql`:

| Table | Purpose |
|-------|---------|
| `documents` | One row per JSON file, tracks content hash for change detection |
| `patients` | Deduplicated patient entities |
| `practitioners` | GPs, opticians, consultants (deduplicated) |
| `extractions` | Raw per-page extraction results with foreign keys to entities |
| `patient_documents` | Which patients appear in which documents |
| `patient_practitioners` | Patient-GP relationships with document counts |
| `corrections` | Override-derived training data (field, old value, new value) |
| `name_aliases` | Learned name mappings from corrections |

### Identity Resolution

Patients are identified by **filename parsing** (not OCR), which avoids junk entries from form labels and OCR noise:

- Pattern: `Surname_Firstname_DDMMYY.json`
- Example: `Anderson-Dixon_Anthony_200461.json` -> "Anthony Anderson-Dixon", DOB 20/04/1961

Dedup key: `(normalized_name, date_of_birth)` for patients; `(normalized_name, type)` for practitioners.

### Learning Feedback Loop

```
User corrects data in Swift app
  -> Swift writes to .addresses/Foo_Bar_010180.json overrides[]
  -> backend_db.py ingests, compares override vs original
  -> Records diffs in corrections table
  -> Updates name_aliases table
  -> Future ingestion uses aliases for better entity resolution
```

---

## Running the Service

### Development

```bash
cd AddressExtractor
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Run extraction service (watches for new OCR results)
python extraction_service.py

# Run backend ingestion + analytics
python backend_db.py --ingest --enrich --stats
```

### Production (Mac mini)

Configured as LaunchAgent at `~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist`. Runs at load, keeps alive.

```bash
# Load/start
launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist

# Check status
launchctl list | grep extraction

# View logs
tail -f ~/Library/Logs/yiana-extraction.log
```

### CLI Reference

```bash
python backend_db.py --ingest              # Ingest .addresses/*.json (idempotent)
python backend_db.py --enrich              # Write enriched data back to JSON
python backend_db.py --stats               # Show database statistics
python backend_db.py --merge-candidates    # Show duplicate entity candidates
python backend_db.py --corrections         # Show corrections and learned aliases
python backend_db.py --top-practitioners   # Show most-referenced practitioners
python backend_db.py --top-links           # Show patient-practitioner relationships
```

---

## Adapting for a Different Domain

The architecture is domain-agnostic. Only the entity types, extraction patterns, and reference data change. Below are suggested prompts you can give an LLM to help adapt each component.

### Step 1: Define Your Entities

**Prompt**:
> I have a document scanning app that extracts structured data from scanned documents. Currently it extracts UK healthcare data (patients, GPs, opticians, specialists). I want to adapt it for [YOUR DOMAIN, e.g., "supply chain management" or "legal practice" or "real estate"]. What entities should I define? For each entity, list the fields I should extract and the relationships between entities. Use the same pattern: a primary entity (like "patient") and secondary entities (like "GP").

### Step 2: Adapt the Database Schema

**Prompt**:
> Here is my current SQLite schema for healthcare entities: [paste backend_schema.sql]. I want to adapt this for [YOUR DOMAIN] with these entities: [LIST FROM STEP 1]. Rewrite the schema keeping the same architectural patterns: a documents table with content hashing, entity tables with normalized names for deduplication, an extractions table for raw per-page results, relationship tables with document counts, and corrections/name_aliases tables for the learning loop. Keep the same deduplication strategy (normalized_name + unique key).

### Step 3: Write Domain-Specific Extractors

**Prompt**:
> Here is my current address extraction code that uses regex pattern matching to extract patient and GP data from OCR text: [paste address_extractor.py]. I want to create a new extractor for [YOUR DOCUMENT TYPE, e.g., "vendor invoices" or "lease agreements" or "insurance claims"]. The documents typically contain: [DESCRIBE TYPICAL CONTENT AND LAYOUT]. Write a new extractor class following the same pattern: try structured extraction first (looking for field labels), then fall back to positional/unstructured extraction. Return a dict with the entity fields from Step 1.

### Step 4: Create a Form-Specific Extractor (Optional)

If you have a common form type with consistent layout:

**Prompt**:
> Here is my Spire Healthcare form extractor that uses regex patterns specific to a known form layout: [paste spire_form_extractor.py]. I have a similar high-volume form from [VENDOR/SOURCE]. Here is a sample of the OCR text output: [PASTE SAMPLE]. Write a specialized extractor for this form type following the same pattern: detect the form by unique text markers, then extract fields using regex patterns tuned to this specific layout. Return confidence 0.9 since form layouts are consistent.

### Step 5: Build Reference Data Matchers

**Prompt**:
> Here is my GP matcher that fuzzy-matches extracted practitioner names against an NHS ODS database: [paste gp_matcher.py and gp_fuzzy_search.py]. I want to create a similar matcher for [YOUR REFERENCE DATA, e.g., "our CRM customer database" or "the DUNS vendor directory"]. The reference data is in [FORMAT: SQLite/CSV/API]. Write a matcher class that takes an extracted entity name and optional hints (address, postcode) and returns the best match from the reference database with a confidence score.

### Step 6: Adapt the Filename Parser

**Prompt**:
> My current system identifies patients from the document filename pattern: `Surname_Firstname_DDMMYY.json` (e.g., `Anderson-Dixon_Anthony_200461.json`). This is more reliable than OCR-based name extraction. My documents use a different naming convention: [DESCRIBE YOUR PATTERN, e.g., "InvoiceNumber_VendorName_YYYYMMDD" or "CaseRef_ClientSurname"]. Write a filename parser that extracts the primary entity identity from this pattern, to be used as the deduplication anchor instead of OCR-extracted names.

### Step 7: Adapt the LLM Prompt

**Prompt**:
> Here is my LLM extraction prompt that asks a local model to extract healthcare data from OCR text: [paste the prompt from llm_extractor.py]. Rewrite this prompt for [YOUR DOMAIN]. The model should extract: [FIELDS FROM STEP 1]. Keep the same approach: ask for JSON output, include examples of expected format, and emphasize extracting what's visible rather than guessing.

### Step 8: Wire It Together

**Prompt**:
> Here is my extraction_service.py that watches for new OCR files and runs the extraction pipeline: [paste extraction_service.py]. I've created these new extractors: [LIST]. Update the service to use my new extractors in priority order, write output in the same JSON format (with pages/overrides/enriched sections), and process my document types instead of healthcare forms.

---

## Key Design Decisions

1. **Filename-based identity**: More reliable than OCR for primary entity identification
2. **Three-section JSON ownership**: pages (extractor), overrides (app), enriched (backend) -- prevents circular dependencies
3. **Local-only LLM**: Ollama, never external APIs -- data stays on your hardware
4. **Content hash for idempotency**: Ingestion skips unchanged files, but enrichment writes don't break idempotency
5. **Atomic file writes**: Temp file + rename prevents partial corruption
6. **Pattern matching first, LLM fallback**: Fast path (10ms) before expensive path (3s)
7. **Three-tier data**: Raw extractions (verbatim OCR) + deduplicated entities + corrections/aliases (learning)
