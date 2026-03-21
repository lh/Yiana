import Foundation

class SenderConfigService {
    static let shared = SenderConfigService()

    private var cachedContainerURL: URL?

    /// Call from main thread to cache the iCloud container URL.
    /// `url(forUbiquityContainerIdentifier:)` returns nil from `Task.detached`.
    func cacheContainerURL() {
        if cachedContainerURL == nil {
            cachedContainerURL = FileManager.default.url(
                forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana"
            )
        }
    }

    private var configURL: URL? {
        cachedContainerURL?.appendingPathComponent("Documents")
            .appendingPathComponent(".letters")
            .appendingPathComponent("config")
    }

    /// Read sender.json from `.letters/config/`.
    /// Call from `Task.detached` (file I/O off main thread).
    func load() throws -> SenderConfig? {
        guard let configURL else { return nil }

        let senderURL = configURL.appendingPathComponent("sender.json")
        guard FileManager.default.fileExists(atPath: senderURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: senderURL)
        return try JSONDecoder().decode(SenderConfig.self, from: data)
    }
}
