//
//  DevelopmentMenu.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//
//  Development tools menu - DEBUG builds only
//

import SwiftUI

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
                // Just delete OCR cache, less destructive than nuke
                deleteOCRCache()
            }) {
                Label("Clear OCR Cache Only", systemImage: "xmark.circle")
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
}
#endif