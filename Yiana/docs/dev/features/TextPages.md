# Text Pages Feature Documentation

**Purpose**: Technical documentation for the text page editor feature
**Audience**: Developers
**Last Updated**: 2025-10-08

---

## Overview

Text pages allow users to create typed notes that are rendered as PDF pages within documents. The feature follows a "pen and paper" philosophy - once finalized, text pages become permanent and cannot be edited.

## Architecture

### Components

**View Layer**:
- `TextPageEditorView.swift` - Main editor interface with toolbar and preview
- `MarkdownTextEditor.swift` - UITextView wrapper with markdown highlighting

**View Models**:
- `TextPageEditorViewModel.swift` - Manages editor state, drafts, and rendering

**Services**:
- `TextPagePDFRenderer.swift` - Renders markdown to PDF with layout options
- `TextPageRenderService.swift` - High-level rendering orchestration
- `TextPageLayoutSettings.swift` - Paper size and layout configuration
- `TextPageDraftManager.swift` - Draft persistence and recovery
- `ProvisionalPageManager.swift` - In-memory PDF composition for previews

### Data Flow

```
User Types → MarkdownTextEditor → TextPageEditorViewModel
                                          ↓
                                   scheduleLiveRender()
                                          ↓
                                  TextPagePDFRenderer
                                          ↓
                              latestRenderedPageData (Data?)
                                          ↓
                              ProvisionalPageManager
                                          ↓
                         Combined PDF (saved + provisional)
                                          ↓
                              DocumentViewModel.displayPDFData
                                          ↓
                                    PDFViewer
```

## Key Features

### 1. Live Preview with Provisional Pages

**Implementation**: `ProvisionalPageManager.swift`

While editing, the markdown is rendered to PDF and shown in the main document view without writing to disk.

```swift
// DocumentViewModel coordinates provisional display
func setProvisionalPreviewData(_ data: Data?) async {
    await provisionalManager.updateProvisionalData(data)
    await refreshDisplayPDF()
}

private func refreshDisplayPDF() async {
    let result = await provisionalManager.combinedData(using: pdfData)
    await MainActor.run {
        self.displayPDFData = result.data ?? pdfData
        self.provisionalPageRange = result.provisionalRange
    }
}
```

**Performance**:
- PDF composition: ~20-50ms (typical documents)
- Cache hit: <1ms (when saved/provisional unchanged)
- Cache invalidation: Hash-based on Data

See: ADR-002 for architectural details

### 2. Draft Management

**Implementation**: `TextPageEditorViewModel.swift`

Drafts are automatically saved and can be recovered if the app crashes or user navigates away.

```swift
enum DraftState {
    case none           // No draft exists
    case creating       // Draft being written (not saved yet)
    case saved          // Draft saved to disk
    case recovered      // Draft recovered from previous session
}
```

**Draft Lifecycle**:
1. User opens text editor → `loadDraftIfAvailable()`
2. User types → `scheduleAutosave()` (debounced, default 2s interval)
3. User exits → `flushDraftNow()` to ensure latest saved
4. User finalizes → Draft deleted, PDF written to document

**Storage**: Drafts stored via `TextPageDraftManager` with document URL as key

### 3. Markdown Rendering

**Implementation**: `TextPagePDFRenderer.swift`

Supports subset of markdown:
- Headers (H1, H2, H3)
- Bold (`**text**`)
- Italic (`*text*`)
- Bulleted lists (`- item`)
- Numbered lists (`1. item`)
- Blockquotes (`> quote`)
- Horizontal rules (`---`)

**Rendering Options**:
```swift
struct TextPageRenderOptions {
    var paperSize: TextPagePaperSize    // A4, US Letter, etc.
    var margins: TextPageEdgeInsets     // Top/bottom/left/right
    var baseFont: UIFont                // Base font for body text
    var headerFont: UIFont?             // Optional header font
    var lineSpacing: CGFloat            // Line height multiplier
}
```

**Default Paper Size**: A4 (595.2 × 841.8 points) - configurable in `TextPageLayoutSettings`

### 4. Toolbar Actions with Queue Pattern

**Implementation**: `MarkdownTextEditor.swift` Coordinator

Toolbar formatting actions (bold, italic, lists) are queued to prevent crashes from SwiftUI state mutation during view updates.

```swift
class Coordinator {
    private var toolbarActionQueue: [TextPageEditorAction] = []
    private var isProcessingToolbarAction = false

    func handle(action: TextPageEditorAction, on textView: UITextView) {
        dispatchPrecondition(condition: .onQueue(.main))
        toolbarActionQueue.append(action)
        guard !isProcessingToolbarAction else { return }  // Re-entrancy guard
        processNextToolbarAction(on: textView)
    }

    private func processNextToolbarAction(on textView: UITextView) {
        // ... serial processing with lifecycle checks
    }
}
```

**Key Principles**:
- Queue in Coordinator, not SwiftUI `@State`
- Re-entrancy guard prevents infinite loops
- Lifecycle checks (`textView.window != nil`) prevent crashes
- Serial processing with recursive `DispatchQueue.main.async`

See: ADR-003 for architectural details

### 5. Split View Preview (iPad)

**Implementation**: `TextPageEditorView.swift`

On iPad with regular horizontal size class, shows editor and preview side-by-side. On iPhone or compact iPad, toggles between editor and preview.

```swift
var contentStack: some View {
    let isCompact = horizontalSizeClass == .compact || verticalSizeClass == .compact
    if isCompact {
        singleColumnContent  // Editor OR preview
    } else {
        splitContent  // Editor AND preview
    }
}
```

**Preview Modes**:
- `MarkdownPreview` - Attributed string preview (lightweight)
- `RenderedPagePreview` - Actual PDF preview (accurate to final output)

## File Format

### Text Page in PDF

Text pages are rendered to PDF pages using Core Graphics:

```swift
// PDF rendering context
UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
    context.beginPage()
    // Draw header (timestamp, page number)
    drawHeader(...)
    // Draw markdown-formatted body
    drawBody(attributedString, ...)
}
```

### Metadata Integration

When text page is finalized, plain text extracted for OCR/search:

```swift
await documentViewModel.appendTextPage(
    markdown: content,
    appendPlainTextToMetadata: true,
    cachedRenderedPage: latestRenderedPageData,
    cachedPlainText: latestRenderedPlainText
)
```

## State Management

### TextPageEditorViewModel Published Properties

```swift
@Published var content: String              // Markdown content
@Published var state: DraftState            // Draft lifecycle state
@Published var showPreview: Bool            // Preview visibility
@Published var latestRenderedPageData: Data?   // Provisional PDF
@Published var liveRenderError: String?     // Render errors
```

### Callbacks

```swift
var onDraftStateChange: ((DraftState) -> Void)?
var onPreviewRenderUpdated: ((Data?) -> Void)?
```

## Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| Keystroke → Highlighting | <16ms | Syntax highlighting updates |
| Content change → Render schedule | 0ms | Debounced, actual render delayed |
| Render markdown → PDF | 50-200ms | Depends on content length |
| PDF composition (cache miss) | 20-50ms | Combine saved + provisional |
| PDF composition (cache hit) | <1ms | Hash-based cache |
| Draft autosave | 10-50ms | Write to disk |

## Common Patterns

### Triggering Toolbar Action

```swift
// From TextPageEditorView
Button(action: {
    pendingAction = .toggleBold
}) {
    Image(systemName: "bold")
}

// Propagates to MarkdownTextEditor → Coordinator
```

### Changing Paper Size

```swift
// User changes setting in TextPageLayoutSettings
TextPageLayoutSettings.shared.setPreferredPaperSize(.usLetter)

// Editor responds
viewModel.refreshRenderForPaperSizeChange()

// Triggers new render with updated paper size
```

### Finalizing Text Page

```swift
// User taps "Done" in editor
await viewModel.flushDraftNow()  // Ensure draft saved

// Parent (DocumentEditView) calls:
await finalizeTextPageIfNeeded()

// Appends to document, deletes draft, clears provisional
```

## Testing Considerations

### Unit Tests

- `TextPagePDFRenderer` - Test markdown parsing and PDF generation
- `TextPageEditorViewModel` - Test draft lifecycle state transitions
- `ProvisionalPageManager` - Test cache invalidation logic

### Integration Tests

- End-to-end: Create text page → Type content → Finalize → Verify PDF in document
- Draft recovery: Create draft → Kill app → Reopen → Verify draft recovered
- Multi-page: Create multiple provisional pages → Verify page ranges

### Manual Testing

- Performance: Large documents (50+ pages) with provisional page composition
- Edge cases: Empty text page, text page with only whitespace
- Platform: iPad split view, iPhone single view, macOS

## Known Limitations

1. **Single draft at a time**: Only one provisional text page per document
2. **No inline images**: Markdown image syntax not supported (images must be scanned pages)
3. **Limited markdown**: Subset of markdown (no tables, code blocks, etc.)
4. **No post-finalization editing**: Once finalized, text pages are permanent PDFs

## Future Enhancements

**Possible improvements**:
- Multiple provisional pages support (would need array of drafts + ranges)
- Extended markdown syntax (tables, code blocks, footnotes)
- Custom fonts/themes
- Export text page as standalone markdown file

**Migration path for multiple drafts**: Change `provisionalData: Data?` to `provisionalPages: [Data]` in ProvisionalPageManager

## Related Documentation

- **ADR-002**: Provisional Page Composition architecture
- **ADR-003**: Toolbar Action Queue pattern
- **User Docs**: `docs/user/Features.md` - Text Pages section
- **Code**:
  - `Yiana/Views/TextPageEditorView.swift`
  - `Yiana/Views/MarkdownTextEditor.swift`
  - `Yiana/ViewModels/TextPageEditorViewModel.swift`
  - `Yiana/Services/TextPagePDFRenderer.swift`
  - `Yiana/Services/ProvisionalPageManager.swift`

## Debugging

### Common Issues

**Issue**: Preview not updating
- Check: `latestRenderedPageData` is being set
- Check: `scheduleLiveRender()` being called on content change
- Debug: Add logging in `TextPagePDFRenderer.render()`

**Issue**: Toolbar actions crash
- Check: `TextPageEditorAction` is Equatable
- Check: Queue depth warnings in console (>8 = problem)
- Debug: Review `MarkdownTextEditor.Coordinator` queue processing

**Issue**: Draft not recovering
- Check: `TextPageDraftManager` file permissions
- Check: Document URL stable across sessions
- Debug: Print draft directory contents

### Debug Logging

```swift
#if DEBUG
// In TextPageEditorViewModel
print("📝 Draft state: \(state)")
print("📝 Render scheduled, debounce: \(autosaveInterval)s")

// In ProvisionalPageManager
print("📄 Cache hit: \(cachedCombinedData != nil)")
print("📄 Combining \(savedPageCount) saved + \(provisionalCount) provisional")
#endif
```
