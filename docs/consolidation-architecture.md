# Consolidation Architecture

## Status: Proposal (2026-03-16)

## Problem Statement

Yiana's processing pipeline is spread across two apps, two languages, a Mac mini
server, and several operational scripts. Communication is entirely via
iCloud-synced JSON files. This works but creates:

- **Operational overhead**: launchd plists, log rotation, watchdog cron, deployment
  protocol, Python venv/PYTHONPATH management
- **Latency**: document must sync to Mac mini, get processed, sync results back
- **Fragility**: iCloud sync is eventually consistent; race conditions between
  watchers; heartbeat monitoring to detect silent failures
- **Cognitive load**: two languages, two build systems, two deployment targets,
  duplicated models (SharedWorkList.swift exists in both apps)

## Current Architecture

```
┌─────────────────────────────────────┐
│ User Devices                        │
│                                     │
│  Yiana (iOS/macOS)                  │
│   - Document management             │
│   - On-device OCR (Vision)          │
│   - Address display + overrides     │
│   - Search index (GRDB FTS5)        │
│                                     │
│  Yiale (iOS/macOS)                  │
│   - Letter composition              │
│   - Patient search (reads .addresses)│
│   - Draft management                │
└──────────────┬──────────────────────┘
               │ iCloud Sync
               ▼
┌─────────────────────────────────────┐
│ Mac mini "Devon"                    │
│                                     │
│  YianaOCRService (Swift daemon)     │
│   - Watches .yianazip files         │
│   - OCR via Vision framework        │
│   - Writes .ocr_results/           │
│                                     │
│  extraction_service.py (Python)     │
│   - Watches .ocr_results/          │
│   - Regex cascade + NHS lookup      │
│   - Writes .addresses/             │
│                                     │
│  backend_db.py (Python)            │
│   - Ingests .addresses/            │
│   - Entity dedup (patients, GPs)    │
│   - Writes enriched data back       │
│                                     │
│  Monitoring (Bash/Python)           │
│   - Watchdog cron (Pushover alerts) │
│   - Dashboard (typst-live)          │
│   - Health check scripts            │
└─────────────────────────────────────┘
```

### Component Inventory

| Component | Language | LOC | Purpose |
|-----------|----------|-----|---------|
| Yiana app | Swift | ~8000 | Document management, OCR, addresses |
| Yiale app | Swift | ~2400 | Letter composition |
| YianaOCRService | Swift | ~2500 | Server-side OCR |
| extraction_service.py | Python | ~960 | Address extraction watcher |
| address_extractor.py | Python | ~620 | Regex-based extraction |
| spire_form_extractor.py | Python | ~330 | Spire Healthcare form parser |
| llm_extractor.py | Python | ~260 | Optional Ollama fallback |
| backend_db.py | Python | ~1420 | Entity deduplication DB |
| NHS lookup (in extraction_service) | Python | ~200 | ODS postcode lookup |
| Scripts (watchdog, status, dashboard) | Bash/Python | ~500 | Monitoring |
| **Total backend** | | **~6790** | |

## Target Architecture

```
┌──────────────────────────────────────────────────┐
│ Yiana (single app — iOS/iPadOS/macOS)            │
│                                                   │
│  Document Management (unchanged)                  │
│  On-Device OCR (Vision, already exists)           │
│  Extraction Engine (NEW — Swift)                  │
│   ├─ Form detector (Spire + generic)             │
│   ├─ Address parser (NLTagger + NSDataDetector)  │
│   ├─ NHS/ODS lookup (GRDB + bundled SQLite)      │
│   └─ Entity resolver (name norm + dedup)         │
│  Entity Database (NEW — GRDB SQLite)              │
│   ├─ Patients (deduped across documents)         │
│   ├─ Practitioners (deduped, ODS-linked)         │
│   └─ Corrections / learning (phase 2)            │
│  Letter Composition (absorbed from Yiale)         │
│   ├─ Patient search (reads entity DB directly)   │
│   ├─ Draft management                            │
│   └─ PDF rendering                               │
│  Search Index (GRDB FTS5, unchanged)              │
│  iCloud Sync (unchanged)                          │
└──────────────────────────────────────────────────┘
```

### The Boss Instance

The Mac mini does not go away. It runs a macOS instance of Yiana as a **login
item** — the "boss instance." This instance:

1. **Is always on.** It processes documents continuously, not just when a user
   happens to have the app open. New documents synced via iCloud are extracted
   immediately.

2. **Runs integrations.** File watchers that copy documents to third-party
   Dropbox folders, send email notifications, trigger webhooks — anything that
   needs an always-on presence. These are configured as part of the boss
   instance, not as separate scripts.

3. **Handles bulk work.** Initial ingestion of 1400+ documents, full re-extraction
   after pattern improvements, entity database rebuilds — work that would drain
   an iPhone battery or block the UI.

4. **Is the same binary.** No separate OCR service, no Python extraction, no
   deployment protocol. `git pull && open Yiana.app` (or automatic App Store
   update). The boss instance runs the same code as every other instance; it
   just happens to be always on.

The boss instance is distinguished by configuration, not by code:

```
Boss Instance (Mac mini):
  - autoProcessOnLaunch: true
  - backgroundExtraction: true
  - integrations: [dropboxCopy, emailNotify]
  - entityDatabasePath: ~/Data/entities.db

Regular Instance (iPhone/iPad/Mac):
  - autoProcessOnLaunch: false (or on-demand)
  - backgroundExtraction: false (process when viewing)
  - integrations: []
  - entityDatabasePath: (local cache, synced subset)
```

### What Changes, What Stays

| Concern | Before | After |
|---------|--------|-------|
| OCR | Dual: on-device + Mac mini daemon | On-device only (Vision) |
| Extraction | Python regex cascade on Mac mini | Swift NLTagger + NSDataDetector in-app |
| Entity DB | Python + raw sqlite3 on Mac mini | GRDB in-app (same as search index) |
| NHS lookup | Python SQLite queries | GRDB + bundled .db |
| Letter composition | Separate app (Yiale) | Feature module in Yiana |
| Work list | Duplicated SharedWorkList.swift | Single implementation |
| Monitoring | Bash watchdog + Pushover | App-level health (or eliminated) |
| Always-on integrations | Bespoke scripts on Mac mini | Boss instance config |
| Deployment | SSH + stop/copy/start protocol | App Store update (or direct build) |
| iCloud file format | Unchanged | Unchanged |
| .yianazip format | Unchanged | Unchanged |
| .addresses/ JSON format | Unchanged during migration | Unchanged during migration |

### What We Lose and How We Mitigate

| Loss | Mitigation |
|------|------------|
| Parallel processing (daemon watches while app is closed) | Boss instance is always running |
| iOS background processing (30s limit) | Process on-demand when app is open; boss instance handles backlog |
| Python's rapid iteration for extraction patterns | Swift extraction is simpler (fewer lines) and provably better (NLTagger) |
| Ollama LLM fallback | Defer; revisit with on-device CoreML models if needed |
| Independent failure domains (app crash doesn't affect server) | Track processing state per-document; resume on relaunch |
| Side-by-side Yiana + Yiale | iPadOS Split View / macOS multi-window within single app |

## Domain Configurability (Phase 2)

The extraction and entity pipeline is domain-specific only in its patterns and
labels. The architecture (scan, OCR, extract, link, compose) is generic.

After consolidation, extracting domain-specific parts into configuration:

| Layer | Medical (current) | Business (example) |
|-------|-------------------|-------------------|
| Entity types | Patient, GP, Specialist | Client, Account Manager, Supplier |
| Key identifier | NHS Number, DOB | Client ID, Company Number |
| Lookup database | NHS ODS (GP practices) | Company directory |
| Extraction patterns | Spire forms, referral letters | Invoices, contracts |
| Letter templates | Clinical correspondence | Business correspondence |
| Filename convention | Surname_Firstname_DDMMYY | Company_Contact_Reference |

Implementation: a `Domain` enum with associated configuration bundles. Core
pipeline code is shared; only patterns, labels, and lookup data vary.

This is explicitly deferred until after consolidation is complete and tested.
