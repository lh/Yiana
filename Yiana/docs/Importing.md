# Importing PDFs

This guide describes how PDFs enter Yiana and how they are handled.

## Ways to Import
- Share Sheet (iOS/iPadOS): Use “Copy to Yiana” or “Open in Yiana”.
- Open from Files (iOS/macOS): Tap/click a PDF and choose Yiana.
- Drag & Drop (planned): Drop a PDF onto the list or viewer.

## Options on Import
- New Document: Creates a `.yianazip` with your PDF and metadata.
- Append to Existing: Merges all pages from the PDF into a chosen document.
- Replace/Inserting (planned): Replace pages or insert at a specific index.

## How It Works (iOS)
- URL Handling: The app receives a file URL from the system (cold or warm launch).
- ImportService:
  - Validates the PDF via `PDFDocument`.
  - Creates a new package or merges into an existing one.
  - Updates metadata (`pageCount`, `modified`, and sets `ocrCompleted = false`).
  - Writes atomically to signal iCloud sync and backend OCR.
- Refresh: The document list refreshes after import so new items appear immediately.

## OCR Integration
- Any imported/modified document is marked `ocrCompleted = false`.
- The OCR service watches the documents directory, processes new/changed files, and:
  - Embeds a text layer when possible.
  - Saves structured results under `.ocr_results/<relative_path>/<name>.json|.xml|.hocr`.
  - Updates metadata (confidence, processedAt) and flips `ocrCompleted = true`.

## Edge Cases & Tips
- Large PDFs: Import works off the main thread; show a spinner; expect iCloud sync delay.
- Permissions: “Copy to Yiana” uses security‑scoped URLs; the app copies to a safe temp location before writing.
- Conflicts: The repository generates unique names when collisions occur (e.g., `Title 1.yianazip`).
- Raw PDFs: If a file is a true PDF with embedded text, OCR may be skipped.

## Troubleshooting
- Import UI doesn’t appear: Ensure Yiana is enabled in the Share Sheet (“More” → enable).
- Nothing appears in the list: Pull to refresh or relaunch; verify iCloud is available.
- OCR didn’t run: Confirm the Mac mini watcher path matches your iCloud Documents; check `.ocr_results`.

