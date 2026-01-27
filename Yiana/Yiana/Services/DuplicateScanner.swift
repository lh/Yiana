//
//  DuplicateScanner.swift
//  Yiana
//
//  Scans existing documents for duplicates based on content hash
//

import Foundation
import CryptoKit
import YianaDocumentArchive

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let baseTitle: String
    let documents: [DuplicateDocument]

    /// The original document (first created, or shortest name)
    var original: DuplicateDocument? {
        documents.first
    }

    /// Documents that are duplicates of the original
    var duplicates: [DuplicateDocument] {
        Array(documents.dropFirst())
    }
}

struct DuplicateDocument: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let title: String
    let hash: String
    let createdDate: Date?
    let fileSize: Int64

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: DuplicateDocument, rhs: DuplicateDocument) -> Bool {
        lhs.url == rhs.url
    }
}

struct DuplicateScanProgress {
    let currentFile: String
    let currentIndex: Int
    let totalFiles: Int

    var progress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(currentIndex) / Double(totalFiles)
    }
}

class DuplicateScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: DuplicateScanProgress?
    @Published var duplicateGroups: [DuplicateGroup] = []

    /// Scan all documents for duplicates
    func scanForDuplicates() async {
        await MainActor.run {
            isScanning = true
            duplicateGroups = []
        }

        let repository = DocumentRepository()
        let allDocs = repository.allDocumentsRecursive()

        // Dictionary to group documents by their content hash
        var hashToDocuments: [String: [DuplicateDocument]] = [:]

        for (index, item) in allDocs.enumerated() {
            // Update progress
            await MainActor.run {
                self.progress = DuplicateScanProgress(
                    currentFile: item.url.lastPathComponent,
                    currentIndex: index + 1,
                    totalFiles: allDocs.count
                )
            }

            // Extract PDF and compute hash
            guard let payload = try? DocumentArchive.read(from: item.url),
                  let pdfData = payload.pdfData else {
                continue
            }

            let hash = computeHash(pdfData)

            // Get file attributes
            let attributes = try? FileManager.default.attributesOfItem(atPath: item.url.path)
            let createdDate = attributes?[.creationDate] as? Date
            let fileSize = (attributes?[.size] as? Int64) ?? 0

            let title = item.url.deletingPathExtension().lastPathComponent
            let doc = DuplicateDocument(
                url: item.url,
                title: title,
                hash: hash,
                createdDate: createdDate,
                fileSize: fileSize
            )

            hashToDocuments[hash, default: []].append(doc)
        }

        // Find groups with duplicates and sort them
        var groups: [DuplicateGroup] = []

        for (_, documents) in hashToDocuments {
            guard documents.count > 1 else { continue }

            // Sort by creation date (oldest first), then by name length (shortest first)
            let sorted = documents.sorted { a, b in
                if let dateA = a.createdDate, let dateB = b.createdDate {
                    return dateA < dateB
                }
                return a.title.count < b.title.count
            }

            // Extract base title (remove numeric suffix)
            let baseTitle = extractBaseTitle(from: sorted.first?.title ?? "Unknown")

            groups.append(DuplicateGroup(baseTitle: baseTitle, documents: sorted))
        }

        // Sort groups by base title
        groups.sort { $0.baseTitle < $1.baseTitle }

        // Capture the final result for thread-safe access
        let finalGroups = groups

        await MainActor.run {
            self.duplicateGroups = finalGroups
            self.isScanning = false
            self.progress = nil
        }
    }

    /// Delete specified duplicate documents
    func deleteDuplicates(_ documents: [DuplicateDocument]) async -> (deleted: Int, failed: Int) {
        var deleted = 0
        var failed = 0

        for doc in documents {
            do {
                try FileManager.default.removeItem(at: doc.url)
                deleted += 1
            } catch {
                print("Failed to delete \(doc.url.lastPathComponent): \(error)")
                failed += 1
            }
        }

        // Notify that documents have changed
        await MainActor.run {
            NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
        }

        return (deleted, failed)
    }

    private func computeHash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Extract base title by removing numeric suffix like " 1", " 2", etc.
    private func extractBaseTitle(from title: String) -> String {
        // Pattern matches " N" at the end where N is a number
        let pattern = #"\s+\d+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return title
        }

        let range = NSRange(location: 0, length: title.utf16.count)
        return regex.stringByReplacingMatches(in: title, range: range, withTemplate: "")
    }
}
