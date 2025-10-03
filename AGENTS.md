# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI app lives in `Yiana/`, with feature code organized under `Views`, `ViewModels`, `Services`, and `Extensions`. App assets reside in `Yiana/Assets.xcassets`, and architecture notes are in `Yiana/docs/` (see `PLAN.md`). XCTest targets sit under `Yiana/YianaTests` (unit) and `Yiana/YianaUITests` (UI). Server-side OCR utilities are bundled in the `YianaOCRService/` Swift Package (`yiana-ocr` executable). Supportive Python tooling for address processing is in `AddressExtractor/`.

## Build, Test, and Development Commands
- `open Yiana/Yiana.xcodeproj` — launch the iOS/macOS workspace in Xcode for interactive builds.
- `xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'` — run the full XCTest suite locally.
- `xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentMetadataTests` — target a focused test when iterating.
- `xcodebuild -scheme Yiana -destination 'generic/platform=iOS' -configuration Release build` — produce a CI-style iOS archive build.
- `cd YianaOCRService && swift run yiana-ocr --help` — validate the OCR executable.
- `cd AddressExtractor && python test_system.py` — exercise the Python integration test after activating its virtualenv.

## Coding Style & Naming Conventions
Follow `CODING_STYLE.md` for Swift: four-space indentation, UpperCamelCase types, lowerCamelCase members, and 1-based page indexing in PDF helpers. Keep SwiftUI views platform-specific instead of abstracting. Python utilities also use four-space indentation with snake_case names. Default to ASCII unless a file already uses extended characters.

## Testing Guidelines
Prefer XCTest for Swift targets; place new unit tests in `Yiana/YianaTests` and UI flows in `Yiana/YianaUITests` with a `*Tests.swift` suffix. Ensure PDF page bounds and extension wrappers stay covered. For the OCR package, add cases under `YianaOCRService/Tests` if functionality expands. Python scripts rely on `AddressExtractor/test_system.py`; add focused `test_*.py` files for new parsing rules.

## Commit & Pull Request Guidelines
Write concise, imperative commits that describe the change (e.g., `Add DocumentRepository pagination`). Each PR should include a clear summary, linked plan item or issue, test steps, and screenshots for UI work. Call out any schema or SQLite file impacts and keep personal provisioning profiles or secrets out of the repo.

## Security & Configuration Tips
Treat OCR workloads as server-side only, keeping the app read-only for PDFs. Remove generated SQLite artifacts before committing and avoid storing credentials in source. When simulator availability changes, run `xcrun simctl list devices` to confirm a valid destination.
