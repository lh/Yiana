# Yiana OCR Service (`yiana-ocr`)

A Swift command-line service that watches the Yiana documents folder, OCRs PDFs, embeds text layers, and writes structured results.

## Build & Run
- Requirements: Swift 5.9+, macOS 13+
- Build: `cd YianaOCRService && swift build -c release`
- Help: `swift run yiana-ocr --help`

Common commands:
- Watch iCloud Docs: `swift run yiana-ocr watch`
- Watch custom path: `swift run yiana-ocr watch --path /path/to/Documents`
- Process one file: `swift run yiana-ocr process /path/to/file.yianazip --format json`
- Batch a folder: `swift run yiana-ocr batch ./Documents --output ./ocr_results --format json`

## How It Works
- Watches `iCloud.com.vitygas.Yiana/Documents` if available; falls back to `~/Documents/YianaDocuments`.
- Processes `.yianazip` files:
  - Parses metadata and PDF payload
  - Skips OCR if PDF already contains text
  - Otherwise, runs OCR (`accurate`, `languages: ["en-US"]`, language correction on)
  - Embeds a text layer in the PDF when possible and flips `ocrCompleted = true`
  - Writes human/interop outputs to `.ocr_results/<relative_path>/<base>.{json,xml,hocr}`
- Tracks processed files in `~/Library/Application Support/YianaOCR/processed.json` to avoid duplicates

## Paths
- Documents root: iCloud → `~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents`
- Local fallback: `~/Documents/YianaDocuments`
- OCR outputs: `<Documents>/.ocr_results/<relative_path>/`
- Processed set: `~/Library/Application Support/YianaOCR/processed.json`

## Configuration
- `--path`: override the documents root (useful on servers or testing sandboxes)
- Logging: `--log-level trace|debug|info|notice|warning|error|critical`
- Export format in `process`/`batch`: `--format json|xml|hocr`
- Extraction flags (single-file): `--extract-forms`, `--extract-demographics`

## Run as a Service (launchd)
1) Create a plist at `~/Library/LaunchAgents/com.vitygas.yiana.ocr.plist`:
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.vitygas.yiana.ocr</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/swift</string>
    <string>run</string>
    <string>yiana-ocr</string>
    <string>watch</string>
    <!-- optional: <string>--path</string><string>/absolute/path</string> -->
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>~/Library/Logs/yiana-ocr.log</string>
  <key>StandardErrorPath</key><string>~/Library/Logs/yiana-ocr.err</string>
  <key>KeepAlive</key><true/>
</dict>
</plist>
```
2) Load: `launchctl load ~/Library/LaunchAgents/com.vitygas.yiana.ocr.plist`
3) Check: `launchctl list | grep yiana`

For production, point `ProgramArguments` to a built binary (`.build/release/yiana-ocr`).

## Health Monitoring
- Heartbeat and errors are written under `~/Library/Application Support/YianaOCR/health/`:
  - `heartbeat.json`: updated on start and each scan (contains ISO8601 timestamp)
  - `last_error.json`: overwritten when a scan/process error occurs
- Watchdog script: `./scripts/ocr_watchdog.sh [--max-age-seconds 180]`
  - Alerts (macOS notification + stderr) if heartbeat is stale or an error is present
  - Example launchd plist snippet to run every 2 minutes:
```
<key>StartInterval</key><integer>120</integer>
<key>ProgramArguments</key>
<array>
  <string>/bin/bash</string>
  <string>-lc</string>
  <string>$HOME/Code/Yiana/YianaOCRService/scripts/ocr_watchdog.sh --max-age-seconds 300</string>
  </array>
```

## Troubleshooting
- No documents found: confirm iCloud container exists, or use `--path` to a local mirror.
- Reprocessing doesn’t happen: delete processed set at `~/Library/Application Support/YianaOCR/processed.json` (it will rebuild).
- Permissions: ensure the user has read/write to the documents path and `.ocr_results` folder.
- Unexpected PDF: some PDFs already contain text; service will mark OCR complete without changes.

## Notes
- OCR options can be tuned in code (`DocumentWatcher` and `Process` subcommand).
- Service intentionally rescans every few seconds to catch missed FS events.
