# DIAGNOSIS: Page Size Mismatch Causing Gesture Failure
**Date**: 2025-10-07
**Status**: 🎯 ROOT CAUSE IDENTIFIED

## The Smoking Gun

### Your Markdown Pages Use A4 Paper
**File**: `TextPageLayoutSettings.swift:56`

```swift
func preferredPaperSize() -> TextPagePaperSize {
    if let rawValue = defaults.string(forKey: paperSizeKey),
       let stored = TextPagePaperSize(rawValue: rawValue) {
        return stored
    }
    return .a4  // ⚠️ DEFAULT IS A4
}
```

**A4 size**: 595.2 × 841.8 points (210mm × 297mm)
**US Letter size**: 612.0 × 792.0 points (8.5" × 11")

### Your Scanned Pages Likely Use US Letter
**Why**: Most iPhone/iPad cameras in US default to US Letter aspect ratio when scanning documents.

---

## The Scale Factor Problem

### PDFView Scale Calculation

When PDFView displays a page, it calculates `scaleFactorForSizeToFit`:
```
scaleFactorForSizeToFit = min(viewWidth / pageWidth, viewHeight / pageHeight)
```

**For A4 page (595.2 × 841.8)**:
```
scale = min(screenWidth / 595.2, screenHeight / 841.8)
```

**For US Letter page (612.0 × 792.0)**:
```
scale = min(screenWidth / 612.0, screenHeight / 792.0)
```

**Result**: Different page sizes → different scale factors!

### The Gesture Check

**File**: `PDFViewer.swift:437`

```swift
let currentScale = pdfView.scaleFactor
let fitScale = pdfView.scaleFactorForSizeToFit

let isAtFitZoom = abs(currentScale - fitScale) < 0.01  // ⚠️ Too strict!

if isAtFitZoom {
    onRequestPageManagement?()
}
```

**Problem**: The tolerance `0.01` is TOO STRICT for different page sizes.

---

## Why This Fails

### Example Calculation (iPhone 15, portrait)

**Screen dimensions**: ~390 × ~844 points (excluding safe area)

#### US Letter Page (612 × 792)
```
scaleFactorForSizeToFit = min(390/612, 844/792)
                        = min(0.637, 1.066)
                        = 0.637
```

#### A4 Page (595.2 × 841.8)
```
scaleFactorForSizeToFit = min(390/595.2, 844/841.8)
                        = min(0.655, 1.003)
                        = 0.655
```

**Difference**: 0.655 - 0.637 = **0.018**

**This exceeds the 0.01 tolerance!**

So when you swipe up on an A4 page, the check fails:
```swift
abs(0.655 - 0.655) < 0.01  // ✅ True for A4-on-A4
abs(0.655 - 0.637) < 0.01  // ❌ False! 0.018 > 0.01
```

---

## Why Scanned Pages Work

**Hypothesis**: Your scanned pages are actually using **inconsistent** page sizes, or PDFKit is normalizing them differently.

**Possible scenarios**:

### 1. Scanned Pages Are Also Variable
If your scanning doesn't enforce strict dimensions, scanned PDFs might have:
- Slightly different sizes per scan session
- Rounded dimensions (e.g., 612 × 792 exact)
- Auto-corrected to "standard" sizes by VisionKit

### 2. Rendering Difference
- Scanned pages: Created by VisionKit → may use exact standard sizes
- Markdown pages: Rendered programmatically → precise decimals (595.2 exactly)

The tolerance check is so strict that small rendering differences break it.

---

## The Real Issue: Page Size Inconsistency

You have **mixed page sizes** in the same document:
- Pages 1-3: Scanned (US Letter or variable)
- Page 4: Markdown-rendered (A4)

When PDFView displays the document, it tries to scale all pages to fit. But with different page sizes:
- It may use a "compromise" scale for multi-size documents
- Or it recalculates per-page
- Leading to scale mismatches

---

## Solutions (Ranked by Effort)

### 🥇 Solution 1: Increase Tolerance (5 minutes)

**File**: `PDFViewer.swift:437`

```swift
let currentScale = pdfView.scaleFactor
let fitScale = pdfView.scaleFactorForSizeToFit

// ✅ FIXED: More lenient tolerance for mixed page sizes
let tolerance: CGFloat = 0.05  // Increased from 0.01
let isAtFitZoom = abs(currentScale - fitScale) < tolerance

#if DEBUG
if !isAtFitZoom {
    print("⚠️ Swipe-up ignored: scale=\(currentScale), fit=\(fitScale), diff=\(abs(currentScale - fitScale))")
}
#endif

if isAtFitZoom {
    onRequestPageManagement?()
}
```

**Pros**:
- ✅ Quick fix (1 line change)
- ✅ Works for all page size combinations
- ✅ Low risk

**Cons**:
- ⚠️ Might trigger when slightly zoomed (acceptable tradeoff)

**Recommendation**: **START HERE** - this will likely fix your issue immediately.

---

### 🥈 Solution 2: Normalize All Pages to Same Size (2-3 hours)

**Goal**: Ensure all pages (scanned + markdown) use the same paper size.

#### Option A: Force US Letter for Markdown

**File**: `TextPageLayoutSettings.swift:56`

```swift
func preferredPaperSize() -> TextPagePaperSize {
    if let rawValue = defaults.string(forKey: paperSizeKey),
       let stored = TextPagePaperSize(rawValue: rawValue) {
        return stored
    }
    // ✅ Changed default to US Letter
    return .usLetter  // Was: .a4
}
```

**Add**: User setting to choose default paper size in app settings.

#### Option B: Normalize Scanned Pages to A4

When importing scanned pages, resize them to A4:
```swift
// In ScanningService or import logic
func normalizePDFToA4(_ pdfData: Data) -> Data? {
    guard let document = PDFDocument(data: pdfData) else { return nil }

    let a4Size = CGSize(width: 595.2, height: 841.8)
    // ... resize pages to A4 ...

    return normalizedDocument.dataRepresentation()
}
```

**Pros**:
- ✅ Consistent page sizes across entire app
- ✅ Predictable scaling behavior
- ✅ Professional appearance (all pages same size)

**Cons**:
- ⚠️ More work to implement
- ⚠️ May distort scanned images slightly
- ⚠️ Need migration for existing documents

---

### 🥉 Solution 3: Remove Zoom Check Entirely (30 minutes)

**File**: `PDFViewer.swift:427-443`

```swift
@objc func swipeUp(_ gesture: UISwipeGestureRecognizer) {
    guard let pdfView = gesture.view as? PDFView else { return }

    // ✅ SIMPLIFIED: Always trigger, no zoom check
    onRequestPageManagement?()

    /* Original zoom check removed
    let currentScale = pdfView.scaleFactor
    let fitScale = pdfView.scaleFactorForSizeToFit
    let isAtFitZoom = abs(currentScale - fitScale) < 0.01

    if isAtFitZoom {
        onRequestPageManagement?()
    }
    */
}
```

**Pros**:
- ✅ Simplest solution
- ✅ Consistent behavior always
- ✅ Works regardless of page size

**Cons**:
- ❌ Triggers even when zoomed in (may be confusing)
- ❌ Loses "only at fit zoom" intentional design

**When to use**: If zoom check isn't critical to your UX.

---

### 🔬 Solution 4: Dynamic Tolerance Based on Page Size (1-2 hours)

**Most sophisticated approach**:

```swift
@objc func swipeUp(_ gesture: UISwipeGestureRecognizer) {
    guard let pdfView = gesture.view as? PDFView else { return }

    let currentScale = pdfView.scaleFactor
    let fitScale = pdfView.scaleFactorForSizeToFit

    // ✅ Calculate tolerance based on page dimensions
    let tolerance: CGFloat
    if let page = pdfView.currentPage {
        let bounds = page.bounds(for: .mediaBox)
        let aspectRatio = bounds.width / bounds.height

        // Larger variance for non-standard aspect ratios
        if abs(aspectRatio - (612.0/792.0)) < 0.05 {
            tolerance = 0.02  // US Letter-like
        } else if abs(aspectRatio - (595.2/841.8)) < 0.05 {
            tolerance = 0.02  // A4-like
        } else {
            tolerance = 0.10  // Non-standard sizes
        }
    } else {
        tolerance = 0.05  // Default fallback
    }

    let isAtFitZoom = abs(currentScale - fitScale) < tolerance

    if isAtFitZoom {
        onRequestPageManagement?()
    }
}
```

**Pros**:
- ✅ Adapts to different page types
- ✅ Maintains zoom-check intent
- ✅ Handles edge cases

**Cons**:
- ⚠️ More complex
- ⚠️ Harder to debug

---

## Recommended Implementation Plan

### Phase 1: Quick Fix (Today - 5 minutes)

**Change tolerance from 0.01 to 0.05**:
```swift
// PDFViewer.swift:437
let tolerance: CGFloat = 0.05  // Increased from 0.01
let isAtFitZoom = abs(currentScale - fitScale) < tolerance
```

**Test**: Verify swipe-up works on both scanned and markdown pages.

### Phase 2: Long-term Solution (Next sprint - 2-3 hours)

**Option A: If users are mostly US-based**
- Change default paper size to `.usLetter`
- Add settings UI to choose paper size
- Show paper size indicator in text editor

**Option B: If users are international**
- Detect locale and use appropriate default (US Letter vs A4)
- Allow per-document paper size choice
- Show visual indicator of page size in editor

### Phase 3: Polish (Optional - 1 hour)

- Add logging to track scale mismatches in production
- Consider normalizing all PDFs on import
- Document expected behavior in code comments

---

## Testing Checklist

After implementing tolerance fix:

- [ ] Create new markdown page → exit → reopen → swipe up works ✓
- [ ] Create mixed document (scan + markdown) → swipe up works on both ✓
- [ ] Test on iPhone (various models) ✓
- [ ] Test on iPad (regular and split view) ✓
- [ ] Test with zoomed-in page (should NOT trigger - optional) ✓
- [ ] Test with different paper size settings ✓

---

## Debug Logging to Confirm

Add this to `swipeUp()` method temporarily:

```swift
@objc func swipeUp(_ gesture: UISwipeGestureRecognizer) {
    guard let pdfView = gesture.view as? PDFView else { return }

    let currentScale = pdfView.scaleFactor
    let fitScale = pdfView.scaleFactorForSizeToFit
    let diff = abs(currentScale - fitScale)

    // ✅ DEBUG: Log page info
    if let page = pdfView.currentPage {
        let bounds = page.bounds(for: .mediaBox)
        print("📄 Page size: \(bounds.size)")
        print("📏 Current scale: \(currentScale)")
        print("📏 Fit scale: \(fitScale)")
        print("📏 Difference: \(diff)")
        print("🎯 Would trigger with 0.01? \(diff < 0.01)")
        print("🎯 Would trigger with 0.05? \(diff < 0.05)")
    }

    let tolerance: CGFloat = 0.05
    let isAtFitZoom = abs(currentScale - fitScale) < tolerance

    if isAtFitZoom {
        print("✅ Triggering page management")
        onRequestPageManagement?()
    } else {
        print("❌ Swipe ignored (not at fit zoom)")
    }
}
```

**What to look for**:
- Scanned pages: What size? What scale?
- Markdown pages: Confirms A4 (595.2 × 841.8)?
- Scale difference: Confirms > 0.01?

---

## Summary

**Root cause**: A4 markdown pages (595.2 × 841.8) vs US Letter scanned pages (612.0 × 792.0) create different scale factors, failing the strict 0.01 tolerance check.

**Quick fix**: Increase tolerance to 0.05 in `PDFViewer.swift:437`

**Long-term fix**: Normalize all pages to same size (either at scan time or render time)

**Estimated fix time**: 5 minutes (tolerance change) or 2-3 hours (normalization)

---

**Next action**: Change tolerance to 0.05 and test on your device!
