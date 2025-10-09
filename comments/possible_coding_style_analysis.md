# Yiana Coding Style Guide

## Core Principles

1. **Simplicity over cleverness** - Trust mature frameworks like PDFKit to handle edge cases
2. **Platform-specific is OK** - Don't force cross-platform abstractions when platform-specific code is clearer
3. **1-based indexing for humans** - Use 1-based page numbers everywhere except PDFKit API boundaries
4. **Wrapper functions for consistency** - Use extension wrappers to encapsulate external API quirks

## Architecture Decisions

### Page Numbering Convention
- **Always use 1-based page numbers** in:
  - User interfaces ("Page 1 of 10")
  - OCR JSON storage
  - Search results
  - Internal state variables
  - API responses

- **Only convert to 0-based** at PDFKit boundaries using our wrapper extensions
- **Document the convention** with comments like `// 1-based page number`

### PDFKit Wrapper Pattern
```swift
// Good - using wrapper
pdfDocument.getPage(number: pageNum)  // 1-based
pdfView.goToPage(number: currentPage)  // 1-based

// Bad - direct PDFKit calls
pdfDocument.page(at: pageNum - 1)  // Error-prone conversion
```

### Mixed Page Size Handling

Documents may contain mixed page sizes (A4 and US Letter). Use appropriate tolerance for scale factor comparisons:

```swift
// ✅ GOOD - tolerance accommodates mixed page sizes
let currentScale = pdfView.scaleFactor
let fitScale = pdfView.scaleFactorForSizeToFit
let tolerance: CGFloat = 0.10  // Handles A4 (595x842) + US Letter (612x792)
let isAtFitZoom = abs(currentScale - fitScale) < tolerance

// ❌ BAD - too strict, fails on mixed page sizes
let isAtFitZoom = abs(currentScale - fitScale) < 0.01
```

**Rationale**:
- A4 and US Letter have different aspect ratios (0.707 vs 0.773)
- On iPad Pro 12.9", scale factor difference can reach 0.097
- Tolerance of 0.10 covers all devices with safety margin
- Trade-off: Users can zoom ~10% before gesture disabled (acceptable)

See: `Yiana/Views/PDFViewer.swift`, ADR-001

### State Management
- **Avoid complex state synchronization** - Let PDFKit manage its own state
- **Use @State sparingly** - Prefer bindings and coordinator patterns
- **Defer state updates** to avoid "modifying state during view update" errors:
```swift
DispatchQueue.main.async {
    self.totalPages = document.pageCount
}
```

### Error Prevention Patterns

#### Search Result Structure
```swift
struct SearchResult {
    let pageNumber: Int?  // Always 1-based, optional for title-only matches
}
```

#### Date Handling
- **Use default Apple date encoding** (TimeInterval since 2001)
- **Avoid custom date strategies** - They cause ecosystem inconsistencies
```swift
let decoder = JSONDecoder()  // Use default, not custom date strategy
```

## SwiftUI Best Practices

### UIViewRepresentable Coordination Patterns

When wrapping UIKit views in SwiftUI, follow these patterns to avoid crashes:

#### DO NOT mutate @State during updateUIView
```swift
// ❌ BAD - causes AttributeGraph cycles and crashes
func updateUIView(_ uiView: UITextView, context: Context) {
    if let action = pendingAction {
        apply(action, to: uiView)
        DispatchQueue.main.async {
            self.pendingAction = nil  // ❌ Mutating state during view update
        }
    }
}
```

#### DO use Coordinator-owned action queue
```swift
// ✅ GOOD - queue in Coordinator, not SwiftUI state
class Coordinator {
    private var actionQueue: [Action] = []
    private var isProcessing = false

    func handle(action: Action, on view: UIView) {
        actionQueue.append(action)
        guard !isProcessing else { return }  // Re-entrancy guard
        processNext(on: view)
    }

    private func processNext(on view: UIView) {
        guard !actionQueue.isEmpty else { return }
        guard view.window != nil else {  // Lifecycle check
            actionQueue.removeAll()
            return
        }

        isProcessing = true
        let next = actionQueue.removeFirst()

        DispatchQueue.main.async { [weak self, weak view] in
            defer { self?.isProcessing = false }
            guard let self, let view else { return }
            self.apply(next, to: view)
            self.processNext(on: view)  // Recursive
        }
    }
}
```

**Key principles**:
- Queue actions in Coordinator, not SwiftUI `@State`
- Use re-entrancy guard (`isProcessing` flag)
- Check lifecycle with `view.window != nil`
- Use `weak` references to prevent retain cycles
- Process serially with recursive `DispatchQueue.main.async`
- Always use `defer` to clean up state

See: `Yiana/Views/MarkdownTextEditor.swift`, ADR-003

### Platform-Specific Views
Create separate views for iOS and macOS rather than complex conditionals:
```swift
// Good
#if os(macOS)
struct MacPDFViewer: View { ... }
#endif

// Avoid
struct PDFViewer: View {
    #if os(iOS)
    // iOS code
    #else
    // macOS code
    #endif
}
```

### In-Memory PDF Composition

When combining PDFs without writing to disk (e.g., provisional page composition):

#### Use caching to avoid repeated composition
```swift
// ✅ GOOD - cache with hash-based invalidation
class ProvisionalPageManager {
    private var cachedCombinedData: Data?
    private var cachedSavedHash: Int?
    private var cachedProvisionalHash: Int?

    func combinedData(using saved: Data?) -> Data? {
        let savedHash = saved?.hashValue
        let provisionalHash = provisionalData?.hashValue

        // Check cache validity
        if cachedSavedHash == savedHash && cachedProvisionalHash == provisionalHash {
            return cachedCombinedData  // ✅ Fast path
        }

        // Build combined PDF (expensive)
        let combined = buildCombined(saved: saved, provisional: provisionalData)

        // Update cache
        cachedCombinedData = combined
        cachedSavedHash = savedHash
        cachedProvisionalHash = provisionalHash

        return combined
    }
}
```

**Key principles**:
- Cache expensive PDF composition operations
- Use hash-based invalidation (acceptable collision risk vs performance gain)
- Combine PDFs by copying pages (not document-level concatenation)
- Track page ranges for visual indicators
- Keep provisional data in memory only (write to disk on finalization)

**Performance**: Typical composition ~20-50ms, cache hit <1ms

See: `Yiana/Services/ProvisionalPageManager.swift`, ADR-002

### View Representables
Keep them simple and focused:
```swift
// Good - simple, single responsibility
struct SimpleMacPDFViewer: NSViewRepresentable {
    let pdfData: Data
    @Binding var currentPage: Int  // 1-based

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.canGoToPage(number: currentPage) {
            nsView.goToPage(number: currentPage)
        }
    }
}
```

## OCR and Search

### OCR JSON Structure
```json
{
  "pages": [
    {
      "pageNumber": 1,  // Always 1-based
      "text": "...",
      "textBlocks": [...]
    }
  ]
}
```

### Search Flow
1. Search both title and OCR content
2. Return results with 1-based page numbers
3. Navigate using `DocumentNavigationData` with page context
4. Open PDF at specific page using wrapper methods

## File Organization

### Extensions
Place API wrappers in `Extensions/` folder:
- `PDFDocument+PageIndexing.swift` - 1-based page wrapper

### Services
- `DocumentRepository.swift` - Document storage management
- `OCRProcessor.swift` - OCR processing logic
- `ScanningService.swift` - Document scanning

### View Models
- Keep search logic in `DocumentListViewModel`
- Navigation state in view models, not views

## Testing Conventions

### Page Number Tests
Always test boundary conditions with 1-based indexing:
```swift
// Test first page
XCTAssertEqual(pdfDocument.getPage(number: 1), firstPage)

// Test last page
XCTAssertEqual(pdfDocument.getPage(number: pageCount), lastPage)

// Test out of bounds
XCTAssertNil(pdfDocument.getPage(number: 0))  // Invalid
XCTAssertNil(pdfDocument.getPage(number: pageCount + 1))  // Invalid
```

## Common Pitfalls to Avoid

1. **Don't mix indexing conventions** - Pick 1-based and stick with it
2. **Don't over-engineer state management** - SwiftUI + PDFKit handle most cases
3. **Don't modify state during view updates** - Use async dispatch
4. **Don't create cross-platform abstractions unnecessarily** - Platform-specific is fine
5. **Don't assume OCR exists** - Always check for OCR JSON before reading

## Debugging Tips

### State Update Issues
If you see "Modifying state during view update":
1. Move state changes to `.task` or `.onAppear`
2. Use `DispatchQueue.main.async`
3. Consider using a simpler view structure

### Page Navigation Issues
1. Check if page numbers are 1-based throughout
2. Verify wrapper methods are being used
3. Add logging: `print("Navigating to page \(pageNum) (1-based)")`

### Search Issues
1. Verify OCR JSON exists and is readable
2. Check page numbers in OCR match expected format (1-based)
3. Ensure `DocumentNavigationData` is passed correctly

## Future Considerations

- When adding new features, maintain 1-based convention
- Consider creating more wrapper extensions for other APIs
- Keep platform-specific optimizations rather than forcing unified code
- Document any deviations from these patterns with clear reasons
