# CLAUDE.md Changelog

Records when and why rules in CLAUDE.md were added or changed. Each entry captures the incident or observation that prompted the change, so the reasoning survives even if the rule is later modified.

---

## 2026-03-09 — Debugging and deployment rules

**Added:** "Exhaust the simplest hypothesis first" debugging rule; deployment protocol details (stop service first, check log sizes, run commands on remote not locally); `~` expansion and PYTHONPATH warnings for Devon.

**Why:** Multiple deployment sessions where commands ran locally instead of on Devon, and a debugging session where TCC permissions were investigated for 45 minutes before checking whether the binary was actually running.

---

## 2026-03-08 — List(selection:) and .sheet(item:) rules

**Added:** `List(selection:)` owns all click gestures — never mix interaction models. `.sheet(item:)` not `.sheet(isPresented:)` when sheet needs data.

**Why:** Eight failed attempts to put work list rows inside the folder sidebar's `List(selection:)`. Every workaround (`.selectionDisabled()`, tag guards, async dispatch) failed because NSTableView/UITableView owns click gestures for the entire list. Fix was a segmented control separating the two views. The `.sheet(item:)` rule came from a first-open bug where the sheet rendered with empty data because state propagation hadn't completed.

---

## 2026-03-03 — Full CLAUDE.md rewrite

**Changed:** Reorganised from accumulated notes into structured sections (Core Rules, Architecture, Code Style, etc.). Added Yiale letter module spec.

**Why:** The file had grown organically and was hard to scan. Structured format makes it easier to find rules and reduces the chance of contradictory guidance.

---

## 2026-02-27 — Documentation refresh

**Changed:** Updated all documentation to match current codebase state.

**Why:** Routine maintenance — several sections referenced removed or renamed files.

---

## 2026-02-21 — Session hooks, clean desk, drag-and-drop rules

**Added:** SessionStart hook for git status reminder. Clean desk rule (address uncommitted changes before new work). iOS List rows cannot be drop targets. Drag-and-drop feedback must use same calculation as action.

**Why:** Clean desk: started work on top of uncommitted changes from a prior session, causing confusion about what was new. Drop targets: five iterations of GeometryReader + PreferenceKey + manual hit-testing to detect drop targets, all unnecessary — `.onDrop(of:delegate:)` worked natively once the List was replaced with ScrollView. Feedback/action mismatch: `dropUpdated` and `performDrop` hit-tested independently, causing the highlighted folder to differ from the actual drop target.

---

## 2026-02-13 — Async state capture rule

**Added:** Never read `@State`/`@Published` inside `Task {}` bodies — capture to a local first.

**Why:** Folder-picker move sheet bug. `moveTarget = nil` ran after `Task {}` was created but before its body executed, so the task body read nil. This class of bug is silent — no crash, just wrong behaviour.

---

## 2026-02-08 — Workflow guidelines from usage analysis

**Added:** Verify before claiming. Use local resources first. Log ideas and problems to Serena memory. swift-log behaviour notes (stderr, bootstrap ordering, log levels).

**Why:** An analysis of prior sessions found patterns: capabilities were documented without verification, internet fetches were used for data already in the repo, and ideas surfaced during work were lost because they weren't recorded anywhere.

---

## 2026-02-01 — Ideas/problems memory log

**Added:** Rule to use `edit_memory` for ideas and problems, not Vestige.

**Why:** Ideas and problems were being scattered across conversation context and lost between sessions. Centralising in a Serena memory makes them persistent and reviewable.

---

## 2025-10-03 — GRDB approved dependency

**Added:** GRDB.swift as approved dependency for SQLite. Dependency management rules (maturity, maintenance, necessity checks).

**Why:** Search index implementation needed a SQLite wrapper. GRDB chosen over raw SQLite3 C API for type safety and migration support. Dependency rules added to prevent accumulation of unnecessary packages.

---

## 2025-09-02 — Address extraction architecture

**Added:** Three-tier data resolution (override > extraction > enrichment). Server architecture (Devon IP, LaunchDaemon/Agent paths). `.addresses/` file ownership model.

**Why:** Initial address extraction system design. Documented to prevent future confusion about which component owns which data.

---

## 2025-07-29 — Git commit guidelines

**Added:** Commit message rules (concise, describe "why", no emoji).

**Why:** Early commits had inconsistent style and lacked context about motivation.

---

## 2025-07-15 — Initial CLAUDE.md

**Created:** Project overview, document format (.yianazip), iCloud container identifier, basic architecture.

**Why:** Project inception. Established baseline context for all future sessions.
