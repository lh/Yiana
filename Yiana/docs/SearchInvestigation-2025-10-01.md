# 2025-10-01 Search Pipeline Investigation

## Context
The iOS/macOS app ingests scans as `.yianazip` bundles, offloads OCR to a Mac mini, and persists search metadata in a GRDB-backed SQLite FTS5 index. Search behaviour has been unreliable, so this report maps the end-to-end flow and captures concrete gaps across ingestion, OCR, indexing, querying, and testing.

## End-to-End Pipeline
- **Capture & Import** – VisionKit scans and direct PDF imports create `.yianazip` packages with `ocrCompleted = false` and queue an initial index entry with empty text (`Yiana/Yiana/Services/ImportService.swift`).
- **Sync & Storage** – `DocumentRepository` resolves the iCloud container and enumerates documents for downstream components (`Yiana/Yiana/Services/DocumentRepository.swift`).
- **Server OCR** – The Mac mini `DocumentWatcher` rewrites documents once OCR finishes, embeds JSON/XML/hOCR under `.ocr_results/`, and updates metadata flags (`YianaOCRService/Sources/.../DocumentWatcher.swift`).
- **Indexing** – Saves trigger `SearchIndexService.indexDocument`, while `BackgroundIndexer` batches through the library on launch, writing to `~/Library/Caches/SearchIndex/search_index.db` (`Yiana/Yiana/Services/SearchIndexService.swift`, `BackgroundIndexer.swift`).
- **Search Consumption** – `DocumentListViewModel` prefers FTS queries, falls back to brute-force OCR/PDF scanning, and presents results across “In This Folder” / “Other Folders” sections (`Yiana/Yiana/ViewModels/DocumentListViewModel.swift`).

## Metadata & OCR Observations
- OCR-complete documents rely on the new metadata being re-indexed; the background sweep never notices updates because it only checks for missing rows, not modified timestamps.
- When the watcher detects PDFs that already contain text, it flips `ocrCompleted` but does **not** write `fullText` or `.ocr_results`, leaving the index permanently empty for those files.
- On-device reindexing only occurs when a user saves the document or manually resets the database; no automatic hook reacts to `ocrCompleted` changes.

## Indexer Reliability Gaps
- `BackgroundIndexer` reindexes only missing IDs and stays on the main actor, so large libraries or corruption recovery can freeze the UI.
- There is no mechanism to queue “OCR finished but not indexed” documents; the UI badge highlights the state but cannot remediate it.
- Zero unit/integration tests cover FTS migrations, corruption recovery, or `BackgroundIndexer` cancellation/ restart behaviour.

## Query & UI Findings
- `sanitizeFTSQuery` appends `*` but ignores reserved characters, so inputs like `tax:` or whitespace trigger SQL errors instead of gracefully falling back.
- After running a query, sorting logic pulls from the unfiltered folder list, causing indexed matches to disappear from the visible list.
- `searchResults` accumulates stale entries across queries and drives both sections, so snippets and matches can mismatch after refinement.
- Search requests lack debouncing/cancellation; parallel tasks can interleave and clobber shared state on the main actor.

## Testing & QA Backlog
1. **GRDB Coverage** – Add in-memory tests for `indexDocument`, `removeDocument`, `search` (error cases), optimizer/reset flows, and migrations.
2. **Integration Fixtures** – Create canonical `.yianazip` + `.ocr_results` pairs to exercise launch-time reindexing and detect stale `fullText` propagation.
3. **Change-Detection Tests** – Simulate OCR completion by mutating metadata and confirm the indexer reprocesses based on `modified` timestamps.
4. **UI Verification** – Author an XCUITest that imports fixtures, waits for OCR, performs a search, and asserts snippet/highlight rendering in both sections.
5. **Mac mini Smoke Test** – Feed the OCR service fixtures covering embedded-text PDFs to ensure it exports `fullText` and `.ocr_results` consistently.
6. **Manual Checklist** – Until automation lands, QA should import a doc, verify `.ocr_results`, trigger reindex, and confirm snippets/flags via the dev menu.

## Recommended Next Steps
- Wire change detection into `BackgroundIndexer` (compare `metadata.modified` vs `indexed_date`) and enqueue reindexing for stale docs.
- Ensure the OCR service writes `fullText`/results even when the source PDF already has text, or add a fallback on iOS to extract strings before indexing.
- Refactor `DocumentListViewModel` search state (clear results per query, debounce async tasks, and keep sorted subsets separate).
- Extend `SearchArchitecture.md` with these behaviours once fixed, and link this report from onboarding docs for continuity.
