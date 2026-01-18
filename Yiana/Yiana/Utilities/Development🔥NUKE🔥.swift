//
//  DevelopmentNuke.swift
//  Yiana
//
//  DANGER: Development/testing utility only!
//  This will DELETE ALL APPLICATION DATA
//

import Foundation
import SwiftUI

/// Utility to completely reset the app's data
/// Available in Release builds when dev mode is enabled
struct DevelopmentNuke {

    /// Completely wipes all app data
    @MainActor
    func nukeEverything() async {
        // Only allow if dev mode is enabled
        guard DevModeManager.shared.isEnabled else {
            print("Nuke blocked: Dev mode not enabled")
            return
        }

        print("NUKE INITIATED - DELETING ALL DATA")

        var deletedItems: [String] = []
        var errors: [String] = []

        let fileManager = FileManager.default

        // 1. Delete iCloud documents contents
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
            let iCloudDocsURL = iCloudURL.appendingPathComponent("Documents")
            if fileManager.fileExists(atPath: iCloudDocsURL.path) {
                do {
                    let contents = try fileManager.contentsOfDirectory(at: iCloudDocsURL,
                                                                      includingPropertiesForKeys: nil)
                    for item in contents {
                        try fileManager.removeItem(at: item)
                    }
                    deletedItems.append("iCloud Documents (contents)")
                } catch {
                    errors.append("iCloud Documents: \(error.localizedDescription)")
                }
            }
        }

        // 2. Delete local documents directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let yianaDocsURL = documentsURL.appendingPathComponent("Documents", isDirectory: true)
            if fileManager.fileExists(atPath: yianaDocsURL.path) {
                do {
                    try fileManager.removeItem(at: yianaDocsURL)
                    deletedItems.append("Local Documents")
                } catch {
                    errors.append("Local Documents: \(error.localizedDescription)")
                }
            }
        }

        // 3. Delete any caches
        if let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            // Delete search index
            let searchIndexURL = cacheURL.appendingPathComponent("SearchIndex")
            if fileManager.fileExists(atPath: searchIndexURL.path) {
                do {
                    try fileManager.removeItem(at: searchIndexURL)
                    deletedItems.append("Search Index Cache")
                } catch {
                    errors.append("Search Index: \(error.localizedDescription)")
                }
            }

            // Delete app-specific cache
            let yianaCacheURL = cacheURL.appendingPathComponent("com.vitygas.Yiana")
            if fileManager.fileExists(atPath: yianaCacheURL.path) {
                do {
                    try fileManager.removeItem(at: yianaCacheURL)
                    deletedItems.append("App Cache")
                } catch {
                    errors.append("App Cache: \(error.localizedDescription)")
                }
            }
        }

        // 4. Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            deletedItems.append("UserDefaults")
        }

        // 5. Post notification for any in-memory cleanup
        NotificationCenter.default.post(name: .developmentDataNuked, object: nil)

        // Log results
        print("NUKE COMPLETE")
        print("Deleted: \(deletedItems.joined(separator: ", "))")
        if !errors.isEmpty {
            print("Errors: \(errors.joined(separator: ", "))")
        }
    }
}

extension Notification.Name {
    static let developmentDataNuked = Notification.Name("developmentDataNuked")
}

// MARK: - Legacy DEBUG-only View (for backwards compatibility)

#if DEBUG
struct DevelopmentNukeView: View {
    @State private var showingConfirmation = false
    @State private var showingFinalConfirmation = false
    @State private var confirmationText = ""
    @State private var resultMessage = ""
    @State private var showingResult = false

    private static let SAFETY_KEY = "YES!DELETE"

    var body: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            Label("NUKE ALL DATA", systemImage: "trash.fill")
                .foregroundColor(.red)
        }
        .alert("EXTREME DANGER", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("I Understand", role: .destructive) {
                showingFinalConfirmation = true
            }
        } message: {
            Text("""
            This will PERMANENTLY DELETE:
            - All documents
            - All OCR data
            - All settings
            - All caches

            This action CANNOT be undone!
            """)
        }
        .alert("Final Confirmation", isPresented: $showingFinalConfirmation) {
            TextField("Type: YES!DELETE", text: $confirmationText)
            Button("Cancel", role: .cancel) {
                confirmationText = ""
            }
            Button("DELETE EVERYTHING", role: .destructive) {
                if confirmationText == Self.SAFETY_KEY {
                    Task {
                        await DevelopmentNuke().nukeEverything()
                        resultMessage = "All data deleted. Restart the app."
                        showingResult = true
                    }
                }
            }
        } message: {
            Text("Type exactly: YES!DELETE")
        }
        .alert("Nuke Result", isPresented: $showingResult) {
            Button("OK") {
                confirmationText = ""
            }
        } message: {
            Text(resultMessage)
        }
    }
}
#endif
