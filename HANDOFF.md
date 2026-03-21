# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 4 Milestone 3: Wire YianaRenderer into Yiana — COMPLETE AND TESTED

| Step | Summary |
|------|---------|
| 3.1 | Switched YianaRenderer Package.swift from `unsafeFlags` source target to `.binaryTarget` XCFramework |
| 3.2 | Added `module.modulemap` to XCFramework Headers and build script `include/` |
| 3.3 | Removed old `CYianaTypstBridge` source target (shim.c + headers) |
| 3.4 | Added YianaRenderer as local package dependency in Xcode project (both targets) |
| 3.5 | Created `LetterRenderService` — maps Yiana types to YianaRenderer types, writes PDFs |
| 3.6 | Updated `ComposeViewModel.sendToPrint()` — renders locally instead of requesting Devon |
| 3.7 | Added public initializers to YianaRenderer types (memberwise inits are internal) |
| 3.8 | Exposed `injectDirectory` and `renderedDirectory()` on LetterRepository |
| 3.9 | Updated ComposeTab status badge: "Sending..." -> "Rendering..." |
| 3.10 | Fixed Typst template: method chain rendered as literal text (single-line fix) |
| 3.11 | Removed valediction, added spacing before signer name |
| 3.12 | Show per-recipient PDF links (Patient copy, To: GP name, Hospital records) |

### Testing
- Manual test: compose -> send to print -> PDFs render instantly -> all 3 copies viewable
- Confirmed working end-to-end on macOS

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both pass
- **Package tests:** 94 pass (YianaExtraction), 5 pass (YianaRenderer)
- **Rust tests:** 3 pass (yiana-typst-bridge)
- **Phase 3:** COMPLETE
- **Phase 4:** Milestones 1-3 done and tested. Milestone 4 (retire Devon render) next
- **Devon:** OCR (Swift) and render (Python/LaTeX) services still running; render ready to retire

## What's Next

### Phase 4 Milestone 4: Retire Devon Render Service
1. `ssh devon-6 launchctl unload ~/Library/LaunchAgents/com.vitygas.yiana-render.plist`
2. Verify compose still works end-to-end (it doesn't touch Devon now)
3. Update docs (consolidation-plan.md, LETTER-MODULE-SPEC.md)

### Address card bugs (logged in ideas_and_problems #21)
- Town/city not inferred from postcode (feature not yet built — see idea #13)
- Cannot add a new GP card
- Changing card type to GP then saving reverts to prior patient data

### Other known issues
- Python extraction plist still on Devon — remove after 2026-04-04
- iOS has no compose access yet (info panel is macOS-only)
- Document doesn't auto-reload after InjectWatcher appends PDF
- Letter formatting polish needed (future session)
- Linker warning: library built for newer macOS (26.2) than linked (15.5) — cosmetic

## Key Files

| File | Purpose |
|------|---------|
| `Yiana/Yiana/Services/LetterRenderService.swift` | Bridges Yiana types to YianaRenderer, writes PDFs |
| `Yiana/Yiana/ViewModels/ComposeViewModel.swift` | Compose logic — now renders locally |
| `Yiana/Yiana/Views/Compose/ComposeTab.swift` | Compose tab view (macOS) |
| `YianaRenderer/Sources/YianaRenderer/LetterRenderer.swift` | Public API — render letter to PDFs |
| `YianaRenderer/Sources/YianaRenderer/Resources/letter.typ` | Typst letter template |
| `YianaRenderer/Package.swift` | Uses .binaryTarget for XCFramework |
