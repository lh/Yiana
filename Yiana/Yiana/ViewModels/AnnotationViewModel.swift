#if os(macOS)
import Foundation
import SwiftUI
import PDFKit
import Combine

class AnnotationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedTool: AnnotationToolType?
    @Published var isMarkupMode: Bool = false
    @Published var hasUnsavedAnnotations: Bool = false
    @Published var currentPageAnnotations: [PDFAnnotation] = []
    
    // Document reload trigger
    @Published var documentNeedsReload: Bool = false
    
    // Success feedback
    @Published var successMessage: String?
    
    // MARK: - Tool Configuration
    
    @Published var toolConfiguration = ToolConfiguration()
    
    // MARK: - Document Properties
    
    var documentURL: URL?
    var documentBookmark: Data?

    // MARK: - Private Properties
    
    private var currentTool: AnnotationTool?
    private var currentPage: PDFPage?
    private var pageAnnotationsMap: [Int: [PDFAnnotation]] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let flattener = PDFFlattener()
    private let backupManager = BackupManager()
    private var isBackupCreated = false

    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        $selectedTool
            .sink { [weak self] toolType in
                self?.updateCurrentTool(toolType)
            }
            .store(in: &cancellables)
        
        $isMarkupMode
            .sink { [weak self] isActive in
                if !isActive {
                    self?.selectedTool = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Tool Management
    
    private func updateCurrentTool(_ toolType: AnnotationToolType?) {
        guard let toolType = toolType else {
            currentTool = nil
            return
        }
        currentTool = AnnotationToolFactory.createTool(for: toolType)
        applyConfigurationToTool()
    }
    
    private func applyConfigurationToTool() {
        guard let tool = currentTool else { return }
        
        switch tool.toolType {
        case .text:
            if let textTool = tool as? TextTool {
                textTool.font = NSFont(name: toolConfiguration.textFont, size: toolConfiguration.textSize) ?? .systemFont(ofSize: toolConfiguration.textSize)
                textTool.color = NSColor(toolConfiguration.textColor)
            }
        case .highlight:
            if let highlightTool = tool as? HighlightTool {
                highlightTool.color = NSColor(toolConfiguration.highlightColor)
            }
        case .underline:
            if let underlineTool = tool as? UnderlineTool {
                underlineTool.color = NSColor(toolConfiguration.underlineColor)
            }
        case .strikeout:
            if let strikeoutTool = tool as? StrikeoutTool {
                strikeoutTool.color = NSColor(toolConfiguration.strikeoutColor)
            }
        }
    }
    
    // MARK: - Annotation Lifecycle
    
    func createAnnotation(at point: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        ensureInitialBackup()
        guard let tool = currentTool else { return nil }
        applyConfigurationToTool()
        
        let annotation = tool.createAnnotation(at: point, on: page)
        if let annotation = annotation {
            addAnnotation(annotation, to: page)
        }
        return annotation
    }
    
    func createAnnotation(from startPoint: CGPoint, to endPoint: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        ensureInitialBackup()
        guard let tool = currentTool else { return nil }
        applyConfigurationToTool()
        
        let annotation = tool.createAnnotation(from: startPoint, to: endPoint, on: page)
        if let annotation = annotation {
            addAnnotation(annotation, to: page)
        }
        return annotation
    }
    
    private func addAnnotation(_ annotation: PDFAnnotation, to page: PDFPage) {
        page.addAnnotation(annotation)
        
        if let pageIndex = page.document?.index(for: page) {
            var annotations = pageAnnotationsMap[pageIndex] ?? []
            annotations.append(annotation)
            pageAnnotationsMap[pageIndex] = annotations
            // Keep the convenience array in sync when adding on the current page
            if let current = currentPage, current == page {
                currentPageAnnotations = annotations
            }
        }
        updateHasUnsavedAnnotations()
    }
    
    func setCurrentPage(_ page: PDFPage?) {
        if let previousPage = currentPage, previousPage != page {
            commitPageIfNeeded(previousPage)
        }
        currentPage = page
        
        // Defer the published property updates to avoid SwiftUI update conflicts
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Sync the convenience published array with our map for the new current page
            if let page = page, let doc = page.document {
                let index = doc.index(for: page)
                self.currentPageAnnotations = self.pageAnnotationsMap[index] ?? []
            } else {
                self.currentPageAnnotations = []
            }
            self.updateHasUnsavedAnnotations()
        }
    }
    
    // MARK: - Commit & Revert Operations
    
    func commitAllChanges() {
        print("DEBUG: commitAllChanges called")
        print("DEBUG: documentURL = \(String(describing: documentURL))")
        print("DEBUG: hasUnsavedAnnotations = \(hasUnsavedAnnotations)")
        print("DEBUG: pageAnnotationsMap = \(pageAnnotationsMap)")
        
        guard let docURL = documentURL,
              let document = currentPage?.document,
              hasUnsavedAnnotations else { 
            print("DEBUG: Commit cancelled - missing requirements")
            return
        }

        do {
            // Ensure we have a backup before making permanent changes
            ensureInitialBackup()
            
            // Use document-level flattening for atomic update
            let flattenedData = flattener.flatten(
                document: document,
                overlaysByPageIndex: pageAnnotationsMap,
                config: PDFFlattener.FlattenConfig(preserveLinksAndForms: true, box: .cropBox)
            )
            
            guard let flattenedData = flattenedData else {
                print("Failed to flatten document")
                return
            }
            
            // Use flattener's atomic write helper
            try flattener.writeAtomically(flattenedData, to: docURL)
            
            // Clean up temporary annotations from the view
            for (pageIndex, annotations) in pageAnnotationsMap {
                guard let page = document.page(at: pageIndex) else { continue }
                annotations.forEach { page.removeAnnotation($0) }
            }
            
            // Clear the tracking map
            pageAnnotationsMap.removeAll()
            currentPageAnnotations.removeAll()
            updateHasUnsavedAnnotations()
            
            // Trigger document reload to show flattened content
            print("DEBUG: Commit successful, triggering document reload")
            DispatchQueue.main.async { [weak self] in
                self?.documentNeedsReload = true
                self?.showSuccessMessage("Annotations committed successfully")
            }
            
        } catch {
            print("Error committing changes: \(error)")
            showErrorAlert(title: "Commit Failed", message: "Unable to save annotations permanently: \(error.localizedDescription)")
        }
    }

    func revertAllChanges() {
        guard let docURL = documentURL,
              let document = currentPage?.document else { return }

        // 1. Remove all temporary, uncommitted annotations from the view
        for (pageIndex, annotations) in pageAnnotationsMap {
            guard let page = document.page(at: pageIndex) else { continue }
            annotations.forEach { page.removeAnnotation($0) }
        }
        pageAnnotationsMap.removeAll()
        currentPageAnnotations.removeAll()
        updateHasUnsavedAnnotations()

        // 2. Revert the document to the start-of-day backup
        do {
            try backupManager.revertToStartOfDay(documentURL: docURL, bookmark: documentBookmark)
            // Trigger document reload to show reverted content
            DispatchQueue.main.async { [weak self] in
                self?.documentNeedsReload = true
                self?.showSuccessMessage("Document reverted to original")
            }
        } catch {
            print("Error reverting document: \(error)")
            showErrorAlert(title: "Revert Failed", message: "Unable to restore original document: \(error.localizedDescription)")
        }
    }

    // Convenience API expected by tests to reset the in-memory overlay state for the current page
    func revertToOriginal() {
        // Clear current page annotations view state
        if let page = currentPage, let doc = page.document {
            let index = doc.index(for: page)
            if let annotations = pageAnnotationsMap[index] {
                // Remove from the visible page
                annotations.forEach { page.removeAnnotation($0) }
            }
            pageAnnotationsMap[index] = []
        }
        currentPageAnnotations.removeAll()
        hasUnsavedAnnotations = false
    }
    
    func commitCurrentPage() {
        guard let page = currentPage,
              let document = page.document,
              let docURL = documentURL else { return }
        
        let pageIndex = document.index(for: page)
        guard let annotations = pageAnnotationsMap[pageIndex],
              !annotations.isEmpty else { return }
        
        do {
            // Ensure backup before first edit
            ensureInitialBackup()
            
            // Use page-level flattening for single page commit
            guard let flattenedPage = flattener.flattenAnnotations(on: page, annotations: annotations) else {
                print("Failed to flatten page")
                return
            }
            
            // Use helper to create new document with replaced page
            guard let newDocument = flattener.documentByReplacingPage(in: document, at: pageIndex, with: flattenedPage),
                  let data = newDocument.dataRepresentation() else {
                print("Failed to create new document")
                return
            }
            
            // Write atomically
            try flattener.writeAtomically(data, to: docURL)
            
            // Clean up annotations
            annotations.forEach { page.removeAnnotation($0) }
            pageAnnotationsMap.removeValue(forKey: pageIndex)
            currentPageAnnotations = pageAnnotationsMap[pageIndex] ?? []
            updateHasUnsavedAnnotations()
            
        } catch {
            print("Error committing current page: \(error)")
        }
    }
    
    private func commitPageIfNeeded(_ page: PDFPage) {
        guard let document = page.document,
              let docURL = documentURL else { return }
        
        let pageIndex = document.index(for: page)
        guard let annotations = pageAnnotationsMap[pageIndex],
              !annotations.isEmpty else { return }
        
        do {
            // Commit the page when switching pages
            guard let flattenedPage = flattener.flattenAnnotations(on: page, annotations: annotations) else {
                print("Failed to flatten page during page switch")
                return
            }
            
            // Use helper to create new document with replaced page
            guard let newDocument = flattener.documentByReplacingPage(in: document, at: pageIndex, with: flattenedPage),
                  let data = newDocument.dataRepresentation() else {
                print("Failed to create new document during page switch")
                return
            }
            
            // Write atomically
            try flattener.writeAtomically(data, to: docURL)
            
            // Clean up annotations
            annotations.forEach { page.removeAnnotation($0) }
            pageAnnotationsMap.removeValue(forKey: pageIndex)
            updateHasUnsavedAnnotations()
            
        } catch {
            print("Error committing page on switch: \(error)")
        }
    }

    // MARK: - Backup Management
    
    private func ensureInitialBackup() {
        guard let docURL = documentURL, !isBackupCreated else { return }
        
        do {
            try backupManager.ensureDailyBackup(for: docURL, bookmark: documentBookmark)
            isBackupCreated = true
            try backupManager.pruneOldBackups(for: docURL, bookmark: documentBookmark)
        } catch {
            // Handle backup creation failure (e.g., permissions)
            print("Failed to create initial backup: \(error)")
        }
    }
    
    // MARK: - State Queries
    
    private func updateHasUnsavedAnnotations() {
        hasUnsavedAnnotations = !pageAnnotationsMap.values.flatMap { $0 }.isEmpty
    }

    func hasAnnotationsOnAnyPage() -> Bool {
        return hasUnsavedAnnotations
    }
    
    // MARK: - User Feedback
    
    private func showErrorAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        // Clear the message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.successMessage = nil
        }
    }
    
    // MARK: - Keyboard Shortcut Handler
    
    func handleKeyboardShortcut(_ key: String) -> Bool {
        guard isMarkupMode else { return false }
        
        switch key.lowercased() {
        case "t":
            selectedTool = (selectedTool == .text) ? nil : .text
            return true
        case "h":
selectedTool = (selectedTool == .highlight) ? nil : .highlight
            return true
        case "u":
            selectedTool = (selectedTool == .underline) ? nil : .underline
            return true
        case "s":
            selectedTool = (selectedTool == .strikeout) ? nil : .strikeout
            return true
        case "escape":
            selectedTool = nil
            return true
        default:
            return false
        }
    }
}
#endif
