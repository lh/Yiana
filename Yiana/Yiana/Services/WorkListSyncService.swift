import Foundation
import os.log

/// Watches `.worklist.json` in the iCloud container and prioritizes downloading
/// `.yianazip` documents whose filenames match work list patient names.
///
/// If no `.worklist.json` exists, this service does nothing.
final class WorkListSyncService: NSObject {
    static let shared = WorkListSyncService()

    private static let logger = Logger(
        subsystem: "com.vitygas.Yiana",
        category: "WorkListSync"
    )

    private let ubiquityIdentifier = "iCloud.com.vitygas.Yiana"
    /// Cached container URL, accessible by `WorkListRepository` for file I/O.
    private(set) var cachedContainerURL: URL?
    private var query: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []
    private var documentsObserver: NSObjectProtocol?

    private var workListItems: [WorkListItem] = []
    /// Lowercased surnames from the work list, used for filename matching.
    private var surnames: Set<String> = []
    private var triggeredURLs: Set<URL> = []

    private var workListLoaded = false
    private var documentsAvailable = false

    private override init() {
        super.init()
    }

    /// Starts monitoring. Safe to call multiple times. Must be called on the main thread.
    func start() {
        assert(Thread.isMainThread)
        guard query == nil else { return }

        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityIdentifier) else {
            Self.logger.warning("iCloud container unavailable — not started")
            return
        }
        cachedContainerURL = container

        // Observe document changes from UbiquityMonitor
        documentsObserver = NotificationCenter.default.addObserver(
            forName: .yianaDocumentsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.documentsAvailable = true
            self?.matchAndTriggerDownloads()
        }

        // Start metadata query for .worklist.json
        let metadataQuery = NSMetadataQuery()
        metadataQuery.operationQueue = .main
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(
            format: "%K == %@",
            NSMetadataItemFSNameKey,
            ".worklist.json"
        )

        let finishObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            Self.logger.info("Query finished gathering")
            self?.handleQueryUpdate()
        }

        let updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            self?.handleQueryUpdate()
        }

        queryObservers = [finishObserver, updateObserver]
        metadataQuery.start()
        self.query = metadataQuery

        Self.logger.info("Started")
    }

    func stop() {
        assert(Thread.isMainThread)

        query?.stop()
        query = nil
        queryObservers.forEach { NotificationCenter.default.removeObserver($0) }
        queryObservers.removeAll()

        if let observer = documentsObserver {
            NotificationCenter.default.removeObserver(observer)
            documentsObserver = nil
        }

        workListItems = []
        surnames.removeAll()
        triggeredURLs.removeAll()
        workListLoaded = false
        documentsAvailable = false
    }

    // MARK: - Private

    private func handleQueryUpdate() {
        guard let query else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        Self.logger.info("Query result count: \(query.resultCount)")

        guard query.resultCount > 0,
              let item = query.result(at: 0) as? NSMetadataItem,
              let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL
        else {
            // No .worklist.json found — clear state
            if workListLoaded {
                Self.logger.info("Work list removed")
                workListItems = []
                surnames.removeAll()
                triggeredURLs.removeAll()
                workListLoaded = false
            } else {
                Self.logger.info("No .worklist.json found")
            }
            return
        }

        // Check if .worklist.json is itself a placeholder that needs downloading
        let downloadStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String ?? ""
        Self.logger.info("Work list download status: \(downloadStatus, privacy: .public)")

        if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
            Self.logger.info("Work list is a placeholder — triggering download")
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return
        }

        // Read and decode the file off the main thread
        let fileURL = url
        Task.detached {
            do {
                let data = try Data(contentsOf: fileURL)
                let workList = try JSONDecoder().decode(WorkList.self, from: data)
                await MainActor.run { [weak self] in
                    self?.applyWorkList(workList)
                }
            } catch {
                Self.logger.error("Failed to read work list: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func applyWorkList(_ workList: WorkList) {
        assert(Thread.isMainThread)

        let newSurnames = Set(workList.items.map { $0.surname.lowercased() })
        let changed = surnames != newSurnames

        workListItems = workList.items
        surnames = newSurnames
        workListLoaded = true

        if changed {
            triggeredURLs.removeAll()
            let names = workList.items.map { "\($0.surname), \($0.firstName)" }.joined(separator: "; ")
            Self.logger.info("Loaded \(workList.items.count) items: \(names, privacy: .public)")
            NotificationCenter.default.post(name: .workListChanged, object: nil)
        }

        matchAndTriggerDownloads()
    }

    private func matchAndTriggerDownloads() {
        assert(Thread.isMainThread)
        guard workListLoaded, documentsAvailable, !surnames.isEmpty else {
            Self.logger.debug("Match skipped: loaded=\(self.workListLoaded) docs=\(self.documentsAvailable) surnames=\(self.surnames.count)")
            return
        }

        let notDownloaded = UbiquityMonitor.shared.notDownloadedURLs()
        Self.logger.info("Not-downloaded documents: \(notDownloaded.count)")
        guard !notDownloaded.isEmpty else { return }

        var triggered = 0
        for url in notDownloaded {
            guard !triggeredURLs.contains(url) else { continue }

            // Filename format: Surname_FirstName_ID.yianazip
            // First underscore-separated word is the surname
            let filename = url.deletingPathExtension().lastPathComponent
            guard let firstWord = filename.split(separator: "_").first else { continue }
            let filenameSurname = String(firstWord).lowercased()

            if surnames.contains(filenameSurname) {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    triggeredURLs.insert(url)
                    triggered += 1
                    Self.logger.info("Triggered download: \(filename, privacy: .public)")
                } catch {
                    Self.logger.error("Failed to trigger download for \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if triggered > 0 {
            Self.logger.info("Triggered \(triggered) total downloads for work list patients")
        } else {
            Self.logger.info("No new matches (already triggered: \(self.triggeredURLs.count))")
        }
    }
}
