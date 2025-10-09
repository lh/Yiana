# Visual Design Refinement: Preview Indicator
**Date**: 2025-10-07
**Topic**: Simplified preview indicator (no redundant hint)

## Agreed Change

✅ **Remove bottom "Tap to edit" hint** - redundant with existing Text button

## Refined Visual Design

### Clean Preview with Border Only

```
┏━━━━━━━━━━━━━━━┓ ← Yellow border (3pt)
┃ Meeting Notes ┃
┃               ┃
┃ • Item 1      ┃
┃ • Item 2      ┃
┃               ┃
┗━━━━━━━━━━━━━━━┛

[Text] button already present in toolbar
```

**Minimal and clear**:
- Yellow/amber border signals "draft/preview state"
- No overlays cluttering the content
- Toolbar Text button provides edit affordance
- User sees their content without distractions

---

## Optional: Subtle Corner Badge

If border alone feels too subtle, add minimal corner indicator:

```
┏━━━━━━━━━━━━━━━┓
┃ Meeting Notes📝┃ ← Small pencil emoji (or icon)
┃               ┃    Top-right corner
┃ • Item 1      ┃
┃ • Item 2      ┃
┗━━━━━━━━━━━━━━━┛
```

**Options for badge**:
- 📝 Pencil emoji (Unicode, no asset needed)
- `Image(systemName: "pencil.circle.fill")` (SF Symbol)
- Small "DRAFT" text label
- Yellow dot indicator

**My recommendation**: Border only is cleanest. Badge only if user testing shows border isn't noticed.

---

## Implementation Code

### Border Only (Simplest)

```swift
case .previewing:
    if let pdf = textPage.temporaryPDF {
        PDFView(pdf: pdf)
            .border(Color.yellow.opacity(0.8), width: 3)
            // That's it! No overlays.
    }
```

### Border + Corner Badge (If Needed)

```swift
case .previewing:
    if let pdf = textPage.temporaryPDF {
        PDFView(pdf: pdf)
            .border(Color.yellow.opacity(0.8), width: 3)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.yellow)
                    .padding(8)
            }
    }
```

---

## Page Thumbnail View

In document grid/list, minimal indicator:

**Option A: Border on thumbnail**
```
┌─────────┐
│┏━━━━━━━┓│ ← Yellow border on thumbnail
││Preview││   (matches full view)
│┗━━━━━━━┛│
└─────────┘
```

**Option B: Badge on thumbnail**
```
┌─────────┐
│  📝     │ ← Small badge overlay
│ Preview │
│         │
└─────────┘
```

**Option C: Text label**
```
Page 3 (Draft)  ← Text annotation
┌─────────┐
│ Preview │
└─────────┘
```

**Recommendation**: Option A (border) - consistent with full view.

---

## Color Psychology

### Yellow/Amber (Recommended)
- Signals "caution" or "in progress"
- Not alarming (red) but noticeable
- Warm, approachable
- Standard for "draft" states

**Code**: `Color.yellow.opacity(0.8)` or `Color.orange.opacity(0.6)`

### Blue (Alternative)
- Informational, neutral
- Less "warning" feel
- May be confused with selection state

**Code**: `Color.blue.opacity(0.5)`

### Green (Not Recommended)
- Signals "complete" or "success"
- Contradicts "draft" meaning

---

## Accessibility Considerations

Border alone may not be sufficient for:
- Color blind users (yellow/green confusion)
- Low vision (thin borders hard to see)

**Solutions**:
1. Use 3pt+ border (thick enough to notice)
2. Add VoiceOver hint: "Preview, tap Text button to edit"
3. Consider pattern fill (diagonal stripes) instead of solid border for color-blind users

```swift
.overlay(alignment: .topLeading) {
    // Hidden visual indicator, VoiceOver reads it
    Text("Preview")
        .font(.caption2)
        .foregroundColor(.clear)
        .accessibilityLabel("Draft preview, editable")
}
```

---

## Final Simplified Design

**Full view**:
- Yellow border (3pt, 80% opacity)
- No overlays, no hints
- Text button in toolbar (existing)

**Thumbnail view**:
- Yellow border on thumbnail (matches full view)
- Optional: small badge if border too subtle

**Code**:
```swift
PDFView(pdf: textPage.temporaryPDF)
    .border(Color.yellow.opacity(0.8), width: 3)
```

**That's it!** Minimal, clean, effective.

---

## User Testing Questions (If Validating)

1. "Is it clear this page is still editable?" (check if border communicates draft state)
2. "What does the yellow border mean to you?" (verify intuitive understanding)
3. "How would you edit this page?" (ensure Text button is discoverable)

If border alone is unclear, add corner badge. But start simple.

---

**Summary**: Border only. No bottom hint. Clean and minimal. ✅
