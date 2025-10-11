//
//  DocumentStatusView.swift
//  Yiana
//
//  UI components for showing document download status
//

import SwiftUI

/// Shows download status for a document
struct DocumentDownloadBadge: View {
    let status: DocumentAvailability
    
    var body: some View {
        switch status {
        case .available:
            EmptyView()
            
        case .downloading:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Downloading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .notDownloaded:
            HStack(spacing: 4) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.caption)
                Text("Not Downloaded")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
        case .error(let error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                Text("Error")
                    .font(.caption)
            }
            .foregroundColor(.red)
            .help(error.localizedDescription)
        }
    }
}

/// Document row with download handling
struct DocumentRowView: View {
    let url: URL
    let status: DocumentAvailability
    let onTap: () -> Void
    
    @State private var isDownloading = false
    
    var body: some View {
        Button(action: handleTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.headline)
                    
                    DocumentDownloadBadge(status: status)
                }
                
                Spacer()
                
                if case .notDownloaded = status {
                    Button(action: downloadDocument) {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .opacity(isDownloading ? 0.6 : 1.0)
        }
        .disabled(isDownloading)
    }
    
    private func handleTap() {
        switch status {
        case .available:
            onTap()
            
        case .notDownloaded:
            downloadDocument()
            
        case .downloading:
            // Already downloading, just wait
            break
            
        case .error:
            // Show error alert
            break
        }
    }
    
    private func downloadDocument() {
        isDownloading = true
        
        let repo = DocumentRepository()
        repo.ensureDocumentDownloaded(url) { success in
            DispatchQueue.main.async {
                isDownloading = false
                if success {
                    onTap()
                }
            }
        }
    }
}

/// Example usage in a List
struct DocumentListExampleView: View {
    @StateObject private var repository = DocumentRepository()
    
    var body: some View {
        List {
            ForEach(repository.documentsWithStatus, id: \.url) { item in
                DocumentRowView(
                    url: item.url,
                    status: item.status,
                    onTap: {
                        openDocument(at: item.url)
                    }
                )
            }
        }
        .onAppear {
            // Repository automatically starts monitoring if using iCloud
        }
    }
    
    private func openDocument(at url: URL) {
        // Your document opening logic here
        print("Opening document: \(url)")
    }
}

// MARK: - Settings View for Download Preferences

struct iCloudSettingsView: View {
    @AppStorage("keepAllDocumentsLocal") private var keepAllLocal: Bool = false
    @AppStorage("keepRecentDays") private var keepRecentDays: Int = 7
    @AppStorage("autoDownloadOnWiFi") private var autoDownloadOnWiFi: Bool = true
    @AppStorage("showDownloadBadges") private var showDownloadBadges: Bool = true
    
    var body: some View {
        Form {
            Section("iCloud Storage") {
                Toggle("Keep All Documents Downloaded", isOn: $keepAllLocal)
                    .help("Prevents iCloud from removing documents to save space")
                
                if !keepAllLocal {
                    Picker("Keep Recent Documents", selection: $keepRecentDays) {
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("Forever").tag(Int.max)
                    }
                    .help("Documents accessed within this period will stay downloaded")
                }
            }
            
            Section("Download Behavior") {
                Toggle("Auto-download on Wi-Fi", isOn: $autoDownloadOnWiFi)
                    .help("Automatically download documents when on Wi-Fi")
                
                Toggle("Show Download Status Badges", isOn: $showDownloadBadges)
            }
            
            Section("About iCloud Sync") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your documents are stored in iCloud Drive.")
                        .font(.subheadline)
                    
                    Text("To save space, iOS may remove local copies of documents. They can be re-downloaded anytime.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("iCloud Settings")
    }
}

#Preview("Download Badge") {
    VStack(spacing: 20) {
        DocumentDownloadBadge(status: .available)
        DocumentDownloadBadge(status: .downloading)
        DocumentDownloadBadge(status: .notDownloaded)
        DocumentDownloadBadge(status: .error(NSError(domain: "test", code: 1)))
    }
    .padding()
}
