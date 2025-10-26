# Vertical Scrolling Test Plan

**Branch**: `experiment/vertical-scrolling-test`
**Date**: 2025-10-26
**Purpose**: Determine if PDFKit's `.singlePageContinuous` mode still exhibits flickering/artifacts on current iOS

## Changes Made

### 1. Display Mode
```swift
// BEFORE (current horizontal paging):
pdfView.displayMode = .singlePage
pdfView.displayDirection = .horizontal

// AFTER (vertical scrolling test):
pdfView.displayMode = .singlePageContinuous
pdfView.displayDirection = .vertical
```

### 2. UIPageViewController
```swift
// BEFORE (enabled for smooth horizontal transitions):
pdfView.usePageViewController(true, withViewOptions: [...])

// AFTER (disabled - conflicts with continuous scrolling):
pdfView.usePageViewController(false, withViewOptions: nil)
```

### 3. Gesture Handlers
- **Swipe up/down**: Keep for UI panels (page management, metadata)
- **Double-tap**: Keep for zoom toggle
- **Horizontal swiping**: Now handled by vertical scroll instead of discrete page turns

## What to Test

### Test Environment
- **Device**: iPad (landscape mode preferred)
- **Document**: Multi-page PDF (5+ pages minimum)
- **iOS Version**: Current (October 2025)

### Test Scenarios

#### 1. Basic Scrolling
- [ ] Scroll smoothly through multiple pages
- [ ] No flickering during scroll
- [ ] No visual artifacts (tearing, corruption)
- [ ] No stuttering or jerky motion

#### 2. Page Transitions
- [ ] Clean visual transition between pages
- [ ] No white flashes
- [ ] No temporary black screens
- [ ] Page boundaries clearly visible

#### 3. Zoom Behavior
- [ ] Double-tap to fit-to-width
- [ ] Content is top-aligned (Y offset = 0)
- [ ] Vertical scrolling still works when zoomed
- [ ] Can scroll through all pages at fit-to-width zoom

#### 4. Memory/Performance
- [ ] Test with large PDFs (20+ pages)
- [ ] No crashes or memory warnings
- [ ] Smooth scrolling throughout document
- [ ] No performance degradation

#### 5. Gesture Conflicts
- [ ] Swipe up triggers page management
- [ ] Swipe down triggers metadata view
- [ ] Vertical scroll doesn't accidentally trigger gestures
- [ ] Double-tap zoom works reliably

## Success Criteria

### ✅ Test PASSES if:
1. No visual flickering or artifacts during scroll
2. Smooth continuous scrolling through all pages
3. Top-alignment works naturally (no fighting)
4. Performance is acceptable on large documents
5. All gestures work as expected

### ❌ Test FAILS if:
1. Visible flickering when scrolling between pages
2. Stuttering or jerky scrolling motion
3. Visual corruption (tearing, black screens, white flashes)
4. Memory issues with large documents
5. Gesture conflicts (can't trigger UI panels)

## Decision Matrix

### If Test PASSES ✅
**Action**: Adopt vertical continuous scrolling as the new standard
- Simpler architecture (no UIPageViewController)
- Top-alignment works naturally
- Matches Files.app/Safari UX patterns
- Update PLAN.md and implement fully

### If Test FAILS ❌
**Action**: Keep current horizontal paging approach
- Document the specific failure symptoms
- Update PDFViewerHistoricalIssues.md with new findings
- Consider alternative approaches:
  - **Hybrid mode** (vertical when zoomed, horizontal when fit-to-height)
  - **Custom layout** (UICollectionView-based)
  - **Accept limitations** (centered fit-to-width, remove top-align)

## Testing Notes

Record observations here during testing:

---

**Tester**:
**Date**:
**Device**:
**iOS Version**:

### Observations:
-

### Issues Found:
-

### Decision:
- [ ] PASS - Adopt vertical scrolling
- [ ] FAIL - Keep horizontal paging
- [ ] INCONCLUSIVE - Needs more testing

---
