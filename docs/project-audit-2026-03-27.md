# Yiana Project Audit — 2026-03-27

## Current State

Yiana is a document scanning and PDF management app for iOS, iPadOS, and macOS, built for clinical workflow. Version 2.0, build 51 on TestFlight. 623 commits over 8.5 months.

All processing is in-app — OCR (Vision), extraction (NLTagger/NSDataDetector), entity DB (GRDB), letter rendering (Typst via Rust FFI). Devon (Mac mini) is an iCloud sync node only. The Python backend is fully retired and deleted from the repo.

Single branch (`main`), single source of truth for issues (GitHub Issues).

---

## Architecture

### Swift Packages

| Package | Purpose | Dependencies |
|---------|---------|-------------|
| **YianaExtraction** | Address extraction, entity DB, NHS lookup | GRDB.swift |
| **YianaRenderer** | Typst letter/envelope PDF rendering | CYianaTypstBridge (Rust FFI) |
| **YianaDocumentArchive** | .yianazip package format | ZIPFoundation |
| **YianaOCRService** | Server OCR (legacy, kept for reference) | swift-argument-parser, swift-log |

### App Source

| Directory | Files | Role |
|-----------|-------|------|
| Services/ | 32 | Persistence, extraction, rendering, sync, import/export |
| Views/ | 26 | SwiftUI views (cross-platform with `#if os()` guards) |
| ViewModels/ | 5 | Business logic layer |
| Models/ | 12 | DocumentMetadata, ExtractedAddress, LetterDraft, etc. |
| Extensions/ | 5 | PDFDocument page indexing, String title case, URL helpers |
| Utilities/ | 12 | Formatting, dev tools, markdown, typography |

---

## Open Issues (26)

### Bugs (fix first)
- #25 Restore-on-launch needs timeout and escape hatch
- #28 Search bar refreshes on each letter typed
- #30 Special characters in folder names corrupt file operations
- #32 Document doesn't auto-reload after InjectWatcher appends PDF

### Data Model
- #27 Multiple "other" addresses + position/title field
- #31 iCloud override race condition

### Essential for Other Users
- #4 Sender details in Settings UI

### Essential for Clinical Workflow
- #14 iOS compose access (the big one)
- #15 Built-in letter preview (iPad)
- #5 Envelope window alignment
- #29 Envelope printing

### Quality of Life
- #3 Performance measurement and optimisation
- #6 DOB validation / date picker
- #12 DOB format standardisation (ISO 8601)
- #23 Clean up dead draft infrastructure
- #11 Traffic light filters on iPad/iPhone
- #24 Email addresses

### Extraction Quality
- #7 Extraction misses address lines on some layouts
- #8 GP data not extracted from some documents
- #9 Duplicate phone numbers in extraction
- #10 Use metadata.fullText as extraction fallback

### Future / Ideas
- #18 Custom/user-editable letter templates
- #19 Visual form template builder for OCR
- #20 Local peer-to-peer sync (Multipeer/Bonjour)
- #21 iPhone camera as scanner for Mac (Continuity Camera)
- #22 Auto-update postcode lookup from ONS ONSPD

---

## Housekeeping Done This Session

- Deleted 14 stale branches + 1 worktree + remote `consolidation/v1.1`
- Deleted `AddressExtractor/` (74 files, -17,497 lines), `memory-bank/`, pruned `scripts/`
- Serena memories: deleted 2, rewrote 2, archived 3 to `legacy/`
- Claude memories: updated 3 (`feedback_compose_design`, `project_consolidation`, `MEMORY.md`)
- Filed 3 missing issues (#30, #31, #32) — all ideas now tracked in GitHub Issues
- `PLAN.md` still in repo — superseded by roadmap, can be deleted

---

## Remaining Housekeeping

- Delete `PLAN.md` (all original phases complete, superseded)
- Verify Serena memories `suggested_commands` and `code_style_conventions` are current
- Remove `dashboard-data.json` from `scripts/` if still present (data file, no script)
