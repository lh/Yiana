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

### Render service deployed to Devon

- Installed MacTeX (`mactex-no-gui`) for lualatex — binary at `/usr/local/texlive/2026/bin/universal-darwin/lualatex`, symlinked via `/Library/TeX/texbin`
- LaunchAgent loaded: `com.vitygas.yiana-render` (PID stable, polling every 30s)
- Config: `.letters/config/sender.json`, `.letters/drafts/`, `.letters/inject/` directories created
- Logs: `/Users/devon/Library/Logs/yiana-render.log` and `yiana-render-error.log`

### End-to-end pipeline verified

Full pipeline tested and confirmed working:
1. Test draft placed in `.letters/drafts/test_e2e.json` (patient: Young_David_050429, status: render_requested)
2. Render service on Devon processed it: produced GP letter PDF, hospital records PDF, email HTML
3. Inject PDF (`Young_David_050429_{uuid}.pdf`) placed in `.letters/inject/`
4. iCloud synced to local Mac
5. InjectWatcher picked it up, appended hospital records page to `Young_David_050429.yianazip`
6. Confirmed: new page visible in app

### Previous session work (carried forward)
- Yiale render service — Phases 1+2 (letter schema + render pipeline, `2d712f8`)
- OCR stub generation, extraction service EPERM fix, Typst dashboard, Tailscale, letter module spec

## What's in progress
- Nothing actively in progress

## What's next
- **Yiale Mac app** — SwiftUI: patient search (reads `.addresses/`), compose, address confirmation step, drafts list with dismiss, preview, share sheet
- **Yiale iOS/iPadOS** — adapt SwiftUI views for smaller screens
- **Cleanup** — archive superseded components (`letter_generator.py`, `letter_cli.py`, `letter_system_db.py`, `clinic_notes_parser.py`)

## Known issues
- iCloud `[ERROR] [Progress]` noise when InjectWatcher renames/deletes `.processing` file — harmless, iCloud complains about file disappearing mid-upload
- Transient "database is locked" on reindex after inject append — resolves on next UbiquityMonitor cycle
- Stale Mercy-Duffy error in OCR health (21+ days old) — not actionable, just noise
- `ocr_today` count in dashboard shows 0 despite processing happening — may be a timezone issue with `processedAt` timestamps in `processed.json`
- Old `ocr_watchdog_pushover.sh` still exists in `YianaOCRService/scripts/` — can be removed after confirming unified watchdog is stable
- `letter_generator.py:_escape_latex()` has the brace-corruption bug for backslash/tilde/caret — low priority since it's being superseded

## Devon services status
| Service | Type | Status |
|---|---|---|
| `com.vitygas.yiana-ocr` | LaunchDaemon | Running |
| `com.vitygas.yiana-extraction` | LaunchAgent | Running |
| `com.vitygas.yiana-dashboard` | LaunchAgent | Running |
| `com.vitygas.yiana-render` | LaunchAgent | Running |
