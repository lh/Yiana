# Session Handoff — 2026-03-21

## Branch
`consolidation/v1.1` — pushed, up to date with origin.

## What Was Done This Session

### Phase 3: Letter Composition (Yiale Absorption) — COMPLETE

All 9 steps completed:

| Step | Summary |
|------|---------|
| 3.1 | Deleted 4 Yiale duplicates |
| 3.2 | Ported LetterDraft + SenderConfig models |
| 3.3 | Ported LetterRepository + SenderConfigService |
| 3.4 | Added patient/practitioner search to EntityDatabase (12 new tests) |
| 3.5-3.7 | Built simplified compose module — tab in DocumentInfoPanel (~300 LOC) |
| 3.8 | Integration testing — full compose-to-render-to-inject flow verified |
| 3.9 | Retired Yiale — directory removed, LETTER-MODULE-SPEC.md rewritten |

### Phase 4: Typst Rendering — IN PROGRESS (Milestones 1-2 done)

| Milestone | Summary |
|-----------|---------|
| 1 (done) | Rust crate `yiana-typst-bridge` — wraps Typst compiler as C static library. 3 Rust tests pass. Cross-compiled for macOS ARM/Intel + iOS device/simulator (~39MB each). XCFramework built (not committed — rebuild via `build-xcframework.sh`) |
| 2 (done) | Swift package `YianaRenderer` — `LetterRenderer` API, `TypstBridge` FFI wrapper, `letter.typ` template. 5 Swift tests pass. Renders 3 PDFs in 30ms |
| 3 (next) | Wire into Yiana — add package to Xcode project, create `LetterRenderService`, update `ComposeViewModel.sendToPrint()` to render locally |
| 4 (future) | Retire Devon render service |

### Key design decisions made during session
- **Compose is a tab in the info panel**, not a separate view or app
- **Recipients are rules-based** (patient=To, GP=CC, hospital_records=implicit)
- **Body text only** — no greeting/salutation (render service handles topping/tailing)
- **No "boss instance"** — each device is self-sufficient; entity DB is a local derived cache
- **Typst replaces LaTeX** — Apache 2.0, ~39MB static library with embedded fonts, renders in milliseconds
- **Typst compiled as Rust static library** via FFI (not CLI subprocess) — works on iOS too
- **XCFramework not committed** — rebuild from source via `build-xcframework.sh`

### Issues logged (not fixed)
- DOB stored as DD/MM/YYYY should be ISO 8601
- Recipient tick boxes in AddressesView (To/CC/None per card)
- HTML render template: leading comma when sender department is empty
- Document doesn't auto-reload after InjectWatcher appends PDF
- Drafts list sidebar mode
- Letter formatting finessing (render template polish)
- iPhone camera as scanner for Mac app (Continuity Camera)

## Current State

- **Branch:** `consolidation/v1.1`
- **Builds:** iOS and macOS both pass (Yiana app)
- **Package tests:** 94 pass (YianaExtraction), 5 pass (YianaRenderer)
- **Rust tests:** 3 pass (yiana-typst-bridge)
- **Phase 3:** COMPLETE
- **Phase 4:** Milestones 1-2 done, Milestone 3 (Xcode integration) next
- **Yiale:** RETIRED
- **Devon:** OCR (Swift) and render (Python/LaTeX) services still running; render to be retired after Milestone 3

## What's Next

### Phase 4 Milestone 3: Wire YianaRenderer into Yiana

1. Add `../YianaRenderer` as local Swift package dependency in Xcode project
2. Create `LetterRenderService.swift` — calls `LetterRenderer.render()`, writes PDFs to `.letters/rendered/`, copies hospital records to `.letters/inject/`
3. Update `ComposeViewModel.sendToPrint()` — render locally instead of setting `render_requested`
4. Update `ComposeTab` — show "Rendering..." briefly, then "Ready" with PDF actions
5. `/check` — build both platforms
6. Manual test: compose -> render -> inject (no Devon involved)

### Prerequisites for Milestone 3
- XCFramework must exist locally at `YianaRenderer/rust/yiana-typst-bridge/YianaTypstBridge.xcframework`
- If not present, run: `cd YianaRenderer/rust/yiana-typst-bridge && ./build-xcframework.sh`
- Requires Rust toolchain with iOS targets installed

## Key Files

| File | Purpose |
|------|---------|
| `YianaRenderer/Sources/YianaRenderer/LetterRenderer.swift` | Public API — render letter to PDFs |
| `YianaRenderer/Sources/YianaRenderer/TypstBridge.swift` | Swift wrapper around C FFI |
| `YianaRenderer/Sources/YianaRenderer/Resources/letter.typ` | Typst letter template |
| `YianaRenderer/rust/yiana-typst-bridge/src/lib.rs` | Rust FFI — wraps Typst compiler |
| `YianaRenderer/rust/yiana-typst-bridge/build-xcframework.sh` | Builds XCFramework for all Apple targets |
| `Yiana/Yiana/Views/Compose/ComposeTab.swift` | Compose tab view (macOS) |
| `Yiana/Yiana/ViewModels/ComposeViewModel.swift` | Compose logic (to be updated in Milestone 3) |
| `docs/consolidation-plan.md` | Master plan |
| `docs/typst-integration-reference.md` | Typst research and integration options |
| `docs/typst-prototype/letter.typ` | Original prototype template (hardcoded data) |

## Known Issues
- Python extraction plist still on Devon — remove after 2026-04-04
- `feature/worklist-integration` branch from prior session still exists
- Devon hostname: SSH connection issues observed
- 6.8% city python_better — residual gap
- iOS has no compose access yet (info panel is macOS-only)
- Document doesn't auto-reload after InjectWatcher appends PDF
