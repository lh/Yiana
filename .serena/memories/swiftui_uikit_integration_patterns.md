# SwiftUI/UIKit Integration Patterns

## Critical Timing Issues

### AttributeGraph Cycles
**Problem:** State mutations during SwiftUI layout phase cause "AttributeGraph: cycle detected" warnings.

**Solution Pattern:**
```swift
// In updateUIView/updateNSView:
DispatchQueue.main.async {
    // State updates go here, AFTER layout completes
    self.someState = newValue
}
```

### Coordinator Guards
Always use coordinator pattern with guards for async operations:
```swift
class Coordinator {
    var isReloadingDocument = false
    var lastReportedValue: Int?
    
    func handleNotification() {
        if isReloadingDocument { return }
        if lastReportedValue == newValue { return }
        // Safe to update
    }
}
```

## PDFKit Specific Issues

### Cache Management
PDFKit caches rendered pages aggressively. After content changes:
```swift
// Force cache clear:
pdfView.document = nil
pdfView.document = newDocument
pdfView.documentView?.setNeedsDisplay()
pdfView.layoutDocumentView()
```

### Change Detection
Use byte count for stable signatures:
```swift
let signature = pdfData.count  // More stable than hashValue
if coordinator.pdfDataSignature != signature {
    // Document actually changed
}
```

## Debug Strategy

### For Timing Issues
1. Add debug logging with clear prefixes:
   ```swift
   print("🟡 DEBUG Component.method: state=\(state)")
   ```
2. Set breakpoints at state mutations
3. Isolate components (disable overlays, bindings)
4. Re-enable one by one
5. Fix timing AND rendering together

### Common Pitfalls
- Don't update @State/@Binding synchronously in updateUIView
- Don't trust framework caches after data changes
- Don't assume notifications are async (many are sync)
- Don't theorize - use empirical debugging

## Key Principles
1. **Defer state updates** - Never mutate during layout
2. **Guard everything** - Prevent cascading updates
3. **Clear caches explicitly** - Frameworks cache aggressively
4. **Test empirically** - Theory often differs from reality
5. **Log strategically** - Track exact call sequences