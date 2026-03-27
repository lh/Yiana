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

**26 open, 4 closed** (30 total)

### By Category

**Bugs (4 open):**
- #25 Restore-on-launch needs timeout and escape hatch
- #28 Search bar refreshes on each letter typed (should debounce or search-on-submit)
- #30 Special characters in folder names corrupt file operations
- #32 Document doesn't auto-reload after InjectWatcher appends PDF

**Data Model (2 open):**
- #27 Multiple "other" addresses needed — adding a second overwrites the first; also needs position/title field
- #31 iCloud override race condition — separate override file needed

**Polish / UX (6 open):**
- #5 Envelope window alignment (needs measurements from work stationery)
- #6 DOB field validation / date picker
- #11 Traffic light filters on iPad/iPhone
- #12 DOB format: DD/MM/YYYY to ISO 8601
- #23 Clean up dead draft infrastructure
- #24 Email addresses (Spire form has them, we don't save them)

**Enhancements (6 open):**
- #3 Performance: note loading/exiting speed
- #4 Sender details in Settings UI
- #14 iOS compose access (the big one)
- #15 Built-in letter preview (iPad)
- #22 Auto-update postcode lookup from ONS ONSPD
- #29 Envelope printing (driving printer properly)

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

### Ideas & Problems Log
Deleted. All open items migrated to GitHub Issues (including 3 filed this session: #30, #31, #32). GitHub Issues is now the single source of truth for bugs, improvements, and ideas.

### Serena Memory Cleanup (completed this session)

| Memory | Action Taken |
|--------|-------------|
| `pending_devon_local_sqlite` | **Deleted** — Devon retired |
| `ideas_and_problems` | **Deleted** — migrated to GitHub Issues |
| `project_overview` | **Rewritten** — reflects current all-Swift architecture |
| `project_structure` | **Rewritten** — reflects current repo layout |
| `address_backend_guide` | **Moved to legacy/** — Python backend retired |
| `address_database_architecture` | **Moved to legacy/** — superseded by consolidation |
| `json_sync_architecture` | **Moved to legacy/** — Devon retired, Swift-only now |
| `session_handoff_2026-02-*` | **Kept** — historical snapshots |
| `code_style_conventions` | **Kept** — still valid |
| `suggested_commands` | **Kept** — may need pruning of Devon commands |
| `swiftui_uikit_integration_patterns` | **Kept** — still valid |
| `task_completion_checklist` | **Kept** — still valid |

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

## 7. Housekeeping Completed This Session

All items from the original audit have been actioned:

1. **Deleted 14 stale branches** + 1 stale worktree + remote `consolidation/v1.1`
2. **Deleted `memory-bank/` directory** — superseded by Serena + Claude memories
3. **Deleted `AddressExtractor/`** (74 files) — retired Python backend, preserved in git history
4. **Pruned `scripts/`** to just `generate_sector_lookup.py`
5. **Deleted Serena memories:** `pending_devon_local_sqlite`, `ideas_and_problems`
6. **Rewrote Serena memories:** `project_overview`, `project_structure`
7. **Archived Serena memories:** `address_backend_guide`, `address_database_architecture`, `json_sync_architecture` moved to `legacy/`
8. **Updated Claude memories:** `feedback_compose_design.md` (Typst), `project_consolidation.md` (complete), `MEMORY.md` (Devon retired)
9. **Filed 3 missing issues** to GitHub: #30, #31, #32
10. **Single source of truth:** GitHub Issues is now the only place for bugs/improvements/ideas

### Still to do
- **Delete `PLAN.md`** — superseded by roadmap (needs user confirmation)

---

## 8. Roadmap Priorities (for discussion)

Based on GitHub Issues and current state, here's how the 26 open issues cluster:

### Bugs (fix first)
- #25 Restore-on-launch timeout/escape hatch
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
- #7, #8, #9, #10 — extraction improvements (address lines, GP data, dedup, fullText fallback)

### Future / Ideas
- #18, #19, #20, #21, #22 — templates, form builder, P2P sync, Continuity Camera, postcode updates
