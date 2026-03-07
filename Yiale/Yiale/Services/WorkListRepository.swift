import Foundation

final class WorkListRepository {
    /// Load the work list from `.worklist.json`.
    /// Call from `Task.detached` (file I/O off main thread).
    func load() throws -> WorkList {
        guard let url = ICloudContainer.shared.workListURL else {
            throw ServiceError.iCloudUnavailable
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return WorkList(modified: ISO8601DateFormatter().string(from: Date()), items: [])
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorkList.self, from: data)
    }

    /// Save the work list with atomic write.
    /// Call from `Task.detached` (file I/O off main thread).
    func save(_ workList: WorkList) throws {
        guard let url = ICloudContainer.shared.workListURL else {
            throw ServiceError.iCloudUnavailable
        }

        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        let tmpURL = url.appendingPathExtension("tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workList)
        try data.write(to: tmpURL, options: .atomic)

        if fm.fileExists(atPath: url.path) {
            _ = try fm.replaceItemAt(url, withItemAt: tmpURL)
        } else {
            try fm.moveItem(at: tmpURL, to: url)
        }
    }

    /// Delete the work list file.
    /// Call from `Task.detached` (file I/O off main thread).
    func clear() throws {
        guard let url = ICloudContainer.shared.workListURL else {
            throw ServiceError.iCloudUnavailable
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
