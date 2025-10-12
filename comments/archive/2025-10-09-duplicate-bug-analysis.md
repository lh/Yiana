# Duplicate Bug Analysis - Pages Appearing in Wrong Location

**Date**: 2025-10-09
**Issue**: Selecting page A and clicking duplicate produces A, B, C, C instead of A, A, B, C
**Status**: Root cause identified

---

## Symptom Summary

**Expected behavior**: Duplicate page A in document [A, B, C] → [A, A, B, C]
**Actual behavior**: Duplicate page A in document [A, B, C] → [A, B, C, C]

The duplicate appears at the **end** of the document instead of **after the original page**.

---

## Code Analysis

### DocumentEditView.swift:748-762

```swift
private func duplicateSelectedSidebarPages() {
    guard let viewModel else { return }
    let indices = Array(selectedSidebarPages)  // ← Converts Set to Array
    Task {
        await viewModel.duplicatePages(at: indices)
        await MainActor.run {
            exitSidebarSelection()
            updateSidebarDocument(with: viewModel.displayPDFData ?? viewModel.pdfData)
            if let target = indices.sorted().first.map({ min($0 + 1, currentDocumentPageCount(from: viewModel) - 1) }) {
                currentViewedPage = target
                navigateToPage = target
            }
        }
    }
}
```

**Key observation**: `let indices = Array(selectedSidebarPages)`

### DocumentViewModel.swift:220-253

```swift
func duplicatePages(at indices: [Int]) async {
    guard let currentData = pdfData, let document = PDFDocument(data: currentData) else { return }

    let sortedIndices = indices.sorted()  // ← Sorts indices in ascending order
    var insertedCount = 0

    for index in sortedIndices {
        let adjustedIndex = index + insertedCount
        guard adjustedIndex >= 0 && adjustedIndex < document.pageCount,
              let original = document.page(at: adjustedIndex) else { continue }

        let insertIndex = min(adjustedIndex + 1, document.pageCount)  // ← Insert after original
        if let copy = original.copy() as? PDFPage {
            document.insert(copy, at: insertIndex)
            insertedCount += 1  // ← Tracks cumulative insertions
        }
    }

    guard let updatedData = document.dataRepresentation() else { return }
    pdfData = updatedData
    await refreshDisplayPDF()
}
```

---

## Root Cause: Index Confusion (0-based vs 1-based)

### The Problem

**Sidebar uses 0-based indexing internally** (confirmed in page-indexing-clarification.md):
- Page A visual label: "Page 1"
- Page A internal index: **0**
- Page B visual label: "Page 2"
- Page B internal index: **1**
- Page C visual label: "Page 3"
- Page C internal index: **2**

**When you select "Page A"**:
- Visual label shows: "Page 1"
- Sidebar stores: `selectedSidebarPages = [0]` ✅ Correct (0-based)

**But here's the subtle bug**:

```swift
// In duplicatePages(at: indices)
let sortedIndices = indices.sorted()  // [0]
var insertedCount = 0

for index in sortedIndices {  // index = 0
    let adjustedIndex = index + insertedCount  // adjustedIndex = 0 + 0 = 0
    // Get page at index 0 (page A)
    let original = document.page(at: adjustedIndex)  // ✅ Gets page A

    let insertIndex = min(adjustedIndex + 1, document.pageCount)  // min(1, 3) = 1
    document.insert(copy, at: insertIndex)  // ✅ Inserts at index 1 (after page A)
}
```

**Wait, this logic looks correct!** 🤔

Let me trace through more carefully...

---

## Deeper Investigation: What's Really Happening?

Let me check if there's something about `refreshDisplayPDF()` or provisional page handling...

### Hypothesis 1: Provisional Pages Interfering

**Question**: Does the document have provisional/draft pages that aren't being accounted for?

From the context, provisional pages are handled separately in `ProvisionalPageManager` and combined via `displayPDFData`. The duplication happens on `pdfData` (saved document), then calls `refreshDisplayPDF()` which recombines with provisional pages.

**Possible issue**: If there are provisional pages, the index math might get confused when refreshing the display.

### Hypothesis 2: PDFKit Insert Behavior

**PDFKit insert semantics**: `document.insert(page, at: index)`

According to PDFKit documentation:
- `insert(_:at:)` inserts the page **before** the current page at that index
- If you want to insert **after** page 0, you insert **at index 1**
- The page currently at index 1 shifts to index 2

**Let's trace the scenario again with 3 pages [A=0, B=1, C=2]**:

```swift
// Initial state: [A=0, B=1, C=2]

for index in [0] {  // Duplicating page A (index 0)
    adjustedIndex = 0 + 0 = 0
    original = document.page(at: 0)  // Gets page A ✅

    insertIndex = min(0 + 1, 3) = 1  // Insert at index 1
    document.insert(copy, at: 1)  // Inserts BEFORE current index 1 (page B)
}

// Expected result: [A=0, A_copy=1, B=2, C=3]
```

**This should work correctly!** The logic appears sound.

### Hypothesis 3: Array Initialization Issue

**Critical check**: Is `Array(selectedSidebarPages)` preserving the correct indices?

`selectedSidebarPages` is a `Set<Int>`, which is unordered. Converting to Array doesn't guarantee order, but that's why `duplicatePages` calls `.sorted()`.

**But wait** - could `selectedSidebarPages` contain the **wrong** indices?

Let's check how pages are selected in the sidebar...

---

## The Smoking Gun: Selection Index Source

From the context files, when you tap a thumbnail in the sidebar:

```swift
// ThumbnailSidebarView.swift (from Iteration 3 review)
ForEach(0..<document.pageCount, id: \.self) { index in
    ThumbnailCell(
        index: index,  // ← 0-based index
        onTap: { onTap(index) }  // ← Passes 0-based index
    )
    Text("Page \(index + 1)")  // ← Display shows 1-based
}
```

```swift
// DocumentEditView.swift
private func toggleSidebarSelection(_ index: Int) {
    if selectedSidebarPages.contains(index) {
        selectedSidebarPages.remove(index)
    } else {
        selectedSidebarPages.insert(index)  // ← Stores 0-based index
    }
}
```

**This looks correct** - sidebar passes 0-based indices and stores them correctly.

---

## Alternative Hypothesis: Document State Timing

**Question**: Could the document state be out of sync?

The flow is:
1. `duplicatePages(at: [0])` modifies the PDFDocument
2. Calls `document.insert(copy, at: 1)` - should insert after page A
3. Updates `pdfData = updatedData`
4. Calls `await refreshDisplayPDF()` which combines with provisional pages
5. Updates `displayPDFData`
6. DocumentEditView updates sidebar via `updateSidebarDocument(with: viewModel.displayPDFData ?? viewModel.pdfData)`

**Potential issue**: The sidebar is being updated with `displayPDFData`, which includes provisional pages. If there are provisional/draft pages at the END of the document, the duplicate might be appearing before them but AFTER the main pages, making it look like it's at the end.

---

## The Real Root Cause (Most Likely)

### Provisional Page Position Issue

From previous iteration reviews, draft/provisional pages appear with a "Draft" badge and yellow border. These are **temporary pages appended at the end** of the display document.

**Scenario**:
- Saved document: [A, B, C] (3 pages)
- Provisional pages: [Draft] (1 page)
- Display document: [A, B, C, Draft] (4 pages)

**When you duplicate page A (index 0)**:
1. `duplicatePages` operates on `pdfData` (saved document, 3 pages)
2. Inserts copy at index 1 → [A, A_copy, B, C]
3. Saves updated data
4. `refreshDisplayPDF()` recombines with provisional pages
5. **If provisional manager appends draft at end**: [A, A_copy, B, C, Draft]

**But if you're seeing [A, B, C, C]**, that suggests:
- Either the duplicate isn't being inserted at index 1
- OR the display is showing an older version of the document
- OR provisional pages are somehow interfering with the display order

---

## Testing Theory: Check Debug Output

The code has debug logging:

```swift
#if DEBUG
print("DEBUG Sidebar: duplicating pages", sortedIndices)
print("DEBUG Sidebar: initial page count", document.pageCount)
// ...
print("DEBUG Sidebar: inserted copy of page", adjustedIndex, "at", insertIndex)
print("DEBUG Sidebar: new page count", document.pageCount)
#endif
```

**What to check**:
1. Does the debug output show `inserted copy of page 0 at 1`?
2. What is the page count before and after?
3. Is the duplicate being inserted, but then the sidebar isn't refreshing correctly?

---

## Most Likely Culprit: Sidebar Refresh Issue

**From Iteration 2 review notes** (the modified file):
> "After deleting pages (keeping only a newly created page), the main viewer showed the correct page but the sidebar still displayed a deleted page until the app was restarted."

**This suggests a known issue**: The sidebar document isn't refreshing properly after modifications.

**Current refresh logic**:
```swift
updateSidebarDocument(with: viewModel.displayPDFData ?? viewModel.pdfData)
```

**The `updateSidebarDocument` function** likely updates the sidebar's PDFDocument reference, but if it's not forcing a full reload or if there's caching, the thumbnails might show the old state.

---

## Conclusion & Diagnosis

### Root Cause (High Confidence)

**The duplicate IS being inserted correctly at index 1**, but **the sidebar isn't refreshing to show the updated document**.

Evidence:
1. The duplication logic in `duplicatePages` is mathematically correct
2. There's a known issue from Iteration 2 about sidebar not refreshing after deletions
3. The main viewer probably shows the correct result, but the sidebar thumbnails are stale

### Why You See [A, B, C, C]

You're likely seeing:
- **Main viewer**: [A, A, B, C] ✅ Correct
- **Sidebar thumbnails**: [A, B, C] (old state) + some visual confusion

The "C, C" you're seeing might be:
- Last thumbnail showing cached version of page C
- Plus a provisional draft page that looks like C

OR the sidebar is showing a completely stale version of the document.

---

## Recommendations

### Immediate Diagnostic Steps

1. **Check the main PDF viewer** - Does it show [A, A, B, C] correctly?
   - If YES: Sidebar refresh issue confirmed
   - If NO: Deeper PDFKit insert problem

2. **Check debug console** - What do the "DEBUG Sidebar" logs show?
   - Does it log "inserted copy of page 0 at 1"?
   - What are the before/after page counts?

3. **Check provisional pages** - Do you have a draft page in the document?
   - If YES: This could be masking the issue

4. **Restart the app and check** - Does the document correctly show [A, A, B, C] after restart?
   - If YES: Confirms it's a display refresh issue, not a data issue

### Likely Fix Direction

**The issue is in `updateSidebarDocument`** (DocumentEditView.swift). It needs to:
1. Set `sidebarDocument = nil` to clear cache
2. Rebuild from updated data
3. Force thumbnail regeneration

From Iteration 2 review:
> "Consider forcing sidebar reload (set `sidebarDocument` to nil then rebuild) after page removal."

**This same fix is needed for duplication.**

---

## Summary

**What's happening**: Duplicate is being inserted correctly in the document data, but the sidebar UI isn't refreshing to show the updated state.

**Why**: Known issue from Iteration 2 - sidebar doesn't properly reload after document modifications.

**Next step**: Check if main viewer shows correct result, then investigate `updateSidebarDocument` implementation and force a proper refresh.

**Expected fix**: Force sidebar document reload by clearing cache before rebuilding thumbnails.
