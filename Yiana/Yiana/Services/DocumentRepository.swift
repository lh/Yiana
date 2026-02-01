//
//  DocumentRepository.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation

/// Manages document URLs in a directory. Does NOT handle document content.
class DocumentRepository {
    let documentsDirectory: URL

    /// Current folder being viewed (relative to documentsDirectory)
    private(set) var currentFolderPath: String = ""

    init(documentsDirectory: URL? = nil) {
        if let directory = documentsDirectory {
            self.documentsDirectory = directory
        } else {
            // Try to use iCloud Documents first
            if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
                // Use Documents folder inside iCloud container
                self.documentsDirectory = iCloudURL.appendingPathComponent("Documents")
            } else {
                // Fallback to local Documents directory if iCloud is not available
                self.documentsDirectory = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!
            }
        }

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: self.documentsDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Returns all .yianazip file URLs in the current folder
    func documentURLs() -> [URL] {
        let targetDirectory = currentFolderPath.isEmpty ?
            documentsDirectory :
            documentsDirectory.appendingPathComponent(currentFolderPath)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: targetDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.filter { $0.pathExtension == "yianazip" }
    }

    /// Generates a new unique URL for a document with given title
    func newDocumentURL(title: String) -> URL {
        let cleanTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let targetDirectory = currentFolderPath.isEmpty ?
            documentsDirectory :
            documentsDirectory.appendingPathComponent(currentFolderPath)

        let baseURL = targetDirectory
            .appendingPathComponent(cleanTitle)
            .appendingPathExtension("yianazip")

        // If file exists, add number
        var url = baseURL
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            url = targetDirectory
                .appendingPathComponent("\(cleanTitle) \(counter)")
                .appendingPathExtension("yianazip")
            counter += 1
        }

        return url
    }

    /// Deletes document at URL
    func deleteDocument(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func duplicateDocument(at url: URL) throws -> URL {
        let fileManager = FileManager.default

        // Read the original document data
        guard fileManager.fileExists(atPath: url.path) else {
            throw NSError(domain: "DocumentRepository", code: 404,
                         userInfo: [NSLocalizedDescriptionKey: "Document not found"])
        }

        // Get the target directory (same as current folder)
        let targetDirectory = currentFolderPath.isEmpty ?
            documentsDirectory :
            documentsDirectory.appendingPathComponent(currentFolderPath)

        // Generate a new name with " Copy" suffix
        let originalName = url.deletingPathExtension().lastPathComponent
        var newName = "\(originalName) Copy"
        var counter = 1

        // Keep incrementing if "Copy" already exists
        var newURL = targetDirectory
            .appendingPathComponent("\(newName)")
            .appendingPathExtension("yianazip")

        while fileManager.fileExists(atPath: newURL.path) {
            newName = "\(originalName) Copy \(counter)"
            newURL = targetDirectory
                .appendingPathComponent("\(newName)")
                .appendingPathExtension("yianazip")
            counter += 1
        }

        // Copy the file
        try fileManager.copyItem(at: url, to: newURL)

        return newURL
    }

    /// Check if using iCloud
    var isUsingiCloud: Bool {
        return documentsDirectory.path.contains("com~apple~CloudDocs") ||
               documentsDirectory.path.contains("Mobile Documents")
    }

    // MARK: - Folder Operations

    /// Returns all folders in the current directory
    func folderURLs() -> [URL] {
        let targetDirectory = currentFolderPath.isEmpty ?
            documentsDirectory :
            documentsDirectory.appendingPathComponent(currentFolderPath)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: targetDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.filter { url in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { return false }
            // Exclude iCloud sync placeholder directories (UUID-named)
            return UUID(uuidString: url.lastPathComponent) == nil
        }
    }

    /// Navigate into a folder
    func navigateToFolder(_ folderName: String) {
        if currentFolderPath.isEmpty {
            currentFolderPath = folderName
        } else {
            currentFolderPath = (currentFolderPath as NSString).appendingPathComponent(folderName)
        }
    }

    /// Navigate to parent folder
    func navigateToParent() {
        if !currentFolderPath.isEmpty {
            currentFolderPath = (currentFolderPath as NSString).deletingLastPathComponent
        }
    }

    /// Navigate to root
    func navigateToRoot() {
        currentFolderPath = ""
    }

    /// Create a new folder
    func createFolder(name: String) throws {
        let targetDirectory = currentFolderPath.isEmpty ?
            documentsDirectory :
            documentsDirectory.appendingPathComponent(currentFolderPath)

        let folderURL = targetDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    /// Get current folder display name
    var currentFolderName: String {
        if currentFolderPath.isEmpty {
            return "Documents"
        }
        return (currentFolderPath as NSString).lastPathComponent
    }

    /// Get folder path components for breadcrumb navigation
    var folderPathComponents: [String] {
        if currentFolderPath.isEmpty {
            return []
        }
        return currentFolderPath.components(separatedBy: "/").filter { !$0.isEmpty }
    }

    // MARK: - Search Operations

    /// Recursively find all documents in all folders
    func allDocumentsRecursive() -> [(url: URL, relativePath: String)] {
        var results: [(URL, String)] = []
        searchRecursive(at: documentsDirectory, relativePath: "", results: &results)
        return results
    }

    private func searchRecursive(at directory: URL, relativePath: String, results: inout [(URL, String)]) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in urls {
            // Use resource values instead of fileExists — fileExists returns false
            // for iCloud placeholder files that haven't been downloaded yet
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory == true {
                let newPath = relativePath.isEmpty ? url.lastPathComponent : relativePath + "/" + url.lastPathComponent
                searchRecursive(at: url, relativePath: newPath, results: &results)
            } else if url.pathExtension == "yianazip" {
                // Resolve symlinks so /var/mobile ↔ /private/var/mobile paths
                // match the URLs stored by UbiquityMonitor (via NSMetadataQuery)
                results.append((url.resolvingSymlinksInPath(), relativePath))
            }
        }
    }
}
