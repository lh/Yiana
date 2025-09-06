# Apple Markup Integration Proposal for Yiana (Revised)

## Executive Summary

This proposal outlines the integration of Apple's native markup capabilities into Yiana. It follows a "paper document" philosophy: annotations are permanently applied to the PDF after each markup session. This approach leverages `QLPreviewController` for a familiar user experience while maintaining architectural simplicity and eliminating conflicts between annotations and structural document edits.

## Core Philosophy: "Ink on Paper"

The guiding principle is that marking up a document is like writing on paper with ink. The change is immediate and permanent.
- **No Editable Annotations:** Once a markup session is complete, the annotations are "burned into" the PDF. They are not stored on a separate layer and cannot be edited later.
- **No "Undo":** This is an intentional design choice. Reversible markup is considered an anti-feature for the intended "paper-like" workflow.
- **Simplicity:** This eliminates the need for complex state management, view modes, or user choices during export. There is only one version of the document: its current state.
- **Preserved Searchability:** Typed text annotations remain as searchable PDF text objects, not rasterized images.

## Problem Statement

Users require a simple, reliable way to annotate PDFs using Apple's standard markup tools. The solution must integrate seamlessly with existing features like page deletion and reordering, without causing data inconsistency or user confusion.

## Proposed Solution: Immediate Flattening

The solution is to use `QLPreviewController` to handle the markup UI, and then immediately use its output to overwrite the existing document.

### Document Format
The existing `.yianazip` structure is preserved with minimal changes. The `document.pdf` within the package is considered mutable, with a one-time backup created before the first markup.
```
.yianazip/
├── metadata.json
├── document.pdf      # Mutable, updated in-place after markup
└── .backup/          # Hidden directory (created on first markup)
    └── original.pdf  # One-time backup of pre-markup document
```

### Workflow
1.  **User Initiates Markup:** User taps a "Markup" button.
2.  **First-Time Backup:** If this is the first markup, create `.backup/original.pdf`.
3.  **`QLPreviewController` is Presented:** The standard iOS/iPadOS markup interface is shown for the `document.pdf`.
4.  **User Annotates and Saves:** User makes their changes (typed text, drawings, highlights) and taps "Done".
5.  **Document is Overwritten:** The app receives the annotated PDF from the controller and atomically replaces the `document.pdf` inside the `.yianazip` package with this new version.
6.  **Text Re-extraction:** The full text is extracted from the updated PDF (including typed annotations) for search indexing.

This workflow ensures that there is only ever one version of the document, which includes all annotations. This completely prevents any conflict between structural edits (add/delete/reorder pages) and annotations.

## Implementation Strategy

### Phase 1: Core Markup Integration (iOS)

#### 1.1 QLPreviewController Integration
The `MarkupCoordinator` remains the entry point, but its completion handler will trigger the document overwrite.
```swift
// New: MarkupCoordinator.swift
class MarkupCoordinator: NSObject, QLPreviewControllerDelegate {
    let completion: (Data) -> Void // Returns the new PDF data
    
    func previewController(_ controller: QLPreviewController, 
                          editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        return .updateContents
    }
    
    func previewController(_ controller: QLPreviewController,
                          didSaveEditedCopyOf previewItem: QLPreviewItem,
                          at modifiedContentsURL: URL) {
        // Extract marked-up PDF and pass to completion handler
        if let markedPDF = try? Data(contentsOf: modifiedContentsURL) {
            completion(markedPDF)
        }
    }
}
```

#### 1.2 UI Integration Points
- Add "Markup" button to the document view toolbar.
- Check file size before allowing markup (50MB limit).
- Create one-time backup if this is the first markup.
- Present `QLPreviewController` as a full-screen modal.
- On completion, atomically overwrite the `document.pdf` with the new data.
- Re-extract text for search indexing (preserves typed annotations as searchable text).

### Phase 2: macOS Support (Optional)
- Investigate the Quick Look framework on macOS for a similar "update-in-place" workflow.
- If not feasible, macOS can remain a viewer for the marked-up PDFs created on iOS/iPadOS.

## Technical Considerations

### Memory Management
The primary challenge remains the memory consumption of `QLPreviewController` with large PDFs.
**Mitigation Strategies**:
- Enforce single-document markup sessions.
- Implement memory pressure monitoring.
- Enforce a 50MB file size limit for markup feature.
```swift
let MAX_MARKUP_SIZE_MB = 50
let fileSizeMB = pdfData.count / (1024 * 1024)
if fileSizeMB > MAX_MARKUP_SIZE_MB {
    // Show alert: "This document is too large for markup."
}
```

### Storage and Synchronization
Since we are not creating multiple versions or storing history (except the one-time backup), the risks of "storage bloat" and "sync conflicts" are minimal. The storage impact is limited to:
- One-time backup (same size as original)
- Natural size increase from annotations (typically < 10%)

### Text Preservation
**Critical Insight**: Typed text annotations added through QLPreviewController remain as searchable PDF text objects, not rasterized images. This means:
- Original OCR'd text is preserved
- New typed annotations are immediately searchable
- No re-OCR required, just text re-extraction
- Search quality is maintained

## Alternative Approaches Considered

The decision to use `QLPreviewController` over `PencilKit` overlays or native `PDFKit` annotations remains valid. This approach was chosen to prioritize simplicity, reliability, and a familiar user experience, which aligns with the project's "LEGO" philosophy. The revised "ink on paper" workflow makes this choice even more compelling, as it removes the need for the complex state management that other solutions would have required.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation Strategy |
|------|------------|--------|-------------------|
| Memory exhaustion during markup | Medium | High | Single-document limit, memory monitoring, 50MB file size cap |
| `QLPreviewController` bugs | Medium | Medium | Error handling and fallback to read-only view on failure |
| Accidental user markup | Low | Low | Explicit user intent required; one-time backup provides safety net |
| Loss of original document | Very Low | Medium | One-time backup before first markup |
| Text becomes unsearchable | Very Low | Low | Typed text remains searchable; only handwriting is not OCR'd |

## Success Metrics

- **Performance**: Markup operations complete without memory warnings on target devices.
- **Reliability**: < 0.1% crash rate during markup operations.
- **Workflow Integrity**: Users can perform structural edits (delete/move pages) immediately after a markup session with no data loss or warnings.

## Migration Plan

No data migration is required. This is an additive feature. Existing documents will work as-is and will be updated in-place if and when a user chooses to mark them up.

## Proof of Concept Implementation

### Minimum Viable Features
1. A "Markup" button in the iOS document view.
2. `QLPreviewController` presentation and handling of the saved result.
3. A method in `DocumentRepository` to overwrite the `document.pdf` with the new data from the markup session.
4. The ability to immediately perform a structural edit (e.g., delete a page) on the newly marked-up document.

### Estimated Timeline
- Core Markup & Overwrite Logic: 1-2 weeks
- Testing & Polish: 1 week
- **Total**: ~2-3 weeks for a production-ready iOS MVP.

## Conclusion

This revised proposal aligns with the core "paper document" philosophy of the application. By treating annotations as permanent, immediate changes, we eliminate architectural complexity and potential user confusion. This approach delivers the desired functionality in the simplest, most robust way possible, staying true to the Yiana project's principles.

## Appendix: Code Examples

### Example: Markup Button Integration
```swift
// In DocumentView.swift
Button(action: { 
    presentMarkupView() // This will trigger the MarkupCoordinator
}) {
    Label("Markup", systemImage: "pencil.tip.crop.circle")
}
.disabled(viewModel.pdfData == nil)
```

### Example: Updating the Document in the Repository
```swift
extension DocumentRepository {
    func updateDocumentWithMarkup(newPDFData: Data, for document: Document) throws {
        // 1. Create one-time backup if first markup
        if !document.hasBackup {
            try createBackup(for: document)
        }
        
        // 2. Atomic save to prevent corruption
        let tempURL = document.pdfURL.appendingPathExtension("tmp")
        try newPDFData.write(to: tempURL)
        try FileManager.default.replaceItem(
            at: document.pdfURL,
            withItemAt: tempURL,
            backupItemName: nil,
            options: []
        )
        
        // 3. Update metadata
        document.metadata.hasMarkup = true
        document.metadata.lastMarkupDate = Date()
        document.metadata.modified = Date()
        
        // 4. Re-extract text for search (preserves typed annotations)
        if let pdf = PDFDocument(data: newPDFData) {
            document.metadata.fullText = pdf.string ?? ""
        }
        
        // 5. Save document
        try document.save()
    }
}
```

### Example: Testing Text Preservation
```swift
func verifyTextPreservation(original: Data, marked: Data) {
    let originalPDF = PDFDocument(data: original)!
    let markedPDF = PDFDocument(data: marked)!
    
    let originalText = originalPDF.string ?? ""
    let markedText = markedPDF.string ?? ""
    
    assert(markedText.contains(originalText), "Original text preserved")
    assert(markedText.count >= originalText.count, "Text not lost")
    print("✓ Typed annotations are searchable!")
}
```