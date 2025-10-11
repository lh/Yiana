//
//  UbiquityMonitor.swift
//  Yiana
//
//  Watches the iCloud ubiquity container for remote document changes and
//  reposts the standard `yianaDocumentsChanged` notification.
//

import Foundation

/// Observes iCloud Drive metadata and notifies the app when remote documents change.
final class UbiquityMonitor: NSObject {
    static let shared = UbiquityMonitor()

    /// Identifier used across the app for the ubiquity container.
    private let ubiquityIdentifier = "iCloud.com.vitygas.Yiana"

    private var query: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []
    private var identityObserver: NSObjectProtocol?
    private var knownDocuments: Set<URL> = []
    private var retryWorkItem: DispatchWorkItem?
    private var isRunningInternal = false

    private let notificationCenter = NotificationCenter.default
    private let retryDelay: TimeInterval = 30

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

        query?.stop()
        query = nil
        knownDocuments.removeAll()

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
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        var currentDocuments: Set<URL> = []

        for case let item as NSMetadataItem in query.results {
            guard
                let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                url.pathExtension == "yianazip"
            else { continue }

            currentDocuments.insert(url.standardizedFileURL)
        }

        let added = currentDocuments.subtracting(knownDocuments)
        let removed = knownDocuments.subtracting(currentDocuments)

        if added.isEmpty && removed.isEmpty {
            return
        }

        knownDocuments = currentDocuments

        log("Documents changed (added: \(added.count), removed: \(removed.count))")

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[UbiquityMonitor] \(message)")
        #endif
    }
}
