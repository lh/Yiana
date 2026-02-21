# Ideas & Problems

Quick-capture list for things that come to mind mid-task.

## Ideas

- Allow folders in the select/bulk-delete workflow (currently only documents). Needs summary UX showing total items affected including folder contents.
1. Sort by last accessed as well as last modified
2. Info panel open/close: the info (i) button shifts position when the panel opens, breaking muscle memory for closing it. Either maintain the button position or add a close icon in the panel at the same location as the original (i) button.
3. Mac version: add keyboard shortcuts and a way to teach them (e.g. hover tooltips showing the shortcut).
4. Migrate ObservableObject to @Observable (deployment targets already well above iOS 17/macOS 14 floor; 12 classes to convert).
5. **Filename-based patient resolution** — Patient-level documents are named `Surname_Firstname_ddmmyy` (with hyphenated variants like `Surname-Other_First-Second_ddmmyy`). Billing/batch documents start with digits (e.g. `yyyymmdd` with place prefix/suffix). Parsing the filename gives a reliable canonical patient name + DOB that's far more trustworthy than OCR-extracted names. Use this to: (a) identify the "document patient" for single-patient docs, (b) improve dedup key quality, (c) filter out junk patient records that are actually OCR noise from form fields/addresses/dates. Deferred to Phase 2+.

## Problems
1. After Force OCR Re-run or Reset Search Index, the BackgroundIndexer scan phase still opens all ~2900 iCloud files at once (resetDatabase() clears the index, so isDocumentIndexedByURL returns false for everything). Can still exhaust macOS sandbox extensions (~1000 limit). Fix by batching the scan phase in performIndexing() — process N files at a time with sleeps between batches.
3. Address display missing from iOS info panel. The Addresses tab is gated on `AddressRepository.isDatabaseAvailable`, which checks `FileManager.fileExists(atPath:)` for `addresses.db` in the iCloud container. On iOS, this file may be an iCloud placeholder (not downloaded), so `fileExists` returns false and the tab is hidden. Fix: trigger download of `addresses.db` on app launch, or use `startDownloadingUbiquitousItem` and show a loading state.

## Resolved (2026-02-14)
6. Drag-to-folder targeting wrong folder — macOS List/NSTableView has internal scroll view offsets invisible to SwiftUI coordinate spaces. Fixed by replacing manual coordinate math with per-folder `.onDrop(of:delegate:)`.

## Resolved (2026-02-08)
1. 14GB yiana-ocr-error.log -- swift-log defaults to stderr, --logLevel was unused. Fixed by bootstrapping LoggingSystem with notice level. newsyslog rotation added.
2. Mercy-Duffy.yianazip -- old format file (raw JSON, not ZIP). Deleted from phone, propagated instantly via iCloud.
3. yiana-ocr.log 314MB stale -- nothing writes to stdout. Rotated via newsyslog.
