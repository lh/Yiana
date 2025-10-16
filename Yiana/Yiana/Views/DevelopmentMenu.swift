//
//  DevelopmentMenu.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//
//  Development tools menu - DEBUG builds only
//

import SwiftUI
#if os(macOS)
import Foundation
#endif

#if DEBUG
struct DevelopmentMenu: View {
    @State private var showingNukeView = false

    var body: some View {
        Menu {
            Button(action: {
                showingNukeView = true
            }) {
                Label("🔥 NUKE ALL DATA 🔥", systemImage: "trash.fill")
                    .foregroundColor(.red)
            }

            Divider()

            Button(action: {
                print("DEBUG: Force OCR re-run requested")
                // Could trigger OCR service to re-process all documents
                NotificationCenter.default.post(
                    name: Notification.Name("ForceOCRReprocess"),
                    object: nil
                )
            }) {
                Label("Force OCR Re-run", systemImage: "doc.text.magnifyingglass")
            }

            Button(action: {
                triggerOCRCleanup()
            }) {
                Label("Run OCR Cleanup", systemImage: "trash.slash")
            }

            Button(action: {
                // Just delete OCR cache, less destructive than nuke
                deleteOCRCache()
            }) {
                Label("Clear OCR Cache Only", systemImage: "xmark.circle")
            }

            Button(action: {
                Task {
                    await resetSearchIndex()
                }
            }) {
                Label("Reset Search Index", systemImage: "arrow.clockwise.circle")
            }

            Button(action: {
                Task {
                    await showIndexStats()
                }
            }) {
                Label("Show Index Stats", systemImage: "chart.bar.doc.horizontal")
            }

            Button(action: {
                Task {
                    await inspectDatabase()
                }
            }) {
                Label("Inspect Database Contents", systemImage: "doc.text.magnifyingglass")
            }

            Button(action: {
                Task {
                    await testSearchPipeline()
                }
            }) {
                Label("Test Search Pipeline", systemImage: "magnifyingglass.circle")
            }

            Divider()

            Button(action: {
                print("DEBUG: Current app state:")
                print("  Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
                print("  Documents path: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "unknown")")
                if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
                    print("  iCloud path: \(iCloudURL.path)")
                }
            }) {
                Label("Print Debug Info", systemImage: "info.circle")
            }
        } label: {
            Label("Dev Tools", systemImage: "hammer.fill")
                .foregroundColor(.orange)
        }
        .sheet(isPresented: $showingNukeView) {
            VStack(spacing: 20) {
                Text("⚠️ DANGER ZONE ⚠️")
                    .font(.largeTitle)
                    .foregroundColor(.red)

                DevelopmentNukeView()

                Button("Cancel") {
                    showingNukeView = false
                }
                .padding()
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
        }
    }

    private func deleteOCRCache() {
        let fileManager = FileManager.default
        let paths = [
            "/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results",
            "/Users/rose/Documents/Yiana/.ocr_results"
        ]

        var deleted = false
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    print("✅ Deleted OCR cache at: \(path)")
                    deleted = true
                } catch {
                    print("❌ Failed to delete OCR cache at \(path): \(error)")
                }
            }
        }

        if deleted {
            print("OCR cache cleared. Documents will be re-OCR'd on next access.")
        } else {
            print("No OCR cache found to delete.")
        }
    }

    private func triggerOCRCleanup() {
#if os(macOS)
        let commands = [
            "cd ~/Code/YianaOCRService",
            "swift run yiana-ocr cleanup"
        ].joined(separator: " && ")

        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-lc", commands]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
        } catch {
            print("❌ Failed to run OCR cleanup: \(error)")
        }
#else
        print("OCR cleanup command is only available on macOS.")
#endif
    }

    private func resetSearchIndex() async {
        print("🔄 Resetting search index...")

        // Cancel any ongoing indexing first
        BackgroundIndexer.shared.cancelIndexing()

        // Wait a moment for cancellation to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        do {
            try await SearchIndexService.shared.resetDatabase()
            print("✅ Search index reset complete")

            // Trigger re-indexing
            print("🔍 Starting re-indexing...")
            BackgroundIndexer.shared.indexAllDocuments()
        } catch {
            print("❌ Failed to reset search index: \(error)")
        }
    }

    private func showIndexStats() async {
        print("\n📊 Search Index Statistics")
        print(String(repeating: "=", count: 50))

        do {
            // Get total indexed count
            let indexedCount = try await SearchIndexService.shared.getIndexedDocumentCount()
            print("Total documents indexed: \(indexedCount)")

            // Get total documents in repository
            let repository = DocumentRepository()
            let allDocs = repository.allDocumentsRecursive()
            print("Total documents in repository: \(allDocs.count)")

            // Check which documents are NOT indexed
            var notIndexed: [String] = []
            for item in allDocs {
                if let metadata = try? NoteDocument.extractMetadata(from: item.url) {
                    let isIndexed = try await SearchIndexService.shared.isDocumentIndexed(id: metadata.id)
                    if !isIndexed {
                        notIndexed.append(metadata.title)
                    }
                }
            }

            if notIndexed.isEmpty {
                print("✅ All documents are indexed!")
            } else {
                print("\n⚠️ Documents NOT indexed (\(notIndexed.count)):")
                for (index, title) in notIndexed.prefix(20).enumerated() {
                    print("  \(index + 1). \(title)")
                }
                if notIndexed.count > 20 {
                    print("  ... and \(notIndexed.count - 20) more")
                }
            }

            print(String(repeating: "=", count: 50) + "\n")
        } catch {
            print("❌ Failed to get index stats: \(error)")
        }
    }

    func testSearchPipeline() async {
        print("\n🔬 Testing Search Pipeline")
        print(String(repeating: "=", count: 50))

        do {
            // Test 1: Direct FTS5 query
            print("\n1️⃣ Testing FTS5 directly...")
            let results = try await SearchIndexService.shared.search(query: "Bailey", limit: 5)
            print("   FTS5 returned \(results.count) results")
            for (i, result) in results.enumerated() {
                print("   [\(i+1)] \(result.title)")
                print("       URL: \(result.url.path)")
                print("       Exists: \(FileManager.default.fileExists(atPath: result.url.path))")
            }

            // Test 2: Check repository paths
            print("\n2️⃣ Checking DocumentRepository...")
            let repository = DocumentRepository()
            print("   Documents directory: \(repository.documentsDirectory.path)")
            print("   Current folder path: '\(repository.currentFolderPath)'")

            let allDocs = repository.allDocumentsRecursive()
            print("   Total documents: \(allDocs.count)")
            if let firstDoc = allDocs.first {
                print("   Sample document URL: \(firstDoc.url.path)")
                let parentPath = firstDoc.url.deletingLastPathComponent().path
                    .replacingOccurrences(of: repository.documentsDirectory.path + "/", with: "")
                print("   Sample parent path after transform: '\(parentPath)'")
            }

            // Test 3: Check what filterDocuments would do
            print("\n3️⃣ Simulating folder filter logic...")
            if let result = results.first {
                let currentPath = repository.currentFolderPath
                let parentPath = result.url.deletingLastPathComponent().path
                    .replacingOccurrences(of: repository.documentsDirectory.path + "/", with: "")
                let shouldMatch = parentPath == currentPath || (currentPath.isEmpty && !parentPath.contains("/"))

                print("   Result URL: \(result.url.path)")
                print("   Parent path: '\(parentPath)'")
                print("   Current path: '\(currentPath)'")
                print("   Would match: \(shouldMatch)")
                print("   Logic breakdown:")
                print("     - parentPath == currentPath: \(parentPath == currentPath)")
                print("     - currentPath.isEmpty: \(currentPath.isEmpty)")
                print("     - !parentPath.contains(\"/\"): \(!parentPath.contains("/"))")
            }

            print("\n" + String(repeating: "=", count: 50) + "\n")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }

    private func inspectDatabase() async {
        print("\n🔍 Database Contents Inspection")
        print(String(repeating: "=", count: 50))

        do {
            // Get total count
            let count = try await SearchIndexService.shared.getIndexedDocumentCount()
            print("Total indexed documents: \(count)")

            // Sample a few documents to check their content
            print("\n📝 Sample documents (first 5):")

            let repository = DocumentRepository()
            let allDocs = repository.allDocumentsRecursive().prefix(5)

            for (index, item) in allDocs.enumerated() {
                if let metadata = try? NoteDocument.extractMetadata(from: item.url) {
                    let isIndexed = try await SearchIndexService.shared.isDocumentIndexed(id: metadata.id)

                    print("\n\(index + 1). \(metadata.title)")
                    print("   ID: \(metadata.id)")
                    print("   Indexed: \(isIndexed)")
                    print("   Title length: \(metadata.title.count)")
                    print("   FullText: \(metadata.fullText?.isEmpty ?? true ? "EMPTY" : "\(metadata.fullText!.prefix(100))...")")
                    print("   FullText length: \(metadata.fullText?.count ?? 0)")

                    // Try searching for this document's title
                    let results = try await SearchIndexService.shared.search(query: metadata.title, limit: 5)
                    print("   Search for title returns: \(results.count) results")
                    if !results.isEmpty {
                        print("   First result: \(results[0].title)")
                    }
                }
            }

            print("\n" + String(repeating: "=", count: 50) + "\n")
        } catch {
            print("❌ Failed to inspect database: \(error)")
        }
    }
}
#endif
