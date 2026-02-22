# Session Handoff — 2026-02-22

## What was completed

### Scan padding removed (iOS)
Scanned pages on iPad had a visible border because `ScanningService.convertImagesToPDF` applied a 24pt inset before aspect-fitting the image. Removed the inset — scans now fill the full PDF page. VNDocumentCamera already crops to the document boundary, so no padding is needed.

### macOS print support
Added printing to the macOS document view:
- `printDocument()` method using `PDFDocument.printOperation` with `runModal(for:window:)`
- Toolbar printer icon button
- Cmd+P via `CommandGroup(replacing: .printItem)` posting a `.printDocument` notification
- Added `com.apple.security.print` entitlement (sandbox was blocking `NSPrintOperation`)

### TestFlight deployment
Build 38 (v1.1) uploaded to App Store Connect as `a19c53c`.

## Files changed this session
- **`Yiana/Yiana/Services/ScanningService.swift`** — removed 24pt `contentRect` inset, scan images now aspect-fit to full page rect
- **`Yiana/Yiana/Views/DocumentReadView.swift`** — added `printDocument()` method, Print toolbar button, `.onReceive(.printDocument)` for Cmd+P
- **`Yiana/Yiana/YianaApp.swift`** — added `CommandGroup(replacing: .printItem)` for Cmd+P
- **`Yiana/Yiana/Extensions/Notification.Name+PageOperations.swift`** — added `.printDocument` notification
- **`Yiana/Yiana/Yiana.entitlements`** — added `com.apple.security.print`
- **`Yiana/Yiana.xcodeproj/project.pbxproj`** — build 38

## Lessons learned
- SwiftUI toolbar `.keyboardShortcut("p")` does NOT override the system File > Print menu item — the system menu takes priority and sends `print:` through the responder chain. Must use `CommandGroup(replacing: .printItem)` at the app level.
- Sandboxed macOS apps need `com.apple.security.print` entitlement for `NSPrintOperation`. Without it, the system shows "This application does not support printing" with error code -50 in the console (`printToolAgent:error`).
- `NSPrintOperation.run()` in a void context may not present properly; use `runModal(for: window, ...)` with the key window.

## What's next
- Search behaviour in sidebar layout (scope to current folder vs global)
- Sidebar width persistence (@SceneStorage or @AppStorage)
- Empty sidebar state polish
- Idea logged: allow folders in select/bulk-delete workflow

## Known issues
- Existing scans created before this session still have the old 24pt border baked into their PDF data. Only new scans benefit from the fix.
