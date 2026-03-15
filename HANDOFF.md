# Session Handoff — 2026-03-15 (evening)

## Branch
`feature/worklist-integration` — 2 commits ahead of main.

## Completed

### MRN in address data (commit 570a447, merged to main)
- `mrn: String?` added to `PatientInfo` in both Yiana and Yiale
- `ExtractedAddress` struct and both init paths carry MRN through
- `AddressRepository.saveOverride()` passes MRN to PatientInfo
- AddressCard UI: MRN field in edit form (first field before Title) and read-only display
- Yiale `ResolvedPatient` reads `patient?.mrn` instead of parsing DOB from filename

### Unified work list (commit 570a447, merged to main)
- `SharedWorkList`/`SharedWorkListItem` model in both apps, shared via `.worklist.json`
- `id: String` (MRN for clinic list items, UUID string for manual/document)
- Yiana watches `.worklist.json` via NSMetadataQuery (replaces deleted YialeSyncService)
- One-time migration from `.yiana-worklist.json` on first Yiana load
- Yiale updated: WorkList/WorkListItem are typealiases to shared types

### MRN extraction from OCR (commit 7b4f03d, on feature branch)
- `spire_form_extractor.py`: extracts MRN from `Patient_ XXXXXXXX` pattern (6-10 digits)
- `extraction_service.py`: passes `mrn` through to patient dict in `.addresses/*.json`
- Added `--reprocess-all` flag; ran on Devon — 548 documents now have MRNs

### OCR service crash-loop fix (commit 128a8d3, on feature branch, deployed to Devon)
- **Root cause**: `DocumentMetadata.init(from:)` in OCR service tried `1...0` range when `pageCount == 0` and no `pageProcessingStates` existed — fatal SIGTRAP
- App had `count > 0` guard but OCR service copy didn't
- The crash-loop was preventing ALL OCR processing since whenever the 0-page document appeared
- Fix applied, binary built and deployed to Devon — service now stable

## Needs Verification

### OCR reprocess button
- Triggered "Reprocess OCR" on `Zivilik_Mark_020661` — Devon picked it up at 22:58 and produced results
- Yiana showed "not processed" — likely iCloud sync delay
- **Check in morning**: does the document show OCR results after sync?

## Next Steps

1. **Re-extract button in info sidebar** — trigger address re-extraction without redoing OCR
2. **Page-specific OCR reprocess** — currently reprocesses entire document
3. **Merge feature branch to main** — once verified
4. **OCR service model drift** — `YianaDocument.swift` in OCR service is missing `hasPendingTextPage`, `pdfHash` fields and uses `String?` for `ocrSource` instead of `OCRSource` enum. Not crashing but should be synced.

## Known Issues
- OCR service reprocesses test files every scan cycle (Latex rusTeX, "2 is a very short name", McTestface) — noisy but harmless
- Extraction service `on_modified` handler skips files already in `processed_files` set — need separate trigger mechanism for re-extract
