# Troubleshooting

Quick fixes for common issues across the app and OCR service.

## Build & Signing
- No signing certificate / device build fails:
  - Sign in to Xcode (Settings → Accounts), select a valid Team.
  - For CI or simulator, build with: `xcodebuild -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Simulator build noise (eligibility.plist): harmless; ignore.

## Importing PDFs (iOS)
- Share/Open shows nothing:
  - Ensure Yiana is enabled in Share Sheet (tap “More”, toggle on).
  - Verify Info.plist declares both `com.adobe.pdf` and `public.pdf`.
  - Cold start: AppDelegate handles `application(_:open:)`; try again after a fresh launch.
- Imported doc not visible:
  - Pull to refresh or relaunch; iCloud sync can lag.
  - Check app logs for `DEBUG: Received URL:` and `Import` actions.

## iCloud & Storage
- No documents listed / 0 found:
  - Ensure iCloud Drive is enabled and “Yiana” container is on.
  - Fallback path: app uses local Documents if iCloud is unavailable.

## OCR Service
- Service finds 0 documents:
  - Confirm watch path. Try: `swift run yiana-ocr watch --path /absolute/path`.
  - Verify `.yianazip` files exist under `Documents/`.
- OCR didn’t run:
  - Imported docs set `ocrCompleted = false`. Ensure the file timestamp changed (atomic save signals sync).
  - Check outputs in `<Documents>/.ocr_results/`.
- Reprocessing needed:
  - Remove `~/Library/Application Support/YianaOCR/processed.json` (service will rebuild processed set).

## Debug Tips
- App: add prints for URL handling and list refresh; ensure `yianaDocumentsChanged` is observed.
- OCR: run `swift run yiana-ocr process <file>` to validate OCR on a single doc.

