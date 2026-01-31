//
//  SyncPerfLog.swift
//  Yiana
//
//  DEBUG-only performance counters for measuring sync/reload overhead.
//  Writes to Documents/perflog.txt so results survive console noise.

import Foundation

#if DEBUG
@MainActor
final class SyncPerfLog {
    static let shared = SyncPerfLog()

    private var refreshCalls = 0
    private var loadDocumentsCalls = 0
    private var loadDocumentsMs: [Double] = []
    private var notificationsReceived = 0
    private var observationCallbacks = 0
    private var downloadStateChecks = 0
    private var placeholderBatchInserts = 0
    private var startTime: Date?
    private var summaryTimer: Timer?
    private var logFileURL: URL?

    private func setupLogFile() {
        let fileManager = FileManager.default
        guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let dir = caches.appendingPathComponent("PerfLog", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "perflog_\(formatter.string(from: Date())).txt"
        logFileURL = dir.appendingPathComponent(filename)

        // Write header
        let header = "# SyncPerfLog — \(Date())\n# File: \(logFileURL?.path ?? "unknown")\n\n"
        try? header.write(to: logFileURL!, atomically: true, encoding: .utf8)
        print("[PerfLog] Writing to \(logFileURL!.path)")
    }

    private func appendToLog(_ text: String) {
        guard let url = logFileURL,
              let data = (text + "\n").data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }

    func start() {
        startTime = Date()
        refreshCalls = 0
        loadDocumentsCalls = 0
        loadDocumentsMs = []
        notificationsReceived = 0
        observationCallbacks = 0
        downloadStateChecks = 0
        placeholderBatchInserts = 0
        summaryTimer?.invalidate()
        setupLogFile()
        summaryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.writeSummary() }
        }
        appendToLog("[PerfLog] Started")
    }

    func stop() {
        writeSummary()
        summaryTimer?.invalidate()
        summaryTimer = nil
        appendToLog("[PerfLog] Stopped")
        if let url = logFileURL {
            print("[PerfLog] Results saved to \(url.path)")
        }
    }

    func countRefresh() { refreshCalls += 1 }
    func countLoadDocuments(ms: Double) { loadDocumentsCalls += 1; loadDocumentsMs.append(ms) }
    func countNotification() { notificationsReceived += 1 }
    func countObservation() { observationCallbacks += 1 }
    func countDownloadStateCheck() { downloadStateChecks += 1 }
    func countPlaceholderBatch() { placeholderBatchInserts += 1 }

    private func writeSummary() {
        let elapsed = -(startTime ?? Date()).timeIntervalSinceNow
        let avgMs = loadDocumentsMs.isEmpty ? 0 : loadDocumentsMs.reduce(0, +) / Double(loadDocumentsMs.count)
        let summary = """
        [PerfLog] \(String(format: "%.0f", elapsed))s elapsed
          notifications received:  \(notificationsReceived)
          refresh() calls:         \(refreshCalls)
          loadDocuments() calls:   \(loadDocumentsCalls)  avg \(String(format: "%.1f", avgMs))ms
          observation callbacks:   \(observationCallbacks)
          downloadState() checks:  \(downloadStateChecks)
          placeholder batches:     \(placeholderBatchInserts)
        """
        appendToLog(summary)
    }
}
#endif
