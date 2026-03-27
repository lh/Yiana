//
//  DocumentReadView+Components.swift
//  Yiana
//
//  Component views for DocumentReadView
//

import SwiftUI
import PDFKit

#if os(macOS)
extension DocumentReadView {
    /// Displays a banner when the document is in read-only mode
    struct ReadOnlyBanner: View {
        let isReadOnly: Bool

        var body: some View {
            if isReadOnly {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("This document is read-only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("This document is read-only")
            }
        }
    }

    /// Document toolbar with title and action buttons
    struct DocumentReadToolbar: View {
        let title: String
        let isReadOnly: Bool
        let hasPDFContent: Bool
        let isInfoVisible: Bool
        let onManagePages: () -> Void
        let onExport: () -> Void
        let onToggleInfo: () -> Void

        var body: some View {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding()
                Spacer()

                // Control buttons
                HStack(spacing: 12) {
                    // Page management button
                    if hasPDFContent {
                        Button(action: onManagePages) {
                            Label("Manage Pages", systemImage: "rectangle.stack")
                        }
                        .buttonStyle(.borderless)
                        .help("Manage pages (copy, cut, paste, reorder)")
                        .toolbarActionAccessibility(label: "Manage pages")
                    }

                    // Export button
                    Button(action: onExport) {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Export as PDF")
                    .toolbarActionAccessibility(label: "Export PDF")

                    // Info panel toggle
                    Button(action: onToggleInfo) {
                        Label("Info", systemImage: isInfoVisible ? "info.circle.fill" : "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Toggle document info panel")
                    .toolbarActionAccessibility(
                        label: isInfoVisible ? "Hide document info" : "Show document info"
                    )
                }
                .padding(.trailing)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    /// Main content area displaying PDF or status messages
    struct DocumentReadContent: View {
        let isLoading: Bool
        let errorMessage: String?
        let showSlowLoadPrompt: Bool
        let pdfData: Data?
        let viewModel: DocumentViewModel?
        @Binding var currentPage: Int
        @Binding var navigateToPage: Int?
        @Binding var pdfDocument: PDFDocument?
        let sidebarRefreshID: UUID
        let onRequestPageManagement: () -> Void
        var onRetry: () -> Void = {}
        var onKeepWaiting: () -> Void = {}
        var onDismiss: () -> Void = {}

        var body: some View {
            ZStack {
                if isLoading && showSlowLoadPrompt {
                    slowLoadPromptView
                } else if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error: error)
                } else if pdfData != nil {
                    pdfContentView
                } else if viewModel != nil {
                    emptyDocumentView
                } else {
                    downloadingView
                }
            }
        }

        private var loadingView: some View {
            ProgressView("Loading document...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private var slowLoadPromptView: some View {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.4)
                Text("Taking longer than expected")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("The document may still be downloading from iCloud.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                HStack(spacing: 16) {
                    Button("Keep Waiting") { onKeepWaiting() }
                    Button("Go Back") { onDismiss() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func errorView(error: String) -> some View {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text("Unable to load document")
                    .font(.title2)
                Text(error)
                    .foregroundColor(.secondary)
                HStack(spacing: 16) {
                    Button("Try Again") { onRetry() }
                    Button("Go Back") { onDismiss() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private var emptyDocumentView: some View {
            VStack(spacing: 16) {
                Image(systemName: "doc")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Empty Document")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("This document has no pages yet. Import or scan pages to add content.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private var downloadingView: some View {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.4)
                Text("Document not downloaded yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(
                    "This document is still downloading from iCloud. " +
                    "It will open automatically once the download finishes."
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        @ViewBuilder
        private var pdfContentView: some View {
            if let viewModel = viewModel, let pdfData = pdfData {
                MacPDFViewer(
                    viewModel: viewModel,
                    legacyPDFData: pdfData,
                    currentPage: $currentPage,
                    navigateToPage: $navigateToPage,
                    pdfDocument: $pdfDocument,
                    refreshTrigger: sidebarRefreshID
                )
            } else if let pdfData = pdfData {
                MacPDFViewer(
                    viewModel: DocumentViewModel(pdfData: pdfData),
                    legacyPDFData: pdfData,
                    currentPage: $currentPage,
                    navigateToPage: $navigateToPage,
                    pdfDocument: $pdfDocument,
                    refreshTrigger: sidebarRefreshID
                )
            }
        }
    }
}
#endif
