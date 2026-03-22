import Foundation
import PDFKit

/// Watches `.letters/inject/` in the iCloud container for PDFs placed by the render service,
/// and appends them to the matching patient document.
final class InjectWatcher {
    static let shared = InjectWatcher()

    private let ubiquityIdentifier = "iCloud.com.vitygas.Yiana"
    private let pollInterval: TimeInterval = 10
    private var timer: Timer?
    private var containerURL: URL?

    private init() {}

    /// Starts polling. Safe to call multiple times.
    func start() {
        guard timer == nil else { return }
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityIdentifier) else {
            log("iCloud container unavailable — inject watcher not started")
            return
        }
        containerURL = container
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        log("Started (polling every \(Int(pollInterval))s)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private var injectDirectory: URL? {
        containerURL?
            .appendingPathComponent("Documents")
            .appendingPathComponent(".letters")
            .appendingPathComponent("inject")
    }

    private var unmatchedDirectory: URL? {
        containerURL?
            .appendingPathComponent("Documents")
            .appendingPathComponent(".letters")
            .appendingPathComponent("unmatched")
    }

    private func poll() {
        Task.detached { [weak self] in
            guard let self else { return }
            await self.scanAndProcess()
        }
    }

    private func scanAndProcess() async {
        guard let injectDir = injectDirectory else { return }

        let fm = FileManager.default
        if !fm.fileExists(atPath: injectDir.path) { return }

        let contents: [URL]
        do {
            // No .skipsHiddenFiles — iCloud marks synced files as hidden
            contents = try fm.contentsOfDirectory(
                at: injectDir,
                includingPropertiesForKeys: nil,
                options: []
            )
        } catch {
            log("Failed to list inject directory: \(error.localizedDescription)")
            return
        }

        let pdfs = contents.filter { $0.pathExtension.lowercased() == "pdf" }
        for pdf in pdfs {
            await processFile(pdf)
        }
    }

    private func processFile(_ url: URL) async {
        let fm = FileManager.default
        let processingURL = url.appendingPathExtension("processing")

        // Atomic claim — if rename fails, another device got it
        do {
            try fm.moveItem(at: url, to: processingURL)
        } catch {
            log("Could not claim \(url.lastPathComponent) — skipping")
            return
        }

        // Parse filename: {yiana_target}_{letter_id}.pdf
        let stem = url.deletingPathExtension().lastPathComponent
        let uuidPattern = try! Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
        guard let match = stem.firstMatch(of: uuidPattern) else {
            log("Could not parse UUID from filename: \(stem)")
            moveToUnmatched(processingURL, originalName: url.lastPathComponent)
            return
        }
        let uuidStart = match.range.lowerBound
        guard uuidStart > stem.startIndex else {
            log("No target name in filename: \(stem)")
            moveToUnmatched(processingURL, originalName: url.lastPathComponent)
            return
        }
        let target = String(stem[stem.startIndex..<stem.index(before: uuidStart)])

        // Find the matching .yianazip document
        let repository = DocumentRepository()
        let allDocs = repository.allDocumentsRecursive()
        let matchingDoc = allDocs.first { doc in
            doc.url.deletingPathExtension().lastPathComponent == target
        }

        guard let matchingDoc else {
            log("No document matching target '\(target)' — moving to unmatched")
            moveToUnmatched(processingURL, originalName: url.lastPathComponent)
            return
        }

        // Read the PDF data with file coordination (iCloud may be mid-sync)
        var pdfData: Data?
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: processingURL, options: [], error: &coordinatorError) { coordURL in
            pdfData = try? Data(contentsOf: coordURL)
        }

        guard let data = pdfData, PDFDocument(data: data) != nil else {
            log("Failed to read valid PDF from \(processingURL.lastPathComponent)")
            moveToUnmatched(processingURL, originalName: url.lastPathComponent)
            return
        }

        // Append to the target document
        do {
            let importService = ImportService()
            _ = try importService.importPDF(
                from: processingURL,
                mode: .appendToExisting(targetURL: matchingDoc.url)
            )
            try? fm.removeItem(at: processingURL)
            log("Appended \(url.lastPathComponent) to \(matchingDoc.url.lastPathComponent)")
            let docURL = matchingDoc.url
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .yianaDocumentContentChanged,
                    object: docURL
                )
            }
        } catch {
            log("Failed to append: \(error.localizedDescription)")
            moveToUnmatched(processingURL, originalName: url.lastPathComponent)
        }
    }

    private func moveToUnmatched(_ processingURL: URL, originalName: String) {
        guard let unmatchedDir = unmatchedDirectory else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: unmatchedDir, withIntermediateDirectories: true)
        let destination = unmatchedDir.appendingPathComponent(originalName)
        do {
            try fm.moveItem(at: processingURL, to: destination)
            log("Moved to unmatched: \(originalName)")
        } catch {
            log("Failed to move to unmatched: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[InjectWatcher] \(message)")
        #endif
    }
}
