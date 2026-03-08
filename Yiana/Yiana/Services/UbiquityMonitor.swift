//
//  UbiquityMonitor.swift
//  Yiana
//
//  Watches the iCloud ubiquity container for remote document changes and
//  reposts the standard `yianaDocumentsChanged` notification.
//

import Foundation
import CryptoKit

/// Observes iCloud Drive metadata and notifies the app when remote documents change.
final class UbiquityMonitor: NSObject {
    static let shared = UbiquityMonitor()

    /// Identifier used across the app for the ubiquity container.
    private let ubiquityIdentifier = "iCloud.com.vitygas.Yiana"

    private var query: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []
    private var identityObserver: NSObjectProtocol?
    private var knownDocuments: Set<URL> = []
    /// Tracks per-file download status across query updates
    private var downloadStates: [URL: String] = [:]
    /// Tracks per-file content version to detect remote content updates
    private var contentVersions: [URL: Date] = [:]
    private var retryWorkItem: DispatchWorkItem?
    private var isRunningInternal = false
    /// After the initial gather seeds all placeholders, subsequent updates only seed newly added items
    private var hasCompletedInitialSeed = false
    /// Debounce rapid-fire NSMetadataQueryDidUpdate notifications to keep the main thread responsive
    private var updateDebounceWorkItem: DispatchWorkItem?
    private let updateDebounceInterval: TimeInterval = 2.0

    private let notificationCenter = NotificationCenter.default
    private let retryDelay: TimeInterval = 30

    private let searchIndex = SearchIndexService.shared
    private lazy var documentsDirectory: URL = {
        DocumentRepository().documentsDirectory
    }()

    override private init() {
        super.init()
        identityObserver = notificationCenter.addObserver(
            forName: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restart()
        }
    }

    deinit {
        if let identityObserver {
            notificationCenter.removeObserver(identityObserver)
        }
        stop()
    }

    /// Indicates whether the monitor currently has an active metadata query.
    var isRunning: Bool {
        if Thread.isMainThread {
            return isRunningInternal
        } else {
            return DispatchQueue.main.sync { isRunningInternal }
        }
    }

    /// Starts monitoring for ubiquity changes. Safe to call multiple times.
    func start() {
        if Thread.isMainThread {
            startOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.startOnMain()
            }
        }
    }

    /// Stops monitoring and tears down observers.
    func stop() {
        if Thread.isMainThread {
            stopOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.stopOnMain()
            }
        }
    }

    // MARK: - Private

    private func startOnMain() {
        assert(Thread.isMainThread)

        retryWorkItem?.cancel()
        retryWorkItem = nil

        guard !isRunningInternal else { return }

        guard FileManager.default.url(forUbiquityContainerIdentifier: ubiquityIdentifier) != nil else {
            log("Ubiquity container unavailable; will retry in \(Int(retryDelay))s")
            scheduleRetry()
            return
        }

        let query = NSMetadataQuery()
        query.operationQueue = .main
        query.notificationBatchingInterval = 2.0
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(
            format: "%K LIKE[c] %@",
            NSMetadataItemFSNameKey,
            "*.yianazip"
        )

        let finishObserver = notificationCenter.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.handleQueryNotification(notification)
        }

        let updateObserver = notificationCenter.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.handleQueryNotification(notification)
        }

        queryObservers = [finishObserver, updateObserver]
        knownDocuments.removeAll()
        downloadStates.removeAll()
        hasCompletedInitialSeed = false

        log("Starting metadata query")
        query.start()

        self.query = query
        isRunningInternal = true
    }

    private func stopOnMain() {
        assert(Thread.isMainThread)

        retryWorkItem?.cancel()
        retryWorkItem = nil

        guard isRunningInternal else { return }

        log("Stopping metadata query")

        updateDebounceWorkItem?.cancel()
        updateDebounceWorkItem = nil
        pendingAdded.removeAll()
        pendingChanged.removeAll()
        pendingRemoved.removeAll()

        query?.stop()
        query = nil
        knownDocuments.removeAll()
        downloadStates.removeAll()

        queryObservers.forEach { notificationCenter.removeObserver($0) }
        queryObservers.removeAll()

        isRunningInternal = false
    }

    private func restart() {
        DispatchQueue.main.async { [weak self] in
            self?.stopOnMain()
            self?.startOnMain()
        }
    }

    private func scheduleRetry() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.startOnMain()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay, execute: workItem)
    }

    private func handleQueryNotification(_ notification: Notification) {
        let isInitialGather = notification.name == .NSMetadataQueryDidFinishGathering

        if isInitialGather {
            // Process initial gather immediately — we need all items for seeding
            updateDebounceWorkItem?.cancel()
            updateDebounceWorkItem = nil
            processInitialGather()
        } else {
            // Accumulate delta items from this notification
            accumulateDelta(from: notification)
            // Debounce: process accumulated deltas after the interval
            updateDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.processAccumulatedDelta()
            }
            updateDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceInterval, execute: workItem)
        }
    }

    // MARK: - Initial Gather (full scan, runs once)

    private func processInitialGather() {
        guard let query = self.query else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        var allItems: [(url: URL, filename: String)] = []

        for case let item as NSMetadataItem in query.results {
            guard
                let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                url.pathExtension == "yianazip"
            else { continue }

            let standardURL = url.resolvingSymlinksInPath()
            knownDocuments.insert(standardURL)

            let filename = (item.value(forAttribute: NSMetadataItemFSNameKey) as? String) ?? standardURL.lastPathComponent
            allItems.append((url: standardURL, filename: filename))

            // Initialize download state
            let statusString = (item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String) ?? ""
            downloadStates[standardURL] = statusString
        }

        log("Initial gather: \(allItems.count) items")

        hasCompletedInitialSeed = true
        if !allItems.isEmpty {
            let items = allItems
            Task { @MainActor in
                await self.seedPlaceholders(items)
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
        }
    }

    // MARK: - Differential Updates (delta only, debounced)

    /// Accumulated delta items between debounce intervals
    private var pendingAdded: [NSMetadataItem] = []
    private var pendingChanged: [NSMetadataItem] = []
    private var pendingRemoved: [NSMetadataItem] = []

    private func accumulateDelta(from notification: Notification) {
        let userInfo = notification.userInfo
        if let added = userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            pendingAdded.append(contentsOf: added)
        }
        if let changed = userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] {
            pendingChanged.append(contentsOf: changed)
        }
        if let removed = userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            pendingRemoved.append(contentsOf: removed)
        }
    }

    private func processAccumulatedDelta() {
        guard let query = self.query else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        // Drain accumulated items
        let addedItems = pendingAdded
        let changedItems = pendingChanged
        let removedItems = pendingRemoved
        pendingAdded.removeAll()
        pendingChanged.removeAll()
        pendingRemoved.removeAll()

        var newlyDownloadedURLs: [URL] = []
        var addedURLs: [(url: URL, filename: String)] = []
        var removedURLs: [URL] = []

        // Process added items
        for item in addedItems {
            guard
                let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                url.pathExtension == "yianazip"
            else { continue }

            let standardURL = url.resolvingSymlinksInPath()
            knownDocuments.insert(standardURL)

            let filename = (item.value(forAttribute: NSMetadataItemFSNameKey) as? String) ?? standardURL.lastPathComponent
            addedURLs.append((url: standardURL, filename: filename))

            let statusString = (item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String) ?? ""
            downloadStates[standardURL] = statusString
        }

        // Process changed items — reindex on download state transitions or content updates
        for item in changedItems {
            guard
                let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                url.pathExtension == "yianazip"
            else { continue }

            let standardURL = url.resolvingSymlinksInPath()
            let statusString = (item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String) ?? ""
            let previousStatus = downloadStates[standardURL]
            downloadStates[standardURL] = statusString

            let isDownloaded = statusString == NSMetadataUbiquitousItemDownloadingStatusCurrent
                || statusString == NSMetadataUbiquitousItemDownloadingStatusDownloaded
            let wasNotDownloaded = previousStatus == nil
                || previousStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
                || previousStatus == ""

            if isDownloaded && wasNotDownloaded {
                // New download — always reindex
                newlyDownloadedURLs.append(standardURL)
                // Record content version so future changes are detected
                if let modDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date {
                    contentVersions[standardURL] = modDate
                }
            } else if isDownloaded {
                // Already downloaded — only reindex if content actually changed
                let modDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
                let previousDate = contentVersions[standardURL]
                if let modDate, modDate != previousDate {
                    contentVersions[standardURL] = modDate
                    newlyDownloadedURLs.append(standardURL)
                }
            }
        }

        // Process removed items
        for item in removedItems {
            guard
                let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                url.pathExtension == "yianazip"
            else { continue }

            let standardURL = url.resolvingSymlinksInPath()
            knownDocuments.remove(standardURL)
            downloadStates.removeValue(forKey: standardURL)
            removedURLs.append(standardURL)
        }

        let deltaSize = addedItems.count + changedItems.count + removedItems.count
        if deltaSize > 0 {
            log("Delta: +\(addedItems.count) ~\(changedItems.count) -\(removedItems.count), \(newlyDownloadedURLs.count) newly downloaded")
        }

        // Seed placeholders for newly added items
        if !addedURLs.isEmpty {
            let items = addedURLs
            Task { @MainActor in
                await self.seedPlaceholders(items)
            }
        }

        // Remove placeholders for items that disappeared
        if !removedURLs.isEmpty {
            let urls = removedURLs
            Task { @MainActor in
                await self.removePlaceholders(for: urls)
            }
        }

        if !addedURLs.isEmpty || !removedURLs.isEmpty {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
            }
        }

        if !newlyDownloadedURLs.isEmpty {
            // Guard against bulk transitions (e.g. first delta after initial gather
            // reporting all items as "downloaded") — the background indexer handles these
            if knownDocuments.count > 0 && newlyDownloadedURLs.count < knownDocuments.count / 2 {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .yianaDocumentsDownloaded,
                        object: nil,
                        userInfo: ["urls": newlyDownloadedURLs]
                    )
                }
            } else {
                log("Suppressed bulk download notification (\(newlyDownloadedURLs.count) items) — background indexer will handle")
            }
        }
    }

    private func seedPlaceholders(_ items: [(url: URL, filename: String)]) async {
        let allEntries = items.map { item in
            let title = (item.filename as NSString).deletingPathExtension
            return (
                id: UUID(stableFromPath: item.url.path),
                url: item.url,
                title: title,
                folderPath: item.url.relativeFolderPath(relativeTo: documentsDirectory)
            )
        }

        // Process in chunks so the main thread can handle gestures/rendering
        // between database transactions
        let chunkSize = 200
        var totalInserted = 0
        for chunkStart in stride(from: 0, to: allEntries.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, allEntries.count)
            let chunk = Array(allEntries[chunkStart..<chunkEnd])
            do {
                let inserted = try await searchIndex.indexPlaceholdersBatch(chunk)
                totalInserted += inserted
            } catch {
                log("Failed to seed placeholder chunk: \(error)")
            }
            // Yield to let the main run loop process events
            await Task.yield()
        }

        if totalInserted > 0 {
            log("Seeded \(totalInserted) new placeholders (of \(allEntries.count) candidates)")
        }
    }

    private func removePlaceholders(for urls: [URL]) async {
        do {
            try await searchIndex.removeDocumentsByURLsBatch(urls)
            log("Removed \(urls.count) placeholders")
        } catch {
            log("Failed to remove placeholders: \(error)")
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[UbiquityMonitor] \(message)")
        #endif
    }
}
