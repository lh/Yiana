import Foundation
import ZIPFoundation

public enum DocumentArchiveError: Error {
    case cannotCreateArchive(URL)
    case cannotCreateArchiveInMemory
    case missingMetadata
    case missingPDF
    case invalidFormatInfo
}

public enum ArchiveDataSource {
    case data(Data)
    case file(URL)
    case stream(() throws -> Data?)
}

public struct DocumentArchivePayload {
    public let metadata: Data
    public let pdfData: Data?
    public let formatVersion: Int
}

public enum DocumentArchive {
    public static let metadataEntryName = "metadata.json"
    public static let pdfEntryName = "content.pdf"
    public static let formatEntryName = "format.json"
    public static let currentFormatVersion = 2

    // MARK: - Read

    public static func read(from url: URL) throws -> DocumentArchivePayload {
        let archive = try archiveForReading(at: url)

        let metadataData = try extractData(named: metadataEntryName, from: archive)
        let pdfData = try optionalData(named: pdfEntryName, from: archive)
        let formatVersion = try readFormatVersion(from: archive) ?? currentFormatVersion

        return DocumentArchivePayload(
            metadata: metadataData,
            pdfData: pdfData,
            formatVersion: formatVersion
        )
    }

    public static func readMetadata(from url: URL) throws -> (data: Data, formatVersion: Int) {
        let archive = try archiveForReading(at: url)
        let metadataData = try extractData(named: metadataEntryName, from: archive)
        let formatVersion = try readFormatVersion(from: archive) ?? currentFormatVersion
        return (metadataData, formatVersion)
    }

    public static func read(from data: Data) throws -> DocumentArchivePayload {
        let archive = try archiveForReading(data: data)
        let metadataData = try extractData(named: metadataEntryName, from: archive)
        let pdfData = try optionalData(named: pdfEntryName, from: archive)
        let formatVersion = try readFormatVersion(from: archive) ?? currentFormatVersion
        return DocumentArchivePayload(metadata: metadataData, pdfData: pdfData, formatVersion: formatVersion)
    }

    public static func readMetadata(from data: Data) throws -> (data: Data, formatVersion: Int) {
        let archive = try archiveForReading(data: data)
        let metadataData = try extractData(named: metadataEntryName, from: archive)
        let formatVersion = try readFormatVersion(from: archive) ?? currentFormatVersion
        return (metadataData, formatVersion)
    }

    public static func extractPDF(from url: URL, to destinationURL: URL) throws {
        let archive = try archiveForReading(at: url)
        guard let entry = archive[pdfEntryName] else {
            throw DocumentArchiveError.missingPDF
        }
        try archive.extract(entry, to: destinationURL)
    }

    // MARK: - Write

    @discardableResult
    public static func write(
        metadata: Data,
        pdf: ArchiveDataSource?,
        to destinationURL: URL,
        formatVersion: Int = currentFormatVersion
    ) throws -> URL {
        let fm = FileManager.default
        let temporaryDirectory = destinationURL.deletingLastPathComponent()
        let temporaryURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        let stagingDirectory = temporaryDirectory.appendingPathComponent(UUID().uuidString)

        if fm.fileExists(atPath: temporaryURL.path) {
            try fm.removeItem(at: temporaryURL)
        }
        if fm.fileExists(atPath: stagingDirectory.path) {
            try fm.removeItem(at: stagingDirectory)
        }

        try fm.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stagingDirectory) }

        let metadataURL = stagingDirectory.appendingPathComponent(metadataEntryName)
        try metadata.write(to: metadataURL)

        var pdfURL: URL?
        if let pdf {
            let targetURL = stagingDirectory.appendingPathComponent(pdfEntryName)
            switch try resolve(data: pdf, destination: targetURL) {
            case .some(let resolvedURL):
                pdfURL = resolvedURL
            case .none:
                pdfURL = nil
            }
        }

        let formatInfo = FormatInfo(formatVersion: formatVersion)
        let formatData = try JSONEncoder().encode(formatInfo)
        let formatURL = stagingDirectory.appendingPathComponent(formatEntryName)
        try formatData.write(to: formatURL)

        guard let archive = Archive(url: temporaryURL, accessMode: .create) else {
            try? fm.removeItem(at: stagingDirectory)
            throw DocumentArchiveError.cannotCreateArchive(temporaryURL)
        }

        try archive.addEntry(with: metadataEntryName, relativeTo: stagingDirectory, compressionMethod: .none)
        if let pdfURL, fm.fileExists(atPath: pdfURL.path) {
            try archive.addEntry(with: pdfEntryName, relativeTo: stagingDirectory, compressionMethod: .none)
        }
        try archive.addEntry(with: formatEntryName, relativeTo: stagingDirectory, compressionMethod: .none)

        if fm.fileExists(atPath: destinationURL.path) {
            try fm.replaceItemAt(destinationURL, withItemAt: temporaryURL)
        } else {
            try fm.moveItem(at: temporaryURL, to: destinationURL)
        }

        // Apply iOS Data Protection to the final archive
        #if os(iOS)
        try fm.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destinationURL.path
        )
        #endif

        return destinationURL
    }

    // MARK: - Helpers

    private static func archiveForReading(at url: URL) throws -> Archive {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw DocumentArchiveError.cannotCreateArchive(url)
        }
        return archive
    }

    private static func archiveForReading(data: Data) throws -> Archive {
        guard let archive = Archive(data: data, accessMode: .read) else {
            throw DocumentArchiveError.cannotCreateArchiveInMemory
        }
        return archive
    }

    private static func extractData(named name: String, from archive: Archive) throws -> Data {
        guard let entry = archive[name] else {
            if name == metadataEntryName {
                throw DocumentArchiveError.missingMetadata
            } else {
                throw DocumentArchiveError.missingPDF
            }
        }
        var data = Data()
        _ = try archive.extract(entry, bufferSize: 128 * 1024) { chunk in
            data.append(chunk)
        }
        return data
    }

    private static func optionalData(named name: String, from archive: Archive) throws -> Data? {
        guard let entry = archive[name] else {
            return nil
        }
        var data = Data()
        _ = try archive.extract(entry, bufferSize: 128 * 1024) { chunk in
            data.append(chunk)
        }
        return data
    }

    private static func readFormatVersion(from archive: Archive) throws -> Int? {
        guard let entry = archive[formatEntryName] else {
            return nil
        }
        var data = Data()
        _ = try archive.extract(entry, bufferSize: 16 * 1024) { chunk in
            data.append(chunk)
        }
        do {
            let info = try JSONDecoder().decode(FormatInfo.self, from: data)
            return info.formatVersion
        } catch {
            throw DocumentArchiveError.invalidFormatInfo
        }
    }

    private static func resolve(data source: ArchiveDataSource, destination: URL) throws -> URL? {
        switch source {
        case .data(let data):
            try data.write(to: destination)
            return destination
        case .file(let url):
            let fm = FileManager.default
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: url, to: destination)
            return destination
        case .stream(let producer):
            let fm = FileManager.default
            fm.createFile(atPath: destination.path, contents: nil)
            let handle = try FileHandle(forWritingTo: destination)
            defer { try? handle.close() }
            while true {
                let chunk = try producer()
                guard let chunk, !chunk.isEmpty else { break }
                try handle.write(contentsOf: chunk)
            }
            let attributes = try fm.attributesOfItem(atPath: destination.path)
            if let size = attributes[.size] as? NSNumber, size.intValue == 0 {
                try? fm.removeItem(at: destination)
                return nil
            }
            return destination
        }
    }

    private struct FormatInfo: Codable {
        let formatVersion: Int
    }
}
