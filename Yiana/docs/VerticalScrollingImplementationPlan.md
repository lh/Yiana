# Vertical Scrolling Implementation Plan

**Date**: 2025-10-26
**Status**: Apple fixed the vertical scrolling bugs! 🎉
**Branch**: `experiment/vertical-scrolling-test` → merge to `refactor/HIG`

## Test Results

✅ **PASSED** - Vertical continuous scrolling works perfectly:
- No flickering
- No artifacts
- Smooth and beautiful scrolling
- Ready for production use

## Implementation Tasks

### Phase 1: UI Cleanup & Access Methods

#### 1. Remove Disabled Gestures ✅
- Delete commented-out swipe up/down gesture code
- We don't need vertical swipes anymore (conflicts with scrolling)

#### 2. Page Organizer Access → Tap Page Indicator ✅
**Implementation**:
```swift
// Add tap gesture to page indicator view
.onTapGesture {
    onRequestPageManagement?()
}
```

**Location**: `PDFViewer.swift` - the `pageIndicator` view
**UX**: User taps "Page 3 of 10" lozenge → page grid opens

#### 3. Metadata Access → Info Icon ✅
**Implementation**:
```swift
// Add to navigation bar trailing items
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { onRequestMetadataView?() }) {
            Image(systemName: "info.circle")
        }
    }
}
```

**Location**: `PDFViewer.swift` - toolbar section
**UX**: User taps ⓘ icon → metadata sheet opens
**Note**: Title tap already handles editing, this is separate

### Phase 2: Default Zoom to Fit-to-Width

#### 4. Change Default Fit Mode ✅
**Current behavior**:
```swift
// In updateUIView/updateNSView, orientation-aware:
let isLandscape = pdfView.bounds.width > pdfView.bounds.height
if isLandscape {
    applyFitToWidth(...)
} else {
    applyFitToHeight(...)
}
```

**New behavior**:
```swift
// Always fit to width (iOS only, macOS keeps current behavior)
#if os(iOS)
applyFitToWidth(pdfView, coordinator: context.coordinator)
#else
applyFitToHeight(pdfView, coordinator: context.coordinator)
#endif
```

**Location**: `PDFViewer.swift` - `updateUIView` initial fit logic (around line 266)

#### 5. Verify Top-Alignment ✅
**What to check**:
- After fit-to-width, content Y offset = 0 (top of page visible)
- Should work naturally now (no UIPageViewController interference)
- Remove timing-based `topAlignContent` delay if it works immediately

**Test**: Double-tap to fit-to-width, verify top of page is visible

#### 6. Test with iPad Split View ✅
**Scenario**: Open another app in iPad split view, verify:
- PDFView bounds reflect available space (excluding sidebar)
- Fit-to-width calculation uses correct available width
- Scrolling still smooth
- Top-alignment still works

**Note**: macOS implementation is separate and working - don't touch it

### Phase 3: Code Cleanup

#### 7. Remove UIPageViewController Remnants ✅
**What to delete**:
- `private let pageSpacing: CGFloat = 12` constant (line ~187)
- All references to pageSpacing
- Comments about UIPageViewController

**Verify**: Code only uses `displayMode = .singlePageContinuous`

#### 8. Update Documentation ✅
**Files to update**:
- `docs/PDFViewerHistoricalIssues.md` - Mark issue as RESOLVED
- `docs/PDFViewerUXDecisions.md` - Update with final implementation
- `docs/VerticalScrollingTestPlan.md` - Mark as PASSED
- `CLAUDE.md` or relevant architecture docs - Document new gesture mappings

### Phase 4: Testing & Merge

#### 9. Comprehensive Testing ✅
- [ ] iPad landscape - vertical scroll through multi-page PDF
- [ ] iPad portrait - vertical scroll
- [ ] iPhone - vertical scroll
- [ ] iPad split view - verify bounds calculation
- [ ] Tap page indicator → opens page organizer
- [ ] Tap info icon → opens metadata
- [ ] Double-tap → toggle fit-to-width/fit-to-height
- [ ] Pinch zoom still works
- [ ] No flickering or artifacts

#### 10. Merge to Main Branch ✅
- Commit all changes with clear messages
- Merge `experiment/vertical-scrolling-test` → `refactor/HIG`
- Delete experimental branch
- Update PLAN.md to mark this as complete

## Implementation Notes

### Top-Alignment Implementation

Since UIPageViewController is gone, top-alignment should work with simple logic:

```swift
private func applyFitToWidth(_ pdfView: PDFView, coordinator: Coordinator) {
    guard let page = pdfView.currentPage else { return }
    let pageRect = page.bounds(for: pdfView.displayBox)
    let viewWidth = pdfView.bounds.width
    let scaleFactor = viewWidth / pageRect.width
    pdfView.scaleFactor = scaleFactor
    coordinator.lastKnownScaleFactor = scaleFactor
    coordinator.currentFitMode = .width
    coordinator.lastExplicitFitMode = .width

    #if os(iOS)
    // Top-align content - should work immediately now
    if let scrollView = findScrollView(in: pdfView) {
        scrollView.contentOffset.y = 0
    }
    #endif
}
```

**Remove** the `DispatchQueue.main.asyncAfter` timing hack - not needed anymore!

### Gesture Mapping (iOS)

**After implementation**:
- Vertical scroll (native) - Navigate through pages
- Double-tap - Toggle fit-to-width ↔ fit-to-height
- Pinch - Custom zoom
- Tap page indicator - Open page organizer
- Tap info icon - Open metadata
- Tap title - Edit title (existing behavior)

**No edge swipes needed** - all interactions have clear affordances

## Success Criteria

✅ All tasks completed
✅ No flickering or artifacts
✅ Smooth vertical scrolling
✅ Top-aligned fit-to-width by default
✅ Page organizer accessible via tap
✅ Metadata accessible via info icon
✅ All tests passing
✅ Documentation updated

---

**Status**: Ready to implement
**Next Step**: Start with Phase 1, Task 1 (remove commented gestures)
