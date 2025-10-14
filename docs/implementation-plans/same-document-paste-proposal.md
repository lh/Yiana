# Same-Document Page Paste Feature Proposal

**Date:** October 13, 2025
**Author:** Implementation Team
**Status:** Proposed
**Platforms:** iOS, iPadOS, macOS

---

## Executive Summary

Currently, when pages are copied from a document in Yiana, they cannot be pasted back into the same document. This limitation prevents users from duplicating pages within a document, which is a common use case for creating templates, duplicating forms, or reorganizing content. This proposal outlines a solution to enable same-document paste operations while maintaining data integrity and preventing conflicts with cut operations.

---

## Current Implementation Analysis

### Current Behavior
1. **Copy Operation**: Creates a `PageClipboardPayload` with source document ID
2. **Cut Operation**: Creates payload with source ID and stores original document data for restoration
3. **Paste Operation**: Currently works but has issues:
   - No explicit check preventing same-document paste
   - Cut operations clear clipboard after paste, making duplication impossible
   - No safeguards against pasting cut pages back into the same document

### Data Model
```swift
struct PageClipboardPayload {
    let sourceDocumentID: UUID?  // Identifies source document
    let operation: Operation      // .copy or .cut
    let pdfData: Data             // The actual page data
    let sourceDataBeforeCut: Data? // For cut restoration
}
```

### The Core Issue
The current implementation doesn't distinguish between:
1. **Duplicating pages** (copy → paste in same document) - Should be allowed
2. **Moving pages** (cut → paste in same document) - Currently problematic
3. **Restoring cut pages** (undo a cut operation) - Already handled separately

---

## Proposed Solution

### Design Principles
1. **Allow copy-paste within same document** for page duplication
2. **Prevent cut-paste loops** that could cause data inconsistency
3. **Maintain clear user mental model** of copy vs cut operations
4. **Preserve existing cross-document functionality**

### Implementation Strategy

#### Phase 1: Enable Same-Document Copy-Paste
Modify `performPaste` to handle same-document operations intelligently:

```swift
private func performPaste(at insertIndex: Int? = nil) {
    guard let payload = PageClipboard.shared.currentPayload() else { return }

    // Check if this is a same-document operation
    let isSameDocument = payload.sourceDocumentID == viewModel.documentID

    // Handle cut operations specially for same document
    if isSameDocument && payload.operation == .cut {
        // Option 1: Convert to copy operation silently
        // Option 2: Show alert explaining the limitation
        // Option 3: Implement smart cut-paste (see Phase 2)
        alertMessage = "Cannot paste cut pages back into the same document. Use 'Restore Cut' instead."
        return
    }

    Task {
        do {
            let insertAt = insertIndex ?? pages.count
            let inserted = try await viewModel.insertPages(from: payload, at: insertAt)

            // For copy operations in same document, don't clear clipboard
            if payload.operation == .cut && !isSameDocument {
                PageClipboard.shared.clear()
            }

            // Clear cut indicators
            cutPageIndices = nil

            // Select the newly inserted pages
            selectedPages = Set(insertAt..<(insertAt + inserted))

            // Reload pages to reflect changes
            loadPages()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
```

#### Phase 2: Smart Cut-Paste for Same Document (Optional Enhancement)
If we want to support cut-paste within the same document (essentially a move operation):

```swift
private func performSmartPaste(at insertIndex: Int? = nil) {
    guard let payload = PageClipboard.shared.currentPayload() else { return }

    if payload.sourceDocumentID == viewModel.documentID && payload.operation == .cut {
        // This is a move operation within the same document
        guard let cutIndices = payload.cutIndices else { return }

        Task {
            do {
                // Calculate adjusted insertion index after removal
                let adjustedIndex = calculateAdjustedIndex(
                    insertAt: insertIndex ?? pages.count,
                    removedIndices: cutIndices
                )

                // Perform the move as a single atomic operation
                let moved = try await viewModel.movePages(
                    from: Set(cutIndices),
                    to: adjustedIndex
                )

                // Clear the cut state
                PageClipboard.shared.clear()
                cutPageIndices = nil

                // Select moved pages at their new location
                selectedPages = Set(adjustedIndex..<(adjustedIndex + moved))

                loadPages()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    } else {
        // Regular paste operation
        performPaste(at: insertIndex)
    }
}
```

#### Phase 3: UI/UX Improvements

1. **Visual Feedback**:
   - Show different paste icon for same-document operations
   - Display tooltip: "Duplicate pages" vs "Paste pages"

2. **Contextual Menus**:
   - Add explicit "Duplicate Selection" command for clarity
   - Keep "Paste" for cross-document operations

3. **Keyboard Shortcuts**:
   - Cmd+D for duplicate (same document)
   - Cmd+V for paste (any document)

---

## Implementation Plan

### Step 1: Core Functionality (2-3 hours)
1. Modify `performPaste` to check source document ID
2. Allow copy-paste within same document
3. Block or handle cut-paste within same document
4. Add appropriate user feedback messages

### Step 2: Testing (1-2 hours)
1. Test copy-paste within same document
2. Test cut-paste prevention/handling
3. Verify cross-document operations still work
4. Test edge cases (empty selection, large selections)

### Step 3: UI Polish (1 hour)
1. Update button labels contextually
2. Add duplicate command if desired
3. Update help text and tooltips

---

## Alternative Approaches Considered

### Alternative 1: Always Allow Everything
- **Pros**: Simple, no restrictions
- **Cons**: Cut-paste in same document is confusing and could lose data

### Alternative 2: Separate Duplicate Command
- **Pros**: Clear mental model, no confusion
- **Cons**: Extra UI complexity, doesn't leverage clipboard

### Alternative 3: Convert Cut to Copy for Same Document
- **Pros**: Allows operation to proceed
- **Cons**: Violates user expectation of cut behavior

---

## Risks and Mitigations

### Risk 1: User Confusion
**Mitigation**: Clear messaging about what operations are allowed and why

### Risk 2: Data Loss with Cut Operations
**Mitigation**: Keep "Restore Cut" functionality, prevent same-document cut-paste

### Risk 3: Performance with Large Duplications
**Mitigation**: Existing pagination limits (200 pages) already handle this

---

## Testing Checklist

- [ ] Copy 1 page, paste in same document → Success
- [ ] Copy multiple pages, paste in same document → Success
- [ ] Cut pages, attempt paste in same document → Appropriate handling
- [ ] Copy from document A, paste in document B → Success
- [ ] Cut from document A, paste in document B → Success
- [ ] Duplicate pages maintains selection
- [ ] Undo/redo works with duplication
- [ ] Memory usage acceptable with large duplications

---

## Recommendation

Implement **Phase 1** immediately to enable copy-paste within the same document while preventing cut-paste loops. This provides immediate value with minimal risk. Consider Phase 2 (smart cut-paste) as a future enhancement based on user feedback.

The key insight is that users expect to be able to duplicate pages within a document (a common operation), but cut-paste within the same document is conceptually problematic and should be handled differently (either prevented or converted to a move operation).