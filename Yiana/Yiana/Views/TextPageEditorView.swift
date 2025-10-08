//
//  TextPageEditorView.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  High-level SwiftUI wrapper that combines the native Markdown text editor
//  bridge, preview pane, and toolbar actions. The view adapts between compact
//  (single column with preview toggle) and regular/wide layouts where editor
//  and preview sit side-by-side.
//

import SwiftUI
#if os(iOS)
import PDFKit
#else
import AppKit
#endif

struct TextPageEditorView: View {
    @ObservedObject var viewModel: TextPageEditorViewModel
    @State private var pendingAction: TextPageEditorAction?
    @State private var isEditing = false
    @State private var selectedPaperSize: TextPagePaperSize = .a4

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    var body: some View {
        VStack(spacing: 0) {
            if let recoveredAt = viewModel.recoveredDraftTimestamp {
                recoveredBanner(date: recoveredAt)
            }

            editorToolbar

            Divider()

            contentStack

            Divider()

            statusBar
        }
        .background(surfaceBackground)
        .onAppear {
            adjustPreviewModeForCurrentLayout()
        }
        #if os(iOS)
        .onChange(of: horizontalSizeClass) {
            adjustPreviewModeForCurrentLayout()
        }
        #endif
        .task {
            await viewModel.loadDraftIfAvailable()
            let preferredPaper = await TextPageLayoutSettings.shared.preferredPaperSize()
            await MainActor.run {
                selectedPaperSize = preferredPaper
            }
        }
    }

    @ViewBuilder
    private var contentStack: some View {
        #if os(iOS)
        let useSplit = horizontalSizeClass == .regular && verticalSizeClass != .compact
        if useSplit {
            splitContent
        } else {
            singleColumnContent
        }
        #else
        splitContent
        #endif
    }

    private var splitContent: some View {
        HStack(spacing: 0) {
            editorPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            previewPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var singleColumnContent: some View {
        if viewModel.showPreview {
            previewPane
        } else {
            editorPane
        }
    }

    private var editorPane: some View {
        MarkdownTextEditor(
            text: $viewModel.content,
            cursorPosition: $viewModel.cursorPosition,
            pendingAction: $pendingAction,
            onEditingBegan: { isEditing = true },
            onEditingEnded: { isEditing = false }
        )
        .background(surfaceBackground)
    }

    private var previewPane: some View {
        Group {
            #if os(iOS)
            if let data = viewModel.latestRenderedPageData,
               let document = PDFDocument(data: data) {
                RenderedPagePreview(document: document)
            } else if let error = viewModel.liveRenderError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Rendering preview…")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
            #else
            MarkdownPreview(markdown: viewModel.content)
            #endif
        }
        .background(previewBackground)
    }

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                styleMenu

                headingMenu

                listMenu

                toolbarButton(systemName: "text.quote", label: "Quote") {
                    pendingAction = .blockquote
                }

                toolbarButton(systemName: "line.horizontal.3", label: "Divider") {
                    pendingAction = .horizontalRule
                }

                #if os(iOS)
                if horizontalSizeClass != .regular || verticalSizeClass == .compact {
                    Divider().frame(height: 16)
                    Button {
                        viewModel.showPreview.toggle()
                    } label: {
                        Label(viewModel.showPreview ? "Editor" : "Preview", systemImage: viewModel.showPreview ? "doc.text" : "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
                #endif

                Divider().frame(height: 16)
                paperSizeMenu
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(toolbarStripColor)
    }
    private var paperSizeMenu: some View {
        Menu {
            ForEach(TextPagePaperSize.allCases) { size in
                Button {
                    selectedPaperSize = size
                    Task {
                        await TextPageLayoutSettings.shared.setPreferredPaperSize(size)
                        viewModel.refreshRenderForPaperSizeChange()
                    }
                } label: {
                    if size == selectedPaperSize {
                        Label(size.displayName, systemImage: "checkmark")
                    } else {
                        Text(size.displayName)
                    }
                }
            }
        } label: {
            Label("Paper: \(selectedPaperSize.displayName)", systemImage: "doc.plaintext")
        }
        .accessibilityLabel("Paper size")
    }

    private var headingMenu: some View {
        Menu {
            Button("Heading 1") { pendingAction = .heading(level: 1) }
            Button("Heading 2") { pendingAction = .heading(level: 2) }
            Button("Heading 3") { pendingAction = .heading(level: 3) }
        } label: {
            menuLabel {
                Text("H1")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .accessibilityLabel("Heading level")
    }

    private var styleMenu: some View {
        Menu {
            Button("Bold") { pendingAction = .bold }
            Button("Italic") { pendingAction = .italic }
        } label: {
            menuLabel {
                Text("T")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                +
                Text("t")
                    .font(.system(size: 15))
                    .italic()
                    .foregroundColor(.primary)
            }
        }
        .accessibilityLabel("Text style")
    }

    private var listMenu: some View {
        Menu {
            Button("Bulleted list") { pendingAction = .unorderedList }
            Button("Numbered list") { pendingAction = .orderedList }
        } label: {
            menuLabel {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 15, weight: .medium))
            }
        }
        .accessibilityLabel("List style")
    }

    private func toolbarButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemName)
                .labelStyle(.iconOnly)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private func menuLabel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }

    private func recoveredBanner(date: Date) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
            Text("Recovered draft from \(relativeDateFormatter.localizedString(for: date, relativeTo: Date()))")
                .font(.footnote)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(bannerBackground)
    }

    private var statusBar: some View {
        HStack {
            if case .failed(let error) = viewModel.state {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.footnote)
            } else if let savedAt = viewModel.lastSavedAt {
                Label("Saved \(relativeDateFormatter.localizedString(for: savedAt, relativeTo: Date()))", systemImage: "checkmark.circle")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            } else {
                Label(isEditing ? "Editing" : "Ready", systemImage: isEditing ? "pencil" : "doc")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func adjustPreviewModeForCurrentLayout() {
        #if os(iOS)
        if horizontalSizeClass == .regular && verticalSizeClass != .compact {
            viewModel.showPreview = true
        }
        #else
        viewModel.showPreview = true
        #endif
    }
}

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter
}()

private var surfaceBackground: Color {
#if os(iOS)
    Color(.systemBackground)
#else
    Color(nsColor: .windowBackgroundColor)
#endif
}

private var previewBackground: Color {
#if os(iOS)
    Color(.secondarySystemBackground)
#else
    Color(nsColor: .underPageBackgroundColor)
#endif
}

private var toolbarStripColor: Color {
#if os(iOS)
    Color(.tertiarySystemBackground)
#else
    Color(nsColor: .controlBackgroundColor)
#endif
}

private var bannerBackground: Color {
#if os(iOS)
    Color(.systemYellow).opacity(0.2)
#else
    Color(nsColor: .systemYellow).opacity(0.2)
#endif
}

private struct MarkdownPreview: View {
    var markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let attributed = TextPageMarkdownFormatter.makePreviewAttributedString(from: markdown)
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
    }
}

#if os(iOS)
private struct RenderedPagePreview: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
        uiView.autoScales = true
    }
}
#endif
