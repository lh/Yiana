# ADR 001: PDF Page Size Tolerance for Gesture Recognition

**Date**: 2025-10-07
**Status**: Accepted
**Deciders**: Development Team
**Context**: Swipe-up gesture for page management was failing on finalized markdown pages after app restart

---

## Context and Problem Statement

The app supports documents with mixed page sizes:
- **A4 pages**: 595.2 × 841.8 points (default for text pages per TextPageLayoutSettings.swift)
- **US Letter pages**: 612.0 × 792.0 points (common for scanned documents)

The swipe-up gesture to open page management uses a zoom-level check to ensure pages are at "fit to screen" zoom:

```swift
let currentScale = pdfView.scaleFactor
let fitScale = pdfView.scaleFactorForSizeToFit
let isAtFitZoom = abs(currentScale - fitScale) < 0.01  // TOO STRICT
```

The original tolerance of `0.01` was too strict and failed when documents contained mixed page sizes because PDFKit calculates different `scaleFactorForSizeToFit` values for A4 vs US Letter pages.

## Decision Drivers

- Must work reliably across all iOS devices (iPhone SE through iPad Pro 12.9")
- Must accommodate documents with mixed A4 and US Letter pages
- Should still prevent false positives when user is genuinely zoomed in
- Keep implementation simple and maintainable

## Considered Options

### Option 1: Fixed tolerance of 0.10
```swift
let tolerance: CGFloat = 0.10
let isAtFitZoom = abs(currentScale - fitScale) < tolerance
```

### Option 2: Platform-specific tolerance
```swift
let tolerance: CGFloat
#if os(iOS)
if UIDevice.current.userInterfaceIdiom == .pad {
    tolerance = 0.12  // iPads
} else {
    tolerance = 0.05  // iPhones
}
#else
tolerance = 0.10  // macOS
#endif
```

### Option 3: Percentage-based tolerance
```swift
let tolerance = fitScale * 0.10  // 10% of fit scale
```

## Decision Outcome

**Chosen option: Fixed tolerance of 0.10**

### Rationale

Testing across all iOS device sizes revealed maximum scale factor differences:

| Device | A4 Scale | US Letter Scale | Difference |
|--------|----------|-----------------|------------|
| iPhone SE | 0.630 | 0.613 | 0.017 |
| iPhone 15 | 0.660 | 0.642 | 0.018 |
| iPhone 15 Pro Max | 0.722 | 0.703 | 0.019 |
| iPad Pro 11" | 1.401 | 1.363 | 0.038 |
| **iPad Pro 12.9"** | 1.720 | 1.623 | **0.097** |

The worst case is **iPad Pro 12.9" at 0.097 difference** - this device's aspect ratio (≈0.750) falls between US Letter (0.773) and A4 (0.707), causing maximum divergence.

A tolerance of **0.10** covers all devices with a small safety margin while remaining strict enough to reject genuinely zoomed pages (>10% zoom).

### Implementation

**File**: `Yiana/Views/PDFViewer.swift` (line 437)

**Change**:
```swift
- let isAtFitZoom = abs(currentScale - fitScale) < 0.01
+ let isAtFitZoom = abs(currentScale - fitScale) < 0.10
```

### Consequences

**Positive**:
- ✅ Gesture works reliably on all devices with mixed page sizes
- ✅ Simple one-line change - easy to maintain
- ✅ Well-tested value based on real device measurements
- ✅ Accommodates future device sizes

**Negative**:
- ⚠️ Users can zoom in ~10% before gesture stops working (acceptable trade-off)
- ⚠️ Less strict than original 0.01 tolerance

**Neutral**:
- Testing showed all current devices pass with 0.10 tolerance
- Alternative percentage-based approach (Option 3) would be more mathematically robust but adds complexity

## Related Decisions

- Text pages default to A4 (TextPageLayoutSettings.swift:56)
- 1-based page indexing throughout app (ADR 002 - to be documented)
- Read-only PDF viewing without annotations (architectural decision)

## References

- Bug Report: Swipe-up gesture not working on finalized markdown pages
- Analysis: `/Users/rose/Code/Yiana/comments/2025-10-07-page-size-mismatch-diagnosis.md`
- Calculations: `/Users/rose/Code/Yiana/comments/2025-10-07-tolerance-calculation.md`
- Code: `Yiana/Services/TextPageLayoutSettings.swift`
- Code: `Yiana/Views/PDFViewer.swift`
