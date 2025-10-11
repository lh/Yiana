# Ubiquity Monitor Spec

**Author:** Codex  
**Date:** 2025-10-11  
**Status:** Draft  
**Scope:** Detect and surface remote iCloud document changes (new, updated, deleted) without requiring app reinstall or manual refresh.

---

## 1. Problem Statement

When a document is added or updated on another device, the iOS/iPadOS/macOS app does not notice the change until a reinstall forces a full resync. Locally we only refresh the document list when our own code posts `Notification.Name.yianaDocumentsChanged`. We need an automatic, push-style signal that triggers the same refresh path as soon as iCloud pushes new metadata down.

Out of scope: restructuring download UI, spinner/empty-state changes, large-scale performance refactors.

---

## 2. Goals

1. Detect remote additions, deletions, or updates to `.yianazip` documents in the ubiquity container.
2. Post `Notification.Name.yianaDocumentsChanged` whenever meaningful changes occur, so existing listeners (e.g. `DocumentListView`, `BackgroundIndexer`) refresh naturally.
3. Optionally hint `DownloadManager` when new URLs arrive so it can mark them for download-on-demand.
4. Keep monitoring singleton-style to avoid multiple concurrent `NSMetadataQuery` instances.
5. Fail gracefully when iCloud Drive is unavailable (no crashes; fall back to manual refresh).

Non-goals: rewriting `DocumentRepository`, changing document format, altering user-visible progress UI.

---

## 3. Proposed Architecture

### 3.1 Components

| Component | Responsibility |
|-----------|----------------|
| `UbiquityMonitor` (new, `Yiana/Yiana/Services/UbiquityMonitor.swift`) | Owns a single `NSMetadataQuery`, translates query results into lightweight change notifications, exposes start/stop methods. |
| `UbiquityMonitor.shared` | Shared instance to prevent duplicate queries; retains the monitor for the app lifecycle. |
| `UbiquityChange` struct (internal) | Captures URLs added/removed/updated between query passes. |

### 3.2 Data Flow

1. App launch (`YianaApp`) calls `UbiquityMonitor.shared.start()` on the main thread once the scene appears.
2. `start()` resolves the ubiquity container via `FileManager.default.url(forUbiquityContainerIdentifier:)`. If unavailable, it logs and schedules a retry (see 3.4).
3. `NSMetadataQuery` is configured with:
   - Search scope: `[NSMetadataQueryUbiquitousDocumentsScope]`
   - Predicate: `NSPredicate(format: "%K LIKE '*.yianazip'", NSMetadataItemFSNameKey)`
4. When the query fires `.NSMetadataQueryDidFinishGathering` or `.NSMetadataQueryDidUpdate`, `UbiquityMonitor` computes the delta between the last known URL set and the new results.
5. If the delta is non-empty, monitor posts `Notification.Name.yianaDocumentsChanged` on the main thread. Optionally, it can invoke a delegate closure to hand off new URLs to `DownloadManager.shared` for preflight checks.
6. Existing observers (Document list, indexer) respond as they already do, without code changes.

### 3.3 Threading & Lifecycle

- `NSMetadataQuery` must be created and started on the main thread. We will marshal all public API calls onto the main queue.
- `UbiquityMonitor` keeps strong references to its notification observers until `stop()` is called (e.g., during app termination or tests).
- We expose `isRunning` for diagnostics/testing.

### 3.4 iCloud Availability & Retry Strategy

- If the ubiquity container returns `nil`, monitoring is skipped but we register for `NSUbiquityIdentityDidChange` and retry `start()` when identity changes.
- Optional: schedule a one-shot retry after a short delay (e.g. 30 seconds) to handle transient connectivity issues.
- When iCloud becomes available mid-session, `start()` succeeds and triggers an immediate initial gather.

### 3.5 Integration Touchpoints

| Location | Change |
|----------|--------|
| `Yiana/Yiana/YianaApp.swift` | Add `.task` (or `.onAppear`) to call `UbiquityMonitor.shared.start()` when the `WindowGroup` activates. |
| `Yiana/Yiana/AppDelegate.swift` (tests) | Provide helper to `stop()` if needed for unit test teardown. |
| `Yiana/Yiana/Services/DownloadManager.swift` (optional) | Add `ingestPendingURLs(_:)` method to accept new URLs flagged by the monitor. |

Feature flag: none required; monitor will no-op if iCloud is absent.

---

## 4. Detailed Behaviour

### 4.1 Change Detection

- Maintain a `Set<URL>` (`knownDocuments`) keyed by standardised file URLs.
- On each query update:
  - Build `currentDocuments` from metadata results.
  - Compute `added = currentDocuments.subtracting(knownDocuments)`
  - Compute `removed = knownDocuments.subtracting(currentDocuments)`
  - `updated` can be approximated by inspecting `NSMetadataUbiquitousItemIsUploadedKey` or modification date changes; for v1, treat any `added` as interesting and rely on `DocumentRepository` to read metadata.
- If `added` or `removed` non-empty, update `knownDocuments` and post notifications.
- To reduce noise, ignore hidden/system files.

### 4.2 Coordination with DownloadManager

- When `added` contains items with `NSMetadataUbiquitousItemDownloadingStatusKey == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded`, optionally call `DownloadManager.shared.registerPending(urls:)` so the toolbar counter reflects pending downloads.
- This is additive; download remains user-controlled unless we decide to auto-download.

### 4.3 Error Handling & Logging

- Wrap query operations in `assert(Thread.isMainThread)` checks (debug builds) to catch misuse.
- Log (debug level) when:
  - iCloud container unavailable on start
  - Monitor starts/stops
  - Added/removed counts
- No user-facing alerts; fallback remains manual refresh.

---

## 5. Testing Strategy

1. **Unit Tests (optional initial coverage)**
   - Inject a mock `NSMetadataQuery`? Complex; we may rely on integration tests.
2. **Integration / Manual**
   - Start app on device A; create/rename/delete documents on device B (or Finder iCloud folder); verify list updates without reinstall.
   - Toggle iCloud Drive availability (sign out/in) and ensure monitor re-registers.
   - Confirm no duplicate notifications are posted for unchanged result sets.
3. **Simulator limitations**
   - iCloud sync is unreliable in simulator; at minimum verify the query starts and initial gather posts a refresh.
4. **Performance**
   - Monitor memory/CPU via Instruments to ensure one query is active and no leaks occur.

---

## 6. Open Questions

1. Do we also care about non-`.yianazip` files (e.g., folder renames)? If yes, expand predicate to include directories and trigger a refresh when folder structure changes.
2. Should the monitor throttle refreshes (e.g., coalesce within 1–2 seconds) to avoid multiple reloads during bulk uploads?
3. For macOS, do we need AppKit-specific lifecycle hooks (e.g., start/stop when window closes)? For now, always running is fine.

---

## 7. Implementation Checklist

1. Create `UbiquityMonitor.swift` with `shared`, `start()`, `stop()`, `isRunning`, delta computation, and notification posting.
2. Integrate monitor startup in `YianaApp`.
3. (Optional) Add hook in `DownloadManager` to mark new URLs as pending.
4. Add debug logging toggled by `#if DEBUG`.
5. Manual verification across devices; document steps in `docs/nice-to-have/icloud-sync-status.md` or new troubleshooting entry.

---

End of spec. Coding may proceed once the above assumptions are accepted.
