import Foundation

final class ICloudContainer {
    static let shared = ICloudContainer()

    private let ubiquityIdentifier = "iCloud.com.vitygas.Yiana"

    private(set) var containerURL: URL?

    private init() {}

    /// Call from main thread at app startup (returns nil from Task.detached).
    func setup() {
        guard containerURL == nil else { return }
        containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: ubiquityIdentifier
        )
        #if DEBUG
        if let url = containerURL {
            print("[ICloudContainer] Ready: \(url.path)")
        } else {
            print("[ICloudContainer] iCloud container unavailable")
        }
        #endif
    }

    var documentsURL: URL? {
        containerURL?.appendingPathComponent("Documents")
    }

    var addressesURL: URL? {
        documentsURL?.appendingPathComponent(".addresses")
    }

    var lettersURL: URL? {
        documentsURL?.appendingPathComponent(".letters")
    }

    var draftsURL: URL? {
        lettersURL?.appendingPathComponent("drafts")
    }

    var configURL: URL? {
        lettersURL?.appendingPathComponent("config")
    }

    var renderedURL: URL? {
        lettersURL?.appendingPathComponent("rendered")
    }

    var workListURL: URL? {
        documentsURL?.appendingPathComponent(".worklist.json")
    }
}
