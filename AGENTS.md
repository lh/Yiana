# Repository Guidelines

## Project Structure & Module Organization
- `Yiana/` hosts the SwiftUI app: `Views/`, `ViewModels/`, `Services/`, and `Extensions/` hold feature code, while `Assets.xcassets/` stores shared media and colors.
- Architecture notes and long-form plans live in `Yiana/docs/`; start with `PLAN.md` before major refactors.
- Unit tests sit in `Yiana/YianaTests`, UI automation in `Yiana/YianaUITests`, and Swift Package OCR utilities live under `YianaOCRService/` (`yiana-ocr` executable).
- Python-based address helpers are in `AddressExtractor/`; treat it as a supporting toolchain rather than app runtime code.

## Build, Test, and Development Commands
- `open Yiana/Yiana.xcodeproj` — launch the workspace in Xcode for iterative builds and previews.
- `xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'` — run the full XCTest suite locally.
- `xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentMetadataTests` — focus on metadata regressions while iterating.
- `xcodebuild -scheme Yiana -destination 'generic/platform=iOS' -configuration Release build` — produce CI-quality archives.
- `cd YianaOCRService && swift run yiana-ocr --help` — verify the OCR CLI remains callable.
- `cd AddressExtractor && python test_system.py` — exercise the Python integration path after activating the virtualenv.

## Coding Style & Naming Conventions
- Swift follows `CODING_STYLE.md`: four-space indentation, UpperCamelCase for types, lowerCamelCase members, and 1-based PDF page indices.
- SwiftUI views stay platform-specific; extract logic into ViewModels rather than cross-platform wrappers.
- Python scripts use four-space indentation, snake_case, and standard library formatting tools (black is optional, but keep output ASCII).

## Testing Guidelines
- Prefer XCTest for Swift targets; place new cases in `Yiana/YianaTests` or UI flows in `Yiana/YianaUITests` with a `*Tests.swift` suffix.
- For OCR package changes, add coverage under `YianaOCRService/Tests`; use `swift test` before publishing.
- Python parsers rely on `AddressExtractor/test_system.py`; introduce targeted `test_*.py` files for new rules.
- Keep edge cases for PDF page bounds and extension wrappers under test before merging.

## Commit & Pull Request Guidelines
- Write concise, imperative commit messages (e.g., `Add DocumentRepository pagination`); avoid bundling unrelated changes.
- PRs should summarize intent, link the relevant plan or issue, list validation steps, and include screenshots for UI-visible changes.
- Call out schema or SQLite impacts explicitly, and remove generated artifacts or personal provisioning profiles prior to review.

## Security & Configuration Tips
- Treat OCR workloads as server-side; keep the client read-only for PDF content.
- Exclude credentials and generated SQLite files from source control, and confirm simulator destinations with `xcrun simctl list devices` when configs shift.
