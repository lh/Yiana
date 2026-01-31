# Performance Comparison — ValueObservation Refactor

## Test conditions
- iPad with ~110 documents syncing via iCloud
- All documents deleted, re-added on Mac, iPad observed during full sync
- Before: `main` branch with notification-driven reloads
- After: `feature/value-observation-refactor` with GRDB ValueObservation

## Results

| Metric | Before (main) | After (ValueObservation) | Change |
|---|---|---|---|
| Duration | 420s | 166s | 2.5x faster |
| notifications received | 115 | 0 | eliminated |
| refresh() calls | 115 | 0 | eliminated |
| loadDocuments() calls | 115 @ 70.3ms | 0 | eliminated |
| observation callbacks | 0 | 221 | replaces refresh/load |
| downloadState() checks | 0* | 29 | — |
| placeholder batches | 0* | 0 | — |
| Main-thread DB query time | ~8.1s total | 0s | eliminated |

*Baseline zeros due to fileExists bug (placeholders invisible, so no rows rendered).

## Key observations

1. **Zero manual reloads**: The notification → refresh() → loadDocuments() chain is
   completely eliminated. The document list updates via GRDB ValueObservation only.

2. **Notifications no longer drive the list**: The `countNotification` counter reads 0
   because BackgroundIndexer no longer posts `.yianaDocumentsChanged` after DB writes.
   The list reacts to DB changes directly.

3. **Observation callback burst**: Callbacks went from 107 to 221 in the last 6 seconds
   (165s mark), coinciding with a batch of documents finishing download. Each individual
   DB write fires a separate observation callback. This could be further optimized by
   batching re-index writes.

4. **Sync completed faster**: 166s vs 420s. Likely because the old code's 115 full
   reloads (each doing filesystem + DB queries on main thread) were slowing down the
   overall sync pipeline.

## Source logs

- Before: `perflog_2026-01-31_115920.txt` (main branch, 420s)
- After: `perflog_2026-01-31_123207.txt` (feature branch, 166s)
