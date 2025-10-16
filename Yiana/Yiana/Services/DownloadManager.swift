//
//  DownloadManager.swift
//  Yiana
//
//  Manages downloading of iCloud documents
//

import Foundation

/// Service for managing iCloud document downloads
@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedCount = 0
    @Published var totalCount = 0
    @Published var currentFile: String = ""

    private var downloadTask: Task<Void, Never>?

    private init() {}

    /// Download all documents that aren't already on device
    func downloadAllDocuments(urls: [URL]) {
        // Don't start if already downloading
        guard !isDownloading else { return }

        downloadTask?.cancel()
        downloadTask = Task { @MainActor in
            await performDownload(urls: urls)
        }
    }

    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
    }

    private func performDownload(urls: [URL]) async {
        isDownloading = true
        downloadedCount = 0
        totalCount = urls.count
        downloadProgress = 0.0

        print("📥 Starting iCloud download check for \(urls.count) documents")

        var filesToDownload: [URL] = []

        // First pass: check which files need downloading
        for url in urls {
            // Check if task was cancelled
            if Task.isCancelled {
                print("⚠️ Download cancelled by user")
                isDownloading = false
                return
            }

            if !isFileDownloaded(url: url) {
                filesToDownload.append(url)
            } else {
                downloadedCount += 1
            }
        }

        print("📥 Found \(filesToDownload.count) documents to download")

        // Update progress for already-downloaded files
        downloadProgress = totalCount > 0 ? Double(downloadedCount) / Double(totalCount) : 0.0

        // Second pass: download files that need it
        for (index, url) in filesToDownload.enumerated() {
            // Check if task was cancelled
            if Task.isCancelled {
                print("⚠️ Download cancelled by user")
                isDownloading = false
                return
            }

            currentFile = url.deletingPathExtension().lastPathComponent

            do {
                // Trigger download
                try FileManager.default.startDownloadingUbiquitousItem(at: url)

                // Wait for download to complete
                var isDownloaded = false
                var attempts = 0
                let maxAttempts = 60 // 30 seconds max per file

                while !isDownloaded && attempts < maxAttempts {
                    if Task.isCancelled {
                        isDownloading = false
                        return
                    }

                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    isDownloaded = isFileDownloaded(url: url)
                    attempts += 1
                }

                if isDownloaded {
                    downloadedCount += 1
                    downloadProgress = Double(downloadedCount) / Double(totalCount)
                    print("✓ Downloaded [\(downloadedCount)/\(totalCount)]: \(currentFile)")
                } else {
                    print("⚠️ Timeout downloading: \(currentFile)")
                }

            } catch {
                print("❌ Error downloading \(currentFile): \(error)")
            }

            // Small delay between files to avoid overwhelming iCloud
            if index < filesToDownload.count - 1 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }

        print("✅ Download complete: \(downloadedCount)/\(totalCount) documents on device")

        isDownloading = false
        downloadProgress = 1.0
        currentFile = ""
    }

    /// Check if a file is already downloaded from iCloud
    private func isFileDownloaded(url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey
            ])

            // Check download status
            if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                switch downloadStatus {
                case .current:
                    // File is fully downloaded
                    return true
                case .downloaded:
                    // File is downloaded but might be evicted
                    return true
                case .notDownloaded:
                    // File is not downloaded
                    return false
                default:
                    return false
                }
            }

            // If we can't get ubiquitous status, check if file exists locally
            return FileManager.default.fileExists(atPath: url.path)

        } catch {
            // If we can't check status, assume it needs downloading
            return false
        }
    }

    /// Get download statistics
    func getDownloadStats(urls: [URL]) -> (downloaded: Int, total: Int) {
        var downloadedCount = 0

        for url in urls {
            if isFileDownloaded(url: url) {
                downloadedCount += 1
            }
        }

        return (downloaded: downloadedCount, total: urls.count)
    }
}
