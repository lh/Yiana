# macOS Text Markup - Digital Paper Implementation

## Core Philosophy: Digital Paper
The PDF is the paper. Text annotations from Mac are permanent ink. Once applied, they cannot be edited, only viewed. This matches the iOS PencilKit paradigm where drawings are flattened into the PDF.

## Architecture Overview

### Technology Stack
- **Display**: PDFKit's PDFView
- **Temporary Annotations**: PDFAnnotation objects (ephemeral)
- **Permanent Rendering**: Core Graphics flattening
- **Storage**: Flattened PDFs with optional daily backups

---

## Parallel Workstreams

### Workstream 1: Core Flattening Engine
**Owner**: Backend Developer
**Dependencies**: None
**Deliverables**: 
- PDF flattening service
- Core Graphics rendering pipeline
- Text layer preservation

#### Components:
```swift
// PDFFlattener.swift
class PDFFlattener {
    func flattenAnnotations(page: PDFPage, annotations: [PDFAnnotation]) -> PDFPage
    func preserveTextLayer(in page: PDFPage) -> Bool
    func renderToCoreGraphics(context: CGContext, annotations: [PDFAnnotation])
}
```

#### Tasks:
- [ ] Create PDFFlattener class
- [ ] Implement Core Graphics rendering
- [ ] Preserve searchable text layer
- [ ] Handle vector vs raster output
- [ ] Memory optimization for large PDFs
- [ ] Unit tests for flattening

---

### Workstream 2: Annotation Tools
**Owner**: UI Developer
**Dependencies**: None initially, integrates with Workstream 1 later
**Deliverables**: 
- Tool implementations
- Temporary annotation management
- Tool state management

#### Components:
```swift
// AnnotationTool.swift
protocol AnnotationTool {
    func createAnnotation(at point: CGPoint) -> PDFAnnotation
    func configureAnnotation(_ annotation: PDFAnnotation)
}

// TextTool.swift
class TextTool: AnnotationTool {
    var font: NSFont
    var color: NSColor
    var size: CGFloat
}

// HighlightTool.swift  
class HighlightTool: AnnotationTool {
    var color: NSColor
    var opacity: CGFloat
}
```

#### Tasks:
- [ ] Define AnnotationTool protocol
- [ ] Implement TextTool
- [ ] Implement HighlightTool
- [ ] Implement UnderlineTool
- [ ] Implement StrikeoutTool
- [ ] Create tool configuration UI
- [ ] Unit tests for each tool

---

### Workstream 3: Backup System
**Owner**: Storage Developer
**Dependencies**: None - completely independent
**Deliverables**:
- Daily backup service
- Backup management UI
- Cleanup scheduler

#### Components:
```swift
// BackupManager.swift
class BackupManager {
    func createDailyBackup(for document: URL) -> URL?
    func listBackups(for document: URL) -> [BackupEntry]
    func restoreBackup(_ backup: BackupEntry) -> Bool
    func cleanupOldBackups(olderThan days: Int)
}
```

#### Tasks:
- [ ] Design backup directory structure
- [ ] Implement backup creation
- [ ] Implement restore functionality
- [ ] Create backup cleanup scheduler
- [ ] Add backup UI menu items
- [ ] Handle iCloud backup sync
- [ ] Unit tests for backup operations

---

### Workstream 4: User Interface
**Owner**: SwiftUI Developer  
**Dependencies**: Workstream 2 (for tools)
**Deliverables**:
- Markup toolbar
- Inspector panel
- Commit UI/UX

#### Components:
```swift
// MarkupToolbar.swift
struct MarkupToolbar: View {
    @Binding var selectedTool: AnnotationTool?
    @Binding var commitAction: () -> Void
}

// AnnotationInspector.swift
struct AnnotationInspector: View {
    @Binding var tool: AnnotationTool
    // Font, color, size controls
}

// CommitButton.swift
struct CommitButton: View {
    var onCommit: () -> Void
    @State private var showingConfirmation = false
}
```

#### Tasks:
- [ ] Design toolbar layout
- [ ] Create tool selection UI
- [ ] Build inspector panel
- [ ] Implement commit button with confirmation
- [ ] Add keyboard shortcuts
- [ ] Create "ink drying" animation
- [ ] Accessibility support

---

### Workstream 5: Commit System
**Owner**: Core Developer
**Dependencies**: Workstreams 1 & 2
**Deliverables**:
- Commit triggers
- Page state management
- Multi-page handling

#### Components:
```swift
// CommitManager.swift
class CommitManager {
    func commitCurrentPage()
    func commitAllPages()
    func handlePageChange(from: Int, to: Int)
    func handleDocumentClose()
}

// PageState.swift
enum PageState {
    case clean
    case editing(annotations: [PDFAnnotation])
    case committed
}
```

#### Tasks:
- [ ] Implement explicit commit (button)
- [ ] Implement implicit commit (page change)
- [ ] Handle document close scenarios
- [ ] Multi-page annotation tracking
- [ ] Commit confirmation dialogs
- [ ] Integration tests

---

### Workstream 6: Integration Layer
**Owner**: Lead Developer
**Dependencies**: All other workstreams
**Deliverables**:
- Complete integration
- Testing
- Performance optimization

#### Components:
```swift
// MacPDFMarkupViewController.swift
class MacPDFMarkupViewController: NSViewController {
    // Integrates all components
    private let flattener: PDFFlattener
    private let backupManager: BackupManager
    private let commitManager: CommitManager
    private var currentTool: AnnotationTool?
}
```

#### Tasks:
- [ ] Wire up all components
- [ ] End-to-end testing
- [ ] Performance profiling
- [ ] Memory leak detection
- [ ] Cross-platform testing (ensure iOS compatibility)
- [ ] Documentation

---

## Testing Strategy

### Unit Tests (Per Workstream)
- Test each component in isolation
- Mock dependencies
- Focus on edge cases

### Integration Tests
- Test component interactions
- Verify commit flows
- Test backup/restore cycles

### UI Tests
- Test tool selection and usage
- Verify commit triggers
- Test keyboard shortcuts

### Performance Tests
- Large PDF handling
- Memory usage during flattening
- Backup performance

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- Workstream 1: Basic flattening
- Workstream 2: Text tool only
- Workstream 3: Backup structure

### Phase 2: Core Features (Weeks 3-4)
- Workstream 1: Advanced rendering
- Workstream 2: All tools
- Workstream 4: Basic UI
- Workstream 5: Commit system

### Phase 3: Integration (Week 5)
- Workstream 6: Full integration
- All workstreams: Bug fixes

### Phase 4: Polish (Week 6)
- Performance optimization
- UI refinements
- Documentation
- Testing

---

## API Contracts

### Between Flattener and Tools
```swift
protocol FlattenerInput {
    var annotations: [PDFAnnotation] { get }
    var page: PDFPage { get }
}
```

### Between UI and Tools
```swift
protocol ToolDelegate {
    func toolDidCreateAnnotation(_ annotation: PDFAnnotation)
    func toolDidUpdateAnnotation(_ annotation: PDFAnnotation)
}
```

### Between Commit and Backup
```swift
protocol BackupDelegate {
    func shouldCreateBackup(for document: URL) -> Bool
    func backupDidComplete(url: URL)
}
```

---

## Success Criteria

### Functional Requirements
- [ ] Text can be added to any PDF page
- [ ] Annotations flatten correctly
- [ ] Backups create/restore successfully
- [ ] Implicit/explicit commits work
- [ ] No memory leaks

### Performance Requirements
- [ ] Flatten 100-page PDF in < 5 seconds
- [ ] Backup creation < 1 second
- [ ] Smooth UI at 60fps during annotation

### Quality Requirements
- [ ] 80% test coverage
- [ ] No critical bugs
- [ ] Accessibility compliant
- [ ] Memory usage < 500MB for typical document

---

## Dependencies & Risks

### External Dependencies
- PDFKit framework
- Core Graphics
- SwiftUI/AppKit

### Risks & Mitigations
1. **Risk**: Flattening degrades quality
   - **Mitigation**: Use vector rendering, preserve text layers

2. **Risk**: Performance issues with large PDFs
   - **Mitigation**: Page-by-page processing, background queues

3. **Risk**: User accidentally commits
   - **Mitigation**: Confirmation dialogs, session backup

4. **Risk**: Backup storage explosion
   - **Mitigation**: Automatic cleanup, compression

---

## Configuration & Settings

### User Preferences
```swift
struct MarkupPreferences {
    var defaultFont: String = "Helvetica"
    var defaultColor: NSColor = .black
    var backupRetentionDays: Int = 7
    var confirmCommit: Bool = true
    var playSounds: Bool = false
}
```

### Feature Flags
```swift
struct FeatureFlags {
    static let stickyNotesEnabled = false  // Phase 2
    static let multiColorHighlight = true
    static let autoBackup = true
}
```

---

## Design Principles

### 1. Paper & Ink Metaphor
- Once ink is applied to paper, it's permanent
- No erasing, only adding
- Backups provide "fresh paper"

### 2. Simplicity Over Features
- Limited font choices (like choosing a pen)
- Basic colors only
- No rich text formatting

### 3. Consistency with iOS
- iOS: PencilKit drawings flattened
- macOS: Text annotations flattened
- Both: Same permanent result

### 4. Professional Reliability
- What you see is what you get
- No hidden annotation states
- Universal PDF compatibility

---

## User Experience Flow

### Entering Markup Mode
1. User opens document
2. Clicks "Markup" button
3. Toolbar appears with tools
4. Optional: Daily backup created

### Adding Annotations
1. Select tool (Text, Highlight, etc.)
2. Configure in inspector (font, color)
3. Click/drag on PDF to apply
4. See temporary annotation

### Committing Changes
1. Trigger: Click "Commit" OR change page OR close document
2. Optional: Confirmation dialog
3. Annotations flatten into PDF
4. Temporary layer cleared
5. Return to read mode

### Reverting Changes
1. Access "Revert" menu
2. Choose "Today's Original"
3. Confirm replacement
4. Clean PDF restored

---

## Technical Details

### Flattening Process
```swift
// Pseudo-code for flattening
func flattenPage(page: PDFPage, annotations: [PDFAnnotation]) -> PDFPage {
    let bounds = page.bounds(for: .mediaBox)
    let pdfData = NSMutableData()
    
    guard let context = CGContext(consumer: CGDataConsumer(data: pdfData),
                                   mediaBox: &bounds,
                                   nil) else { return page }
    
    context.beginPDFPage(nil)
    
    // Draw original page
    page.draw(with: .mediaBox, to: context)
    
    // Draw annotations
    for annotation in annotations {
        drawAnnotation(annotation, in: context)
    }
    
    context.endPDFPage()
    context.closePDF()
    
    return PDFPage(data: pdfData as Data) ?? page
}
```

### Memory Management
- Release temporary annotations after commit
- Use autoreleasepool for batch operations
- Stream large PDFs page-by-page
- Cache only visible pages

---

## Future Enhancements (Not Phase 1)

### Phase 2 Possibilities
- Form filling mode
- Stamps/signatures
- Drawing tools (lines, arrows)
- OCR integration for typed text

### Phase 3 Possibilities
- Collaborative markup (shared sessions)
- Version history beyond daily
- Export annotations separately
- Template system

---

## Conclusion

This design provides a robust, principled foundation for macOS text markup that:
- Maintains simplicity through the paper/ink metaphor
- Enables parallel development through clear workstreams
- Ensures compatibility with iOS through flattening
- Delivers professional reliability through permanent commits

The modular architecture allows teams to work independently while maintaining clear integration points.