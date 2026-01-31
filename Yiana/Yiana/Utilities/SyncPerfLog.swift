//
//  SyncPerfLog.swift
//  Yiana
//
//  DEBUG-only performance counters for measuring sync/reload overhead.

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
        summaryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.printSummary() }
        }
        print("[PerfLog] Started")
    }

    func stop() {
        printSummary()
        summaryTimer?.invalidate()
        summaryTimer = nil
        print("[PerfLog] Stopped")
    }

    func countRefresh() { refreshCalls += 1 }
    func countLoadDocuments(ms: Double) { loadDocumentsCalls += 1; loadDocumentsMs.append(ms) }
    func countNotification() { notificationsReceived += 1 }
    func countObservation() { observationCallbacks += 1 }
    func countDownloadStateCheck() { downloadStateChecks += 1 }
    func countPlaceholderBatch() { placeholderBatchInserts += 1 }

    private func printSummary() {
        let elapsed = -(startTime ?? Date()).timeIntervalSinceNow
        let avgMs = loadDocumentsMs.isEmpty ? 0 : loadDocumentsMs.reduce(0, +) / Double(loadDocumentsMs.count)
        print("""
        [PerfLog] \(String(format: "%.0f", elapsed))s elapsed
          notifications received:  \(notificationsReceived)
          refresh() calls:         \(refreshCalls)
          loadDocuments() calls:   \(loadDocumentsCalls)  avg \(String(format: "%.1f", avgMs))ms
          observation callbacks:   \(observationCallbacks)
          downloadState() checks:  \(downloadStateChecks)
          placeholder batches:     \(placeholderBatchInserts)
        """)
    }
}
#endif
