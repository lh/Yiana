# Manual Testing Guide for Phase 4

## How to Test Without Command Line

### Option 1: Xcode (Recommended)
1. Open `/Users/rose/Code/Yiana/Yiana/Yiana.xcodeproj` in Xcode
2. Select "Yiana" scheme from the scheme selector
3. Choose target device:
   - For iOS: Select an iPhone simulator (e.g., iPhone 15)
   - For macOS: Select "My Mac"
4. Press Cmd+B to build
5. Press Cmd+R to run

### Option 2: Check for Compilation Errors in Xcode
1. Open the project in Xcode
2. Press Cmd+B to build
3. Check the Issue Navigator (Cmd+5) for any errors or warnings
4. Common issues to look for:
   - Missing imports
   - Undefined types
   - Syntax errors
   - Platform-specific code issues

### Option 3: SwiftUI Preview
1. Open any of these files in Xcode:
   - `DocumentListView.swift`
   - `DocumentEditView.swift`
   - `ContentView.swift`
2. Look for the Preview pane (or press Opt+Cmd+Return)
3. Click "Resume" if preview is paused
4. The preview will compile the code and show if there are errors

## Test Scenarios

### iOS Testing
1. **Launch App**
   - Should see empty state with "No Documents" message
   
2. **Create Document**
   - Tap + button
   - Enter title "Test Document"
   - Tap Create
   - Should navigate to edit view
   
3. **Edit Document**
   - Change title in text field
   - Should see Save button appear
   - Tap Save
   - Navigate back
   
4. **Delete Document**
   - Swipe left on document in list
   - Tap Delete
   - Document should disappear

### macOS Testing
1. **Launch App**
   - Should see document list
   
2. **Create Document**
   - Click + button
   - Enter title
   - Should see URL in list (no actual file created yet)
   
3. **Click Document**
   - Should see "Document editing not available on macOS" message

## Verification Checklist

✅ All Swift files compile without errors
✅ DocumentListView shows empty state initially
✅ Can create new documents with titles
✅ iOS: Can navigate to edit view
✅ iOS: Can edit document titles
✅ macOS: Shows appropriate placeholder
✅ Can delete documents from list
✅ Error alerts appear when needed
✅ Loading indicators show during operations

## Known Limitations

- PDF viewing is placeholder only
- No actual PDF content yet
- macOS has limited functionality
- No scanner integration yet
- Files may not persist between app launches (until Phase 7 iCloud integration)