import Foundation

final class SenderConfigService {
    /// Read sender.json from .letters/config/.
    /// Call from Task.detached (file I/O off main thread).
    func load() throws -> SenderConfig {
        guard let configURL = ICloudContainer.shared.configURL else {
            throw ServiceError.iCloudUnavailable
        }

        let senderURL = configURL.appendingPathComponent("sender.json")
        guard FileManager.default.fileExists(atPath: senderURL.path) else {
            throw ServiceError.fileNotFound(senderURL.path)
        }

        let data = try Data(contentsOf: senderURL)
        return try JSONDecoder().decode(SenderConfig.self, from: data)
    }
}
