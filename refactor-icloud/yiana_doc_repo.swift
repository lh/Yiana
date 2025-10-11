//
//  DocumentRepository.swift
//  Yiana
//
//  Enhanced with iCloud reliability features
//

import Foundation
import Combine

/// Document availability status
enum DocumentAvailability {
    case available          // Downloaded and ready
    case downloading       // Currently downloading
    case notDownloaded    // Not downloaded yet
    case error(Error)     // Error accessing
}

/// Manages document URLs with iCloud-aware operations
class DocumentRepository: ObservableObject {
    let documentsDirectory: URL
    
    /// Current folder being viewed (relative to documentsDirectory)
    private(set) var currentFolderPath: String = ""
    
    /// Published documents with their availability status
    @Published var documentsWithStatus: [(url: URL, status: DocumentAvailability)] = []
    
    private var metadataQuery: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []
    
    init(documentsDirectory: URL? = nil) {
        if let directory = documentsDirectory {
            self.documentsDirectory = directory
        } else {
            // Try to use iCloud Documents first
            if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
                self.documentsDirectory = iCloudURL.appendingPathComponent("Documents")
            } else {
                self.documentsDirectory = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!
            }
        }
        
        // Ensure directory exists with file coordination
        ensureDirectoryExists()
        
        // Start monitoring if using iCloud
        if isUsingiCloud {
            startMonitoring()
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func ensureDirectoryExists() {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(writingItemAt: documentsDirectory,
                              options: .forMerging,
                              error: &error) { url in
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
        
        if let error = error {
            print("ERROR: Could not ensure directory exists: \(error)")
        }
    }
    
    // MARK: - Document Listing with File Coordination
    
    /// Returns all .yianazip file URLs in the current folder
    /// Uses file coordination for iCloud safety
    func documentURLs() -> [URL] {
        let targetDirectory = currentFolderPath.isEmpty ?
            documentsDirectory :
            documentsDirectory.appendingPathComponent(currentFolderPath)
        
        let coordinator = NSFileCoordinator()
        var urls: [URL] = []
        var coordinationError: NSError?
        
        coordinator.coordinate(readingItemAt: targetDirectory,
                              options: .withoutChanges,
                              error: &coordinationError) { coordURL in
            guard let foundURLs = try? FileManager.default.contentsOfDirectory(
                at: coordURL,
                includingPropertiesForKeys: [.isRegularFileKey, .ubiquitousItemDownloadingStatusKey],
                options: [.skipsHiddenFiles]
            ) else {
                return
            }
            
            urls = foundURLs.filter { $0.pathExtension == "yianazip" }
        }
        
        if let error = coordinationError {
            print("ERROR: File coordination failed: \(error)")
        }
        
        return urls
    }
    
    // MARK: - iCloud Download Status
    
    /// Check if document is downloaded locally
    func isDocumentDownloaded(_ url: URL) -> DocumentAvailability {
        guard isUsingiCloud else { return .available }
        
        var status: DocumentAvailability = .available
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        
        coordinator.coordinate(readingItemAt: url,
                              options: .withoutChanges,
                              error: &coordinationError) { coordURL in
            do {
                let resourceValues = try coordURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                
                if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                    switch downloadStatus {
                    case .current:
                        status = .available
                    case .downloaded:
                        status = .available
                    case .notDownloaded:
                        status = .notDownloaded
                    @unknown default:
                        status = .notDownloaded
                    }
                }
            } catch {
                status = .error(error)
            }
        }
        
        if let error = coordinationError {
            status = .error(error)
        }
        
        return status
    }
    
    /// Download document if not already available
    /// Returns true if document is ready, false if download failed
    @discardableResult
    func ensureDocumentDownloaded(_ url: URL, completion: @escaping (Bool) -> Void) -> Bool {
        guard isUsingiCloud else {
            completion(true)
            return true
        }
        
        let status = isDocumentDownloaded(url)
        
        switch status {
        case .available:
            completion(true)
            return true
            
        case .notDownloaded:
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                monitorDownload(url: url, completion: completion)
                return false
            } catch {
                print("ERROR: Could not start download: \(error)")
                completion(false)
                return false
            }
            
        case .downloading:
            monitorDownload(url: url, completion: completion)
            return false
            
        case .error(let error):
            print("ERROR: Document status error: \(error)")
            completion(false)
            return false
        }
    }
    
    private func monitorDownload(url: URL, completion: @escaping (Bool) -> Void) {
        var attempts = 0
        let maxAttempts = 60 // 30 seconds max
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            attempts += 1
            
            let status = self.isDocumentDownloaded(url)
            
            switch status {
            case .available:
                timer.invalidate()
                completion(true)
                return
                
            case .error:
                timer.invalidate()
                completion(false)
                return
                
            default:
                if attempts >= maxAttempts {
                    timer.invalidate()
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - NSMetadataQuery for iCloud Monitoring
    
    /// Start monitoring documents with NSMetadataQuery
    private func startMonitoring() {
        guard isUsingiCloud else { return }
        
        metadataQuery = NSMetadataQuery()
        metadataQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery?.predicate = NSPredicate(
            format: "%K LIKE '*.yianazip'",
            NSMetadataItemFSNameKey
        )
        
        // Observe updates
        let updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            self?.updateDocumentsWithStatus()
        }
        queryObservers.append(updateObserver)
        
        // Observe when query finishes gathering
        let gatherObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            self?.updateDocumentsWithStatus()
        }
        queryObservers.append(gatherObserver)
        
        metadataQuery?.start()
    }
    
    func stopMonitoring() {
        metadataQuery?.stop()
        queryObservers.forEach { NotificationCenter.default.removeObserver($0) }
        queryObservers.removeAll()
    }
    
    private func updateDocumentsWithStatus() {
        guard let query = metadataQuery else { return }
        
        query.disableUpdates()
        defer { query.enableUpdates() }
        
        var results: [(URL, DocumentAvailability)] = []
        
        for item in query.results {
            guard let metadataItem = item as? NSMetadataItem,
                  let url = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                continue
            }
            
            let downloadStatus = metadataItem.value(
                forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey
            ) as? String
            
            let availability: DocumentAvailability
            if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                availability = .available
            } else if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusDownloading {
                availability = .downloading
            } else {
                availability = .notDownloaded
            }
            
            results.append((url, availability))
        }
        
        documentsWithStatus = results
    }
    
    // MARK: - Document Operations with File Coordination
    
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
        
        var url = baseURL
        var counter = 1
        
        // Use file coordination to check existence
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        
        coordinator.coordinate(readingItemAt: targetDirectory,
                              options: .withoutChanges,
                              error: &coordinationError) { coordURL in
            while FileManager.default.fileExists(atPath: url.path) {
                url = targetDirectory
                    .appendingPathComponent("\(cleanTitle) \(counter)")
                    .appendingPathExtension("yianazip")
                counter += 1
            }
        }
        
        return url
    }
    
    /// Deletes document at URL with file coordination
    func deleteDocument(at url: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        
        coordinator.coordinate(writingItemAt: url,
                              options: .forDeleting,
                              error: &coordinationError) { coordURL in
            try? FileManager.default.removeItem(at: coordURL)
        }
        
        if let error = coordinationError {
            throw error
        }
    }
    
    /// Duplicate document with file coordination
    func duplicateDocument(at url: URL) throws -> URL {
        let coordinator = NSFileCoordinator()
        var newURL: URL?
        var coordinationError: NSError?
        
        coordinator.coordinate(readingItemAt: url,
                              options: .withoutChanges,
                              error: &coordinationError) { coordURL in
            guard FileManager.default.fileExists(atPath: coordURL.path) else {
                return
            }
            
            let targetDirectory = currentFolderPath.isEmpty ?
                documentsDirectory :
                documentsDirectory.appendingPathComponent(currentFolderPath)
            
            let originalName = coordURL.deletingPathExtension().lastPathComponent
            var newName = "\(originalName) Copy"
            var counter = 1
            
            var candidateURL = targetDirectory
                .appendingPathComponent(newName)
                .appendingPathExtension("yianazip")
            
            while FileManager.default.fileExists(atPath: candidateURL.path) {
                newName = "\(originalName) Copy \(counter)"
                candidateURL = targetDirectory
                    .appendingPathComponent(newName)
                    .appendingPathExtension("yianazip")
                counter += 1
            }
            
            try? FileManager.default.copyItem(at: coordURL, to: candidateURL)
            newURL = candidateURL
        }
        
        if let error = coordinationError {
            throw error
        }
        
        guard let result = newURL else {
            throw NSError(domain: "DocumentRepository", code: 500,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to duplicate document"])
        }
        
        return result
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
        
        let coordinator = NSFileCoordinator()
        var folders: [URL] = []
        var coordinationError: NSError?
        
        coordinator.coordinate(readingItemAt: targetDirectory,
                              options: .withoutChanges,
                              error: &coordinationError) { coordURL in
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: coordURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return
            }
            
            folders = urls.filter { url in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
        }
        
        return folders
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
        
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        
        coordinator.coordinate(writingItemAt: folderURL,
                              options: .forMerging,
                              error: &coordinationError) { coordURL in
            try? FileManager.default.createDirectory(at: coordURL, withIntermediateDirectories: true)
        }
        
        if let error = coordinationError {
            throw error
        }
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
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        
        coordinator.coordinate(readingItemAt: directory,
                              options: .withoutChanges,
                              error: &coordinationError) { coordURL in
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: coordURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return
            }
            
            for url in urls {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        let newPath = relativePath.isEmpty ? url.lastPathComponent : relativePath + "/" + url.lastPathComponent
                        searchRecursive(at: url, relativePath: newPath, results: &results)
                    } else if url.pathExtension == "yianazip" {
                        results.append((url, relativePath))
                    }
                }
            }
        }
    }
}
