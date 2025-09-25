//
//  DocumentEditView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit

#if os(iOS)
enum ActiveSheet: Identifiable {
    case share(URL)
    case pageManagement

    var id: String {
        switch self {
        case .share: return "share"
        case .pageManagement: return "pageManagement"
        }
    }
}

struct DocumentEditView: View {
    let documentURL: URL
    @State private var document: NoteDocument?
    @State private var viewModel: DocumentViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveError = false
    @State private var isLoading = true
    @FocusState private var titleFieldFocused: Bool
    @State private var showingScanner = false
    @State private var isProcessingScans = false
    @State private var scanColorMode: ScanColorMode = .color
    @State private var showTitleField = false
    @State private var navigateToPage: Int? = nil
    @State private var currentViewedPage: Int = 0
    @State private var exportedPDFURL: URL?
    @State private var activeSheet: ActiveSheet?
    @State private var showingMarkupError = false
    @State private var markupErrorMessage = ""
    
    private let scanningService = ScanningService()
    private let exportService = ExportService()
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let viewModel = viewModel {
                documentContent(viewModel: viewModel)
            } else {
                Text("Failed to load document")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(viewModel?.errorMessage ?? "Failed to save document")
        }
        .task {
            await loadDocument()
        }
        .documentScanner(isPresented: $showingScanner) { scannedImages in
            handleScannedImages(scannedImages)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .share(let url):
                ShareSheet(items: [url])
                    .onDisappear {
                        // Clean up temporary file
                        try? FileManager.default.removeItem(at: url)
                        exportedPDFURL = nil
                        activeSheet = nil
                    }
            case .pageManagement:
                if let viewModel = viewModel {
                        PageManagementView(
                        pdfData: Binding(
                            get: { viewModel.pdfData },
                            set: {
                                viewModel.pdfData = $0
                                viewModel.hasChanges = true
                            }
                        ),
                        isPresented: .constant(true),
                        currentPageIndex: currentViewedPage,
                        onPageSelected: { pageIndex in
                            navigateToPage = pageIndex
                            activeSheet = nil
                        }
                    )
                }
            }
        }
        .alert("Markup Error", isPresented: $showingMarkupError) {
            Button("OK") { }
        } message: {
            Text(markupErrorMessage)
        }
    }
    
    @ViewBuilder
    private func documentContent(viewModel: DocumentViewModel) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Spacer for collapsible title area
                Color.clear.frame(height: showTitleField ? 60 : 44)
            
            // PDF content area with scan button
            if isProcessingScans {
                VStack {
                    ProgressView("Processing scanned documents...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                    Text("Please wait...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            } else if let pdfData = viewModel.pdfData {
                PDFViewer(pdfData: pdfData, navigateToPage: $navigateToPage, currentPage: $currentViewedPage)
                    .overlay(alignment: .bottomTrailing) {
                        // Page management button
                        if pdfData.count > 0 {
                            Button(action: {
                                activeSheet = .pageManagement
                            }) {
                                Label("Pages", systemImage: "rectangle.stack")
                                    .font(.title3)
                                    .padding(12)
                                    .background(Color.secondary.opacity(0.8))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding()
                        }
                    }
                    .overlay(alignment: .bottom) {
                        scanButtonBar
                    }
            } else {
                ContentPlaceholderView()
                    .overlay(alignment: .bottom) {
                        scanButtonBar
                    }
            }
            }
            
            // Overlay title field at top
            VStack {
                if showTitleField {
                    HStack {
                        TextField("Document Title", text: Binding(
                            get: { viewModel.title },
                            set: { viewModel.title = $0 }
                        ), onCommit: {
                            showTitleField = false
                            Task {
                                _ = await viewModel.save()
                            }
                        })
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)
                        
                        Button("Done") {
                            showTitleField = false
                            titleFieldFocused = false
                            Task {
                                _ = await viewModel.save()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .shadow(radius: 2)
                } else {
                    // Minimal title display with back button
                    HStack(spacing: 0) {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 16)  // More space between button and title
                        
                        Text(viewModel.title.isEmpty ? "Untitled" : viewModel.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showTitleField = true
                                titleFieldFocused = true
                            }
                        
                        Spacer()
                        
                        // Markup button
                        if viewModel.pdfData != nil {
                            Button(action: {
                                presentMarkup()
                            }) {
                                Image(systemName: "pencil.tip.crop.circle")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .padding(.trailing, 4)
                        }
                        
                        // Export button
                        if viewModel.pdfData != nil {
                            Button(action: {
                                exportPDF()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 0)
                    .background(Color(.systemBackground).opacity(0.95))
                }
                Spacer()
            }
        }
    }
    
    private var scanButtonBar: some View {
        HStack(spacing: 40) {
            // Color scan button - "Scan"
            Button(action: {
                if scanningService.isScanningAvailable() {
                    scanColorMode = .color
                    showingScanner = true
                }
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.3), .yellow.opacity(0.3), .green.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Text("Scan")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .disabled(!scanningService.isScanningAvailable())
            
            // B&W document scan button - "Doc"
            Button(action: {
                if scanningService.isScanningAvailable() {
                    scanColorMode = .blackAndWhite
                    showingScanner = true
                }
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Text("Doc")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .disabled(!scanningService.isScanningAvailable())
        }
        .padding(.bottom, 20)
    }
    
    private func loadDocument() async {
        let loadedDocument = NoteDocument(fileURL: documentURL)
        
        await withCheckedContinuation { continuation in
            loadedDocument.open { success in
                Task { @MainActor in
                    if success {
                        self.document = loadedDocument
                        self.viewModel = DocumentViewModel(document: loadedDocument)
                    }
                    self.isLoading = false
                    continuation.resume()
                }
            }
        }
    }
    

    
    private func handleScannedImages(_ images: [UIImage]) {
        Task {
            isProcessingScans = true
            
            // Convert images to PDF with selected color mode
            if let newPDFData = await scanningService.convertImagesToPDF(images, colorMode: scanColorMode),
               let viewModel = viewModel {
                
                // If document already has PDF data, append pages
                if let existingPDFData = viewModel.pdfData,
                   let existingPDF = PDFDocument(data: existingPDFData),
                   let newPDF = PDFDocument(data: newPDFData) {
                    
                    // Append all pages from new PDF to existing PDF
                    for pageIndex in 0..<newPDF.pageCount {
                        if let page = newPDF.page(at: pageIndex) {
                            existingPDF.insert(page, at: existingPDF.pageCount)
                        }
                    }
                    
                    // Update with combined PDF
                    viewModel.pdfData = existingPDF.dataRepresentation()
                } else {
                    // No existing PDF, just use the new one
                    viewModel.pdfData = newPDFData
                }
                
                viewModel.hasChanges = true
                
                // Save the document
                _ = await viewModel.save()
            }
            
            isProcessingScans = false
        }
    }
    
    private func presentMarkup() {
        guard let viewModel = viewModel, let pdfData = viewModel.pdfData else {
            print("DEBUG Markup: No PDF data to mark up")
            return
        }
        
        print("DEBUG Markup: Using PencilKit implementation for page \(currentViewedPage + 1)")
        let markupVC = PencilKitMarkupViewController(
            pdfData: pdfData,
            pageIndex: currentViewedPage
        ) { result in
            Task { @MainActor in
                await handleMarkupResult(result)
            }
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(markupVC, animated: true)
        }
    }
    
    
    private func handleMarkupResult(_ result: Result<Data, Error>) async {
        switch result {
        case .success(let markedPDFData):
            print("DEBUG Markup: Received marked PDF with \(markedPDFData.count) bytes")
            
            // Update the document with marked-up PDF
            if let viewModel = viewModel {
                // TODO: Create backup before first markup
                // TODO: Implement atomic save
                
                // Update PDF data
                viewModel.pdfData = markedPDFData
                viewModel.hasChanges = true
                
                // Re-extract text for search
                if let pdfDocument = PDFDocument(data: markedPDFData) {
                    let extractedText = pdfDocument.string ?? ""
                    print("DEBUG Markup: Extracted \(extractedText.count) characters of text")
                    // TODO: Update metadata with extracted text
                }
                
                // Save the document
                let saved = await viewModel.save()
                if saved {
                    print("DEBUG Markup: Document saved successfully")
                } else {
                    markupErrorMessage = "Failed to save marked-up document"
                    showingMarkupError = true
                }
            }
        case .failure(let error):
            print("DEBUG Markup: Failed - \(error)")
            markupErrorMessage = error.localizedDescription
            showingMarkupError = true
        }
    }
    
    private func exportPDF() {
        guard let viewModel = viewModel, let pdfData = viewModel.pdfData else {
            print("DEBUG Export: No PDF data to export")
            return
        }
        
        print("DEBUG Export: PDF data size: \(pdfData.count) bytes")
        
        // Create a temporary file with the PDF data
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(viewModel.title.isEmpty ? "Document" : viewModel.title).pdf"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        print("DEBUG Export: Creating temp file at: \(tempURL.path)")
        
        do {
            try pdfData.write(to: tempURL)
            print("DEBUG Export: Successfully wrote PDF to temp file")
            
            // Verify file exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                print("DEBUG Export: File exists, size: \(try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] ?? 0)")
                exportedPDFURL = tempURL
                activeSheet = .share(tempURL)
            } else {
                print("DEBUG Export: ERROR - File doesn't exist after writing!")
            }
        } catch {
            print("DEBUG Export: Failed to write PDF - \(error)")
        }
    }
}

// ShareSheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("DEBUG ShareSheet: Creating with \(items.count) items")
        for (index, item) in items.enumerated() {
            print("DEBUG ShareSheet: Item \(index): \(type(of: item)) - \(item)")
            if let url = item as? URL {
                print("DEBUG ShareSheet: URL path: \(url.path)")
                print("DEBUG ShareSheet: File exists: \(FileManager.default.fileExists(atPath: url.path))")
            }
        }
        
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [.addToReadingList, .assignToContact]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

// Placeholder view for PDF content
struct PDFPlaceholderView: View {
    let pdfData: Data
    
    var body: some View {
        VStack {
            Image(systemName: "doc.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("PDF Preview")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("\(pdfData.count) bytes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

// Placeholder for empty documents
struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("No Content")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Add content by scanning documents")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

#Preview {
    NavigationStack {
        DocumentEditView(documentURL: URL(fileURLWithPath: "/tmp/test.yianazip"))
    }
}
#endif
