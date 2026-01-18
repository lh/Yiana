//
//  DeveloperToolsView.swift
//  Yiana
//
//  Developer tools accessible via hidden dev mode toggle.
//  Works in Release builds when dev mode is enabled.
//

import SwiftUI

struct DeveloperToolsView: View {
    @State private var showingNukeConfirmation = false
    @State private var outputLog: String = ""
    @State private var showingOutput = false

    var body: some View {
        Form {
            Section(header: Text("Search Index")) {
                Button {
                    Task { await resetSearchIndex() }
                } label: {
                    Label("Reset Search Index", systemImage: "arrow.clockwise.circle")
                }

                Button {
                    Task { await showIndexStats() }
                } label: {
                    Label("Show Index Stats", systemImage: "chart.bar.doc.horizontal")
                }

                Button {
                    Task { await inspectDatabase() }
                } label: {
                    Label("Inspect Database Contents", systemImage: "doc.text.magnifyingglass")
                }

                Button {
                    Task { await testSearchPipeline() }
                } label: {
                    Label("Test Search Pipeline", systemImage: "magnifyingglass.circle")
                }
            }

            Section(header: Text("OCR")) {
                Button {
                    NotificationCenter.default.post(
                        name: Notification.Name("ForceOCRReprocess"),
                        object: nil
                    )
                    log("Force OCR re-run requested")
                } label: {
                    Label("Force OCR Re-run", systemImage: "doc.text.magnifyingglass")
                }

                Button {
                    deleteOCRCache()
                } label: {
                    Label("Clear OCR Cache", systemImage: "xmark.circle")
                }

#if os(macOS)
                Button {
                    triggerOCRCleanup()
                } label: {
                    Label("Run OCR Cleanup", systemImage: "trash.slash")
                }
#endif
            }

            Section(header: Text("Debug Info")) {
                Button {
                    printDebugInfo()
                } label: {
                    Label("Print Debug Info", systemImage: "info.circle")
                }
            }

            Section(header: Text("Danger Zone")) {
                Button(role: .destructive) {
                    showingNukeConfirmation = true
                } label: {
                    Label("Delete All Data", systemImage: "trash.fill")
                }
            }

            if !outputLog.isEmpty {
                Section(header: Text("Output Log")) {
                    ScrollView {
                        Text(outputLog)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)

                    Button("Clear Log") {
                        outputLog = ""
                    }
                }
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showingNukeConfirmation) {
            NukeConfirmationView(isPresented: $showingNukeConfirmation)
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        outputLog += "[\(timestamp)] \(message)\n"
    }

    // MARK: - Search Index

    private func resetSearchIndex() async {
        log("🔄 Resetting search index...")

        BackgroundIndexer.shared.cancelIndexing()
        try? await Task.sleep(nanoseconds: 500_000_000)

        do {
            try await SearchIndexService.shared.resetDatabase()
            log("✅ Search index reset complete")
            log("🔍 Starting re-indexing...")
            BackgroundIndexer.shared.indexAllDocuments()
        } catch {
            log("❌ Failed to reset search index: \(error)")
        }
    }

    private func showIndexStats() async {
        log("📊 Search Index Statistics")
        log(String(repeating: "=", count: 40))

        do {
            let indexedCount = try await SearchIndexService.shared.getIndexedDocumentCount()
            log("Total documents indexed: \(indexedCount)")

            let repository = DocumentRepository()
            let allDocs = repository.allDocumentsRecursive()
            log("Total documents in repository: \(allDocs.count)")

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
                log("✅ All documents are indexed!")
            } else {
                log("⚠️ Documents NOT indexed (\(notIndexed.count)):")
                for title in notIndexed.prefix(10) {
                    log("  - \(title)")
                }
                if notIndexed.count > 10 {
                    log("  ... and \(notIndexed.count - 10) more")
                }
            }
        } catch {
            log("❌ Failed to get index stats: \(error)")
        }
    }

    private func inspectDatabase() async {
        log("🔍 Database Contents Inspection")
        log(String(repeating: "=", count: 40))

        do {
            let count = try await SearchIndexService.shared.getIndexedDocumentCount()
            log("Total indexed documents: \(count)")

            let repository = DocumentRepository()
            let allDocs = repository.allDocumentsRecursive().prefix(5)

            log("📝 Sample documents (first 5):")
            for (index, item) in allDocs.enumerated() {
                if let metadata = try? NoteDocument.extractMetadata(from: item.url) {
                    let isIndexed = try await SearchIndexService.shared.isDocumentIndexed(id: metadata.id)
                    log("\(index + 1). \(metadata.title)")
                    log("   Indexed: \(isIndexed)")
                    log("   FullText: \(metadata.fullText?.isEmpty ?? true ? "EMPTY" : "\(metadata.fullText!.count) chars")")
                }
            }
        } catch {
            log("❌ Failed to inspect database: \(error)")
        }
    }

    private func testSearchPipeline() async {
        log("🔬 Testing Search Pipeline")
        log(String(repeating: "=", count: 40))

        do {
            let results = try await SearchIndexService.shared.search(query: "test", limit: 5)
            log("Search for 'test' returned \(results.count) results")
            for (i, result) in results.enumerated() {
                log("  [\(i+1)] \(result.title)")
            }
        } catch {
            log("❌ Test failed: \(error)")
        }
    }

    // MARK: - OCR

    private func deleteOCRCache() {
        let fileManager = FileManager.default

        // Get the iCloud container URL dynamically
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
            let ocrPath = iCloudURL.appendingPathComponent("Documents/.ocr_results")
            if fileManager.fileExists(atPath: ocrPath.path) {
                do {
                    try fileManager.removeItem(at: ocrPath)
                    log("✅ Deleted OCR cache at: \(ocrPath.path)")
                } catch {
                    log("❌ Failed to delete OCR cache: \(error)")
                }
            } else {
                log("No OCR cache found at: \(ocrPath.path)")
            }
        } else {
            log("⚠️ iCloud container not available")
        }
    }

#if os(macOS)
    private func triggerOCRCleanup() {
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
                log(output)
            }
        } catch {
            log("❌ Failed to run OCR cleanup: \(error)")
        }
    }
#endif

    // MARK: - Debug Info

    private func printDebugInfo() {
        log("📱 App Debug Info")
        log(String(repeating: "=", count: 40))
        log("Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")

        if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            log("Documents: \(docsURL.path)")
        }

        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
            log("iCloud: \(iCloudURL.path)")
        } else {
            log("iCloud: Not available")
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        log("Version: \(version) (\(build))")

#if DEBUG
        log("Build: DEBUG")
#else
        log("Build: RELEASE")
#endif
    }
}

// MARK: - Nuke Confirmation View (Multi-step)

struct NukeConfirmationView: View {
    @Binding var isPresented: Bool
    @State private var step = 1
    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var deleteComplete = false

    private let confirmationPhrase = "Yes, nuke all data!"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Warning icon
                Image(systemName: step == 1 ? "exclamationmark.triangle.fill" : "trash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                if step == 1 {
                    // Step 1: Acknowledge what will be deleted
                    step1View
                } else if step == 2 {
                    // Step 2: Type confirmation phrase
                    step2View
                } else {
                    // Step 3: Final result
                    step3View
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Danger Zone")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isDeleting || deleteComplete)
                }
            }
        }
    }

    // MARK: - Step 1: Warning

    private var step1View: some View {
        VStack(spacing: 20) {
            Text("Delete All Data?")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("This will PERMANENTLY delete:")
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Label("All your documents", systemImage: "doc.fill")
                    Label("All your folders", systemImage: "folder.fill")
                    Label("All OCR data", systemImage: "text.magnifyingglass")
                    Label("Search index", systemImage: "magnifyingglass")
                    Label("All app settings", systemImage: "gear")
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            Text("This action CANNOT be undone!")
                .font(.headline)
                .foregroundColor(.red)

            Button(role: .destructive) {
                withAnimation { step = 2 }
            } label: {
                Text("I understand, continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Step 2: Type confirmation

    private var step2View: some View {
        VStack(spacing: 20) {
            Text("Final Confirmation")
                .font(.title)
                .fontWeight(.bold)

            Text("To confirm you want to delete everything, type exactly:")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text(confirmationPhrase)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)

            TextField("Type here...", text: $confirmText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .padding(.horizontal, 40)

            Button(role: .destructive) {
                Task { await performNuke() }
            } label: {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Delete Everything Forever")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .disabled(confirmText != confirmationPhrase || isDeleting)
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal, 40)

            Button("Go Back") {
                withAnimation {
                    step = 1
                    confirmText = ""
                }
            }
            .disabled(isDeleting)
        }
    }

    // MARK: - Step 3: Result

    private var step3View: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("All Data Deleted")
                .font(.title)
                .fontWeight(.bold)

            Text("Please restart the app for a clean state.")
                .foregroundColor(.secondary)

            Button("Done") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Perform Nuke

    private func performNuke() async {
        isDeleting = true

        let nuker = DevelopmentNuke()
        await nuker.nukeEverything()

        await MainActor.run {
            isDeleting = false
            deleteComplete = true
            step = 3
        }
    }
}
