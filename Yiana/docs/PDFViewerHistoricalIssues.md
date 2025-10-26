# PDF Viewer Historical Issues - Why We Abandoned Vertical Scrolling

**Date**: 2025-10-26
**Context**: Understanding why we moved from `.singlePageContinuous` to `.singlePage` with UIPageViewController

## Timeline of Issues

### July 29, 2025 - Initial Flickering Problem (commit b652cee)

**Issue**: PDF scrolling flicker on iOS with continuous scrolling mode

**Attempted Fix**: Disabled page view controller when using continuous scrolling
- Problem: Conflict between PDFView's continuous scrolling and UIPageViewController

### August 12, 2025 - Experimental Single-Page Mode (commit 88d1c92)

**Decision**: Switch from `.singlePageContinuous` to `.singlePage`

**Rationale**: "Eliminate scrolling artifacts" and "flickering/hiccup issues"

**Changes Made**:
```swift
// BEFORE:
pdfView.displayMode = .singlePageContinuous
pdfView.displayDirection = .vertical

// AFTER:
pdfView.displayMode = .singlePage
pdfView.displayDirection = .horizontal
```

**Added**:
- Page navigation buttons (left/right arrows)
- UIPageViewController for smooth transitions
- Swipe gestures for page navigation
- Disabled shadows for performance

### September 25, 2025 - Page Transition Glitches (commit aa98498)

**Issue**: UIPageViewController causing "flashing/glitches" during page transitions

**Fix**:
- Removed `pdfView.usePageViewController(true)`
- Added rendering optimizations:
  - `interpolationQuality = .high`
  - `displayBox = .cropBox`
  - `backgroundColor = .systemBackground`

### October 21-26, 2025 - Current State (Tier 2 transitions)

**Re-enabled UIPageViewController** for smooth horizontal paging
- Conflicts with fit-to-width top-alignment goal
- Page view controller centers content (by design)

## The Core Problem with Vertical Continuous Scrolling

### Symptoms Observed

1. **Flickering** - Visual glitches when scrolling between pages
2. **Hiccup issues** - Stuttering or jerky scrolling
3. **Scrolling artifacts** - Visual corruption or tearing

### Root Cause (Suspected)

PDFKit's `.singlePageContinuous` mode on iOS has performance/rendering issues:
- May be related to PDFView's internal layout calculations
- Could be memory management issues with large documents
- Possibly iOS-specific (may not affect macOS)

### Why Single-Page Mode Worked

- Only one page rendered at a time (lower memory footprint)
- No continuous scroll calculations
- UIPageViewController handles page-to-page transitions
- Discrete page boundaries (no ambiguous scroll positions)

## Current Dilemma

### What We Want
- Vertical continuous scrolling (like Files.app)
- Top-aligned fit-to-width zoom
- Smooth page transitions

### What We Have
- Horizontal single-page mode with UIPageViewController
- Smooth page transitions ✅
- Centered content (conflicts with top-alignment) ❌

### The Conflict
UIPageViewController is designed to center pages. When we try to top-align content, it fights us.

## Questions to Answer

### 1. Has PDFKit been fixed since July 2025?
- Was this an iOS 18 beta issue that's now resolved?
- Should we test `.singlePageContinuous` again?

### 2. What exactly were the "scrolling artifacts"?
- Page flickering during scroll?
- Memory issues causing crashes?
- Layout jumping/bouncing?
- PDF rendering corruption?

### 3. Can we reproduce the original issue?
Need to test on current iOS to see if the problem still exists.

## Next Steps

1. **Test `.singlePageContinuous` on current iOS** to see if flickering is still present
2. **Document the exact symptoms** if it still occurs
3. **Consider workarounds** if vertical scrolling is truly broken:
   - Custom page layout using UICollectionView
   - PDFView subclass with manual page management
   - Accept horizontal paging as the iOS pattern

## Possible Solutions if Vertical Scrolling Still Broken

### Option A: Accept Horizontal Paging (Current Approach)
- Keep UIPageViewController for smooth transitions
- Remove top-alignment feature (accept centered content)
- Matches iBooks UX pattern

### Option B: Hybrid Mode Switching
- Horizontal paging for fit-to-height
- Custom vertical scroll for fit-to-width (without PDFView's continuous mode)
- Complex but achieves both goals

### Option C: Custom Page Layout
- Don't use PDFView's display modes at all
- Build our own page layout using UICollectionView
- Full control but significant engineering effort

### Option D: Wait for Apple to Fix PDFKit
- File bug report with Apple
- Stick with current horizontal paging
- Revisit in future iOS versions
