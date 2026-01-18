//
//  SettingsView.swift
//  Yiana
//
//  Created by GPT-5 Codex on 10/08/2025.
//
//  Centralised settings sheet for app-wide configuration such as paper size.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var devMode = DevModeManager.shared
    @State private var selectedPaperSize: TextPagePaperSize = .a4
    @State private var selectedSidebarPosition: SidebarPosition = .right
    @State private var selectedThumbnailSize: SidebarThumbnailSize = .medium
    @State private var isLoading = true
    @State private var showingDevMenu = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Paper"), footer: paperFooter) {
                    Picker("Paper Size", selection: $selectedPaperSize) {
                        ForEach(TextPagePaperSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.inline)
                    .disabled(isLoading)
                }

#if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Section(header: Text("Sidebar")) {
                        Picker("Position", selection: $selectedSidebarPosition) {
                            ForEach(SidebarPosition.allCases) { position in
                                Text(position.displayName).tag(position)
                            }
                        }
                        Picker("Thumbnail Size", selection: $selectedThumbnailSize) {
                            ForEach(SidebarThumbnailSize.allCases) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                    }
                }
#endif

                if AddressRepository.isDatabaseAvailable {
                    Section(header: Text("Address Types")) {
                        NavigationLink {
                            AddressTypeSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "person.3.fill")
                                Text("Manage Address Types")
                            }
                        }
                    }
                }

                // Developer Mode section (only visible when enabled)
                if devMode.isEnabled {
                    Section(header: Text("Developer")) {
                        Button {
                            showingDevMenu = true
                        } label: {
                            HStack {
                                Image(systemName: "hammer.fill")
                                Text("Developer Tools")
                            }
                        }

                        Button(role: .destructive) {
                            devMode.disable()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Disable Developer Mode")
                            }
                        }
                    }
                }

                // Version section with tap-to-unlock
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .devModeTapTarget()
                } footer: {
                    if devMode.isEnabled {
                        Text("Developer mode is enabled")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingDevMenu) {
                DeveloperMenuSheet()
            }
        }
        .task { await loadPreferences() }
        .onChange(of: selectedPaperSize) { _, newValue in
            Task { await TextPageLayoutSettings.shared.setPreferredPaperSize(newValue) }
        }
#if os(iOS)
        .onChange(of: selectedSidebarPosition) { _, newValue in
            Task { await TextPageLayoutSettings.shared.setPreferredSidebarPosition(newValue) }
        }
        .onChange(of: selectedThumbnailSize) { _, newValue in
            Task { await TextPageLayoutSettings.shared.setPreferredThumbnailSize(newValue) }
        }
#endif
    }

    private func loadPreferences() async {
        let size = await TextPageLayoutSettings.shared.preferredPaperSize()
#if os(iOS)
        let position = await TextPageLayoutSettings.shared.preferredSidebarPosition()
        let thumbnail = await TextPageLayoutSettings.shared.preferredThumbnailSize()
#endif
        await MainActor.run {
            selectedPaperSize = size
#if os(iOS)
            selectedSidebarPosition = position
            selectedThumbnailSize = thumbnail
#endif
            isLoading = false
        }
    }

    private var paperFooter: some View {
        Text("Applies to rendered text pages and newly scanned documents.")
            .font(.footnote)
            .foregroundColor(.secondary)
    }
}

// MARK: - Developer Menu Sheet (works in Release builds when dev mode enabled)

struct DeveloperMenuSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DeveloperToolsView()
                .navigationTitle("Developer Tools")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
