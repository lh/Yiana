# Lessons Learned

## Multiplatform Architecture (2025-07-15)

### Problem
Attempted to create a complex protocol-based architecture to share document code between iOS and macOS platforms. This led to:
- Conflicts between UIDocument (non-optional fileURL) and NSDocument (optional fileURL)
- Complex conditional compilation
- Overengineered abstractions that didn't add value

### Solution
iOS/iPadOS and macOS apps should:
- Share the same data format (.yianazip, DocumentMetadata)
- Have separate implementations using their native document classes
- Use platform idioms directly without forcing abstraction

### Key Insight
Don't force shared code when platforms have different paradigms. It's better to have clean, platform-specific implementations that handle the same data format than complex abstractions that fight the frameworks.

### What to do instead
- Use conditional compilation at the file level (#if os(iOS) around entire files)
- Share only data structures and business logic that truly makes sense
- Let each platform use its native patterns

## SwiftUI/PDFKit AttributeGraph Cycles (2025-01-05)

### Problem
After markup saves, console flooded with `AttributeGraph: cycle detected` warnings. Initial theories about "circular bindings" were wrong - the real issue was state mutations happening during SwiftUI's layout phase when PDFKit views were rebuilding.

### Symptoms
- Warnings appeared immediately after `viewModel.pdfData` updates
- Multiple `updateUIView` calls in rapid succession
- Markup annotations disappeared after saving (PDFKit cache issue)

### Root Cause
The sequence was:
1. Markup save triggers `pdfData` change
2. `updateUIView` called synchronously
3. State updates (`currentPage`, `totalPages`) fired during layout
4. SwiftUI detected state changes during view update → AttributeGraph cycle

### Solution (Three-Part Fix)
1. **Async document reload with coordinator guards:**
```swift
context.coordinator.isReloadingDocument = true
DispatchQueue.main.async {
    pdfView.document = nil  // Clear cache
    pdfView.document = document
    self.totalPages = pageCount  // Update state AFTER layout
    context.coordinator.isReloadingDocument = false
}
```

2. **Notification guards to prevent cascading updates:**
```swift
if isReloadingDocument { return }
if lastReportedPageIndex == pageIndex { return }
```

3. **PDFKit cache management** - Must nil out document first to force re-render

### Key Insights
- **Empirical debugging beats theoretical analysis** - Actual problem differed from assumptions
- **PDFKit aggressively caches rendered pages** - Need explicit cache invalidation
- **SwiftUI has strict timing rules** - State updates during layout cause cycles
- **Platform quirks matter** - Generic SwiftUI patterns don't always work with UIKit/AppKit views

### Debug Methodology That Worked
1. Add strategic logging to track call sequences
2. Set breakpoints at state mutation points
3. Isolate by temporarily disabling components
4. Re-enable one by one to find exact trigger
5. Fix both the cycle AND the rendering issue together

### What NOT to do
- Don't assume binding patterns are the problem
- Don't try to rewrite the architecture
- Don't update @State synchronously in updateUIView
- Don't trust PDFKit's render cache after document changes
- Don't skip empirical testing for theoretical solutions