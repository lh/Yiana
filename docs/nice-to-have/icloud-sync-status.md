# iCloud Sync Status Indicator
**Idea logged:** 2025-10-11  
**Motivation:** Users often see a document on one device before the bytes finish downloading through iCloud; today the row looks empty or the open action fails. We should surface sync state so the delay feels understood.

## Suggested Enhancements
1. **Inspect ubiquitous metadata**
   - Use `URLResourceValues` (`isUbiquitousItem`, `isDownloaded`, `ubiquitousItemDownloadingStatus`, `percentDownloaded`) to identify files that exist in iCloud but aren’t local yet.
2. **UI treatment**
   - Show a placeholder row (“Available when download completes…”) or a progress indicator where thumbnails normally appear.
   - Optionally trigger `FileManager.default.startDownloadingUbiquitousItem(at:)` if the user taps a not-yet-downloaded document.
3. **Realtime updates**
   - Extend the existing `yianaDocumentsChanged` notification or adopt `NSFilePresenter` to refresh rows when download status changes.
   - Consider a transient banner (“Waiting for iCloud to synchronise…”) when more than a few items are pending.

## Implementation Notes
- Most logic should live in `DocumentListViewModel` so iOS, iPadOS, and macOS present consistent status.
- Verify behaviour with offline/slow-network scenarios; avoid endless spinners if iCloud refuses a download.
