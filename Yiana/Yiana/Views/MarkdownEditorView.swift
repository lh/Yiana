//
//  MarkdownEditorView.swift
//  Yiana
//
//  SwiftUI view for editing markdown text that will be rendered to PDF
//

import SwiftUI

struct MarkdownEditorView: View {
    @Binding var isPresented: Bool
    @Binding var draftText: String
    let documentURL: URL
    let onSave: (String) -> Void

    @State private var localText: String = ""
    @State private var showPreview = false
    @State private var lastSaveTime = Date()
    @FocusState private var isTextEditorFocused: Bool

    private let sidecarManager = SidecarManager.shared
    private let autosaveInterval: TimeInterval = 30

    init(isPresented: Binding<Bool>, draftText: Binding<String>, documentURL: URL, onSave: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self._draftText = draftText
        self.documentURL = documentURL
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showPreview {
                    previewContent
                } else {
                    editorContent
                }
            }
            .navigationTitle("Add Text Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        handleDone()
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    formattingToolbar
                }
            }
        }
        .onAppear {
            localText = draftText
            isTextEditorFocused = true
            loadDraftIfExists()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            saveDraft()
        }
        .onReceive(Timer.publish(every: autosaveInterval, on: .main, in: .common).autoconnect()) { _ in
            if Date().timeIntervalSince(lastSaveTime) > autosaveInterval {
                saveDraft()
            }
        }
    }

    // MARK: - Editor View

    @ViewBuilder
    private var editorContent: some View {
        VStack(spacing: 0) {
            // Toggle between edit and preview
            Picker("View Mode", selection: $showPreview) {
                Text("Edit").tag(false)
                Text("Preview").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Divider()

            // Text editor
            TextEditor(text: $localText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .focused($isTextEditorFocused)
                .onChange(of: localText) { oldValue, newValue in
                    draftText = newValue
                }
        }
    }

    // MARK: - Preview View

    @ViewBuilder
    private var previewContent: some View {
        VStack(spacing: 0) {
            // Toggle between edit and preview
            Picker("View Mode", selection: $showPreview) {
                Text("Edit").tag(false)
                Text("Preview").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Divider()

            ScrollView {
                MarkdownPreviewView(markdown: localText)
                    .padding()
            }
        }
    }

    // MARK: - Formatting Toolbar

    @ViewBuilder
    private var formattingToolbar: some View {
        HStack {
            Button(action: { insertMarkdown("**", "**") }) {
                Image(systemName: "bold")
            }

            Button(action: { insertMarkdown("*", "*") }) {
                Image(systemName: "italic")
            }

            Divider()

            Button(action: { insertMarkdown("# ", "") }) {
                Text("H1")
                    .font(.system(size: 14, weight: .bold))
            }

            Button(action: { insertMarkdown("## ", "") }) {
                Text("H2")
                    .font(.system(size: 14, weight: .bold))
            }

            Button(action: { insertMarkdown("### ", "") }) {
                Text("H3")
                    .font(.system(size: 14, weight: .bold))
            }

            Divider()

            Button(action: { insertMarkdown("- ", "") }) {
                Image(systemName: "list.bullet")
            }

            Button(action: { insertMarkdown("> ", "") }) {
                Image(systemName: "quote.opening")
            }

            Spacer()

            // Help button
            Button(action: { showMarkdownHelp() }) {
                Image(systemName: "questionmark.circle")
            }
        }
    }

    // MARK: - Actions

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        // For simplicity, just append at cursor position
        // In a production app, you'd want to handle text selection properly
        localText += prefix + (suffix.isEmpty ? "" : "text" + suffix)
    }

    private func handleCancel() {
        // Save draft before canceling
        saveDraft()
        isPresented = false
    }

    private func handleDone() {
        // Save and render
        onSave(localText)
        // Clear draft after successful save
        try? sidecarManager.deleteDraft(for: documentURL)
        isPresented = false
    }

    private func saveDraft() {
        do {
            try sidecarManager.saveDraft(localText, for: documentURL)
            let metadata = DraftMetadata(lastModified: Date())
            try sidecarManager.saveDraftMetadata(metadata, for: documentURL)
            lastSaveTime = Date()
        } catch {
            print("Failed to save draft: \(error)")
        }
    }

    private func loadDraftIfExists() {
        if let existingDraft = sidecarManager.loadDraft(for: documentURL) {
            localText = existingDraft
            draftText = existingDraft
        }
    }

    private func showMarkdownHelp() {
        // In a real app, show a help sheet explaining markdown syntax
        // For now, we'll just print to console
        print("Markdown Help: Use **text** for bold, *text* for italic, # for headers, - for lists, > for quotes")
    }
}

// MARK: - Markdown Preview View

struct MarkdownPreviewView: View {
    let markdown: String
    private let renderer = MarkdownToPDFService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(markdown.components(separatedBy: .newlines), id: \.self) { line in
                renderLine(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("# ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.title)
                .fontWeight(.bold)
        } else if trimmed.hasPrefix("## ") {
            Text(String(trimmed.dropFirst(3)))
                .font(.title2)
                .fontWeight(.bold)
        } else if trimmed.hasPrefix("### ") {
            Text(String(trimmed.dropFirst(4)))
                .font(.title3)
                .fontWeight(.bold)
        } else if trimmed.hasPrefix("> ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.body)
                .foregroundColor(.gray)
                .padding(.leading, 20)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .top) {
                Text("•")
                Text(String(trimmed.dropFirst(2)))
            }
            .padding(.leading, 20)
        } else if trimmed == "---" || trimmed == "***" {
            Divider()
        } else if !trimmed.isEmpty {
            Text(renderInlineMarkdown(trimmed))
        }
    }

    private func renderInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // For now, just return the text as-is without inline formatting
        // This is a simplified version that doesn't process bold/italic
        // TODO: Implement proper regex-based markdown parsing

        return result
    }
}