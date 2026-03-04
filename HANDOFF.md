# Session Handoff — 2026-03-04

## What was completed

### Inject watcher — Phase 3 (Yiana Swift app)

Implemented `InjectWatcher`, a background service that polls `.letters/inject/` in the iCloud container and appends PDFs placed by the render service to matching patient documents. Committed as `c4b7fd1`.

**New file: `Yiana/Yiana/Services/InjectWatcher.swift`**
- Singleton following `UbiquityMonitor` pattern, started from `.task {}` in `YianaApp.swift`
- Polls `.letters/inject/` every 10 seconds via `Task.detached` (file I/O off main thread)
- Filename parsing: `{yiana_target}_{uuid}.pdf` — regex extracts trailing UUID, remainder is document target
- Atomic rename to `.processing` for multi-device safety
- Matches target against `DocumentRepository.allDocumentsRecursive()` by filename stem
- Appends via `ImportService.importPDF(from:mode:.appendToExisting)`
- Unmatched files moved to `.letters/unmatched/`
- `NSFileCoordinator` for reading PDFs (iCloud may be mid-sync)

**Bugs found and fixed during testing:**
1. `FileManager.url(forUbiquityContainerIdentifier:)` returns `nil` when called from `Task.detached` — fixed by caching the container URL at `start()` time on the main thread
2. `contentsOfDirectory(options: .skipsHiddenFiles)` returns 0 results in iCloud directories — iCloud marks synced files as hidden. Fixed by using `options: []`

**Verified end-to-end on macOS:** dropped test PDF `Young_David_050429_{uuid}.pdf` into inject directory, watcher picked it up within 10s, appended to `Young_David_050429.yianazip`, cleaned up `.processing` file, UbiquityMonitor detected change and re-indexed.

### Previous session work (carried forward)
- Yiale render service — Phases 1+2 (letter schema + render pipeline, `2d712f8`)
- OCR stub generation, extraction service EPERM fix, Typst dashboard, Tailscale, letter module spec

## What's in progress
- Nothing actively in progress

## What's next
- **Deploy render service to Devon** — `git pull`, verify lualatex is installed (`brew install --cask mactex-no-gui` if not), copy plist, `launchctl load`, test with sample draft
- **End-to-end test with render service** — place a letter draft in `.letters/drafts/`, verify render service produces PDF, inject watcher appends it to the patient document
- **Yiale Mac app** — SwiftUI: patient search (reads `.addresses/`), compose, address confirmation step, drafts list with dismiss, preview, share sheet
- **Yiale iOS/iPadOS** — adapt SwiftUI views for smaller screens
- **Cleanup** — archive superseded components (`letter_generator.py`, `letter_cli.py`, `letter_system_db.py`, `clinic_notes_parser.py`)

## Known issues
- Stale Mercy-Duffy error in OCR health (21+ days old) — not actionable, just noise
- `ocr_today` count in dashboard shows 0 despite processing happening — may be a timezone issue with `processedAt` timestamps in `processed.json`
- Old `ocr_watchdog_pushover.sh` still exists in `YianaOCRService/scripts/` — can be removed after confirming unified watchdog is stable
- `letter_generator.py:_escape_latex()` has the brace-corruption bug for backslash/tilde/caret — low priority since it's being superseded, but note if reusing
