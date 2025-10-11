//
//  DevelopmentNuke.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//
//  DANGER: Development testing utility only!
//  This will DELETE ALL APPLICATION DATA
//

import Foundation
import SwiftUI

#if DEBUG
/// Development-only utility to completely reset the app's data
/// WARNING: This will DELETE ALL documents, OCR data, and caches
struct DevelopmentNuke {
    
    // Multiple safety checks to prevent accidental use
    private static let SAFETY_KEY = "YES!DELETE🔥EVERYTHING💀I_AM_SURE!"
    private static let isDevelopmentBuild = true  // Could check for Xcode/TestFlight/AppStore
    
    /// Completely wipes all app data with multiple confirmations
    /// - Parameters:
    ///   - safetyConfirmation: Must exactly match SAFETY_KEY
    ///   - doubleCheck: Must be true as second confirmation
    ///   - completion: Called with result message
    static func nukeAllData(
        safetyConfirmation: String,
        doubleCheck: Bool,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Safety check 1: DEBUG only
        #if !DEBUG
        completion(.failure(NukeError.notDebugBuild))
        return
        #endif
        
        // Safety check 2: Confirmation string must match
        guard safetyConfirmation == SAFETY_KEY else {
            completion(.failure(NukeError.incorrectSafetyKey))
            return
        }
        
        // Safety check 3: Double check must be true
        guard doubleCheck else {
            completion(.failure(NukeError.notDoubleChecked))
            return
        }
        
        // Safety check 4: Development build only
        guard isDevelopmentBuild else {
            completion(.failure(NukeError.notDevelopmentBuild))
            return
        }
        
        print("⚠️ NUKE INITIATED - DELETING ALL DATA ⚠️")
        
        var deletedItems: [String] = []
        var errors: [String] = []
        
        let fileManager = FileManager.default
        
        // 1. Delete main documents directory
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
        
        // 2. Delete iCloud documents
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.vitygas.Yiana") {
            let iCloudDocsURL = iCloudURL.appendingPathComponent("Documents")
            if fileManager.fileExists(atPath: iCloudDocsURL.path) {
                do {
                    // Delete all contents but keep Documents folder
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
        
        // 3. Delete OCR results
        let paths = [
            "/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results",
            "/Users/rose/Documents/Yiana/.ocr_results"
        ]
        
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    deletedItems.append("OCR Results at \(path)")
                } catch {
                    errors.append("OCR Results at \(path): \(error.localizedDescription)")
                }
            }
        }
        
        // 4. Remove OCR service state (Application Support/YianaOCR)
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let ocrSupportURL = appSupportURL.appendingPathComponent("YianaOCR", isDirectory: true)
            if fileManager.fileExists(atPath: ocrSupportURL.path) {
                do {
                    try fileManager.removeItem(at: ocrSupportURL)
                    deletedItems.append("Application Support/YianaOCR")
                } catch {
                    errors.append("Application Support/YianaOCR: \(error.localizedDescription)")
                }
            }
        }
        
        // 5. Delete any caches
        if let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let yianaCacheURL = cacheURL.appendingPathComponent("com.vitygas.Yiana")
            if fileManager.fileExists(atPath: yianaCacheURL.path) {
                do {
                    try fileManager.removeItem(at: yianaCacheURL)
                    deletedItems.append("Cache")
                } catch {
                    errors.append("Cache: \(error.localizedDescription)")
                }
            }
        }
        
        // 6. Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            deletedItems.append("UserDefaults")
        }
        
        // 7. Reset any in-memory state (if app is running)
        NotificationCenter.default.post(name: .developmentDataNuked, object: nil)
        
        // Report results
        var message = "🔥 NUKE COMPLETE 🔥\n\n"
        
        if !deletedItems.isEmpty {
            message += "✅ Deleted:\n"
            for item in deletedItems {
                message += "  • \(item)\n"
            }
        }
        
        if !errors.isEmpty {
            message += "\n⚠️ Errors:\n"
            for error in errors {
                message += "  • \(error)\n"
            }
        }
        
        message += "\n⚠️ Restart the app for a clean state"
        
        print(message)
        
        if errors.isEmpty {
            completion(.success(message))
        } else {
            completion(.failure(NukeError.partialFailure(message)))
        }
    }
    
    enum NukeError: LocalizedError {
        case notDebugBuild
        case incorrectSafetyKey
        case notDoubleChecked
        case notDevelopmentBuild
        case partialFailure(String)
        
        var errorDescription: String? {
            switch self {
            case .notDebugBuild:
                return "Nuke is only available in DEBUG builds"
            case .incorrectSafetyKey:
                return "Safety confirmation key does not match. Must be: \(SAFETY_KEY)"
            case .notDoubleChecked:
                return "Double check confirmation not provided"
            case .notDevelopmentBuild:
                return "Nuke is only available in development builds"
            case .partialFailure(let message):
                return message
            }
        }
    }
}

extension Notification.Name {
    static let developmentDataNuked = Notification.Name("developmentDataNuked")
}

// MARK: - SwiftUI View for Testing

/// Development menu item for nuking data
struct DevelopmentNukeView: View {
    @State private var showingConfirmation = false
    @State private var showingFinalConfirmation = false
    @State private var confirmationText = ""
    @State private var resultMessage = ""
    @State private var showingResult = false
    
    var body: some View {
        #if DEBUG
        Button(action: {
            showingConfirmation = true
        }) {
            Label("🔥 NUKE ALL DATA 🔥", systemImage: "trash.fill")
                .foregroundColor(.red)
        }
        .alert("⚠️ EXTREME DANGER ⚠️", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("I Understand", role: .destructive) {
                showingFinalConfirmation = true
            }
        } message: {
            Text("""
            This will PERMANENTLY DELETE:
            • All documents
            • All OCR data
            • All settings
            • All caches
            
            This action CANNOT be undone!
            
            Are you absolutely sure?
            """)
        }
        .alert("Final Confirmation", isPresented: $showingFinalConfirmation) {
            TextField("Type: YES!DELETE🔥EVERYTHING💀I_AM_SURE!", text: $confirmationText)
            Button("Cancel", role: .cancel) {
                confirmationText = ""
            }
            Button("DELETE EVERYTHING", role: .destructive) {
                performNuke()
            }
        } message: {
            Text("Type exactly: YES!DELETE🔥EVERYTHING💀I_AM_SURE!")
        }
        .alert("Nuke Result", isPresented: $showingResult) {
            Button("OK") {
                confirmationText = ""
            }
        } message: {
            Text(resultMessage)
        }
        #else
        EmptyView()
        #endif
    }
    
    #if DEBUG
    private func performNuke() {
        DevelopmentNuke.nukeAllData(
            safetyConfirmation: confirmationText,
            doubleCheck: true
        ) { result in
            switch result {
            case .success(let message):
                resultMessage = message
            case .failure(let error):
                resultMessage = "Failed: \(error.localizedDescription)"
            }
            showingResult = true
        }
    }
    #endif
}

#endif // DEBUG only
