# SwiftUI PDFKit Integration: Timing Issues & Solutions

## Executive Summary

This document captures the resolution of a critical AttributeGraph cycle issue that occurred when updating PDFKit views within SwiftUI. The problem manifested as console spam (`AttributeGraph: cycle detected`) and required careful coordination between SwiftUI state updates and PDFKit rendering.

## The Problem

### Symptoms
- Console flooded with `AttributeGraph: cycle detected through attribute XXXXXX` warnings
- Occurred specifically after markup saves when PDF data was updated
- Performance degradation and potential UI glitches

### Root Cause
Every markup save triggered a cascade of synchronous updates:
1. Markup save → `viewModel.pdfData` change
2. PDFViewer's `updateUIView` called immediately
3. State updates (`currentPage`, `totalPages`) triggered during SwiftUI layout phase
4. SwiftUI detected circular dependency and logged warnings

## Debug Methodology

### 1. Isolation Testing
```swift
// Added debug logging to track the exact call sequence
print("🟡 DEBUG PDFViewer.updateUIView:")
print("   - isReloadingDocument: \(context.coordinator.isReloadingDocument)")
print("   - pdfView.document?.pageCount: \(pdfView.document?.pageCount ?? 0)")
print("   - totalPages binding: \(totalPages)")
```

### 2. Breakpoint Analysis
Set breakpoints at:
- `DocumentViewModel.pdfData` setter
- `PDFKitView.updateUIView`
- `Coordinator.pageChanged`

This revealed multiple synchronous `updateUIView` passes happening during a single update cycle.

### 3. Empirical Verification
Rather than theorizing about the cause, we:
- Temporarily disabled components (page indicator, navigation bindings)
- Re-enabled them one by one to identify the exact trigger
- Confirmed the issue was in the PDF reload sequence, not the UI overlays

## The Solution

### Part 1: Signature-Based Change Detection
```swift
// Use byte count as a stable signature (hashValue was unreliable)
let signature = pdfData.count
if context.coordinator.pdfDataSignature != signature {
    context.coordinator.pdfDataSignature = signature
    // Proceed with reload
}
```

### Part 2: Async Document Reload with Guards
```swift
context.coordinator.isReloadingDocument = true
DispatchQueue.main.async {
    // Critical: Clear document first to bust PDFKit's render cache
    pdfView.document = nil
    pdfView.document = document

    // Force PDFKit to redraw (essential for markup visibility)
    pdfView.documentView?.setNeedsDisplay()
    pdfView.layoutDocumentView()

    // Update SwiftUI state AFTER layout completes
    self.totalPages = pageCount
    if self.currentPage != clamped {
        self.currentPage = clamped
    }

    // Clear the guard flag
    context.coordinator.isReloadingDocument = false
}
```

### Part 3: Notification Guards
```swift
@objc func pageChanged(_ notification: Notification) {
    // Don't process notifications during reload
    if isReloadingDocument { return }

    // Prevent duplicate updates
    if lastReportedPageIndex == pageIndex { return }
    lastReportedPageIndex = pageIndex

    // Now safe to update SwiftUI state
    DispatchQueue.main.async {
        if self.parent.currentPage != pageIndex {
            self.parent.currentPage = pageIndex
        }
    }
}
```

## Critical PDFKit Insights

### Cache Management
PDFKit aggressively caches rendered pages. After updating PDF data with markup:
```swift
// ❌ Wrong: PDFKit may show cached version without markup
pdfView.document = newDocument

// ✅ Correct: Force cache invalidation
pdfView.document = nil  // Clear first
pdfView.document = newDocument  // Then set new
pdfView.documentView?.setNeedsDisplay()  // Force redraw
```

### Timing Considerations
- PDFKit sends `PDFViewPageChanged` notifications **synchronously** during document assignment
- These notifications can trigger SwiftUI state updates at unsafe times
- Always guard notification handlers with async dispatch and reload flags

## Testing Checklist

- [ ] Open document with existing PDF content
- [ ] Add markup annotations
- [ ] Save markup
- [ ] Verify no AttributeGraph warnings in console
- [ ] Confirm markup is visible immediately after save
- [ ] Test page navigation during and after markup save
- [ ] Verify search index updates after save

## Guidelines for Future PDFKit Work

### DO:
- Always use `DispatchQueue.main.async` for SwiftUI state updates from PDFKit callbacks
- Implement coordinator guards (`isReloadingDocument`) to prevent cascading updates
- Clear `pdfView.document` before setting new documents when content changes
- Use stable signatures (byte count) rather than hash values for change detection
- Add comprehensive debug logging during development

### DON'T:
- Update `@State` or `@Binding` properties synchronously in `updateUIView`
- Trust PDFKit's rendering cache after document updates
- Assume PDFKit notifications fire asynchronously
- Skip empirical testing in favor of theoretical solutions

## Related Issues

- SwiftUI's `updateUIView` can be called multiple times per update cycle
- `NotificationCenter` observers fire synchronously unless explicitly dispatched
- PDFKit's `layoutDocumentView()` must be called after document changes for proper rendering

## Code Locations

- Main fix: `Yiana/Yiana/Views/PDFViewer.swift:78-134`
- Coordinator guards: `Yiana/Yiana/Views/PDFViewer.swift:348-390`
- Navigation handling: `Yiana/Yiana/Views/PDFViewer.swift:318-340`

## Lessons Learned

This issue highlighted the importance of:
1. **Empirical debugging over theoretical analysis** - The actual problem was different from initial assumptions
2. **Understanding framework internals** - PDFKit's caching behavior was non-obvious
3. **Careful timing management** - SwiftUI has strict rules about when state can be modified
4. **Comprehensive solutions** - Fixing the cycles without addressing rendering would have left markup invisible