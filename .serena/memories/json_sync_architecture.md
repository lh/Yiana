# JSON Sync Architecture for Address Data

## Overview
Replaced SQLite `addresses.db` in iCloud (which got silently overwritten by iCloud's whole-file sync) with per-document JSON files in `.addresses/` directory. iCloud syncs individual files atomically.

## Architecture
- **Before**: Python (Devon) -> writes -> `addresses.db` (iCloud) <- reads/writes <- Swift app
- **After**: Python (Devon) -> writes `pages[]` -> `.addresses/*.json` (iCloud) <- reads `pages[]`, writes `overrides[]` <- Swift app

## Key Files
- `Yiana/Yiana/Models/ExtractedAddress.swift` — Codable structs for JSON schema + flat `ExtractedAddress` view model
- `Yiana/Yiana/Services/AddressRepository.swift` — JSON file reader/writer (replaced GRDB/SQLite)
- `AddressExtractor/extraction_service.py` — Writes `.addresses/*.json` on Devon
- `AddressExtractor/migrate_to_json.py` — One-time migration script (already run)

## Write Ownership Rules
- **Devon (Python)**: Writes `pages[]` and extraction metadata. Never touches `overrides[]`.
- **Swift app**: Writes `overrides[]`, `is_prime`, `address_type` changes. Never touches `pages[]`.
- **Re-extraction**: Devon reads existing file, replaces `pages[]` only, preserves `overrides[]`.

## JSON Schema (`.addresses/{document_id}.json`)
```json
{
  "schema_version": 1,
  "document_id": "...",
  "extracted_at": "...",
  "page_count": 1,
  "pages": [{ "page_number": 1, "patient": {...}, "address": {...}, "gp": {...}, "extraction": {...} }],
  "overrides": [{ "page_number": 1, "match_address_type": "patient", ... }]
}
```

## Override Matching
Overrides match pages by composite key: `page_number` + `match_address_type` (not array index). Most recent override wins by `override_date`. Override fields replace page fields entirely.

## Atomic Writes
All writes use temp-file-then-rename:
- Python: `os.replace(tmp_path, final_path)`
- Swift: `FileManager.default.replaceItemAt()`

## Devon Deployment
- Devon pulls code via `git pull` (HTTPS clone at `/Users/devon/Code/Yiana`)
- Extraction service runs as LaunchAgent (NOT LaunchDaemon — needs user-level iCloud access)
- Plist: `~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist`
- KeepAlive + RunAtLoad ensures auto-restart on crash and start on login
- Python 3.9 needs Full Disk Access for `~/Library/Mobile Documents` (iCloud container)
- Full Disk Access granted to: `/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9`
- Logs: `~/Library/Logs/yiana-extraction.log` and `yiana-extraction-error.log`

## Devon Git Setup
- HTTPS clone (not SSH — no SSH keys configured for GitHub on Devon)
- Data files (*.db, api_output/, gp_data/, letters/) are gitignored
- venv is gitignored — must be recreated after clone with `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`
- To deploy: `ssh devon@Devon-6.local` then `cd /Users/devon/Code/Yiana && git pull`
- After pull, restart agent: `launchctl unload ~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist && launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist`

## Migration
- Run once via `migrate_to_json.py` — already completed (1395 documents, 3993 pages, 4 overrides)
- Old `addresses.db` in iCloud still exists but is no longer written to by the Swift app

## Deferred
- File monitoring via `NSMetadataQuery` for live iCloud change notifications
- Devon local SQLite rebuild script for cross-document SQL queries
