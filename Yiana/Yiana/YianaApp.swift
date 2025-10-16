//
//  YianaApp.swift
//  Yiana
//
//  Created by Luke Herbert on 15/07/2025.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct YianaApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var importHandler = DocumentImportHandler()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(importHandler)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .task {
                    await MainActor.run {
                        UbiquityMonitor.shared.start()
                    }
                }
                #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name.yianaOpenURL)) { notification in
                    if let url = notification.object as? URL {
                        handleIncomingURL(url)
                    }
                }
                #endif
        }
        #if os(iOS)
        .handlesExternalEvents(matching: ["*"])
        #endif
        #if os(macOS)
        .commands {
            // Page operations commands
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy Pages") {
                    NotificationCenter.default.post(name: .copyPages, object: nil)
                }
                .keyboardShortcut("C", modifiers: [.option, .command])

                Button("Cut Pages") {
                    NotificationCenter.default.post(name: .cutPages, object: nil)
                }
                .keyboardShortcut("X", modifiers: [.option, .command])

                Button("Paste Pages") {
                    NotificationCenter.default.post(name: .pastePages, object: nil)
                }
                .keyboardShortcut("V", modifiers: [.option, .command])
                .disabled(!PageClipboard.shared.hasPayload)
            }

            #if DEBUG
            CommandMenu("Debug") {
                Button("Create Test Document with OCR") {
                    TestDataHelper.createTestDocumentWithOCR()
                }
                .keyboardShortcut("T", modifiers: [.command, .shift])

                Button("Create Test Document without OCR") {
                    TestDataHelper.createTestDocumentWithoutOCR()
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])
            }
            #endif
        }
        #endif
    }

    private func handleIncomingURL(_ url: URL) {
        print("DEBUG: Received URL: \(url)")

        // Check if it's a PDF
        if url.pathExtension.lowercased() == "pdf" {
            importHandler.importPDF(from: url)
        }
        // Check if it's our custom document type
        else if url.pathExtension == "yianazip" {
            // Handle opening existing Yiana documents
            importHandler.openDocument(at: url)
        }
    }
}

// Document import handler
class DocumentImportHandler: ObservableObject {
    @Published var showingImportDialog = false
    @Published var pdfToImport: URL?
    @Published var documentToOpen: URL?

    func importPDF(from url: URL) {
        // Copy to temporary location if needed
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                // Read the PDF data
                let pdfData = try Data(contentsOf: url)

                // Save to temporary location
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("pdf")

                try pdfData.write(to: tempURL)

                DispatchQueue.main.async {
                    self.pdfToImport = tempURL
                    self.showingImportDialog = true
                }
            } catch {
                print("Error importing PDF: \(error)")
            }
        } else {
            // Direct access
            DispatchQueue.main.async {
                self.pdfToImport = url
                self.showingImportDialog = true
            }
        }
    }

    func openDocument(at url: URL) {
        DispatchQueue.main.async {
            self.documentToOpen = url
        }
    }
}
