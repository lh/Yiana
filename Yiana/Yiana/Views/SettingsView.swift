//
//  SettingsView.swift
//  Yiana
//
//  Created by GPT-5 Codex on 10/08/2025.
//
//  Centralised settings sheet for app-wide configuration such as paper size.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPaperSize: TextPagePaperSize = .a4
    @State private var isLoading = true

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
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadPaperPreference() }
        .onChange(of: selectedPaperSize) { _, newValue in
            Task { await TextPageLayoutSettings.shared.setPreferredPaperSize(newValue) }
        }
    }

    private func loadPaperPreference() async {
        let size = await TextPageLayoutSettings.shared.preferredPaperSize()
        await MainActor.run {
            selectedPaperSize = size
            isLoading = false
        }
    }

    private var paperFooter: some View {
        Text("Applies to rendered text pages and newly scanned documents.")
            .font(.footnote)
            .foregroundColor(.secondary)
    }
}

