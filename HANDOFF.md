# Session Handoff — 2026-03-03

## What was completed

### OCR stub generation for embedded-text documents
- Documents with `ocrCompleted: true` set on-device but no `.json`/`.xml`/`.hocr` result files were causing the health check to report ~101 "pending OCR"
- Extracted `writeOCRResultFiles` from `saveOCRResults` in `DocumentWatcher.swift`
- Extracted `generateMissingResultFiles` helper, called from all three early-return paths in `checkAndProcessDocument` (already-tracked same mod date, already-tracked changed mod date, ocrCompleted block)
- Deployed to Devon. Documents: 2975, OCR results: 3007 — all processed, pending: 0

### Extraction service EPERM fix
- Root cause: macOS TCC `kTCCServiceFileProviderDomain` — the CLT Python 3.9 used by the LaunchAgent didn't have iCloud file provider access
- Fix: switched extraction service to Python 3.12 (`/Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12`) which already had the TCC grant
- Installed `watchdog` for Python 3.12, updated LaunchAgent plist
- 18 new successful extractions immediately after restart

### Typst server dashboard
- Created `scripts/dashboard.typ` (dark-themed Typst template), `scripts/dashboard-collector.py` (local data collection), `scripts/dashboard-data.sh` (SSH wrapper for local use), `scripts/dashboard-serve.sh` (launcher for Devon)
- Fixed: extraction PID detection (pgrep -f extraction_service.py), bar chart divide-by-zero guard, Typst comment syntax collision in footer
- Deployed to Devon as LaunchAgent (`com.vitygas.yiana-dashboard.plist`) — typst-live on port 5599, data refreshes every 60s
- Accessible at `http://devon-6:5599` via Tailscale from any device

### Tailscale setup on Devon
- Installed via Homebrew, authenticated with `tailscale up`
- Devon is `devon-6` on the tailnet, accessible from all devices

### Yiale letter module spec (docs/LETTER-MODULE-SPEC.md)
- Complete spec (v4) for standalone letter composition app
- Three parts: Yiale (SwiftUI app), Render Service (Python + LaTeX on Devon), Inject Watcher (small addition to Yiana using existing ImportService.append)
- Shared iCloud container with Yiana via matching entitlements
- Draft JSON → render_requested → rendered → user dismisses → deleted
- 24 resolved questions covering architecture, workflow, and edge cases
- Build order: render service → Yiale Mac → Yiale iOS → inject watcher → cleanup

### CLAUDE.md rewrite
- Project CLAUDE.md: removed stale rules (Rust, PLAN.md, memory-bank, TDD), consolidated duplicates, added server architecture, address extraction, custom skills, recent learnings
- Global ~/.claude/CLAUDE.md: populated with universal development standards (role, communication, code style, security, architecture, observability, testing)
- Trimmed project file to avoid duplicating global rules

## What's in progress
- Nothing actively in progress

## What's next
- **Yiale implementation** — follow build order in LETTER-MODULE-SPEC.md:
  1. Sender config + draft JSON schema (hand-write sample files, validate against real letters)
  2. Render service (Python watcher + LaTeX rendering on Devon)
  3. Yiale Mac app (SwiftUI: patient search, compose, address confirmation, drafts list)
  4. Yiale iOS/iPadOS
  5. Yiana inject watcher (~50-80 lines, calls ImportService.append)
- Consider moving inject watcher earlier in build order (between steps 2 and 3) for faster end-to-end testing

## Known issues
- Stale Mercy-Duffy error in OCR health (21+ days old) — not actionable, just noise
- `ocr_today` count in dashboard shows 0 despite processing happening — may be a timezone issue with `processedAt` timestamps in `processed.json`
- Old `ocr_watchdog_pushover.sh` still exists in `YianaOCRService/scripts/` — can be removed after confirming unified watchdog is stable
