//
//  MarkupCoordinator.swift
//  Yiana
//
//  Coordinates the markup workflow using QLPreviewController
//

import Foundation
import QuickLook
import PDFKit

#if os(iOS)
import UIKit

/// Container view controller for QLPreviewController with overlay save button
class MarkupContainerViewController: UIViewController {
    private let navController: UINavigationController
    private let previewController: QLPreviewController
    private let coordinator: MarkupCoordinator
    private var saveButton: UIButton!
    
    init(previewController: QLPreviewController, coordinator: MarkupCoordinator) {
        self.previewController = previewController
        self.coordinator = coordinator
        // Wrap the preview controller in a navigation controller to get the toolbar
        self.navController = UINavigationController(rootViewController: previewController)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add navigation controller as child (which contains the preview controller)
        addChild(navController)
        view.addSubview(navController.view)
        navController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navController.view.topAnchor.constraint(equalTo: view.topAnchor),
            navController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        navController.didMove(toParent: self)
        
        // Add a close button to the navigation bar
        previewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(closeTapped)
        )
        
        // Create floating save button
        setupFloatingSaveButton()
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    
    private func setupFloatingSaveButton() {
        // Create a floating Done button
        saveButton = UIButton(type: .system)
        saveButton.setTitle("Done", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 25
        saveButton.layer.shadowColor = UIColor.black.cgColor
        saveButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        saveButton.layer.shadowOpacity = 0.3
        saveButton.layer.shadowRadius = 4
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            saveButton.widthAnchor.constraint(equalToConstant: 80),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])
    }
    
    @objc private func saveButtonTapped() {
        print("DEBUG Markup: Floating Done button tapped")
        
        // Try to trigger save programmatically
        coordinator.attemptSave()
        
        // Dismiss after a short delay to allow save to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.dismiss(animated: true)
        }
    }
}

/// Coordinates the markup workflow for PDFs using QLPreviewController
class MarkupCoordinator: NSObject {
    
    // MARK: - Properties
    
    private let sourceURL: URL
    private let completion: (Result<Data, Error>) -> Void
    private var tempFileURL: URL?
    private let originalPDFData: Data
    private let pageIndex: Int
    private var hasChanges = false
    private var savedData: Data?
    
    // MARK: - Initialization
    
    init(pdfData: Data, currentPageIndex: Int, completion: @escaping (Result<Data, Error>) -> Void) throws {
        // Validate inputs
        guard let pdfDocument = PDFDocument(data: pdfData),
              currentPageIndex >= 0,
              currentPageIndex < pdfDocument.pageCount,
              let currentPage = pdfDocument.page(at: currentPageIndex) else {
            throw MarkupError.invalidPDF
        }
        
        // Store original data for merging later
        self.originalPDFData = pdfData
        self.pageIndex = currentPageIndex
        self.completion = completion
        
        // Create single-page PDF
        let singlePagePDF = PDFDocument()
        singlePagePDF.insert(currentPage, at: 0)
        
        guard let singlePageData = singlePagePDF.dataRepresentation() else {
            throw MarkupError.invalidPDF
        }
        
        // Create a temporary file for QLPreviewController
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "markup_page_\(currentPageIndex)_\(UUID().uuidString).pdf"
        let tempURL = tempDir.appendingPathComponent(tempFileName)
        
        // Write single page PDF data to temp file
        try singlePageData.write(to: tempURL)
        
        self.sourceURL = tempURL
        self.tempFileURL = tempURL
        
        super.init()
        
        print("DEBUG Markup: Extracted page \(currentPageIndex + 1) for markup")
    }
    
    deinit {
        // Clean up temporary file
        if let tempURL = tempFileURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
    
    // MARK: - Public Methods
    
    /// Creates and configures a container with QLPreviewController for markup
    func createMarkupContainer() -> MarkupContainerViewController {
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        
        let container = MarkupContainerViewController(
            previewController: previewController,
            coordinator: self
        )
        
        return container
    }
    
    /// Attempts to save the current markup
    func attemptSave() {
        print("DEBUG Markup: Attempting to save markup")
        
        // Check if we have saved data already
        if savedData != nil {
            print("DEBUG Markup: Already have saved data")
            return
        }
        
        // If changes were made, try to read the temp file again
        if hasChanges, let tempURL = tempFileURL {
            do {
                let currentData = try Data(contentsOf: tempURL)
                
                // Check if it's different from original
                if let currentPDF = PDFDocument(data: currentData),
                   currentPDF.pageCount == 1,
                   let currentPage = currentPDF.page(at: 0),
                   let originalPDF = PDFDocument(data: originalPDFData) {
                    
                    // Replace the page
                    originalPDF.removePage(at: pageIndex)
                    originalPDF.insert(currentPage, at: pageIndex)
                    
                    if let completeData = originalPDF.dataRepresentation() {
                        print("DEBUG Markup: Successfully saved via attemptSave")
                        self.savedData = completeData
                        completion(.success(completeData))
                    }
                }
            } catch {
                print("DEBUG Markup: Failed to read temp file in attemptSave: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleDismissal() {
        print("DEBUG Markup: Handling custom dismissal")
        
        // If we have saved data, use it
        if let savedData = savedData {
            print("DEBUG Markup: Using saved data from didSaveEditedCopyOf")
            completion(.success(savedData))
            return
        }
        
        // If we detected changes but no save, try to recover
        if hasChanges {
            print("DEBUG Markup: Changes detected but no save - checking for auto-saved file")
            
            // Check if there's an auto-saved version
            let autoSaveURL = tempFileURL?.deletingPathExtension().appendingPathExtension("autosave.pdf")
            if let autoSaveURL = autoSaveURL,
               FileManager.default.fileExists(atPath: autoSaveURL.path),
               let autoSavedData = try? Data(contentsOf: autoSaveURL) {
                print("DEBUG Markup: Found auto-saved file, attempting to merge")
                
                // Process the auto-saved data
                if let markedPagePDF = PDFDocument(data: autoSavedData),
                   markedPagePDF.pageCount == 1,
                   let markedPage = markedPagePDF.page(at: 0),
                   let originalPDF = PDFDocument(data: originalPDFData) {
                    
                    originalPDF.removePage(at: pageIndex)
                    originalPDF.insert(markedPage, at: pageIndex)
                    
                    if let completeData = originalPDF.dataRepresentation() {
                        print("DEBUG Markup: Successfully recovered and merged auto-saved changes")
                        completion(.success(completeData))
                        return
                    }
                }
            }
            
            print("DEBUG Markup: Changes were made but could not be recovered")
            completion(.failure(MarkupError.changesMadeButNotSaved))
        } else {
            print("DEBUG Markup: No changes detected - user cancelled")
            completion(.failure(MarkupError.userCancelled))
        }
    }
    
    @objc private func saveButtonTapped() {
        print("DEBUG Markup: Save button tapped - QLPreviewController limitation")
        
        // Unfortunately, we cannot programmatically save QLPreviewController markups
        // This is a known limitation. The user MUST use the built-in Done button.
        // 
        // Alternative solutions:
        // 1. Use PDFKit with PDFAnnotation (more complex but reliable)
        // 2. Use WKWebView with JavaScript PDF annotation libraries
        // 3. Use a third-party library like PSPDFKit
        //
        // For now, alert the user about the limitation
        
        let alert = UIAlertController(
            title: "Saving Markup",
            message: "Due to an iOS limitation, markups must be saved using the 'Done' button in the markup toolbar at the bottom of the screen.\n\nIf you don't see a 'Done' button, try:\n• Rotating your device\n• Swiping to show hidden toolbars\n• Using landscape orientation",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController?.presentedViewController {
            rootVC.present(alert, animated: true)
        }
    }
}

// MARK: - QLPreviewControllerDataSource

extension MarkupCoordinator: QLPreviewControllerDataSource {
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return sourceURL as QLPreviewItem
    }
}

// MARK: - QLPreviewControllerDelegate

extension MarkupCoordinator: QLPreviewControllerDelegate {
    
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        // Allow editing/markup
        return .updateContents
    }
    
    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        // Read the marked-up single page PDF
        do {
            let markedPageData = try Data(contentsOf: modifiedContentsURL)
            
            // Verify it's valid PDF data
            guard let markedPagePDF = PDFDocument(data: markedPageData),
                  markedPagePDF.pageCount == 1,
                  let markedPage = markedPagePDF.page(at: 0) else {
                completion(.failure(MarkupError.invalidPDF))
                return
            }
            
            // Load the original full document
            guard let originalPDF = PDFDocument(data: originalPDFData) else {
                completion(.failure(MarkupError.invalidPDF))
                return
            }
            
            // Replace the page in the original document
            originalPDF.removePage(at: pageIndex)
            originalPDF.insert(markedPage, at: pageIndex)
            
            // Get the complete document with the marked-up page
            guard let completeData = originalPDF.dataRepresentation() else {
                completion(.failure(MarkupError.invalidPDF))
                return
            }
            
            // Store the saved data for the dismissal handler
            self.savedData = completeData
            
            // Log for debugging
            print("DEBUG Markup: Successfully merged marked page \(pageIndex + 1) back into document")
            print("DEBUG Markup: Final document has \(originalPDF.pageCount) pages")
            
            // Clean up the modified file
            try? FileManager.default.removeItem(at: modifiedContentsURL)
            
        } catch {
            print("DEBUG Markup: Failed to process marked page - \(error)")
            completion(.failure(error))
        }
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        // This is called when the controller is dismissed
        // If the user saved, didSaveEditedCopyOf would have been called first
        // If not, this means they cancelled or dismissed without saving
        print("DEBUG Markup: Preview controller dismissed - user may have cancelled markup")
    }
    
    func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
        // This is called when the user makes changes
        print("DEBUG Markup: User is actively editing the document")
        hasChanges = true
    }
}

// MARK: - Error Types

enum MarkupError: LocalizedError {
    case invalidPDF
    case fileSizeTooLarge
    case backupFailed
    case changesMadeButNotSaved
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "The marked-up document is not a valid PDF"
        case .fileSizeTooLarge:
            return "This document is too large for markup (maximum 50MB)"
        case .backupFailed:
            return "Failed to create backup before markup"
        case .changesMadeButNotSaved:
            return "Changes were made but could not be saved. Please try again using the Done button in the markup toolbar."
        case .userCancelled:
            return "Markup was cancelled"
        }
    }
}

// MARK: - File Size Check

extension MarkupCoordinator {
    
    /// Maximum file size for markup in megabytes
    static let maxFileSizeMB = 50
    
    /// Checks if PDF data is within size limit for markup
    static func canMarkup(pdfData: Data) -> Bool {
        let fileSizeMB = Double(pdfData.count) / (1024.0 * 1024.0)
        return fileSizeMB <= Double(maxFileSizeMB)
    }
    
    /// Returns file size in MB as a formatted string
    static func formattedFileSize(for data: Data) -> String {
        let fileSizeMB = Double(data.count) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", fileSizeMB)
    }
}

#endif