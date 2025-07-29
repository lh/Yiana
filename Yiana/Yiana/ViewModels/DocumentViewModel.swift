//
//  DocumentViewModel.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit

@MainActor
class DocumentViewModel: ObservableObject {
    @Published var title: String {
        didSet {
            if title != document.metadata.title {
                hasChanges = true
                scheduleAutoSave()
            }
        }
    }
    
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    @Published var pdfData: Data? {
        didSet {
            document.pdfData = pdfData
            hasChanges = true
            scheduleAutoSave()
        }
    }
    
    var autoSaveEnabled = false {
        didSet {
            if autoSaveEnabled && hasChanges {
                scheduleAutoSave()
            }
        }
    }
    
    private let document: NoteDocument
    private var autoSaveTask: Task<Void, Never>?
    
    init(document: NoteDocument) {
        self.document = document
        self.title = document.metadata.title
        self.pdfData = document.pdfData
    }
    
    func save() async -> Bool {
        guard hasChanges else { return true }
        
        isSaving = true
        errorMessage = nil
        
        // Update document
        document.metadata.title = title
        document.metadata.modified = Date()
        
        // Save
        return await withCheckedContinuation { continuation in
            document.save(to: document.fileURL, for: .forOverwriting) { success in
                Task { @MainActor in
                    self.isSaving = false
                    if success {
                        self.hasChanges = false
                    } else {
                        self.errorMessage = "Failed to save document"
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        
        guard autoSaveEnabled && hasChanges else { return }
        
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if !Task.isCancelled {
                _ = await save()
            }
        }
    }
}

#else

// Placeholder - macOS document editing will come later
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var title = "Document viewing not yet supported on macOS"
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    var pdfData: Data? { nil }
    var autoSaveEnabled = false
    
    init() {}
    
    func save() async -> Bool {
        return false
    }
}
#endif