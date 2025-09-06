# Project Status — September 2025

This note captures what was built, why we chose this design, and how the pieces work together. It’s a snapshot for “future us” to quickly regain context.

## What We Built
- iOS/iPadOS import flow
  - Accept PDFs via Share → “Copy to Yiana” and “Open in Yiana”.
  - Import sheet lets you create a new document or append to an existing one.
  - Reliable URL handling using both `.onOpenURL` and a `UIApplicationDelegate` bridge.
  - `Info.plist`: added `LSSupportsOpeningDocumentsInPlace` and both `com.adobe.pdf` + `public.pdf` UTIs.
- ImportService (modular core)
  - Validates PDFs, creates `.yianazip` packages, or merges pages into existing docs.
  - Updates metadata (`pageCount`, `modified`) and sets `ocrCompleted=false` to trigger backend OCR.
- App refresh hooks
  - After import, the app posts `yianaDocumentsChanged`; list view listens and refreshes.
- OCR pipeline (Mac mini backend)
  - `YianaOCRService` watches the documents folder, OCRs PDFs that lack text, embeds a text layer when possible, updates metadata, and writes rich results to `.ocr_results` (JSON/XML/hOCR).
  - Health monitoring: heartbeat + last error files written under `~/Library/Application Support/YianaOCR/health/`.
  - Watchdog script `scripts/ocr_watchdog.sh` alerts (macOS notification) if heartbeat is stale or errors occur.
- Tests and docs
  - App unit tests: import append path, NoteDocument round‑trip, PDF 1‑based helpers, repo naming, OCR search.
  - SwiftPM tests: OCR exporters and `.yianazip` parsing in the service.
  - New docs: root `README.md`, `docs/Architecture.md`, `docs/Importing.md`, `docs/Troubleshooting.md`, OCR service `README.md`.

## Why These Choices
- Simplicity and reliability first
  - Keep platform‑specific code (SwiftUI + UIDocument on iOS; lightweight macOS read path) to avoid heavy abstractions.
  - 1‑based page indexing everywhere; wrap PDFKit conversions.
  - Offload OCR to the Mac mini so the app stays responsive and battery‑friendly.
- UX pragmatism
  - Support mainstream share paths without a custom share extension (optional later).
  - Atomic writes for `.yianazip` to ensure iCloud notices changes.
- Maintainability
  - ImportService encapsulates PDF creation/merge rules.
  - Tests cover the highest‑risk flows to catch regressions.

## How It Works (End‑to‑End)
- User shares/opens a PDF on iOS → app receives a file URL via `.onOpenURL` and `UIApplicationDelegate`.
- Import sheet appears: choose New or Append.
  - New → `ImportService` builds metadata + PDF into `[JSON][FF FF FF FF][PDF]` and saves as `.yianazip`.
  - Append → `ImportService` merges pages using PDFKit, updates metadata, and overwrites atomically.
- App posts `yianaDocumentsChanged` → list view reloads → new/updated doc appears.
- iCloud sync propagates the change → `YianaOCRService` notices a modified file.
  - If the PDF already has text: mark OCR complete and save.
  - Else: OCR the PDF, embed text when possible, update metadata, and write `.ocr_results/<relative>/<name>.json|.xml|.hocr`.
- Health monitor writes `heartbeat.json` on each scan and `last_error.json` on failures. The watchdog can notify if the service stalls.

## Key Conventions
- 1‑based page numbers everywhere outside PDFKit.
- Read‑only PDF viewing (no heavy annotation layer).
- Platform‑specific implementations are fine; avoid premature cross‑platform abstractions.

## How To Validate
- App tests: `xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'`.
- OCR tests: `cd YianaOCRService && swift test`.
- Watchdog: `./YianaOCRService/scripts/ocr_watchdog.sh --max-age-seconds 300`.

## Known Gaps / Future Enhancements
- Import UX: insert/replace at a specific page (not just append).
- Drag & Drop: drop PDFs onto the list/editor (iOS + macOS).
- macOS write path: mirror iOS format to enable append/edit on macOS.
- OCR status in UI: small indicator for “Waiting for OCR / OCR complete”.
- Optional Share Extension: tighter share UX if needed.
- CI: add a simulator test job and SPM test job.

## Gotchas & Troubleshooting
- iCloud delays are normal; pulls refresh automatically, but allow for sync time.
- Device signing must be valid to run on hardware (simulator doesn’t need signing).
- Ensure both `public.pdf` and `com.adobe.pdf` are declared so “Copy to Yiana” appears across apps.
- Simulator log line `eligibility.plist` is harmless noise.

