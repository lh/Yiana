# Session Handoff — 2026-03-22

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 4 Complete — App is fully self-sufficient

| Step | Summary |
|------|---------|
| M3.1 | Switched YianaRenderer to `.binaryTarget` XCFramework (no unsafeFlags) |
| M3.2 | Added YianaRenderer as local package in Xcode project |
| M3.3 | Created `LetterRenderService` — bridges types, writes PDFs |
| M3.4 | Updated `ComposeViewModel.sendToPrint()` for local Typst rendering |
| M3.5 | Fixed Typst template: method chain literal text, removed valediction |
| M3.6 | Per-recipient PDF links in ComposeTab |
| M4.1 | Stopped Devon render service |
| M4.2 | Stopped Devon OCR service, dashboard, watchdog cron |
| Fix | iPad Air watchdog kill — removed sync migration from AddressRepository.init() |
| Fix | XCFramework universal macOS binary (arm64 + x86_64) for archive |
| New | "New Letter" button in ComposeTab |
| New | Version bumped to 2.0 |
| New | Polish roadmap (`docs/v2-polish-roadmap.md` + Typst editions) |

### TestFlight
- Build 47: v1.1 — first local rendering build. Crashed on iPad Air + MacBook Air (watchdog)
- Build 48: v1.1 — fixed watchdog. All devices working.
- Build 49 pending: v2.0 with New Letter button (not yet uploaded)

## Current State

- **Branch:** `consolidation/v1.1`
- **Version:** 2.0 (build 48 on TestFlight, local is ahead)
- **Builds:** iOS and macOS both pass
- **Package tests:** 94 pass (YianaExtraction), 5 pass (YianaRenderer), 3 pass (Rust)
- **Phase 4:** COMPLETE — all Devon services retired
- **Devon:** iCloud sync node only. No active services. Plists preserved until 2026-04-04

## What's Next

See `docs/v2-polish-roadmap.md` for full prioritised backlog.

**Session A (next):** Letter template polish — envelope window alignment + footer contact block. Bring envelope measurements. Pure Typst, no app code.

**Session B:** Auto-reload after inject (#17) + GP card save bug (#21c).

## Key Files

| File | Purpose |
|------|---------|
| `Yiana/Yiana/Services/LetterRenderService.swift` | Bridges types, renders locally |
| `Yiana/Yiana/ViewModels/ComposeViewModel.swift` | Compose logic with local render |
| `Yiana/Yiana/Views/Compose/ComposeTab.swift` | Compose UI (macOS) |
| `YianaRenderer/Sources/YianaRenderer/Resources/letter.typ` | Typst letter template |
| `docs/v2-polish-roadmap.md` | Prioritised backlog |
