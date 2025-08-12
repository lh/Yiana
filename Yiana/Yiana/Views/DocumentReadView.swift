//
//  DocumentReadView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit

#if os(macOS)
struct DocumentReadView: View {
    let documentURL: URL
    @State private var pdfData: Data?
    @State private var documentTitle: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingPageManagement = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Unable to load document")
                        .font(.title2)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pdfData = pdfData {
                VStack(spacing: 0) {
                    // Title bar
                    HStack {
                        Text(documentTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding()
                        Spacer()
                        
                        // Page management button
                        if pdfData.count > 0 {
                            Button(action: {
                                showingPageManagement = true
                            }) {
                                Label("Manage Pages", systemImage: "rectangle.stack")
                            }
                            .buttonStyle(.borderless)
                            .padding(.trailing)
                        }
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    // PDF content
                    PDFViewer(pdfData: pdfData)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No content available")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("This document was created on iOS")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(documentURL.deletingPathExtension().lastPathComponent)
        .task {
            await loadDocument()
        }
        .sheet(isPresented: $showingPageManagement) {
            PageManagementView(
                pdfData: $pdfData,
                isPresented: $showingPageManagement,
                currentPageIndex: 0  // macOS version doesn't track current page yet
            )
        }
    }
    
    private func loadDocument() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Read the document data directly
            let data = try Data(contentsOf: documentURL)
            
            // Try to decode as a simple yianazip format
            // For now, we'll just check if it's PDF data directly
            if isPDFData(data) {
                // It's a raw PDF (shouldn't happen with our format)
                pdfData = data
                documentTitle = documentURL.deletingPathExtension().lastPathComponent
            } else if data.isEmpty {
                // Empty file (created on macOS)
                pdfData = nil
                documentTitle = documentURL.deletingPathExtension().lastPathComponent
            } else {
                // Try to parse as our document format
                // For now, we'll assume it's our custom format with metadata
                if let document = try? extractDocumentData(from: data) {
                    pdfData = document.pdfData
                    documentTitle = document.title
                } else {
                    throw YianaError.invalidFormat
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func isPDFData(_ data: Data) -> Bool {
        // Check for PDF magic number
        let pdfHeader = "%PDF"
        if let string = String(data: data.prefix(4), encoding: .ascii) {
            return string == pdfHeader
        }
        return false
    }
    
    private func extractDocumentData(from data: Data) throws -> (title: String, pdfData: Data?) {
        // Parse the NoteDocument format: metadata + separator + PDF data
        let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
        
        guard let separatorRange = data.range(of: separator) else {
            throw YianaError.invalidFormat
        }
        
        // Extract metadata JSON
        let metadataData = data[..<separatorRange.lowerBound]
        let pdfDataStart = separatorRange.upperBound
        
        // Decode metadata
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(DocumentMetadata.self, from: metadataData)
        
        // Extract PDF data (if any)
        let pdfData = pdfDataStart < data.count ? data[pdfDataStart...] : nil
        
        return (
            title: metadata.title,
            pdfData: pdfData?.isEmpty == false ? Data(pdfData!) : nil
        )
    }
}

enum YianaError: LocalizedError {
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "This document format is not supported"
        }
    }
}
#endif