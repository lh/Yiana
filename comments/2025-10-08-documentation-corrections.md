# Documentation Corrections - October 8, 2025

## Issue

User reported that initial user documentation (GettingStarted.md, Features.md, FAQ.md) was "shocked at the poor quality" - the documentation did not accurately represent the actual workflow.

## Root Cause

I wrote user documentation WITHOUT examining the actual code implementation. I made assumptions based on typical scanning app patterns rather than looking at the real code behavior.

## Code Analysis Findings

### 1. Document Title Workflow

**Incorrect assumption**: Documents default to "Untitled" and can be created without a title.

**Actual behavior** (from DocumentListView.swift:121-169):
```swift
private func createDocument() {
    Task {
        guard !newDocumentTitle.isEmpty else { return }
        // ... creates document
    }
}
```

The `guard !newDocumentTitle.isEmpty else { return }` check means:
- User MUST enter a title when creating a document
- Empty titles are rejected - nothing happens if title field is blank
- No "Untitled" default exists in the creation flow

### 2. Scanning Workflow

**Incorrect assumption**: User manually taps a shutter button to capture each scan.

**Actual behavior** (from ScannerView.swift:23-26):
```swift
func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
    let scannerViewController = VNDocumentCameraViewController()
    scannerViewController.delegate = context.coordinator
    return scannerViewController
}
```

The app uses Apple's `VNDocumentCameraViewController` from VisionKit which:
- **Automatically** detects documents in the camera frame
- **Automatically** captures when document is in frame
- **Automatically** crops, enhances, and corrects perspective
- NO manual shutter button - it's hands-free detection

### 3. Default Scan Mode

**My confusion**: Code shows `scanColorMode = .color` as initialization (DocumentEditView.swift:34)

**User clarification**: "The monochrome is central. The camera always starts in colour mode but that doesn't matter. What matters is the scan. And as the monochome scan is in the centre it becomes the default by its position."

**Actual UX** (from DocumentEditView.swift:293-354):
```
Button layout (left to right):
1. "Scan" (colorful circle) → .color mode
2. "Doc" (gray circle) → .blackAndWhite mode [CENTER POSITION]
3. "Text" button → text page editor
```

The **center position** of the "Doc" button makes it the default by virtue of its visual prominence, regardless of code initialization. Users naturally gravitate to the center button.

## Documentation Corrections Made

### GettingStarted.md
- **Combined Steps 1 & 2**: Document creation and scanning are now one step
- **Removed "Untitled" references**: Clarified title is required at creation
- **Updated scanning description**: Emphasized automatic VisionKit detection
- **Added button layout**: Explained the three-button layout with center "Doc" button

### Features.md
- **Updated scan modes section**: Added button positions (left/center/right)
- **Emphasized automatic scanning**: "VisionKit auto-detects edges and crops"
- **Clarified multi-page workflow**: "Camera automatically detects and captures documents"
- **Button toolbar section**: Added "(center - default position)" for Doc button

### FAQ.md
- **Updated "Scan vs Doc" question**: Added complete three-button layout
- **Emphasized center position**: "(center, gray circle) - default position"
- **Multi-page scanning**: Clarified automatic capture behavior with VisionKit

## Key Lessons

1. **ALWAYS examine code before writing user documentation**
2. **Don't assume typical app patterns** - check the actual implementation
3. **UI positioning matters** - the center button becomes the de facto default
4. **Framework behavior is critical** - VisionKit's automatic detection is the core UX

## Files Modified

- `/Users/rose/Code/Yiana/Yiana/docs/user/GettingStarted.md`
- `/Users/rose/Code/Yiana/Yiana/docs/user/Features.md`
- `/Users/rose/Code/Yiana/Yiana/docs/user/FAQ.md`

## Code Files Examined

- `Yiana/Yiana/Views/DocumentListView.swift` (document creation)
- `Yiana/Yiana/Views/DocumentEditView.swift` (scan buttons, layout)
- `Yiana/Yiana/Views/ScannerView.swift` (VisionKit integration)
- `Yiana/Yiana/Services/ScanningService.swift` (scan processing)
