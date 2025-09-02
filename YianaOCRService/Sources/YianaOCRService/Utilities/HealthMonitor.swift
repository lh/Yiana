import Foundation
import Logging

/// Simple health monitor that writes a heartbeat and last error for external watchers.
final class HealthMonitor {
    private let logger: Logger
    private let dir: URL
    private let heartbeatFile: URL
    private let lastErrorFile: URL

    init(logger: Logger) {
        self.logger = logger
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = appSupport.appendingPathComponent("YianaOCR/health", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.dir = base
        self.heartbeatFile = base.appendingPathComponent("heartbeat.json")
        self.lastErrorFile = base.appendingPathComponent("last_error.json")
    }

    func touchHeartbeat(note: String? = nil) {
        let payload: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "note": note ?? "scan"
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            try data.write(to: heartbeatFile, options: .atomic)
        } catch {
            logger.error("Failed to write heartbeat", metadata: ["error": .string(error.localizedDescription)])
        }
    }

    func recordError(_ message: String) {
        let payload: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "error": message
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            try data.write(to: lastErrorFile, options: .atomic)
        } catch {
            logger.error("Failed to write last error", metadata: ["error": .string(error.localizedDescription)])
        }
    }
}

