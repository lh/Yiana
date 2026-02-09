# Address Database & Learning System Architecture

## Decided 2026-02-09

### Dual-Layer Storage
- **JSON files** (`.addresses/*.json` in iCloud) = sync layer between Devon and Swift app
- **Backend SQLite** (Devon local, outside iCloud) = canonical entity repository
- JSON files are ingestion events; backend DB is source of truth for entities

### Entity-Centric Backend
- Practitioners (GP, optometrist, specialist) are first-class entities with canonical records
- Patients deduplicated across documents
- Documents are observations of entities, not the primary unit

### Write Ownership
- Devon owns `pages[]` in JSON files
- Swift app owns `overrides[]` in JSON files
- Devon enriches JSON with canonical data (writes back to `pages[]`)

### Corrections as Training Data
- Every Swift override is ingested into backend `corrections` table with full context
- Corrections drive: alias tables, exclusion rules, confidence stats
- Human review before any learned rules go live

### Implementation Phases
1. **Backend SQLite schema + ingestion from JSONs** ← START HERE
2. Corrections flow (overrides → corrections table)
3. Simplest learning: aliases & exclusions
4. Enrichment write-back (canonical data → JSON pages[])
5. Advanced learning (LLM few-shot, confidence recalibration, letters)

### Key Principle
One thing at a time. Simplest implementation first. Confirm it works before building on it.

## Key Files
- Python extraction: `AddressExtractor/extraction_service.py`, `address_extractor.py`
- Swift models: `Yiana/Yiana/Models/ExtractedAddress.swift`
- Swift repository: `Yiana/Yiana/Services/AddressRepository.swift`
- Legacy schema: `AddressExtractor/schema.sql`
- Dead code: `AddressExtractor/training_analysis.py` (queries nonexistent columns)
