# Page Reorder Data Loss Analysis - Critical Bug

**Date**: 2025-10-09
**Severity**: 🚨 CRITICAL - Data Loss
**Issue**: Reordering pages in swipe-up sheet deletes all page content
**Affected Pages**: Markdown text pages created via internal workstream
**Status**: Bug confirmed reproducible

---

## Symptom Summary

**What happened**:
1. User opened document with 3 markdown text pages
2. Used swipe-up sheet to view page order
3. Attempted to reorder pages
4. **All page content was deleted** - pages became blank
5. **Reproducible** - happened twice in testing

**Evidence from logs**:

### Before Reorder
```
DEBUG Sidebar: sidebarDocument updated with 3 pages
DEBUG Sidebar: page 0 preview text: Page added 09-10-2025 15:46
Page 1
DEBUG Sidebar: page 1 preview text: Page added 09-10-2025 15:46
Page 2
DEBUG Sidebar: page 2 preview text: Page added 09-10-2025 15:47
Page 3
```
✅ Pages have content

### After Reorder
```
DEBUG Sidebar: sidebarDocument updated with 3 pages
DEBUG Sidebar: page 0 preview text: <no text>
DEBUG Sidebar: page 1 preview text: <no text>
DEBUG Sidebar: page 2 preview text: <no text>
```
❌ All content gone!

---

## Critical Observations

### 1. Page Count Preserved
- Before: 3 pages
- After: 3 pages
- **Conclusion**: Pages weren't deleted, just their content was erased

### 2. Content Type Specific?
- User mentioned: "pages were ones I had created with the internal markdown workstream"
- These are **text pages rendered to PDF**, not scanned documents
- **Question**: Does this affect all page types or just markdown text pages?

### 3. Reorder Operation Was Incomplete
- User said: "tried re-ordering the notes"
- **Critical question**: Was the reorder confirmed/applied, or just attempted?
- Did the user complete the reorder gesture or cancel it?

### 4. Sidebar Updated Twice
Notice two sidebar updates in the log:
1. First update: Pages have content
2. Second update: Pages have `<no text>`

**This suggests**:
- Reorder operation triggered
- Document was modified
- Sidebar refreshed with corrupted document data

---

## Root Cause Hypothesis

### Hypothesis 1: Page Reorder Logic Bug (Most Likely)

**Location**: `PageManagementView.swift` (swipe-up sheet)

**Theory**: The reorder implementation is corrupting page data during the move operation.

**Possible mechanisms**:

#### A. Empty Page Creation During Reorder
```swift
// Suspected buggy code pattern:
func reorderPages(from: Int, to: Int) {
    // Get page at source
    let page = document.page(at: from)

    // Remove from source
    document.removePage(at: from)

    // Insert at destination
    document.insert(???, at: to)  // ← What gets inserted?
}
```

**If the code does**:
1. Remove page at source index
2. Create **new blank page** instead of using the removed page
3. Insert blank page at destination

**Result**: Content loss ✅ Matches symptom

#### B. Copy Instead of Move
```swift
// If using page.copy() incorrectly:
if let pageCopy = page.copy() as? PDFPage {
    document.insert(pageCopy, at: to)
}
```

**Problem**: `PDFPage.copy()` might not preserve all content attributes
- Text content might not copy correctly
- Annotations/drawings lost
- Results in blank pages

#### C. Incorrect Index Calculation
```swift
// If indices get confused during multi-step reorder:
func reorderPages(from: IndexSet, to: Int) {
    // Remove pages (indices shift!)
    // Insert at wrong location
    // Overwrite existing pages
}
```

**Result**: Pages end up pointing to wrong data or corrupted references

---

### Hypothesis 2: PDF Data Serialization Issue

**Theory**: The document is correctly modified in memory, but when saving/reloading, content is lost.

**Flow**:
1. User reorders pages → PDFDocument modified in memory ✅
2. Document saved → `pdfData = document.dataRepresentation()` ✅
3. Sidebar refreshes → Loads from `pdfData`
4. **But**: `dataRepresentation()` produces corrupted/empty PDF data ❌

**Why this could happen**:
- Markdown pages are rendered PDFs, not native text
- If rendering metadata is lost during reorder, pages become empty
- PDFKit's `dataRepresentation()` might not preserve certain page types

---

### Hypothesis 3: Provisional Page Interaction

**Theory**: If provisional/draft pages are involved, reorder might be handling them incorrectly.

**User context**: "pages I had created with the internal markdown workstream"

**These pages might be**:
- Provisional pages (displayed via `displayPDFData`)
- Not yet fully committed to main `pdfData`
- Reorder operates on `pdfData`, ignoring provisional state

**Scenario**:
1. User has 3 provisional markdown pages in `displayPDFData`
2. User opens PageManagementView (which uses `pdfData` binding)
3. `pdfData` has 3 **placeholder/empty pages** (provisional content is separate)
4. User reorders these empty placeholders
5. Reorder succeeds, but operates on empty pages
6. Provisional data is lost or disconnected

**Result**: All pages appear blank ✅ Matches symptom

---

### Hypothesis 4: Binding Mutation Issue

**Theory**: SwiftUI binding to `pdfData` causes corruption during reorder.

**From DocumentEditView.swift:102-107**:
```swift
PageManagementView(
    pdfData: Binding(
        get: { viewModel.pdfData },
        set: {
            viewModel.pdfData = $0
            viewModel.hasChanges = true
        }
    ),
    // ...
)
```

**Potential issue**:
1. PageManagementView modifies PDFDocument in place
2. Calls `pdfData.wrappedValue = modifiedData`
3. This triggers the setter
4. Setter updates `viewModel.pdfData`
5. **But**: If ViewModel also has provisional page logic, it might overwrite changes
6. Or: Multiple updates race, last one wins (and it's blank)

---

## Investigation: Where Is PageManagementView?

**Critical files to examine**:
1. `PageManagementView.swift` - The reorder UI
2. How does it handle page reordering?
3. Does it work on a copy or the live document?
4. How does it save changes back?

**Expected implementation patterns**:

### Pattern A: Direct Manipulation (Risky)
```swift
// PageManagementView
@Binding var pdfData: Data?

var document: PDFDocument {
    PDFDocument(data: pdfData ?? Data()) ?? PDFDocument()
}

func reorderPages(from: IndexSet, to: Int) {
    // Modify document directly
    // Update binding
    pdfData = document.dataRepresentation()
}
```
⚠️ **Dangerous** if not careful with indices

### Pattern B: Transactional (Safer)
```swift
@State private var workingDocument: PDFDocument
@Binding var pdfData: Data?

func reorderPages(...) {
    // Modify workingDocument
    // Only commit on "Done"
}

func commitChanges() {
    pdfData = workingDocument.dataRepresentation()
}
```
✅ Safer, but must handle provisional pages

---

## Text Page Creation Workflow

**Understanding markdown text pages**:

From context, text pages are created via:
1. `TextPageEditorView` - User writes markdown
2. Markdown rendered to PDF page (via HTML/WebKit?)
3. PDF page data stored as provisional preview
4. Eventually committed to main document

**Key components**:
- `TextPageEditorViewModel`
- `DocumentViewModel.appendTextPage(markdown:...)`
- `ProvisionalPageManager`

**Storage model**:
- `pdfData` - Main saved PDF document
- `displayPDFData` - Combined (saved + provisional pages)
- Provisional pages appended at end

**Critical insight**: When reordering, are we reordering `pdfData` or `displayPDFData`?

---

## The Smoking Gun: displayPDFData vs pdfData

### From DocumentEditView.swift:118

```swift
displayPDFData: viewModel.displayPDFData,
```

**PageManagementView receives `displayPDFData`** for display!

But the binding is to `pdfData`:
```swift
pdfData: Binding(
    get: { viewModel.pdfData },
    set: { viewModel.pdfData = $0; viewModel.hasChanges = true }
),
```

### The Bug Pattern (High Confidence)

**Scenario**:
1. User creates 3 markdown text pages
2. These are **provisional pages** (not yet in main `pdfData`)
3. They're visible via `displayPDFData` (which = `pdfData` + provisional)
4. User opens PageManagementView
5. View displays `displayPDFData` (shows 3 pages with content) ✅
6. User reorders pages
7. **But reorder modifies the `pdfData` binding** (which is empty or has placeholders!)
8. Reorder shuffles empty pages around
9. Changes saved back to `pdfData`
10. Provisional data is disconnected/lost
11. Sidebar refreshes, shows blank pages ❌

### Evidence Supporting This

**Log shows**:
```
DEBUG Sidebar: page 0 preview text: Page added 09-10-2025 15:46
```

The text "Page added 09-10-2025 15:46" suggests these are provisional text pages with timestamps.

**After reorder**:
```
DEBUG Sidebar: page 0 preview text: <no text>
```

The provisional content is gone because reorder operated on `pdfData` (without provisional), then saved that back, effectively discarding provisional pages.

---

## Detailed Mechanism (Most Likely)

### Initial State
```
pdfData: []  (empty or has 3 placeholder pages)
provisionalPages: [TextPage1, TextPage2, TextPage3]
displayPDFData: [TextPage1, TextPage2, TextPage3]  (combined result)
```

### User Sees in PageManagementView
- Displays `displayPDFData` → User sees 3 pages with content ✅

### User Reorders Page 1 to Position 3
```swift
// PageManagementView operates on pdfData binding
let doc = PDFDocument(data: pdfData)  // Empty or placeholder document!
doc.removePage(at: 0)
doc.insert(???, at: 2)
pdfData = doc.dataRepresentation()
```

### Result
```
pdfData: [Blank, Blank, Blank]  (reordered placeholders)
provisionalPages: Still [TextPage1, TextPage2, TextPage3]  (but now orphaned)
displayPDFData: Gets regenerated, but provisional pages can't map to new structure
```

### Why All Pages Become Blank

**Provisional page manager probably keys provisional pages by index**:
```swift
// Pseudocode
func combinedData() -> Data? {
    var combined = PDFDocument(data: pdfData)
    for (index, provisionalPage) in provisionalPages {
        combined.insert(provisionalPage, at: index)  // ← Index is now wrong!
    }
    return combined.dataRepresentation()
}
```

**After reorder**:
- Provisional pages still think they go at indices 0, 1, 2
- But `pdfData` has been restructured
- Indices no longer match
- Result: Provisional pages either not inserted, or inserted wrong
- Sidebar sees empty pages

---

## Additional Evidence Needed

### Questions to Investigate

1. **How does PageManagementView implement reorder?**
   - Does it use `.onMove()` modifier?
   - Does it work on `pdfData` or `displayPDFData`?

2. **What is the provisional page state?**
   - Were these pages fully committed to `pdfData`?
   - Or still in provisional state?

3. **Does ProvisionalPageManager track by index or UUID?**
   - If by index, reorder breaks the mapping
   - If by UUID, should survive reorder (but maybe not implemented?)

4. **Is there a "commit provisional pages" step before reorder?**
   - Should reorder be disabled if provisional pages exist?
   - Or should provisional pages be auto-committed first?

---

## Related Code Patterns to Examine

### 1. ProvisionalPageManager (Likely Key File)

**Expected location**: `ProvisionalPageManager.swift` or similar

**What to look for**:
```swift
class ProvisionalPageManager {
    private var provisionalPages: [Int: PDFPage] = [:]  // ← Index-based?

    func addProvisionalPage(_ page: PDFPage, at index: Int) {
        provisionalPages[index] = page  // ← Will break on reorder!
    }

    func combinedData(using basePDF: Data?) -> Data? {
        // Combine base + provisional
        // ← Does this handle index shifts?
    }
}
```

**If provisional tracking is index-based, reorder will break it.**

### 2. PageManagementView Reorder Implementation

**Expected pattern**:
```swift
List {
    ForEach(pages) { page in
        PageThumbnail(page)
    }
    .onMove { from, to in
        reorderPages(from: from, to: to)  // ← What does this do?
    }
}
```

**What `reorderPages` should do**:
1. Check for provisional pages → warn or commit first
2. Reorder in PDFDocument
3. Update provisional page indices (if any)
4. Save atomically

**What it probably does**:
1. Reorder in PDFDocument
2. Save to `pdfData`
3. (Provisional pages get orphaned)

---

## User Workflow That Triggers Bug

### Step-by-Step Recreation

1. **Create text pages**:
   - Open document (empty or existing)
   - Tap "Text" button to create markdown page
   - Write "Page 1", save
   - Repeat for "Page 2" and "Page 3"
   - **These pages are provisional** (not fully committed?)

2. **Trigger reorder**:
   - Swipe up to open PageManagementView
   - See 3 pages with content
   - Long-press and drag to reorder
   - Release

3. **Bug occurs**:
   - Pages reorder visually
   - Content disappears
   - All pages show blank

4. **Evidence**:
   - Sidebar debug log shows `<no text>`
   - Pages still exist (count unchanged)
   - Content is gone

---

## Why This Is Critical

### Data Loss Severity

**User impact**:
- ✅ Pages exist (structure preserved)
- ❌ Content lost (data destroyed)
- ❌ No undo/recovery
- ❌ Reproducible (happens every time)

**Data that's lost**:
- User-written markdown content
- Rendered PDF pages
- Hours of work potentially gone

### Why It Went Unnoticed

**Hypothesis**:
1. Reorder feature works fine for **scanned pages** (no provisional state)
2. Bug only affects **markdown text pages** (which use provisional system)
3. Sidebar implementation is new (this week)
4. Reorder in swipe-up sheet predates sidebar
5. Provisional page system might be recent addition
6. **These systems weren't tested together**

---

## Fix Strategy (Conceptual - No Code Yet)

### Option 1: Disable Reorder for Provisional Pages

**Safest short-term fix**:
```swift
// In PageManagementView
if hasProvisionalPages {
    // Disable .onMove()
    // Show banner: "Commit draft pages before reordering"
}
```

✅ Prevents data loss
❌ Reduces functionality

### Option 2: Commit Provisional Pages Before Reorder

**Better UX**:
```swift
func beginReorder() {
    if hasProvisionalPages {
        commitProvisionalPages()
    }
    // Then allow reorder
}
```

✅ Preserves functionality
⚠️ Requires reliable commit logic

### Option 3: Reorder in displayPDFData, Not pdfData

**Most correct**:
```swift
// Reorder the combined document
let doc = PDFDocument(data: displayPDFData)
// Perform reorder
// Extract which pages are provisional (track by content or metadata)
// Rebuild pdfData + provisional state from reordered doc
```

✅ Handles provisional pages correctly
❌ Complex to implement correctly

### Option 4: UUID-Based Provisional Tracking

**Architectural fix**:
```swift
// Instead of tracking provisional pages by index:
class ProvisionalPageManager {
    struct ProvisionalPage {
        let uuid: UUID
        let data: Data
        var insertAfterPageUUID: UUID?
    }

    private var pages: [UUID: ProvisionalPage] = [:]
}
```

✅ Survives reorder operations
❌ Requires refactor of provisional system

---

## Immediate Recommendations

### 1. Verify Hypothesis

**Check these files**:
- `PageManagementView.swift` - How is reorder implemented?
- `ProvisionalPageManager.swift` - How are provisional pages tracked?
- `DocumentViewModel.swift` - How does `displayPDFData` combine pages?

**Look for**:
- Index-based provisional page storage
- Reorder operating on `pdfData` while displaying `displayPDFData`
- Missing provisional page index update after reorder

### 2. Quick Safety Fix

**Disable reorder for documents with provisional pages**:
- Add check in PageManagementView
- Show alert: "Save draft pages before reordering"
- Prevent data loss while investigating proper fix

### 3. Add Provisional Page Commit

**Implement "Commit All Drafts" button**:
- In PageManagementView or before allowing reorder
- Converts provisional pages to permanent pages
- Then allow reorder

### 4. Improve Logging

**Add debug logs**:
```swift
print("DEBUG Reorder: pdfData page count:", pdfData pageCount)
print("DEBUG Reorder: displayPDFData page count:", displayPDFData pageCount)
print("DEBUG Reorder: provisional page count:", provisionalPages.count)
print("DEBUG Reorder: before reorder indices:", indices)
print("DEBUG Reorder: after reorder, checking page content...")
```

### 5. Add Backup/Undo

**Before any reorder operation**:
```swift
// Backup current state
let backupData = pdfData
let backupProvisional = provisionalPages.copy()

// Perform reorder
reorderPages()

// Verify content preserved
if contentLost() {
    // Restore backup
    pdfData = backupData
    provisionalPages = backupProvisional
    showError("Reorder failed, restored previous state")
}
```

---

## Testing Plan

### Reproduce Bug

1. Create new document
2. Add 3 markdown text pages (via Text button)
3. Verify pages visible in sidebar
4. Swipe up to open PageManagementView
5. Attempt to reorder pages
6. Observe content loss

### Test Fix

1. Apply safety fix (disable reorder with provisional)
2. Verify alert shows when attempting reorder
3. Commit provisional pages
4. Verify reorder now works
5. Verify content preserved after reorder

### Regression Testing

1. Test reorder with scanned pages (should still work)
2. Test reorder with mixed (scanned + text pages)
3. Test reorder with only text pages (after commit)
4. Test on iPhone (swipe-up sheet) and iPad (sidebar)

---

## Summary

### Root Cause (High Confidence)

**The bug**: PageManagementView reorders `pdfData` while displaying `displayPDFData`, and provisional pages are tracked by index.

**Why content is lost**: Reordering `pdfData` breaks the index-based mapping of provisional pages, causing them to be disconnected from the document.

**Why it's reproducible**: Text pages created via markdown workstream are provisional until committed, and reorder operation doesn't handle provisional state.

### Immediate Action Required

1. **Disable reorder** for documents with provisional pages (safety fix)
2. **Investigate** PageManagementView and ProvisionalPageManager implementation
3. **Implement** provisional page commit before allowing reorder
4. **Consider** UUID-based provisional tracking (architectural fix)

### Critical Files to Examine

1. `PageManagementView.swift` - Reorder implementation
2. `ProvisionalPageManager.swift` (or equivalent) - Provisional page tracking
3. `DocumentViewModel.swift` - How `displayPDFData` is generated
4. Integration between reorder and provisional page system

---

## Priority

🚨 **CRITICAL** - This is a data loss bug affecting user-created content. Should be addressed before merging sidebar feature or releasing any version with PageManagementView reorder.

**Recommended approach**:
1. Immediate: Add safety check to prevent reorder with provisional pages
2. Short-term: Implement provisional page commit before reorder
3. Long-term: Refactor provisional tracking to be reorder-safe (UUID-based)
