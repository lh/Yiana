# UX Design Advice: Markdown Editor Preview State
**Date**: 2025-10-07
**Topic**: Showing edited text before final PDF render
**Type**: Architecture & UX consultation

## Current Behavior (As Described)

### Lifecycle
1. User opens note → sees existing PDF pages
2. User taps "Text" button → opens markdown editor for a page
3. User edits markdown text
4. User exits editor (back to note view) → **page goes blank** ⚠️
5. Text is still editable (can return to editor via "Text" button)
6. User exits entire note → markdown renders to PDF (final/permanent)

### Design Philosophy
✅ "Pen and paper" - once written, it's permanent
✅ Save happens on note exit (PDF render is commitment)
✅ Can still edit while within the note

### The Problem
🤔 After exiting markdown editor but before exiting note:
- User sees blank page (no visual feedback of what they wrote)
- Text exists but isn't visible
- Creates "funny hiatus" where work seems lost

---

## Solution Options

### Option 1: Live Preview Render (Temporary PDF)
**Concept**: Render markdown to temporary in-memory PDF immediately after editor exit

**How it works**:
```
┌─────────────────┐
│ Markdown Editor │
│  "Hello world"  │
└────────┬────────┘
         │ (exit editor)
         ↓
┌─────────────────┐
│ Generate temp   │  ← Render markdown to PDF in memory
│ preview PDF     │    (not saved to .yianazip yet)
└────────┬────────┘
         ↓
┌─────────────────┐
│ Note View       │
│ [preview PDF]   │  ← Show temp PDF while still in note
│ *not final*     │
└────────┬────────┘
         │ (exit note)
         ↓
┌─────────────────┐
│ Final render    │  ← Replace temp with official PDF
│ Save to file    │    Write to .yianazip
└─────────────────┘
```

**Pros**:
- ✅ User sees their work immediately
- ✅ Clear visual feedback after editing
- ✅ Can preview formatting before committing
- ✅ Maintains "final render on exit" philosophy
- ✅ No modal/dialog needed

**Cons**:
- ⚠️ Double rendering (once for preview, once for final)
- ⚠️ Need to track "temp vs final" state per page
- ⚠️ Preview might look different from final render (confusing)
- ⚠️ Memory overhead (multiple PDFs in flight)

**Implementation Considerations**:
- Store temp PDF in `DocumentMetadata` or ViewModel as transient state
- Add flag: `page.hasPendingMarkdownChanges: Bool`
- PDFViewer checks: "if pending changes, show temp PDF, else show saved PDF"
- On note exit: replace all temp PDFs with final renders

**Visual indicator**:
Add subtle UI hint that preview isn't final:
- Watermark: "Preview - not saved"
- Border color (yellow outline?)
- Badge on page thumbnail

---

### Option 2: Markdown Preview Mode (Keep It Text)
**Concept**: Show rendered markdown *as text/attributed string*, not PDF

**How it works**:
```
┌─────────────────┐
│ Markdown Editor │
│  # Hello        │ ← Edit mode (raw markdown)
│  **world**      │
└────────┬────────┘
         │ (exit editor)
         ↓
┌─────────────────┐
│ Markdown View   │
│  Hello          │ ← Preview mode (rendered text)
│  world          │   (bold, headings styled)
│                 │   NOT a PDF yet
└────────┬────────┘
         │ (tap to edit)
         ↓
┌─────────────────┐
│ Back to editor  │
└────────┬────────┘
         │ (exit note)
         ↓
┌─────────────────┐
│ Render to PDF   │ ← Only now becomes permanent
└─────────────────┘
```

**Pros**:
- ✅ Fast (no PDF rendering needed)
- ✅ User sees content immediately
- ✅ Easy to implement (SwiftUI Text with AttributedString)
- ✅ No double-render overhead
- ✅ Clear distinction: text view = editable, PDF = final

**Cons**:
- ⚠️ Preview won't match final PDF exactly (different layout engine)
- ⚠️ Need new view type: "markdown preview panel"
- ⚠️ User might expect preview to match final output precisely
- ⚠️ Doesn't fit existing "all pages are PDFs" architecture

**Implementation Considerations**:
- Add `TextPagePreview.swift` - shows rendered markdown as SwiftUI Text
- Store markdown in memory: `page.pendingMarkdownText: String?`
- Page view switches between: PDFView (if saved) vs TextPagePreview (if pending)
- On note exit: render all pending markdown to PDF

**Visual indicator**:
- Different background (paper texture vs white)
- "Tap to edit" hint overlay
- Icon badge: pencil icon on page thumbnail

---

### Option 3: Modal "Save or Discard" Confirmation
**Concept**: Prompt user when exiting editor

**How it works**:
```
User exits editor
         ↓
┌─────────────────────┐
│ Save changes?       │
│                     │
│ [Preview] [Discard] │ ← Preview shows render
│ [Save]              │   Save = commit to PDF
└─────────────────────┘
```

**Pros**:
- ✅ Explicit user control
- ✅ Prevents accidental loss of work
- ✅ Can offer preview before committing

**Cons**:
- ❌ Breaks "pen and paper" philosophy (too much friction)
- ❌ Modal fatigue (annoying on every edit)
- ❌ Doesn't solve "preview while still in note" problem
- ❌ User can't edit multiple pages without committing each one

**Verdict**: ❌ Don't do this - violates your design goals

---

### Option 4: "Draft" Indicator with Text Badge
**Concept**: Show page thumbnail with "DRAFT" overlay until note exit

**How it works**:
```
┌──────────────┐
│ Page 1       │
│ [PDF]        │  ← Existing saved pages
└──────────────┘

┌──────────────┐
│ Page 2       │
│ [blank]      │  ← New page, no content yet
│   DRAFT      │
└──────────────┘
         ↑
    User edited this in markdown
    But it's not rendered yet
    "DRAFT" tells them it exists
```

**Pros**:
- ✅ Minimal implementation (just add badge)
- ✅ User knows page has content (not broken)
- ✅ Maintains "render on exit" workflow
- ✅ No performance overhead

**Cons**:
- ❌ User still can't SEE what they wrote
- ❌ Doesn't solve the core "funny hiatus" problem
- ❌ Requires remembering what they wrote

**Verdict**: 🤷 Better than nothing, but not ideal

---

### Option 5: Side-by-Side Edit/Preview (Split View)
**Concept**: Show markdown editor + live preview simultaneously

**How it works**:
```
┌──────────────┬──────────────┐
│ # Hello      │  Hello       │  ← Left: editor
│              │               │     Right: preview
│ **world**    │  world       │
│              │               │
└──────────────┴──────────────┘
```

**Pros**:
- ✅ WYSIWYG experience
- ✅ Instant feedback while typing
- ✅ Users love this (Bear, Typora, Obsidian all do it)
- ✅ No "hiatus" - preview always visible

**Cons**:
- ⚠️ Screen space (tight on iPhone, fine on iPad)
- ⚠️ Doesn't solve "after exit" problem (preview still temporary)
- ⚠️ Performance cost (continuous re-rendering)
- ⚠️ Complexity (need split view layout)

**Implementation**:
- iPad: side-by-side split
- iPhone: swipe between edit/preview tabs (like Ulysses)

**Verdict**: ✅ Great UX, but significant work

---

## Recommended Solution

### 🏆 Hybrid: Option 1 + Option 2
**"Temporary Preview Render with Visual Indicator"**

**Strategy**:
1. **While in note**: Show temporary preview render
   - On editor exit → render markdown to temp PDF
   - Display temp PDF in page view
   - Add visual indicator: yellow border or "Preview" badge
   - User can tap to return to editor (still editable)

2. **On note exit**: Commit all temp previews to final PDFs
   - Batch render all edited pages
   - Replace temp PDFs with final versions
   - Save to .yianazip
   - Remove "preview" indicators

3. **Optimization**: Use Option 2 (text preview) for fast feedback
   - Immediately after editor exit: show text-based preview
   - Background render to PDF (takes 1-2 seconds)
   - Swap text preview → PDF preview when render completes
   - User sees instant feedback (text), then high-fidelity preview (PDF)

**Why this is best**:
- ✅ User sees their work immediately (no blank page)
- ✅ Maintains "pen and paper" philosophy (final on exit)
- ✅ Fast feedback (text preview) + accurate preview (PDF)
- ✅ Clear visual distinction (preview vs final)
- ✅ No modals or prompts (low friction)

---

## Implementation Sketch (High Level)

### Data Model Changes
```swift
// DocumentMetadata or similar
struct TextPage {
    let pageNumber: Int
    var markdownContent: String?      // nil if rendered to PDF
    var previewPDF: PDFDocument?      // temp render (not saved)
    var finalPDF: PDFDocument?        // saved to .yianazip
    var state: PageState

    enum PageState {
        case final           // Saved to file, immutable
        case editingDraft    // Currently in editor
        case pendingPreview  // Exited editor, not committed
    }
}
```

### View Logic
```swift
// In page viewer
switch page.state {
case .final:
    PDFPageView(pdf: page.finalPDF)

case .editingDraft:
    MarkdownEditor(text: $page.markdownContent)

case .pendingPreview:
    if let preview = page.previewPDF {
        PDFPageView(pdf: preview)
            .overlay(PreviewBadge())  // Yellow border or "PREVIEW" tag
    } else {
        MarkdownPreviewText(content: page.markdownContent)
            .onAppear {
                // Background render to PDF
                renderMarkdownToPDF(page.markdownContent) { pdf in
                    page.previewPDF = pdf
                }
            }
    }
}
```

### On Note Exit
```swift
func finalizeNote() async {
    // Batch render all pending pages
    let pendingPages = pages.filter { $0.state == .pendingPreview }

    for page in pendingPages {
        let finalPDF = await renderMarkdownToPDF(page.markdownContent)
        page.finalPDF = finalPDF
        page.previewPDF = nil  // Free memory
        page.markdownContent = nil  // Remove editable text
        page.state = .final
    }

    await document.save()  // Write to .yianazip
}
```

---

## UX Flow Example

**Scenario**: User adds text to page 3

1. User taps page 3 → taps "Text" button
   - State: `editingDraft`
   - Shows: Markdown editor

2. User types "# Meeting Notes"
   - Still in editor
   - Syntax highlighting active

3. User taps "Done" (exit editor)
   - State: `editingDraft` → `pendingPreview`
   - Action 1: Show text-based preview (instant)
   - Action 2: Background render to temp PDF (~1 sec)
   - Action 3: Swap text → PDF when ready
   - Visual: Yellow border or "PREVIEW" badge

4. User sees page 3 with content visible ✅
   - Not blank anymore!
   - Can tap "Text" to edit again
   - Can swipe to other pages

5. User reviews page 4, returns to page 3
   - Still shows preview (persisted in memory)
   - Badge still visible (not final yet)

6. User exits note (back to document list)
   - State: `pendingPreview` → `final`
   - Action: Final render, save to .yianazip
   - Badge removed, yellow border gone
   - Now immutable (pen and paper!)

---

## Alternative Considerations

### If You Want Pure Simplicity: Option 2 Only
**Just show text preview, skip PDF preview entirely**

- On editor exit → show rendered markdown as SwiftUI Text
- On note exit → render everything to PDF
- Pros: Simple, fast, no double-render
- Cons: Preview doesn't match final (line breaks, fonts differ)

**When to choose this**:
- If PDF rendering is slow (>2 seconds)
- If preview accuracy isn't critical
- If you want minimal code changes

### If You Want Maximum Fidelity: Option 1 Only
**Always render to PDF, accept the cost**

- On editor exit → full PDF render
- Show temp PDF immediately
- On note exit → re-render (or reuse temp as final)
- Pros: WYSIWYG preview
- Cons: Double work, slower, uses more memory

**When to choose this**:
- If PDF rendering is fast (<500ms)
- If preview accuracy is critical
- If memory isn't constrained

---

## Visual Design Suggestions

### Preview Badge Options

**Option A: Corner badge**
```
┌─────────────────┐
│ PREVIEW      [✏️]│ ← Top-right corner
│                 │
│   Hello         │
│   World         │
│                 │
└─────────────────┘
```

**Option B: Border glow**
```
┏━━━━━━━━━━━━━━━┓  ← Yellow/amber border
┃                ┃
┃   Hello        ┃
┃   World        ┃
┃                ┃
┗━━━━━━━━━━━━━━━┛
```

**Option C: Watermark**
```
┌─────────────────┐
│                 │
│   Hello         │
│   World   DRAFT │ ← Faint watermark
│                 │
└─────────────────┘
```

**Recommendation**: Option B (border) - most visible, least intrusive

---

## Questions to Consider

1. **How fast is your PDF rendering?**
   - If <500ms → Option 1 (temp PDF) is fine
   - If >2sec → Option 2 (text preview) is better

2. **How important is preview accuracy?**
   - Critical → Must use temp PDF
   - Nice-to-have → Text preview OK

3. **How often do users edit multiple pages in one session?**
   - Often → Need efficient multi-page preview
   - Rarely → Simple per-page solution OK

4. **What's the typical markdown complexity?**
   - Simple (headings, bold) → Text preview looks good
   - Complex (tables, images) → Need PDF preview

5. **Do you plan to support collaborative editing ever?**
   - Yes → Preview state becomes more important
   - No → Simpler solutions acceptable

---

## Final Recommendation

**Start with: Hybrid (text preview → PDF preview)**

1. Implement text-based preview (fast, 2 hours work)
2. Test with users - do they care about exact layout?
3. If yes: Add background PDF render (4 hours work)
4. If no: Ship text preview only

**Rationale**:
- Solves the "blank page" problem immediately
- Low risk, fast to implement
- Can iterate based on user feedback
- Maintains your "pen and paper" philosophy

**Do NOT**:
- Add modal confirmations (breaks flow)
- Force save on every edit (violates design)
- Leave pages blank (confusing UX)

---

## Questions for You

To refine this advice:
1. How long does PDF rendering typically take?
2. Do users edit one page at a time, or jump between multiple pages?
3. Is markdown simple (headings/lists) or complex (tables/images)?
4. Would users accept "preview won't look 100% identical to final"?

Let me know and I can refine the recommendation!
