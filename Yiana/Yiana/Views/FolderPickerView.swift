//
//  FolderPickerView.swift
//  Yiana
//
//  "Move to..." sheet for selecting a destination folder.

import SwiftUI

struct FolderPickerView: View {
    let currentFolderPath: String
    let folders: [(name: String, path: String)]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(folders.enumerated()), id: \.offset) { _, folder in
                    let isCurrentFolder = folder.path == currentFolderPath
                    let depth = folder.path.isEmpty ? 0 : folder.path.components(separatedBy: "/").count
                    Button {
                        onSelect(folder.path)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: folder.path.isEmpty ? "folder.fill" : "folder")
                                .foregroundColor(.accentColor)
                            Text(folder.name)
                                .foregroundColor(isCurrentFolder ? .secondary : .primary)
                            Spacer()
                            if isCurrentFolder {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, CGFloat(depth) * 16)
                    }
                    .disabled(isCurrentFolder)
                }
            }
            .navigationTitle("Move to...")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 350, minHeight: 400)
        #endif
    }
}
