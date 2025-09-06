# Apple Markup Integration Proposal for Yiana

## Executive Summary

This proposal outlines the integration of Apple's native markup capabilities into Yiana, allowing users to annotate PDFs using the familiar iOS/iPadOS markup tools while maintaining the application's core philosophy of simplicity and reliability.

## Current State Analysis

### Architecture Overview
- **Document Format**: `.yianazip` files containing:
  - `metadata.json`: Document metadata, OCR text, tags
  - Binary separator: 4 bytes (0xFF, 0xFF, 0xFF, 0xFF)
  - PDF data: Original PDF content
- **PDF Handling**: PDFKit configured for read-only viewing
- **Platform Distribution**: 
  - iOS/iPadOS: Primary platform for document viewing, scanning, management
  - macOS: Document viewing, bulk import capabilities
  - Mac mini server: Future OCR processing and indexing

### Technical Stack
- **iOS/iPadOS**: UIDocument, PDFKit, VisionKit for scanning
- **macOS**: NSDocument, PDFKit
- **Storage**: iCloud Documents synchronization via CloudKit
- **Design Constraints**: 
  - No PDF editing/annotations (deliberate architectural choice)
  - Memory optimization for large PDF handling
  - Read-only PDF viewing to avoid PDFKit memory issues

### Current File Structure
```
iCloud Documents/
└── DocumentName.yianazip
    ├── [metadata JSON]
    ├── [separator bytes]
    └── [PDF data]
```

## Problem Statement

Users require PDF annotation capabilities using Apple's standard markup tools (as seen in Mail, Files, and Screenshots) while maintaining:
1. Current architectural integrity
2. Memory efficiency with large PDFs
3. Application simplicity
4. Original PDF preservation
5. Familiar user experience

## Proposed Solution

### Enhanced Document Format

#### New Structure
```
.yianazip/
├── metadata.json       # Enhanced with markup tracking
├── document.pdf        # Original PDF (immutable)
└── markups/           # Markup versions directory
    ├── latest.pdf     # Most recent marked-up version
    └── history/       # Optional version history
        ├── 2024-01-15_143022.pdf
        └── 2024-01-15_151545.pdf
```

#### Enhanced Metadata Schema
```json
{
  "title": "Document Title",
  "created": "2024-01-15T10:30:00Z",
  "modified": "2024-01-15T11:45:00Z",
  "page_count": 12,
  "file_size": 2048000,
  "tags": ["client", "meeting", "project-alpha"],
  "ocr_completed": true,
  "ocr_timestamp": "2024-01-15T10:35:00Z",
  "full_text": "Complete OCR text content...",
  "markup": {
    "has_markup": true,
    "last_markup_date": "2024-01-15T15:15:45Z",
    "markup_count": 2,
    "active_version": "latest",
    "preserve_history": false,
    "total_markup_size": 3145728
  }
}
```

## Implementation Strategy

### Phase 1: Core Markup Integration (iOS)

#### 1.1 QLPreviewController Integration
```swift
// New: MarkupCoordinator.swift
class MarkupCoordinator: NSObject, QLPreviewControllerDelegate {
    let documentURL: URL
    let completion: (Data?) -> Void
    
    func previewController(_ controller: QLPreviewController, 
                          editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        return .updateContents
    }
    
    func previewController(_ controller: QLPreviewController,
                          didSaveEditedCopyOf previewItem: QLPreviewItem,
                          at modifiedContentsURL: URL) {
        // Extract and save marked-up PDF
        let markedPDF = try? Data(contentsOf: modifiedContentsURL)
        completion(markedPDF)
    }
}
```

#### 1.2 UI Integration Points
- Add "Markup" button to DocumentEditView toolbar (iOS)
- Present QLPreviewController as full-screen modal
- Save marked-up PDF to document structure on completion
- Update metadata to track markup state

### Phase 2: View Mode Management

#### 2.1 Dual View System
```swift
enum PDFViewMode: String, CaseIterable {
    case original = "Original"
    case markup = "Markup"
}

struct DocumentView {
    @State private var viewMode: PDFViewMode = .original
    @AppStorage("preferredViewMode") private var defaultViewMode: PDFViewMode = .original
    
    var currentPDFData: Data {
        switch viewMode {
        case .original:
            return document.originalPDF
        case .markup:
            return document.markupPDF ?? document.originalPDF
        }
    }
}
```

#### 2.2 Visual Indicators
- Segmented control for view mode selection
- Badge indicator on documents with markup in list view
- Different tint color for marked-up mode
- "Modified" indicator with timestamp

### Phase 3: Export Enhancement

#### 3.1 Multi-Mode Export
```swift
enum ExportMode: String, CaseIterable {
    case original = "Original Only"
    case withMarkup = "With Markup"
    case both = "Both Versions"
}

extension ExportService {
    func exportPDF(document: Document, mode: ExportMode) -> [ExportResult] {
        switch mode {
        case .original:
            return [exportOriginal(document)]
        case .withMarkup:
            return [exportMarkup(document)]
        case .both:
            return [exportOriginal(document), exportMarkup(document)]
        }
    }
}
```

### Phase 4: macOS Support (Optional)

- Investigate Quick Look framework for macOS
- Alternative: Defer macOS markup to future release
- Maintain view-only capability for marked-up documents

## Technical Considerations

### Memory Management

**Challenge**: QLPreviewController memory consumption with large PDFs

**Mitigation Strategies**:
- Release source PDF data after passing to QLPreviewController
- Enforce single-document markup sessions
- Implement memory pressure monitoring
- Clear preview cache after markup completion
- Set maximum file size for markup (e.g., 50MB)

### Storage Optimization

**Challenge**: Multiple PDF versions increase storage requirements

**Solutions**:
- **Default**: Store only latest markup version
- **Option A**: Compressed storage using PDF optimization
- **Option B**: Delta storage (store differences only)
- **Option C**: User-configurable history retention policy

### Synchronization Strategy

**Challenge**: Increased iCloud sync traffic

**Approach**:
- Prioritize original document sync
- Lazy sync for markup versions
- Optional markup sync (user preference)
- Compress marked PDFs before sync
- Implement sync conflict resolution

## Alternative Approaches Considered

### Option A: PencilKit Overlay
- **Pros**: Granular control, separate annotation layer, smaller storage
- **Cons**: Complex coordinate mapping, high maintenance burden, custom UI required
- **Decision**: Rejected due to complexity

### Option B: PDFKit Native Annotations
- **Pros**: Native to PDFKit, programmatic access
- **Cons**: Known memory issues, flattening challenges, crash risks
- **Decision**: Rejected due to reliability concerns

### Option C: Third-party SDK (PSPDFKit, etc.)
- **Pros**: Feature-complete, proven stability
- **Cons**: Licensing costs, external dependency, app size increase
- **Decision**: Rejected to maintain independence

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation Strategy |
|------|------------|--------|-------------------|
| Memory exhaustion during markup | Medium | High | Single-document limit, memory monitoring, file size caps |
| Storage bloat from versions | High | Medium | Compression, retention limits, user controls |
| iCloud sync conflicts | Low | High | Version isolation, conflict resolution UI |
| QLPreviewController bugs | Medium | Medium | Fallback to read-only, error recovery |
| User confusion with modes | Low | Low | Clear UI indicators, onboarding |

## Success Metrics

- **Performance**: Markup operations complete without memory warnings
- **Storage**: Document size increase < 2x with typical markups
- **Sync**: Sync time increase < 20% for marked documents
- **UX**: Mode switching latency < 0.5 seconds
- **Reliability**: < 0.1% crash rate during markup operations

## Migration Plan

1. **Backward Compatibility**: Existing documents continue working unchanged
2. **Progressive Enhancement**: Markup features appear only when first used
3. **No Data Migration**: Additive changes only, no document conversion required
4. **Gradual Rollout**: Feature flag for beta testing

## Open Questions for Technical Review

1. **Storage Policy**: Should markup history be preserved or only the latest version?
2. **Sync Strategy**: Should markups sync via iCloud or remain device-local?
3. **Platform Scope**: Should we support markup on macOS initially or focus on iOS?
4. **Protection**: Should original PDFs be cryptographically protected from modification?
5. **Size Limits**: What's the acceptable storage increase threshold (2x, 3x, user-defined)?
6. **Cleanup**: Automatic cleanup policy for old markup versions?

## Proof of Concept Implementation

### Minimum Viable Features
1. Single "Markup" button in iOS DocumentEditView
2. QLPreviewController presentation with save handling
3. Store marked PDF as `document_markup.pdf`
4. Toggle control for original/markup views
5. Export includes choice of version

### Estimated Timeline
- Phase 1 (Core Markup): 2 weeks
- Phase 2 (View Modes): 1 week
- Phase 3 (Export): 3 days
- Testing & Polish: 1 week
- **Total**: ~1 month for iOS MVP

## Conclusion

This proposal maintains Yiana's core philosophy of leveraging proven Apple frameworks while adding significant user value through native markup capabilities. The approach prioritizes reliability, simplicity, and user familiarity while carefully managing technical risks.

## Appendix: Code Examples

### Example: Markup Button Integration
```swift
// In DocumentEditView.swift
Button(action: { 
    presentMarkupView() 
}) {
    Label("Markup", systemImage: "pencil.tip.crop.circle")
}
.disabled(viewModel.pdfData == nil)
```

### Example: Storage Structure Update
```swift
extension DocumentRepository {
    func saveMarkup(_ pdfData: Data, for document: Document) throws {
        let markupURL = documentURL
            .appendingPathComponent("markups")
            .appendingPathComponent("latest.pdf")
        
        try FileManager.default.createDirectory(
            at: markupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        try pdfData.write(to: markupURL)
        updateMetadata(for: document, markupSaved: true)
    }
}
```