# iOS Metadata Sheet Implementation Plan

## Overview
Add a metadata/info sheet for iOS that appears when user swipes down on PDF at fit-to-screen zoom. The sheet will show document metadata, OCR status, and extracted text, similar to the existing macOS DocumentInfoPanel.

## What Already Exists
✅ Swipe gesture handler in `PDFViewer.swift:333-351`
✅ Callback mechanism `onRequestMetadataView` wired up
✅ TODO placeholder in `DocumentEditView.swift:133-136`
✅ Full macOS implementation in `DocumentInfoPanel.swift` (use as reference)
✅ `ActiveSheet` enum pattern for sheets in DocumentEditView

## Implementation Steps

### 1. Create iOS Metadata Sheet View
**New file**: `Yiana/Views/DocumentMetadataSheet.swift`
- Adapt macOS `DocumentInfoPanel` for iOS (no #if os(macOS) wrapper)
- Use same tab structure: Metadata, OCR Text, Debug
- Simplify for mobile:
  - Use `.presentationDetents([.medium, .large])` for bottom sheet
  - Use iOS-appropriate UI (no GroupBox, use Card-style backgrounds)
  - Replace NSPasteboard with UIPasteboard
  - Replace NSSavePanel with share sheet for export
- Keep same helper views: InfoRow, TagView, OCRStatusBadge (adapted for iOS)

### 2. Add to ActiveSheet Enum
**File**: `DocumentEditView.swift:12-15`
```swift
enum ActiveSheet: Identifiable {
    case share(URL)
    case pageManagement
    case metadata  // ADD THIS

    var id: String {
        switch self {
        case .share: return "share"
        case .pageManagement: return "pageManagement"
        case .metadata: return "metadata"  // ADD THIS
        }
    }
}
```

### 3. Wire Up Sheet Presentation
**File**: `DocumentEditView.swift:71-100`
Add new case to sheet switch:
```swift
case .metadata:
    if let viewModel = viewModel {
        DocumentMetadataSheet(
            metadata: viewModel.metadata,
            pdfData: viewModel.pdfData
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
```

### 4. Connect Swipe Gesture
**File**: `DocumentEditView.swift:133-136`
Replace TODO with:
```swift
onRequestMetadataView: {
    activeSheet = .metadata
}
```

## Design Decisions

### iOS-Specific Adaptations
1. **Bottom Sheet**: Use `.presentationDetents([.medium, .large])` instead of sidebar
2. **Export**: Use iOS share sheet instead of NSSavePanel
3. **Copy**: Use UIPasteboard instead of NSPasteboard
4. **Layout**: Remove GroupBox (macOS only), use Card pattern with `.background()` and `.cornerRadius()`

### What to Keep From macOS Version
- ✅ Three-tab structure (Metadata, OCR, Debug)
- ✅ Search-in-text functionality for OCR tab
- ✅ Character count display
- ✅ Raw JSON toggle
- ✅ Helper views: InfoRow, TagView, OCRStatusBadge, StateRow

### What to Change
- ❌ GroupBox → Card-style backgrounds
- ❌ NSSavePanel → Share sheet
- ❌ NSPasteboard → UIPasteboard
- ❌ Fixed width (300-350) → Full width with safe area
- ❌ Segmented picker → iOS tab view style

## Files to Modify
1. **NEW**: `Yiana/Yiana/Views/DocumentMetadataSheet.swift` (~300 lines)
2. **EDIT**: `Yiana/Yiana/Views/DocumentEditView.swift`
   - Add `.metadata` to ActiveSheet enum (~3 lines)
   - Add case to sheet switch (~10 lines)
   - Replace TODO callback (~1 line)

## Testing Checklist
- [ ] Swipe down at fit-to-screen zoom shows sheet
- [ ] Medium/large detents work, drag indicator present
- [ ] All metadata fields display correctly
- [ ] OCR text shows if available, "Not processed" if not
- [ ] Search in OCR text highlights matches
- [ ] Copy OCR text to clipboard works
- [ ] Export OCR text via share sheet works
- [ ] Debug tab shows file info and state
- [ ] Raw JSON toggle works
- [ ] Sheet dismisses cleanly

## Risk Assessment
**Low Risk** - Well-defined pattern already exists on macOS, just adapting UI layer for iOS conventions.

## Reference Files
- **macOS Implementation**: `Yiana/Views/DocumentInfoPanel.swift` (lines 1-399)
- **Existing Sheet Pattern**: `DocumentEditView.swift` (lines 71-100)
- **Gesture Handler**: `PDFViewer.swift` (lines 333-351)
- **Metadata Model**: `Models/DocumentMetadata.swift`

## Additional Notes
- The macOS version includes a "Process OCR" button (line 199-203) that's currently a TODO
- Consider whether iOS version should also trigger OCR processing
- Character count is shown at line 182 of macOS version
- Text highlighting for search uses AttributedString (lines 211-230)
