# Phase 11 Manual Testing Guide - Page Management

## Overview
This guide covers testing the page management functionality added in Phase 11. Test on both iOS and macOS platforms.

## Prerequisites
- Build and run the app on both iOS Simulator/Device and macOS
- Have at least one PDF document with multiple pages (3+ pages recommended)
- If no multi-page PDFs exist, scan or import one first

## Test Cases

### 1. Access Page Management

#### iOS
- [ x ] Open a document from the list
- [ x ] Verify the "Pages" button appears in the navigation bar (circle with rectangle.stack icon)
- [ x ] Tap the "Pages" button
- [ x ] Verify PageManagementView opens as a sheet

#### macOS
- [ x ] Open a document from the list
- [ ? ] Verify the "Pages" button appears in the toolbar (no - get a top rigth "Manage Pages" instead)
- [ x ] Click the "Pages" button
- [ x ] Verify PageManagementView opens as a sheet

### 2. View Page Thumbnails

#### Both Platforms
- [ x ] Verify all pages display as thumbnails in a grid
- [ x ] Verify thumbnails show page preview (not blank)
- [ x ] Verify page numbers display below each thumbnail
- [ yes for phone, sort of for mac - it is a popup and doesn't respect the outer window size ] Verify grid layout adjusts to window/screen size
- [ x ] Test with documents of various page counts (1, 3, 10+ pages)

### 3. Edit Mode Toggle

#### iOS
- [ x ] Verify "Edit" button appears in top toolbar
- [ x ] Tap "Edit" button
- [ x ] Verify UI enters edit mode:
  - [ x ] Edit button changes to "Done"
  - [ x ] Selection circles appear on thumbnails
  - [ x ] Bottom toolbar appears with "Delete Selected" button
- [ x ] Tap "Done" to exit edit mode
- [ x ] Verify UI returns to normal state

#### macOS
- [ no, bottom of popup after invoking "manage pages" but it is ok ] Verify "Edit" button appears in toolbar
- [ x ] Click "Edit" button
- [ x ] Verify UI enters edit mode:
  - [ x ] Edit button changes to "Done"
  - [ x ] Selection circles appear on thumbnails
  - [ x ] Delete button appears in toolbar
- [ x ] Click "Done" to exit edit mode - but "delete selected" takes the "done" button back to "edit" mode. There is also a "cancel" and "save" button to the right of the pop up so some of the buttons seem redundant.
- [ x ] Verify UI returns to normal state

### 4. Page Selection (Edit Mode)

#### Both Platforms
- [ x ] Enter edit mode
- [ x ] Tap/click on a page thumbnail
- [ x ] Verify page gets selected (checkmark appears)
- [ x ] Select multiple pages
- [ no ] Verify selection count updates - there is no selection counter
- [ x ] Deselect a page by tapping/clicking again
- [ x ] Verify checkmark disappears

### 5. Delete Pages

#### Both Platforms
- [ x ] Enter edit mode
- [ x ] Select one or more pages (not all)
- [ x ] Tap/click "Delete Selected" button
- [ x ] Verify selected pages are removed
- [ x ] Verify remaining pages renumber correctly
- [ x ] Verify page count updates (no explicit page count)

#### Edge Cases
- [ no warning or error ] Try to delete all pages - should show error/warning
- [ x ] Delete first page - verify document still opens correctly BUT WHEN THE PAGE IS DELETED,  IT STILL SHOWS ON RETURN TO THE PREVIOUS VIEW. The views go document tree|document (press "Page" round button bottom right on iOS, page order viewer where I can drag and drop stuff) | click "edit" top right now I can delete stuff, and then back up the tree.
- [ x ] Delete last page - verify document still opens correctly
- [ x ] Delete middle pages - verify order remains correct

### 6. Drag to Reorder (iOS Only)

#### iOS
- [ x ] Enter edit mode
- [ x ] Long press and drag a page thumbnail
- [ x ] Verify page can be dragged to new position
- [ x ] Drop page in new location
- [ x ] Verify pages reorder correctly
- [ x ] Verify page numbers update
- [ x ] Test dragging:
  - [ x ] First page to middle
  - [ x ] Last page to beginning
  - [ x ] Middle page to end

### 7. Save Changes

#### Both Platforms
- [ x ] Make changes (delete or reorder pages)
- [ x ] Tap/click "Save" button (there are two layers of save buttons see above)
- [ x ] Verify sheet dismisses
- [ x ] Verify document shows updated page count - no - it keeps the deleted page until it is closed (marked as save in the interface)
- [ x ] Close and reopen document - now the deleted page has gone.
- [ x ] Verify changes persisted

### 8. Cancel Changes

#### Both Platforms
- [ x ] Make changes (delete or reorder pages)
- [ x ] Tap/click "Cancel" button
- [ x ] Verify sheet dismisses
- [ x ] Verify document unchanged
- [ x ] Open page management again
- [ x ] Verify original pages still present

### 9. iCloud Sync

#### Cross-Platform
- [ x ] Make page changes on iOS
- [ x ] Save changes
- [ x ] Open same document on macOS
- [ x ] Verify changes appear
- [ x ] Make different changes on macOS - I cannot change the order?
- [ x ] Save changes
- [ x ] Return to iOS
- [ x ] Verify macOS changes appear

### 10. Performance Testing

#### Both Platforms
- [ x ] Test with large PDF (50+ pages)
- [ x ] Verify thumbnails load reasonably fast
- [ no ] Verify scrolling is smooth - the mac versio (running from xcode) seems to "hic-up" and redraw the whole pdf every page or so of scrolling. It would be better to either be smooth or to flick form one page to another, but the scroll balck appear is terrible. The iOS version loks like it is trying to always fit a whole lage in view so there is sort of smooth scrolling but then it jumps tot he page, which gives it a jerky unresponsive feel.
- [ x ] Verify selection/deletion responsive
- [ x ] Test memory usage doesn't spike excessively

## Known Limitations
- Drag to reorder is iOS only (macOS requires click to select, then move buttons) - there is no move I can find!
- Page operations cannot be undone after saving
- Very large PDFs (100+ pages) may show performance degradation

## Error Scenarios to Test

1. **Empty Document**
   - [ x ] Create new document with no pages
   - [ x ] Try to open page management - impossible no page management shows (good!)
   - [ x ] Should show "No Pages" message

2. **Single Page Document**
   - [ x ] Open single page PDF
   - [ x ] Enter edit mode
   - [ x ] Try to delete the only page
   - [ xo ] Should prevent or show warning prevents on mac, no warning no prevention on iOS

3. **Concurrent Editing**
   - [ x ] Open same document on two devices
   - [ ] Edit pages on both simultaneously - not possibel as I cannot move on mac.
   - [ ] Save on both
   - [ ] Verify conflict resolution (last save wins)

## Platform-Specific UI Differences

### iOS
- Navigation bar with inline title
- Edit mode uses iOS-style selection
- Bottom toolbar in edit mode
- Drag and drop for reordering
- Swipe gestures work

### macOS
- Standard window toolbar
- No bottom toolbar
- No drag to reorder
- Command-click for multi-select (when implemented)
- Larger default thumbnail size

## Success Criteria
- All basic operations work without crashes
- Changes persist after save
- iCloud sync works correctly
- UI is responsive and intuitive
- Error cases handled gracefully
