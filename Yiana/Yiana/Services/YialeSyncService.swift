//
//  YialeSyncService.swift
//  Yiana
//

import Foundation

/// Watches for Yiale's `.worklist.json` in the iCloud container and posts
/// `.yialeWorkListChanged` when it changes.
///
/// Uses `NSMetadataQuery` scoped to the iCloud container, matching the
/// `UbiquityMonitor` pattern.
final class YialeSyncService: NSObject {
    static let shared = YialeSyncService()

    private let ubiquityIdentifier = "iCloud.com.vitygas.Yiana"
    private var query: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []
    private var cachedContainerURL: URL?
    private var isRunning = false

    override private init() {
        super.init()
    }

    deinit {
        stop()
    }

    /// Call from main thread to start watching.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Cache container URL on main thread
        cachedContainerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: ubiquityIdentifier
        )

        guard cachedContainerURL != nil else { return }

        let metadataQuery = NSMetadataQuery()
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(format: "%K == %@",
            NSMetadataItemFSNameKey, ".worklist.json")

        let gatherObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            self?.handleQueryResult()
        }
        queryObservers.append(gatherObserver)

        let updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            self?.handleQueryResult()
        }
        queryObservers.append(updateObserver)

        query = metadataQuery
        metadataQuery.start()
    }

    func stop() {
        query?.stop()
        query = nil
        for observer in queryObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        queryObservers.removeAll()
        isRunning = false
    }

    private func handleQueryResult() {
        guard let query, let containerURL = cachedContainerURL else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        guard query.resultCount > 0,
              let item = query.result(at: 0) as? NSMetadataItem,
              let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL
        else { return }

        // Read and parse the Yiale worklist file
        let documentsURL = containerURL.appendingPathComponent("Documents")
        let yialeURL = documentsURL.appendingPathComponent(".worklist.json")

        guard url.standardizedFileURL == yialeURL.standardizedFileURL else { return }

        // Decode Yiale's worklist format
        guard let data = try? Data(contentsOf: url) else { return }

        // Yiale writes a WorkList with items: [WorkListItem] — decode the MRN/name fields
        guard let yialeList = try? JSONDecoder().decode(YialeWorkListFile.self, from: data) else {
            return
        }

        let items = yialeList.items.map { item in
            ClinicListItem(
                mrn: item.mrn,
                surname: item.surname,
                firstName: item.firstName,
                gender: item.gender,
                age: item.age,
                doctor: item.doctor
            )
        }

        NotificationCenter.default.post(
            name: .yialeWorkListChanged,
            object: nil,
            userInfo: ["items": items]
        )
    }
}

// MARK: - Yiale's file format

/// Matches the JSON structure written by the Yiale app.
private struct YialeWorkListFile: Codable {
    var modified: String
    var items: [YialeWorkListItem]
}

private struct YialeWorkListItem: Codable {
    let mrn: String
    let surname: String
    let firstName: String
    let gender: String?
    let age: Int?
    let doctor: String?
    let added: String
}
