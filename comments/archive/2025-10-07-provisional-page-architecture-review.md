# Architecture Review: Provisional Page Composition
**Date**: 2025-10-07
**Context**: Response to clarified requirements in `2025-10-07-preview-visual-refinement-response.md`
**Reviewer**: Senior Supervising Programmer

## Understanding Corrected ✅

Thank you for the clarification! I now understand the actual issue:

### What I Initially Thought
- User exits editor → sees blank page
- Need to show preview in editor pane

### What You Actually Need
- User exits editor → returns to document view
- **Problem**: Newly written page **disappears from PDF viewer** (blank/missing)
- **Need**: Show provisional draft page **in the main document PDF viewer** alongside scanned pages
- **Until**: User exits note (then final render happens)

This is a much more sophisticated requirement than I initially understood!

---

## Proposed Architecture Analysis

### Your Planned Approach (from the document)

```
┌─────────────────────────────────────┐
│ User writes markdown in editor      │
└──────────────┬──────────────────────┘
               │ (exits editor)
               ↓
┌─────────────────────────────────────┐
│ Build in-memory combined PDF:       │
│ [Saved pages] + [Provisional page]  │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│ Main PDFViewer shows combined PDF   │
│ - Page 1: Scanned (saved)           │
│ - Page 2: Scanned (saved)           │
│ - Page 3: Markdown (provisional) 📝 │
└─────────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│ User exits note                     │
│ → Finalize (render + save)          │
│ → OR discard provisional            │
└─────────────────────────────────────┘
```

**This is excellent architecture!** 🎯

---

## Design Assessment

### ✅ Strengths

1. **Maintains "pen and paper" philosophy** - Final commit still happens on note exit
2. **Seamless UX** - Page appears immediately in context, not hidden
3. **In-memory only** - No disk writes until finalization (safe)
4. **Clear state distinction** - Provisional vs final pages visually different
5. **Reversible** - Discard is clean (just drop in-memory page)

### ⚠️ Challenges to Address

#### 1. PDF Composition Performance

**Question**: How fast is combining PDFs in memory?

**Implementation**:
```swift
func buildProvisionalDocument(
    savedPDF: PDFDocument,
    provisionalPageData: Data
) -> PDFDocument? {
    guard let provisionalPage = PDFDocument(data: provisionalPageData)?.page(at: 0) else {
        return nil
    }

    let combined = PDFDocument()

    // Copy saved pages
    for i in 0..<savedPDF.pageCount {
        if let page = savedPDF.page(at: i) {
            combined.insert(page, at: combined.pageCount)
        }
    }

    // Append provisional page
    combined.insert(provisionalPage, at: combined.pageCount)

    return combined
}
```

**Concern**: On large documents (50+ pages), this rebuild happens:
- Every time user exits editor
- Every time document view refreshes
- Potentially on every SwiftUI view update

**Recommendation**: Cache the combined PDF, invalidate only when:
- Draft content changes
- User discards draft
- User finalizes

#### 2. Page Management Grid Complexity

**Scenario**: User opens page thumbnails (swipe-up gesture).

**Expected behavior**:
```
Thumbnails:
┌───┐ ┌───┐ ┌───┐
│ 1 │ │ 2 │ │3📝│  ← Page 3 has draft badge
└───┘ └───┘ └───┘
```

**Challenges**:
- Provisional page should be visible in grid
- Should have visual indicator (border/badge)
- Should NOT be deletable (or deletion = discard draft)
- Tapping it should... what? Re-open editor? View PDF?

**Questions**:
1. Can user delete provisional page from grid?
   - If YES → equivalent to discarding draft
   - If NO → need to disable delete for that page
2. Can user reorder provisional page?
   - Probably NO (it's always last until finalized)
3. Can user tap provisional page to view PDF?
   - YES → should show preview with draft indicator

#### 3. State Management Complexity

**Current state locations**:
- `TextPageEditorViewModel.latestRenderedPageData` - Draft PDF
- `DocumentViewModel.pdfData` - Saved PDF
- Need: Combined PDF for display

**State flow**:
```swift
// In DocumentEditView or similar
@State private var displayPDF: Data?  // Combined or saved PDF

func updateDisplayPDF() {
    if let draftData = textEditorViewModel?.latestRenderedPageData,
       let savedPDF = viewModel?.pdfData {
        // Build combined PDF
        displayPDF = buildCombinedPDF(saved: savedPDF, draft: draftData)
    } else {
        // No draft, show saved only
        displayPDF = viewModel?.pdfData
    }
}
```

**Triggers for rebuild**:
- `.onChange(of: textEditorViewModel?.latestRenderedPageData)`
- `.onChange(of: viewModel?.pdfData)`
- On editor dismiss
- On discard

**Risk**: View update loops if not careful with bindings.

#### 4. Navigation Complexity

**Scenario**: User has provisional page, then navigates to specific page via search.

**Example**:
- Document has pages 1-2 (saved) + page 3 (provisional)
- User searches, finds result on page 1
- Navigation should work normally
- BUT: Page indices might be off if not accounting for provisional

**Recommendation**: Keep page numbering simple:
- Saved pages: 1-N
- Provisional page: N+1
- Always append (never insert in middle)

#### 5. Multiple Draft Pages

**Question**: Can user create multiple provisional pages?

**Scenarios**:
- User writes text page → exits editor → writes another text page
- Should second draft append to first, or replace?

**Options**:
A. **Single draft at a time** (simpler)
   - Exiting editor without committing replaces previous draft
   - Or: Force commit before starting new draft

B. **Multiple drafts** (complex)
   - Each draft appends to provisional document
   - Need to track multiple draft states
   - More complexity in finalization

**Recommendation**: Start with **single draft** (Option A).

---

## Implementation Considerations

### Visual Indicator Options

#### Option A: Yellow Border (Recommended)
```
┌━━━━━━━━━━━━━┓  ← 3pt yellow border
┃ Meeting Notes┃
┃              ┃
┃ • Item 1     ┃
┗━━━━━━━━━━━━━┛
```

**Pros**:
- Clear, non-intrusive
- Matches previous recommendations
- Easy to implement (PDFView overlay)

**Implementation**:
```swift
PDFViewer(pdfData: displayPDF, ...)
    .overlay(alignment: .topTrailing) {
        if isShowingProvisionalPage {
            provisionalPageIndicator
        }
    }
```

**Problem**: How to know WHICH page is provisional in multi-page PDF?

**Solution**: Track provisional page range:
```swift
struct ProvisionalPageInfo {
    let startIndex: Int  // In combined PDF
    let count: Int       // Usually 1
}
```

Then in page change handler:
```swift
.onChange(of: currentPage) { newPage in
    if let provisional = provisionalPageInfo,
       newPage >= provisional.startIndex && newPage < provisional.startIndex + provisional.count {
        showProvisionalIndicator = true
    } else {
        showProvisionalIndicator = false
    }
}
```

#### Option B: Watermark Overlay
```
┌─────────────┐
│             │
│ DRAFT    📝 │  ← Watermark in corner
│             │
└─────────────┘
```

**Pros**:
- Very clear
- Always visible

**Cons**:
- Obscures content
- Harder to implement (need to render on PDF)

#### Option C: Page Thumbnail Badge
```
In page management grid:
┌───┐
│📝 │  ← Badge on thumbnail
│   │
└───┘
```

**Pros**:
- Doesn't obscure main view
- Clear in grid

**Cons**:
- Not visible in main PDF view

**Recommendation**: Combine A + C (border in main view, badge in grid).

---

## Architectural Recommendations

### 1. Create Dedicated Provisional Document Manager

```swift
// New file: ProvisionalPageManager.swift
actor ProvisionalPageManager {
    private var provisionalPages: [Data] = []  // Draft PDFs
    private var combinedDocument: PDFDocument?
    private var combinedDocumentData: Data?

    func setProvisionalPage(_ data: Data) {
        provisionalPages = [data]  // Single draft mode
        invalidateCache()
    }

    func clearProvisional() {
        provisionalPages = []
        invalidateCache()
    }

    func buildCombinedDocument(savedPDF: Data) -> Data? {
        // Check cache
        if let cached = combinedDocumentData {
            return cached
        }

        guard let saved = PDFDocument(data: savedPDF) else { return nil }
        let combined = PDFDocument()

        // Copy saved pages
        for i in 0..<saved.pageCount {
            if let page = saved.page(at: i) {
                combined.insert(page, at: combined.pageCount)
            }
        }

        // Append provisional pages
        for draftData in provisionalPages {
            if let draft = PDFDocument(data: draftData) {
                for i in 0..<draft.pageCount {
                    if let page = draft.page(at: i) {
                        combined.insert(page, at: combined.pageCount)
                    }
                }
            }
        }

        combinedDocumentData = combined.dataRepresentation()
        return combinedDocumentData
    }

    func provisionalPageRange(savedPageCount: Int) -> Range<Int>? {
        guard !provisionalPages.isEmpty else { return nil }
        let start = savedPageCount
        let count = provisionalPages.count  // Assume 1 page per draft for now
        return start..<(start + count)
    }

    private func invalidateCache() {
        combinedDocument = nil
        combinedDocumentData = nil
    }
}
```

### 2. Integrate with DocumentViewModel

```swift
// In DocumentViewModel
class DocumentViewModel: ObservableObject {
    @Published var pdfData: Data?
    private let provisionalManager = ProvisionalPageManager()

    var displayPDF: Data? {
        if let saved = pdfData,
           let combined = await provisionalManager.buildCombinedDocument(savedPDF: saved) {
            return combined
        }
        return pdfData
    }

    func setProvisionalPage(_ data: Data) async {
        await provisionalManager.setProvisionalPage(data)
        objectWillChange.send()  // Trigger view update
    }

    func clearProvisionalPage() async {
        await provisionalManager.clearProvisional()
        objectWillChange.send()
    }

    func provisionalPageRange() async -> Range<Int>? {
        guard let pdfDoc = pdfData.flatMap(PDFDocument.init) else { return nil }
        return await provisionalManager.provisionalPageRange(savedPageCount: pdfDoc.pageCount)
    }
}
```

### 3. Update DocumentEditView

```swift
// In DocumentEditView.swift
@ViewBuilder
private func documentContent(viewModel: DocumentViewModel) -> some View {
    // ...
    if let displayPDF = viewModel.displayPDF {
        PDFViewer(
            pdfData: displayPDF,
            navigateToPage: $navigateToPage,
            currentPage: $currentViewedPage,
            onRequestPageManagement: {
                activeSheet = .pageManagement
            },
            onRequestMetadataView: { ... }
        )
        .overlay(alignment: .topTrailing) {
            if let range = await viewModel.provisionalPageRange(),
               range.contains(currentViewedPage) {
                provisionalPageBadge
            }
        }
    }
}

private var provisionalPageBadge: some View {
    HStack(spacing: 4) {
        Image(systemName: "pencil.circle.fill")
        Text("DRAFT")
    }
    .font(.caption)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.yellow.opacity(0.9))
    .foregroundColor(.black)
    .cornerRadius(8)
    .padding(12)
}
```

---

## Risks & Mitigations

### Risk 1: Performance on Large Documents

**Scenario**: 50-page document + 1 provisional page = rebuilding 51-page PDF on every view update.

**Mitigation**:
- ✅ Cache combined PDF (implemented in ProvisionalPageManager)
- ✅ Invalidate only on draft changes
- ✅ Use actor for thread-safe caching

### Risk 2: Memory Pressure

**Scenario**: Holding 3 PDFs in memory:
- Saved PDF (on disk)
- Provisional page PDF (in-memory)
- Combined PDF (in-memory)

**Mitigation**:
- Store combined as Data, not PDFDocument (lighter)
- Release combined cache when not visible
- Consider weak references where appropriate

### Risk 3: State Synchronization

**Scenario**: User discards draft but combined PDF still shows it.

**Mitigation**:
- Use `objectWillChange.send()` to force view updates
- Clear cache immediately on discard
- Add defensive checks in view updates

### Risk 4: Page Management Grid Confusion

**Scenario**: User sees provisional page in grid, tries to delete it.

**Mitigation**:
```swift
// In PageManagementView
if pageIndex == provisionalPageIndex {
    // Show different UI for provisional page
    Button("Discard Draft") {
        await viewModel.clearProvisionalPage()
    }
} else {
    // Normal delete button
    Button("Delete Page") { ... }
}
```

---

## Testing Strategy

### Unit Tests
- [ ] Build combined PDF with 0 saved pages + 1 provisional
- [ ] Build combined PDF with 3 saved pages + 1 provisional
- [ ] Cache invalidation on draft change
- [ ] Cache reuse when draft unchanged
- [ ] Provisional page range calculation

### Integration Tests
- [ ] Exit editor → provisional appears in PDF viewer
- [ ] Navigate to provisional page → border shows
- [ ] Discard draft → provisional disappears
- [ ] Exit note → provisional finalizes
- [ ] Swipe-up gesture → provisional in grid with badge

### UI Tests
- [ ] Create draft → verify page count increases
- [ ] View provisional page → verify draft indicator
- [ ] Delete provisional from grid → verify discard
- [ ] Exit without saving → verify no permanent changes

---

## Open Questions

1. **What happens if user edits provisional page again?**
   - Re-open editor with existing draft?
   - Create new draft replacing old?

2. **Can user have multiple provisional pages?**
   - Or limit to one draft at a time?

3. **What if provisional render fails?**
   - Show error in place of page?
   - Keep previous provisional?

4. **Should provisional survive app backgrounding?**
   - Currently: TextPageDraftManager persists drafts
   - Provisional PDF: Rebuild from draft on resume?

5. **Page reordering with provisional?**
   - Can provisional be reordered?
   - Or always stays last?

---

## Recommendation Summary

Your planned approach is **architecturally sound**! The key implementation points:

1. ✅ **Create ProvisionalPageManager** to handle PDF composition & caching
2. ✅ **Cache combined PDF** to avoid rebuilding on every view update
3. ✅ **Visual indicators**: Yellow border + grid badge
4. ✅ **Clear state boundaries**: Provisional vs saved vs finalized
5. ✅ **Limit to single draft** initially (can expand later)

**Estimated implementation**: 4-6 hours including tests

**Risk level**: 🟡 MEDIUM (state management complexity, but well-designed)

**Biggest gotcha**: Cache invalidation timing - make sure combined PDF updates when it should, but not too often.

---

Ready to discuss any of these points or move forward with implementation guidance!
