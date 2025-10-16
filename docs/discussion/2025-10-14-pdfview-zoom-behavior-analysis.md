# PDFView Zoom Behavior Analysis

**Date**: 2025-10-14
**Issue**: Strange zoom behavior where initial pinch gestures don't work, but work after using keyboard shortcuts

## Observed Behavior

1. **Initial page load**: Page fits screen correctly
2. **Pinch to zoom in**: Fails - no effect
3. **Pinch to zoom out**: Makes page smaller but immediately bounces back to fit-to-screen
4. **Using Command-+ or Command--**: Works correctly
5. **After using keyboard shortcuts**: Pinch gestures now work as expected
6. **Double-tap**: Does NOT return page to fit-to-screen (expected behavior missing)

## Root Cause Analysis

### 1. `autoScales` Property Conflict

**Location**: `PDFViewer.swift:253`

```swift
pdfView.autoScales = true
```

**Apple's Documentation** (from PDFKit):
> When `autoScales` is `true`, PDFView automatically adjusts the scale factor to ensure the PDF page fits the visible area. This happens:
> - On initial display
> - After window resizing
> - **After any programmatic zoom change**

**The Problem**:
- `autoScales = true` continuously monitors and resets the scale factor
- When user pinches to zoom OUT, `autoScales` detects the scale is below fit-to-window and **immediately resets it**
- When user pinches to zoom IN, the gesture may be fighting against `autoScales`'s attempts to maintain fit-to-window

### 2. Why Keyboard Shortcuts Work

When `Command-+` or `Command--` is pressed:

```swift
case .zoomIn:
    pdfView.zoomIn(nil)
case .zoomOut:
    pdfView.zoomOut(nil)
```

**PDFView's `zoomIn(_:)` and `zoomOut(_:)` methods**:
- These methods **temporarily disable** `autoScales` internally
- They perform the zoom
- They leave `autoScales` disabled until explicitly re-enabled or until fit-to-window is called

This is why after using keyboard shortcuts, pinch gestures work - `autoScales` has been implicitly disabled.

### 3. Missing Double-Tap Handler

**Current State**: No double-tap gesture is configured for PDFView
**Expected**: Double-tap should trigger fit-to-window (same as Command-0)

On iOS, there are tap gestures defined (lines 271-287) for swipes, but no double-tap for zoom reset.
On macOS, there are no tap gestures configured at all.

## Technical Details from PDFKit

### `autoScales` Behavior
- **Purpose**: Ensures document always fits visible area
- **Side Effect**: Prevents manual zoom unless explicitly disabled
- **Recommendation**: Should be `false` for apps that allow user zoom control

### Scale Factor Management
```swift
pdfView.scaleFactor              // Current zoom level
pdfView.scaleFactorForSizeToFit  // Calculated fit-to-window scale
pdfView.minScaleFactor           // Minimum zoom (default: 0.25)
pdfView.maxScaleFactor           // Maximum zoom (default: 8.0)
```

### Zoom Methods
- `zoomIn(_:)`: Increases scale by ~1.3x, **disables autoScales**
- `zoomOut(_:)`: Decreases scale by ~0.77x, **disables autoScales**
- Setting `scaleFactor` directly: Does NOT disable autoScales (may be overridden)

## Proposed Solution

### Option A: Disable `autoScales` Completely (Recommended)

**Changes**:
1. Set `pdfView.autoScales = false` on configuration
2. Manually set initial scale to fit-to-window:
   ```swift
   pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
   ```
3. Handle window resize events to recalculate fit-to-window if desired
4. Add double-tap gesture to trigger fit-to-window

**Pros**:
- User has full manual zoom control
- No "bouncing back" behavior
- Consistent with most PDF viewer apps

**Cons**:
- Must manually handle window resize if we want auto-fit on resize
- Slightly more complex state management

### Option B: Smart `autoScales` Management

**Changes**:
1. Start with `autoScales = true` for initial fit
2. Disable `autoScales` when user performs first manual zoom
3. Re-enable when user explicitly requests fit-to-window (Command-0 or double-tap)
4. Add double-tap gesture

**Pros**:
- Best of both worlds - auto-fit initially, manual control after
- Window resize can still auto-fit when in "auto" mode

**Cons**:
- More complex state tracking
- Need to track "user has zoomed" flag

### Option C: Conditional `autoScales` Based on Scale

**Changes**:
1. Keep `autoScales = true`
2. Monitor scale factor changes
3. If scale deviates from fit-to-window by threshold, disable `autoScales`
4. Re-enable when returning to fit-to-window

**Pros**:
- Automatic handling
- No explicit user intent tracking needed

**Cons**:
- Most complex implementation
- May have edge cases with rapid zoom changes

## Recommendation

**Option A (Disable autoScales)** is the cleanest solution:

1. It matches user expectations from other PDF viewers
2. It's the simplest to implement and maintain
3. It eliminates the "bouncing back" issue completely
4. We can still provide fit-to-window via Command-0 and double-tap

### Implementation Plan

1. **Modify `configurePDFView`** (line 253):
   ```swift
   pdfView.autoScales = false
   pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
   ```

2. **Add double-tap gesture** (iOS - around line 287, macOS - new):
   ```swift
   // iOS
   let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.doubleTap(_:)))
   doubleTap.numberOfTapsRequired = 2
   pdfView.addGestureRecognizer(doubleTap)

   // macOS
   let doubleTap = NSClickGestureRecognizer(target: context.coordinator,
                                            action: #selector(Coordinator.doubleTap(_:)))
   doubleTap.numberOfClicksRequired = 2
   pdfView.addGestureRecognizer(doubleTap)
   ```

3. **Add Coordinator method**:
   ```swift
   @objc func doubleTap(_ gesture: TapGestureRecognizer) {
       guard let pdfView = gesture.view as? PDFView else { return }
       pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
   }
   ```

4. **Optional: Handle window resize** (macOS):
   - Listen for frame changes
   - Recalculate and maintain current zoom level relative to new size
   - OR provide a "reset zoom" button if window resized

## Testing Plan

1. Verify pinch gestures work immediately after page load
2. Verify zoom in doesn't bounce back
3. Verify zoom out doesn't bounce back
4. Verify Command-+, Command--, Command-0 still work
5. Verify double-tap returns to fit-to-window
6. Verify behavior persists across page navigation
7. Verify behavior after window resize (macOS)

## References

- [Apple PDFKit Documentation](https://developer.apple.com/documentation/pdfkit/pdfview)
- `PDFView.autoScales`: Controls automatic scaling behavior
- `PDFView.zoomIn(_:)` and `zoomOut(_:)`: Implicitly disable autoScales
