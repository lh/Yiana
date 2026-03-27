# Yiana Project Audit — 2026-03-27

## Executive Summary

Yiana is a mature, production-quality document scanning and PDF management app across iOS, iPadOS, and macOS. Over 8.5 months and 623 commits, the project has evolved from a simple scanner to a full clinical document workflow tool with OCR, address extraction, entity resolution, letter composition, and Typst-based rendering — all consolidated into a single Swift codebase.

The app is on TestFlight as version 2.0 (build 51). Devon (Mac mini) is retired as a processing server and serves only as an iCloud sync node. The Python backend is fully replaced by Swift packages.

**Key finding:** The project is feature-rich and architecturally sound, but has accumulated housekeeping debt in documentation, memories, and stale branches. The codebase itself is clean — the debt is in the surrounding metadata.

---

## 1. Project Structure

### Active Swift Packages (4)

| Package | Purpose | Dependencies |
|---------|---------|-------------|
| **YianaExtraction** | Address extraction, entity DB, NHS lookup | GRDB.swift |
| **YianaRenderer** | Typst-based letter/envelope PDF rendering | CYianaTypstBridge (Rust FFI) |
| **YianaDocumentArchive** | .yianazip package format | ZIPFoundation |
| **YianaOCRService** | Server-side OCR (legacy, Devon retired) | swift-argument-parser, swift-log |

### App Source (Yiana/)

| Directory | Files | Role |
|-----------|-------|------|
| Services/ | 32 | Persistence, extraction, rendering, sync, import/export |
| Views/ | 26 | SwiftUI views (cross-platform with `#if os()` guards) |
| ViewModels/ | 5 | Business logic layer |
| Models/ | 12 | Data models (DocumentMetadata, ExtractedAddress, LetterDraft, etc.) |
| Extensions/ | 5 | PDFDocument page indexing, String title case, URL helpers |
| Utilities/ | 12 | Formatting, dev tools, markdown, typography |
| Accessibility/ | 1 | VoiceOver support |
| Markup/ | 2 | PencilKit PDF markup |

### Legacy / Retired (still in repo)

| Directory | Status | Notes |
|-----------|--------|-------|
| **AddressExtractor/** | Retired | 74 files, 32 Python scripts, 5 SQLite databases. Fully replaced by YianaExtraction Swift package. Python extraction service, backend DB, letter generator — all ported to Swift |
| **YianaOCRService/** | Retired | Devon OCR daemon no longer running. On-device OCR via Vision framework replaced it |
| **scripts/** | Partially retired | Dashboard, watchdog, status scripts for Devon. Some (generate_sector_lookup.py) still useful |
| **memory-bank/** | Stale | Old context system from pre-Serena/Claude memory days |

---

## 2. Development Trajectory

- **623 total commits** across 8.5 months (Jul 2025 - Mar 2026)
- **97 commits in March 2026 alone** (~3.6/day) — massive polish sprint
- **10 consolidation phase tags** tracking the Python-to-Swift migration
- **16 local branches**, 14 fully merged and deletable

### Recent Focus (March 2026)
The last month has been a polish and consolidation sprint: letter formatting, recipient management, work list, postcode lookup, address card type fixes, settings UI, and this session's type-aware save refactor.

---

## 3. GitHub Issues

**20 open, 4 closed** (24 total)

### By Category

**Bugs (1 open):**
- #25 Restore-on-launch needs timeout and escape hatch

**Polish / UX (6 open):**
- #5 Envelope window alignment (needs measurements from work stationery)
- #6 DOB field validation / date picker
- #11 Traffic light filters on iPad/iPhone
- #12 DOB format: DD/MM/YYYY to ISO 8601
- #23 Clean up dead draft infrastructure
- #24 Email addresses (Spire form has them, we don't save them)

**Enhancements (5 open):**
- #3 Performance: note loading/exiting speed
- #4 Sender details in Settings UI
- #14 iOS compose access (the big one)
- #15 Built-in letter preview (iPad)
- #22 Auto-update postcode lookup from ONS ONSPD

**Extraction Quality (4 open):**
- #7 Extraction misses address lines on some layouts
- #8 GP data not extracted from some documents
- #9 Duplicate phone numbers in extraction
- #10 Use metadata.fullText as extraction fallback

**Ideas / Future (4 open):**
- #18 Custom/user-editable letter templates
- #19 Visual form template builder for OCR
- #20 Local peer-to-peer sync (Multipeer/Bonjour)
- #21 iPhone camera as scanner for Mac (Continuity Camera)

### Closed (4):
- #13 Rename Prime to Verified -- done
- #16 Drafts list / sidebar -- done
- #17 Work list reimplementation -- done
- #26 Write default recipient role when verified -- done

---

## 4. Serena Memory Audit

### Ideas & Problems Log (32 items)

Cross-referenced against GitHub Issues and current codebase state:

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Connected scanner on macOS | Parked | Deliberately out of scope |
| 3 | Expandable Typst dashboard | Stale | Devon retired; dashboard was Devon-only |
| 7 | fullText as extraction fallback | Open | GitHub #10 |
| 8 | Special chars in folder names | Open | Not in GitHub issues — **should be filed** |
| 9 | Extraction misses address lines | Open | GitHub #7 |
| 10 | Duplicate phone numbers | Open | GitHub #9 |
| 11 | GP data not extracted | Open | GitHub #8 |
| 12 | iCloud override race condition | Open | Not in GitHub — **should be filed or resolved** |
| 13 | Postcode lookup table | **Done** | Implemented (9,603 sectors from ONS ONSPD) |
| 14 | DOB format standardisation | Open | GitHub #12 |
| 15 | Recipient tick boxes | **Done** | Implemented (To/CC/None per card) |
| 16 | HTML render leading comma | Stale | HTML render was Devon Python; now Typst |
| 17 | Document auto-reload after inject | Open | Not in GitHub — **should be filed** |
| 18 | Typst replaces LaTeX | **Done** | YianaRenderer fully operational |
| 19a | Envelope window alignment | Open | GitHub #5 |
| 19b | Footer contact block | **Done** |  |
| 19c | Custom letter templates | Open | GitHub #18 |
| 20 | iPhone Continuity Camera | Open | GitHub #21 |
| 21a-c | Address card UI issues | **Mostly done** | Town inferred, GP cards work, save fixed today |
| 22 | Traffic light filters | Open | GitHub #11 |
| 23 | P2P sync | Open | GitHub #20 |
| 24 | Visual form template builder | Open | GitHub #19 |
| 25 | NHS candidate click to adopt | **Done** | Implemented |
| 26 | Performance improvements | Open | GitHub #3 |
| 27 | Restore last state | **Done** | Implemented |
| 28 | Rename Prime to Verified | **Done** | GitHub #13 closed |
| 29 | DOB field validation | Open | GitHub #6 |
| 30 | Built-in letter preview (iPad) | Open | GitHub #15 |
| 31 | Sender details Settings UI | Open | GitHub #4 |
| 32 | Auto-update postcode lookup | Open | GitHub #22 |

**Summary:** 10 items done, 15 open (most tracked in GitHub), 3 stale, 3 not in GitHub and should be filed or resolved.

### Stale Serena Memories

| Memory | Issue | Recommendation |
|--------|-------|----------------|
| `pending_devon_local_sqlite` | Devon retired; no need for local SQLite rebuild | **Delete** — entity DB now runs in-app via GRDB |
| `project_overview` | Lists Phase 2 "in progress", references macOS 14+/iOS 17+ (now 15+/12+), says "server-side OCR" | **Rewrite** — fundamentally outdated |
| `project_structure` | Lists 8 development phases from original plan, missing 4 Swift packages, AddressExtractor, scripts | **Rewrite** — doesn't reflect current repo |
| `session_handoff_2026-02-08` | Historical record only | **Keep as-is** (session handoffs are snapshots) |
| `session_handoff_2026-02-09` | Historical record only | **Keep as-is** |
| `session_handoff_2026-02-10` | Historical record only | **Keep as-is** |
| `address_backend_guide` | References Python backend_db.py on Devon, deployment commands | **Mark as legacy** — Python backend retired |
| `address_database_architecture` | Dual-layer design doc; references Python Devon writes, planned phases | **Mark as legacy** — architecture superseded by consolidation |
| `json_sync_architecture` | References Devon Python extraction, LaunchAgent deployment, git pull deploy | **Update** — Devon retired, write ownership simplified (Swift-only) |
| `code_style_conventions` | May be current | **Verify** — some conventions may reference old patterns |
| `suggested_commands` | May reference Devon SSH commands | **Verify and prune** |
| `swiftui_uikit_integration_patterns` | Likely still valid | **Keep** |
| `task_completion_checklist` | Likely still valid | **Keep** |

### Stale Claude Memory Files

| File | Issue | Recommendation |
|------|-------|----------------|
| `feedback_compose_design.md` | References "LaTeX on Devon" for rendering, "don't preview in-app" | **Update** — Typst rendering is now in-app, not on Devon. Letter preview is the next feature (#15) |
| `project_consolidation.md` | Hasn't been updated since Phase 4 completion | **Update** with current status: consolidation complete, Devon retired |
| `swift-log-and-launchd.md` | Fix was implemented; this is a postmortem | **Keep** as reference (still valid knowledge) |
| MEMORY.md line 127-134 | "Address Backend Database" section references Python backend_db.py and Devon deploy commands | **Update** — this is now GRDB in YianaExtraction |
| MEMORY.md line 120-125 | "Server (Mac mini Devon)" section | **Update** — Devon retired, services no longer running |

### Stale Repo Files

| File | Issue | Recommendation |
|------|-------|----------------|
| `PLAN.md` | All 8 phases complete; says "see Roadmap.md for current status" | **Delete or archive** |
| `memory-bank/activeContext.md` | References "January 2025", old architecture with optional backends | **Delete** — superseded by Serena + Claude memories |
| `docs/consolidation-architecture.md` | Proposal from 2026-03-16 | **Keep** as historical design doc |

---

## 5. Stale Branch Cleanup

14 branches are fully merged into main and can be deleted:

```
consolidation/v1.1          (also on remote)
feature/name-field-split
feature/on-device-ocr
feature/page-copy-paste
feature/text-page-editor
feature/work-list-redesign
iPad-enhancements
ios-drag-and-drop
ocr-tuning
refactor-icloud
refactor/zip
sidebar-inline-editing
untested
```

`feature/text-page-addition` has 4 unmerged commits from October 2025 (6 months stale) — review before deleting.

---

## 6. Architecture Status Post-Consolidation

### What's In-App Now (was on Devon)
- OCR: Vision framework on-device (`OnDeviceOCRService`)
- Extraction: `YianaExtraction` Swift package (NLTagger + NSDataDetector)
- Entity DB: GRDB.swift in `EntityDatabaseService`
- Letter rendering: `YianaRenderer` (Typst via Rust FFI, 30ms for 3 PDFs)
- Letter composition: `ComposeViewModel` + `ComposeTab`

### What Devon Still Does
- iCloud sync node (keeps files available when devices sleep)
- Nothing else — all processing services are retired

### Dependency Inventory
| Dependency | Version | Purpose | Status |
|-----------|---------|---------|--------|
| GRDB.swift | 7.7+ | SQLite wrapper for entity DB + NHS lookup | Active, healthy |
| ZIPFoundation | 0.9.19+ | .yianazip package format | Active, healthy |
| swift-argument-parser | 1.3+ | CLI for OCR service | Legacy (OCR service retired) |
| swift-log | 1.5+ | Logging for OCR service | Legacy (OCR service retired) |
| CYianaTypstBridge | Binary | Rust FFI for Typst rendering | Active |

---

## 7. Items Not Tracked Anywhere

Found during audit — these exist in `ideas_and_problems` but not in GitHub Issues:

1. **Special characters in folder names** (#8 in ideas) — `?`, `#`, `%` corrupt file operations
2. **iCloud override race condition** (#12 in ideas) — separate override file needed
3. **Document auto-reload after InjectWatcher** (#17 in ideas) — appended pages not visible without reopen

These should either be filed as GitHub Issues or resolved/dismissed.

---

## 8. Recommended Housekeeping

### Immediate (low effort, high clarity)

1. **Delete 14 stale branches** (all fully merged)
2. **Delete `PLAN.md`** — superseded by roadmap and consolidation plan
3. **Delete `memory-bank/` directory** — superseded by Serena + Claude memories
4. **Delete Serena memory `pending_devon_local_sqlite`** — Devon retired
5. **Update `feedback_compose_design.md`** — Typst is in-app now, not LaTeX on Devon
6. **Update `project_consolidation.md`** — mark consolidation as complete
7. **File 3 untracked issues** to GitHub (#8 folder chars, #12 override race, #17 inject reload)

### Medium effort

8. **Rewrite Serena memories `project_overview` and `project_structure`** — fundamentally outdated
9. **Mark `address_backend_guide`, `address_database_architecture`, `json_sync_architecture`** as legacy/archived in Serena
10. **Update MEMORY.md** — Devon and backend DB sections need revision
11. **Prune `ideas_and_problems`** — remove completed items, update status of remaining

### Consider for roadmap discussion

12. **AddressExtractor/ directory** — 74 files of retired Python code still in repo. Archive or delete?
13. **YianaOCRService/** — retired but contains useful plist templates and SERVER-SETUP.md
14. **scripts/** — some scripts reference Devon services that no longer run

---

## 9. Roadmap Priorities (for discussion)

Based on GitHub Issues, ideas log, and current state, here's how the open work clusters:

### Essential for Other Users
- #4 Sender details in Settings UI
- #25 Restore-on-launch timeout/escape hatch (bug)

### Essential for Clinical Workflow
- #14 iOS compose access
- #15 Built-in letter preview (iPad)
- #5 Envelope window alignment

### Quality of Life
- #3 Performance measurement and optimisation
- #6 DOB validation / date picker
- #12 DOB format standardisation (ISO 8601)
- #23 Clean up dead draft infrastructure
- #11 Traffic light filters on iPad/iPhone

### Extraction Quality
- #7, #8, #9, #10 — extraction improvements (address lines, GP data, dedup, fullText fallback)
- #24 Email addresses

### Future / Ideas
- #18, #19, #20, #21, #22 — templates, form builder, P2P sync, Continuity Camera, postcode updates
