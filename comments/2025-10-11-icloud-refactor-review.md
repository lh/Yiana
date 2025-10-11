# iCloud Sync Refactor Review

We reviewed the `refactor-icloud/` artifacts and compared them with the current implementation to judge how well the suggested replacements would integrate.

## Current Architecture Touchpoints
- `DocumentRepository` is a lightweight, synchronous helper that is instantiated in many places (DocumentListViewModel, BackgroundIndexer, ImportService, ContentView) and is exercised by unit tests (`Yiana/Yiana/Services/DocumentRepository.swift:10`, `Yiana/Yiana/ViewModels/DocumentListViewModel.swift:55`, `Yiana/Yiana/Services/BackgroundIndexer.swift:42`, `Yiana/Yiana/Services/ImportService.swift:53`, `Yiana/Yiana/ContentView.swift:123`, `Yiana/YianaTests/DocumentRepositoryTests.swift:29`).
- Download state today is coordinated by `DownloadManager.shared`, which already triggers `startDownloadingUbiquitousItem` and tracks progress for the toolbar (`Yiana/Yiana/Services/DownloadManager.swift:10`, `Yiana/Yiana/Views/DocumentListView.swift:252`, `Yiana/Yiana/Views/DocumentListView.swift:603`).
- Document persistence relies on the `YianaDocumentArchive` package; `NoteDocument` delegates all read/write work to it, and many services expect that zipped container format (`Yiana/Yiana/Models/NoteDocument.swift:47`, `Yiana/Yiana/Models/NoteDocument.swift:67`, `Yiana/Yiana/Services/ImportService.swift:83`, `Yiana/Yiana/ViewModels/DocumentListViewModel.swift:239`).

## Proposed DocumentRepository Replacement
- The artifact turns the repository into an `ObservableObject` with a long-lived `NSMetadataQuery`, timers, and file coordination (`refactor-icloud/yiana_doc_repo.swift:20`). Because every caller currently instantiates its own repository, adopting this version would spin up parallel metadata queries and timers per feature. That is both wasteful and likely to trip the system-imposed query limits.
- `ensureDirectoryExists()` coordinates with `.forMerging` against a directory that may not exist yet (`refactor-icloud/yiana_doc_repo.swift:60`). Apple’s docs recommend coordinating on the parent directory when creating new folders; otherwise a missing item produces coordination failures before we even touch iCloud.
- `monitorDownload` schedules a repeating `Timer` that captures `self` strongly and assumes a run loop (`refactor-icloud/yiana_doc_repo.swift:190`). When the repository is created on a background actor (e.g., our async tasks in `DownloadManager` and `BackgroundIndexer`), that timer will never fire; if it does fire, the strong reference means repositories leak indefinitely.
- The new `DocumentAvailability.downloading` branch is never set by `isDocumentDownloaded` (it only emits `.available`/`.notDownloaded`/`.error`, `refactor-icloud/yiana_doc_repo.swift:114`), so the additional UI states would not activate without further changes.
- Tests expect immediate, synchronous filesystem behaviour (`Yiana/YianaTests/DocumentRepositoryTests.swift:33`). Introducing asynchronous coordination and timers would force non-trivial rewrites to keep the test suite deterministic.
- The rest of the codebase still calls `FileManager` directly for attributes, duplication and sorting (`Yiana/Yiana/ViewModels/DocumentListViewModel.swift:168`, `Yiana/Yiana/Views/DocumentListView.swift:836`), so “never touch FileManager on iCloud items” is not achievable without pervasive refactors beyond the repository swap.
- Because we already consolidate downloads through `DownloadManager` (`Yiana/Yiana/Services/DownloadManager.swift:25`), exposing separate `ensureDocumentDownloaded` callbacks risks divergent behaviours and user feedback paths.

## Proposed NoteDocument Replacement
- The suggested file replaces our archive format with a raw `[metadata][0xFFFFFFFF][pdf data]` blob (`refactor-icloud/yiana_note_doc.swift:61`). This would break every caller that expects `.yianazip` bundles produced by `DocumentArchive` (`Yiana/Yiana/Models/NoteDocument.swift:47`, `Yiana/Yiana/Services/ImportService.swift:83`, `Yiana/Yiana/ViewModels/DocumentListViewModel.swift:239`) and invalidate the `YianaDocumentArchive` Swift package entirely.
- Existing tests and the search index rely on the archive’s versioning, attachments, and metadata extraction helpers (`Yiana/YianaTests/NoteDocumentRoundtripTests.swift`, `Yiana/Yiana/Services/BackgroundIndexer.swift:76`). None of that survives if we bypass the package.
- The UIKit conflict handler in the artifact presents alerts through `UIApplication.shared` (`refactor-icloud/yiana_note_doc.swift:123`), which is awkward for multi-window SwiftUI scenes and completely absent on macOS.

## Download Status UI & Settings
- The new `DocumentDownloadBadge`/`DocumentRowView` build on `documentsWithStatus` (`refactor-icloud/doc_status_view.swift:10`, `refactor-icloud/doc_status_view.swift:118`), but our actual list uses `DocumentRow` to surface OCR/indexing state and snippets (`Yiana/Yiana/Views/DocumentListView.swift:836`). Replacing the row would discard those features.
- Each row in the artifact instantiates its own `DocumentRepository`, instantly creating more metadata queries (`refactor-icloud/doc_status_view.swift:104`). That multiplies the earlier coordination concerns.
- We already expose settings in `SettingsView.swift`, focused on layout (`Yiana/Yiana/Views/SettingsView.swift:12`). Dropping in a parallel `iCloudSettingsView` would fragment configuration rather than extend the current sheet.
- The existing toolbar “Download All” button integrates cleanly with `DownloadManager` (`Yiana/Yiana/Views/DocumentListView.swift:603`). Adding a second, row-level downloader without consolidating state would produce conflicting indicators.

## Import & Content Flow Suggestions
- `ImportService` writes through `DocumentArchive.write(...)` today (`Yiana/Yiana/Services/ImportService.swift:83`). Wrapping the outer call in a `coordinate(writingItemAt:)` helper—without updating the archive to cooperate—risks double-writing or clashing temp files.
- The import sheet already queues the metadata refresh once an import succeeds (`Yiana/Yiana/ContentView.swift:183`). Piping the proposed `ensureDocumentDownloaded` continuation into that flow would duplicate the work already queued by `DownloadManager.downloadAllDocuments()`.

## Suggested Direction
- Start by capturing the concrete failure modes we are seeing (e.g. add logging around `isFileDownloaded` and archive loads when `NSFileReadNoSuchFileError` appears). That will tell us whether we need better download signalling or true coordination.
- If coordination is needed, consider a shared `UbiquityService` that manages the lone `NSMetadataQuery` alongside `DownloadManager`, rather than embedding it in every repository.
- Evaluate adding `NSFileCoordinator` only around the high-risk write paths (imports, deletions) while keeping the zipped archive format intact; pairing it with an `NSFilePresenter` will avoid the log spam Apple warns about.
- Any UI changes should extend `DocumentRow` so we can blend download state with the existing OCR/indexing indicators instead of replacing the view wholesale.
- Once the above is scoped, we can revisit targeted changes to `DocumentRepository` (e.g. expose an async download helper that delegates to `DownloadManager`) without breaking the package and tests that already pass today.
