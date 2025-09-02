# Repository Guidelines

## Project Structure & Modules
- `Yiana/`: SwiftUI app for iOS/iPadOS/macOS. Sources in `Yiana/` (Views, ViewModels, Services, Extensions), assets in `Yiana/Assets.xcassets`.
- `Yiana/YianaTests` and `Yiana/YianaUITests`: XCTest unit/UI tests.
- `YianaOCRService/`: Swift Package executable (`yiana-ocr`) for OCR/server-side tasks.
- `AddressExtractor/`: Python utilities for letter generation and data processing.
- `Yiana/docs/`: Architecture and planning docs; see `PLAN.md` and `docs/*.md`.

## Build, Test, and Dev Commands
- App (Xcode): `open Yiana/Yiana.xcodeproj` then build/run (Cmd+R).
- App tests (CLI):
  - `xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'`
  - Run one test: `xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentMetadataTests`
- Simulator tip: list available devices with `xcrun simctl list devices` and substitute an installed simulator (e.g., `iPhone 15`).
- CI examples:
  - iOS build (no simulator): `xcodebuild -scheme Yiana -destination 'generic/platform=iOS' -configuration Release build`
  - Tests (headless runner): ensure a simulator is available, then `xcodebuild -scheme Yiana -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' -only-testing:YianaTests test`
  - macOS build: `xcodebuild -scheme Yiana -destination 'platform=macOS' -configuration Release build`
- OCR service: `cd YianaOCRService && swift build -c release` then `swift run yiana-ocr --help`.
- Python tools: `cd AddressExtractor && python test_system.py` (integration test). Install deps: `python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`.

## Coding Style & Naming
- Swift: Follow `CODING_STYLE.md` (simplicity, 1-based page indexing, PDFKit wrapper extensions). Use Swift defaults (4‑space indent, UpperCamelCase types, lowerCamelCase members). Prefer platform-specific views over heavy abstractions.
- Python: 4‑space indent, snake_case for functions/vars, descriptive module names (e.g., `clinic_notes_parser.py`). Keep scripts small and single‑purpose.
- Formatting/Lint: No enforced linters; keep diffs clean and readable.

## Testing Guidelines
- Swift (XCTest): Place unit tests in `Yiana/YianaTests` and UI tests in `Yiana/YianaUITests` with `*Tests.swift` suffix. Test 1‑based page boundaries and extension wrappers.
- Swift Package: Add tests under `YianaOCRService/Tests/` if expanding.
- Python: Primary check is `AddressExtractor/test_system.py`; additional focused tests welcome (name `test_*.py`). No coverage threshold enforced yet.

## Commit & Pull Requests
- Commits: Small, focused, and verifiable. No emojis. Follow project plan (`PLAN.md`) and update docs when behavior changes.
- Messages: Imperative, present tense (e.g., "Add DocumentRepository pagination"). Reference files/components (e.g., `Yiana/Services/...`).
- PRs: Include clear description, linked issue/plan item, steps to test, and screenshots for UI changes. Note any DB/schema impacts (SQLite files in repo root or `AddressExtractor/`).

## Security & Configuration Tips
- Do not commit personal signing profiles or secrets. Local SQLite databases (`*.db`) are development artifacts—clean before committing if generated.
- Keep OCR on server-side; app remains read-only for PDFs.
