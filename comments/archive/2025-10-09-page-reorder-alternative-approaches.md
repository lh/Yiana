# Page Reorder Alternative Approaches - After dataRepresentation() Failed

**Date**: 2025-10-09
**Context**: Attempted fix using `page.dataRepresentation()` failed - method doesn't exist on PDFPage
**Status**: Need alternative approach to preserve page content during reorder

---

## Why The Attempted Fix Failed

### The Problem

```swift
// Attempted code:
if let pageData = page.dataRepresentation(),  // ← ERROR: PDFPage has no dataRepresentation()
   let singleDoc = PDFDocument(data: pageData),
   let singlePage = singleDoc.page(at: 0) {
    // ...
}
```

**PDFKit API reality**:
- ✅ `PDFDocument` has `dataRepresentation()` → Returns entire PDF as Data
- ❌ `PDFPage` does NOT have `dataRepresentation()` → Can't serialize individual page
- ✅ `PDFPage` has `copy()` → Creates copy (but can fail/lose content)

### Available PDFPage Methods

```swift
class PDFPage {
    func copy() -> Any?  // Shallow copy, unreliable
    var bounds(for: PDFDisplayBox) -> CGRect  // Geometry
    var string -> String?  // Text content only
    func draw(with box: PDFDisplayBox, to context: CGContext)  // Render to graphics context
    var annotations: [PDFAnnotation]  // Get/set annotations
    // No dataRepresentation() ❌
}
```

---

## Alternative Approaches

### Approach 1: Create Single-Page PDFDocument Wrapper

**Concept**: To serialize a single page, wrap it in a temporary PDFDocument

```swift
// Create temporary document with just this page
let tempDoc = PDFDocument()
tempDoc.insert(page, at: 0)  // Add page to empty document

// Now serialize the DOCUMENT (which contains one page)
if let docData = tempDoc.dataRepresentation(),
   let freshDoc = PDFDocument(data: docData),
   let freshPage = freshDoc.page(at: 0) {
    newDocument.insert(freshPage, at: insertionIndex)
    insertionIndex += 1
    continue
}
```

**Pros**:
- ✅ Uses available PDFKit API
- ✅ Creates true deep copy via serialization
- ✅ Should preserve content

**Cons**:
- ⚠️ Creates temporary document for each page
- ⚠️ Might be slow
- ⚠️ **Critical issue**: `tempDoc.insert(page, at: 0)` might have same problem as direct insert!

**Will this work?**
- 🤔 Uncertain - if inserting page into `tempDoc` already corrupts it, serialization won't help
- Worth testing, but might not solve root issue

---

### Approach 2: Render Page to Image, Then Convert Back to PDF

**Concept**: Render page to bitmap, create new PDF from bitmap

```swift
// Get page dimensions
let pageRect = page.bounds(for: .mediaBox)

// Create graphics context and render page to image
let renderer = UIGraphicsImageRenderer(size: pageRect.size)
let pageImage = renderer.image { context in
    UIColor.white.setFill()
    context.fill(pageRect)

    let cgContext = context.cgContext
    cgContext.translateBy(x: 0, y: pageRect.size.height)
    cgContext.scaleBy(x: 1.0, y: -1.0)

    page.draw(with: .mediaBox, to: cgContext)
}

// Convert image to PDF page
if let pdfData = pageImage.pngData() {
    // Create PDF from image...
    // Then insert into newDocument
}
```

**Pros**:
- ✅ Guaranteed to capture visual content
- ✅ Creates truly independent page

**Cons**:
- ❌ Loses text selectability (becomes image)
- ❌ Loses vector graphics (becomes raster)
- ❌ Large file size increase
- ❌ Quality loss
- ❌ Not acceptable for production

**Assessment**: ❌ Too destructive, not a real solution

---

### Approach 3: Use PDFPage's Drawing Method with New Context

**Concept**: Create new blank page, draw old page content onto it

```swift
// This doesn't work either - PDFKit doesn't expose page creation from scratch
// You can only get pages from existing PDFDocuments
```

**Assessment**: ❌ Not possible with PDFKit API

---

### Approach 4: Fix at Document Level, Not Page Level

**Concept**: Instead of copying pages individually, rebuild entire document in new order

```swift
func reorderDocument(originalDoc: PDFDocument, newOrder: [Int]) -> PDFDocument? {
    // Strategy 1: Serialize entire document first
    guard let originalData = originalDoc.dataRepresentation() else { return nil }

    // Create fresh document from data (deep copy)
    guard let freshDoc = PDFDocument(data: originalData) else { return nil }

    // Now build result document in new order
    let resultDoc = PDFDocument()

    for originalIndex in newOrder {
        guard let page = freshDoc.page(at: originalIndex) else { continue }
        // Now copying from freshDoc, not originalDoc
        // This might work better?
        if let copied = page.copy() as? PDFPage {
            resultDoc.insert(copied, at: resultDoc.pageCount)
        }
    }

    return resultDoc
}
```

**Key insight**: Copy from freshDoc (created from serialized data), not originalDoc

**Pros**:
- ✅ Works with available PDFKit API
- ✅ Serialization creates fresh document without provisional page complications
- ✅ Pages from fresh document might copy better

**Cons**:
- ⚠️ Serializes entire document (might be slow for large docs)
- 🤔 Still relies on `page.copy()` working

**Assessment**: 🤔 Worth trying - might be the best available approach

---

### Approach 5: Don't Copy Pages - Use Index Remapping

**Concept**: Don't create new document, just track new page order and apply it

```swift
// Instead of creating new PDFDocument with reordered pages
// Keep original document and just remap indices

class ReorderedPDFDocument {
    let originalDocument: PDFDocument
    let indexMapping: [Int: Int]  // newIndex -> originalIndex

    func page(at index: Int) -> PDFPage? {
        let originalIndex = indexMapping[index] ?? index
        return originalDocument.page(at: originalIndex)
    }
}
```

**Pros**:
- ✅ No copying needed
- ✅ No data loss possible
- ✅ Fast

**Cons**:
- ❌ Requires refactoring entire document handling
- ❌ PDFKit expects actual PDFDocument, not wrapper
- ❌ Saving requires rebuilding document anyway
- ❌ Complex to maintain

**Assessment**: ❌ Too invasive, not practical

---

## The Real Root Cause (Revisited)

Let's step back and reconsider what's actually happening.

### Original Hypothesis from Bug Analysis

**The provisional page theory**:
1. Markdown text pages are **provisional** (stored separately from main PDF)
2. Reorder operates on `pdfData` (main PDF without provisional)
3. Provisional pages are tracked by index
4. Reorder breaks index mapping
5. Content appears lost

### Testing This Theory

**Key questions**:
1. At the time of reorder, are the text pages **already committed** to `pdfData`?
2. Or are they still **provisional**?
3. Is the reorder operating on `pdfData` or `displayPDFData`?

**To verify**: Add debug logging before reorder:
```swift
print("DEBUG Reorder: pdfData page count:", pdfData?.count)
print("DEBUG Reorder: displayPDFData page count:", displayPDFData?.count)
print("DEBUG Reorder: hasProvisionalPages:", viewModel.hasProvisionalPages)

// For each page in document being reordered:
for i in 0..<document.pageCount {
    let text = document.page(at: i)?.string ?? "<no text>"
    print("DEBUG Reorder: Page \(i) text preview:", text.prefix(50))
}
```

**If text previews show content BEFORE reorder**, but `<no text>` AFTER:
→ The copy operation is the problem

**If text previews show `<no text>` BEFORE reorder**:
→ The provisional page theory is correct - reordering wrong document

---

## Most Promising Approach: Document-Level Serialization

### Implementation Strategy

```swift
func reorderPages(from sourceIndexSet: IndexSet, to destination: Int) {
    guard let viewModel = viewModel else { return }

    // 1. Get the current document (with all content)
    let sourceData = viewModel.displayPDFData ?? viewModel.pdfData
    guard let sourceData = sourceData else { return }

    // 2. Create fresh document from serialized data
    //    This ensures we're working with committed, stable content
    guard let freshDocument = PDFDocument(data: sourceData) else { return }

    // 3. Calculate new page order
    var pageOrder = Array(0..<freshDocument.pageCount)
    // ... apply sourceIndexSet and destination to pageOrder array ...

    // 4. Build new document in correct order
    let reorderedDocument = PDFDocument()
    for originalIndex in pageOrder {
        guard let page = freshDocument.page(at: originalIndex) else { continue }

        // Try to copy page
        if let copiedPage = page.copy() as? PDFPage {
            reorderedDocument.insert(copiedPage, at: reorderedDocument.pageCount)
        } else {
            // If copy fails, we're stuck - log and try direct insert
            print("ERROR: Failed to copy page \(originalIndex)")
            reorderedDocument.insert(page, at: reorderedDocument.pageCount)
        }
    }

    // 5. Save reordered document
    guard let newData = reorderedDocument.dataRepresentation() else { return }

    // 6. Update viewModel (this clears provisional pages!)
    viewModel.pdfData = newData
    viewModel.hasChanges = true

    // 7. Clear provisional state if any
    // viewModel.clearProvisionalPages() or similar
}
```

### Key Aspects

**Step 1-2**: Work from `displayPDFData` (includes provisional), serialize to get clean document

**Step 3-4**: Reorder pages from fresh document (not original)

**Step 5-6**: Save result, replacing `pdfData`

**Critical**: This **commits provisional pages** as side effect
- Provisional pages are in `displayPDFData`
- We serialize `displayPDFData` → Creates PDF with all content
- Save as new `pdfData` → Provisional pages are now permanent
- This is **probably correct behavior** for reorder

---

## Alternative: Block Reorder for Provisional Pages

### The Conservative Approach

**Philosophy**: Don't try to fix reorder for provisional pages, just prevent it

```swift
func canReorderPages() -> Bool {
    guard let viewModel = viewModel else { return false }

    // Check if there are provisional pages
    if viewModel.provisionalPageRange != nil {
        return false  // Block reorder
    }

    return true
}

// In UI:
.onMove { from, to in
    guard canReorderPages() else {
        showAlert("Please save draft pages before reordering")
        return
    }
    reorderPages(from: from, to: to)
}
```

**Pros**:
- ✅ Prevents data loss
- ✅ Simple to implement
- ✅ Makes requirements clear to user

**Cons**:
- ❌ Reduces functionality
- ❌ User must manually commit drafts first

**Assessment**: ✅ **Good short-term fix while investigating deeper issue**

---

## Recommended Next Steps

### Immediate: Add Diagnostic Logging

**Before attempting any fix**, understand what's actually happening:

```swift
func reorderPages(from: IndexSet, to: Int) {
    #if DEBUG
    print("\n=== REORDER DEBUG START ===")
    print("Source indices:", from)
    print("Destination:", to)

    if let pdfData = viewModel?.pdfData,
       let pdfDoc = PDFDocument(data: pdfData) {
        print("pdfData page count:", pdfDoc.pageCount)
        for i in 0..<pdfDoc.pageCount {
            let text = pdfDoc.page(at: i)?.string ?? "<no text>"
            print("pdfData page \(i):", text.prefix(80))
        }
    } else {
        print("pdfData: nil or invalid")
    }

    if let displayData = viewModel?.displayPDFData,
       let displayDoc = PDFDocument(data: displayData) {
        print("displayPDFData page count:", displayDoc.pageCount)
        for i in 0..<displayDoc.pageCount {
            let text = displayDoc.page(at: i)?.string ?? "<no text>"
            print("displayPDFData page \(i):", text.prefix(80))
        }
    } else {
        print("displayPDFData: nil or matches pdfData")
    }

    print("Provisional range:", viewModel?.provisionalPageRange ?? "none")
    print("=== REORDER DEBUG END ===\n")
    #endif

    // ... actual reorder code ...
}
```

**This will reveal**:
1. Do pages have content in `pdfData` or only in `displayPDFData`?
2. Is provisional range set?
3. Does content exist before reorder attempt?

### Short-Term: Prevent Reorder with Provisional Pages

**Add safety check**:

```swift
// In PageManagementView or wherever reorder is triggered
guard viewModel.provisionalPageRange == nil else {
    showAlert(
        title: "Save Draft Pages First",
        message: "Please save or discard draft pages before reordering."
    )
    return
}

// Proceed with reorder
```

### Medium-Term: Implement Reorder from displayPDFData

**If diagnostic logging shows**:
- Content exists in `displayPDFData`
- But not in `pdfData`
- Provisional pages are present

**Then implement**:
```swift
func reorderPages(...) {
    // 1. Work from displayPDFData (has all content)
    let sourceData = viewModel.displayPDFData ?? viewModel.pdfData
    guard let freshDoc = PDFDocument(data: sourceData) else { return }

    // 2. Reorder pages
    let reorderedDoc = buildReorderedDocument(from: freshDoc, ...)

    // 3. Save as new pdfData (commits provisional pages)
    guard let newData = reorderedDoc.dataRepresentation() else { return }
    viewModel.pdfData = newData

    // 4. Clear provisional state
    viewModel.clearProvisionalPages()  // Or equivalent
}
```

### Long-Term: Fix Provisional Page Architecture

**Root issue**: Provisional pages tracked by index, breaks on reorder

**Solution**: Track by UUID or content hash
```swift
struct ProvisionalPage {
    let id: UUID
    let data: Data
    var insertAfterPageWithID: UUID?  // Instead of index
}
```

**But**: This is major refactor, defer until core functionality stable

---

## Comparison of Approaches

| Approach | Complexity | Safety | Performance | Preserves Features |
|----------|-----------|--------|-------------|-------------------|
| **Block reorder with provisional** | Low | High | N/A | No (blocks feature) |
| **Reorder from displayPDFData** | Medium | Medium | Good | Yes (auto-commits) |
| **Document-level serialization** | Medium | Medium | Slow | Yes |
| **Single-page wrapper** | Medium | Low | Medium | Maybe |
| **Render to image** | High | Low | Slow | No (lossy) |
| **Index remapping** | Very High | High | Fast | Yes (but invasive) |

**Recommendation**: Start with **block reorder**, then implement **reorder from displayPDFData** once confirmed

---

## Critical Question to Answer First

### Is page.copy() Actually Failing?

**Test this directly**:

```swift
func testPageCopy() {
    // Get a text page that's losing content
    let textPage = document.page(at: 0)

    print("Original page text:", textPage?.string ?? "<no text>")

    // Try to copy it
    if let copied = textPage?.copy() as? PDFPage {
        print("Copied page text:", copied.string ?? "<no text>")

        // Try inserting into new document
        let newDoc = PDFDocument()
        newDoc.insert(copied, at: 0)

        print("After insert, page text:", newDoc.page(at: 0)?.string ?? "<no text>")
    } else {
        print("ERROR: page.copy() returned nil")
    }
}
```

**If this test shows**:
- Original: "Page 1 content"
- Copied: "Page 1 content"
- After insert: "Page 1 content"

**Then**: `page.copy()` works fine, issue is elsewhere (likely provisional page tracking)

**If this test shows**:
- Original: "Page 1 content"
- Copied: `<no text>`
- After insert: `<no text>`

**Then**: `page.copy()` is broken for these page types, need alternative copy method

---

## Summary

### What We Learned

- ❌ `PDFPage.dataRepresentation()` doesn't exist
- 🤔 Alternative approaches exist but all have tradeoffs
- 🔍 Need diagnostic logging to understand actual failure mode

### Recommended Path Forward

1. **Add diagnostic logging** to understand what's happening
2. **Implement safety block** to prevent reorder with provisional pages
3. **Based on logs, implement**:
   - If content exists in `pdfData`: Fix page copying issue
   - If content only in `displayPDFData`: Reorder from display data instead
4. **Test thoroughly** before removing safety block

### Most Likely Fix

**Hypothesis**: Content is in `displayPDFData` but not `pdfData`

**Solution**:
```swift
// Reorder from displayPDFData
let sourceData = viewModel.displayPDFData ?? viewModel.pdfData
let freshDoc = PDFDocument(data: sourceData)
// ... reorder freshDoc ...
// Save as new pdfData (commits provisional)
```

**This should work** and is the cleanest approach available with PDFKit API.

Would you like me to help craft the diagnostic logging code to understand what's actually happening?
