# Manual Test Checklist - Yiana

**Purpose**: Quick smoke test to verify core functionality before releases
**Time**: ~10-15 minutes
**Frequency**: Before merging to main, before TestFlight releases

---

## Pre-Test Setup

### Environment
- [ ] Clean iCloud state (or note existing documents)
- [ ] OCR service running on Mac mini (if testing OCR)
- [ ] Test devices charged and ready

### Test Devices
- [ ] Mac (primary development machine)
- [ ] iPhone (physical device preferred)
- [ ] iPad (physical device preferred)

### Test Files Needed
- [ ] Sample PDF: 1-2 pages (for quick tests)
- [ ] Sample PDF: 20-50 pages (for performance tests)
- [ ] PDF with known text content (for OCR/search verification)

---

## Test Scenarios

## 1. ✅ New Document Creation

### 1.1 Create Empty Document (Text Page)
**Platform**: iPhone or iPad

- [ ] Launch Yiana app
- [ ] Tap **"+"** button
- [ ] Select **"Text Page"** (if available)
- [ ] Type some text (e.g., "Test document created on [date]")
- [ ] Save/Close
- [ ] **Verify**: Document appears in list with correct title
- [ ] **Verify**: Document shows in iCloud folder

**Expected**:
- Document created as `.yianazip` file
- Appears in document list immediately
- Title reflects content or "Untitled"

**Location**: `~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/`

---

### 1.2 Create from Camera Scan
**Platform**: iPhone or iPad (with camera)

- [ ] Launch Yiana app
- [ ] Tap **"+"** button
- [ ] Select **"Scan Document"**
- [ ] Scan 1-2 pages (any paper document)
- [ ] Tap "Save"
- [ ] **Verify**: Document appears in list
- [ ] **Verify**: Thumbnail shows scanned content
- [ ] **Verify**: Page count is correct

**Expected**:
- Document created immediately
- Thumbnail visible
- Page count matches scanned pages

---

## 2. 📥 Import PDF

### 2.1 Import New PDF (Create New)
**Platform**: Any (Mac easiest for file access)

- [ ] Open Files app / Finder
- [ ] Locate test PDF file
- [ ] Share to Yiana (iOS) or drag-and-drop (Mac)
- [ ] Select **"Create New Document"**
- [ ] Enter title: "Import Test [timestamp]"
- [ ] Tap "Import"
- [ ] **Verify**: Document appears in list
- [ ] **Verify**: Page count matches source PDF
- [ ] **Verify**: Thumbnail shows first page

**Expected**:
- Import completes within 2-5 seconds (for small PDFs)
- Document title matches what you entered
- File size reasonable (~similar to source PDF)

---

### 2.2 Import and Append to Existing
**Platform**: Any

**Prerequisites**: At least one existing document

- [ ] Select existing document (from 1.2 or 2.1)
- [ ] Note current page count (e.g., 3 pages)
- [ ] Import another PDF
- [ ] Select **"Append to [Document Name]"**
- [ ] Tap "Append"
- [ ] **Verify**: Page count increased correctly
- [ ] **Verify**: Original pages still intact (open and check)
- [ ] **Verify**: New pages appear after original pages

**Expected**:
- Page count = old count + new count
- No pages lost
- Order preserved (original first, appended last)

---

### 2.3 Import Large PDF (Performance Test)
**Platform**: Any

- [ ] Import PDF with 50+ pages
- [ ] Measure time to import
- [ ] **Verify**: Import completes without crash
- [ ] **Verify**: App remains responsive
- [ ] **Verify**: Document opens and scrolls smoothly

**Expected**:
- Import completes (even if slow)
- No memory warnings or crashes
- PDF viewer works smoothly

**Performance baseline**:
- 50-page PDF: < 30 seconds import
- 200-page PDF: < 2 minutes import

---

## 3. 📤 Export PDF

### 3.1 Export to Files App
**Platform**: iPhone or iPad

- [ ] Open any document with content
- [ ] Tap **Share/Export** button
- [ ] Select **"Export as PDF"**
- [ ] Save to Files app (choose location)
- [ ] **Verify**: PDF saved successfully
- [ ] Open exported PDF in Files app
- [ ] **Verify**: All pages present
- [ ] **Verify**: Content matches original

**Expected**:
- Export completes quickly
- PDF is valid (opens in Files app)
- No pages missing

---

### 3.2 Export and Share
**Platform**: Any

- [ ] Open document
- [ ] Tap **Share** button
- [ ] Select **"Mail"** or **"Messages"**
- [ ] **Verify**: PDF attached correctly
- [ ] **Verify**: Recipient can open PDF

**Expected**:
- Share sheet shows PDF option
- PDF attaches to email/message
- File size reasonable

---

## 4. 🔍 OCR and Search

### 4.1 Trigger OCR
**Platform**: Any (Mac mini OCR service must be running)

**Prerequisites**: Document with scanned or image-based content

- [ ] Import document with text (scanned receipt, book page, etc.)
- [ ] Wait for OCR indicator (if visible)
- [ ] **Verify**: OCR completes (check `.ocr_results/` folder if accessible)
- [ ] **Verify**: No error messages

**Expected**:
- OCR starts automatically
- Completes within 1-5 minutes (depending on page count)
- No crashes or errors

**How to verify OCR completed**:
- Check document metadata: `ocrCompleted: true`
- Or search should work (test in 4.2)

---

### 4.2 Search for Text
**Platform**: Any

**Prerequisites**: Document with OCR completed

- [ ] Tap **Search** icon/field
- [ ] Enter known text from document (e.g., "invoice", "total", "2025")
- [ ] **Verify**: Search results appear
- [ ] Tap on a result
- [ ] **Verify**: Correct page opens
- [ ] **Verify**: Page number is 1-based (not 0-based)
- [ ] **Verify**: Search term highlighted on page (if implemented)

**Expected**:
- Search is fast (< 1 second for reasonable queries)
- Results show correct page numbers
- Tapping result navigates to correct page

---

### 4.3 Search Edge Cases
**Platform**: Any

- [ ] Search for text that doesn't exist: **"xyzabc123"**
  - [ ] **Verify**: "No results" message shown
- [ ] Search with special characters: **"$100"** or **"email@example.com"**
  - [ ] **Verify**: Works correctly or handles gracefully
- [ ] Search in document with no OCR
  - [ ] **Verify**: Empty results or "OCR not completed" message

**Expected**:
- No crashes
- Graceful handling of edge cases

---

## 5. 📱 iCloud Sync

### 5.1 Cross-Device Sync
**Platform**: 2 devices (e.g., iPhone + iPad)

- [ ] Create document on Device A (iPhone)
- [ ] Wait 10-30 seconds
- [ ] Open Yiana on Device B (iPad)
- [ ] Pull to refresh (if needed)
- [ ] **Verify**: Document appears on Device B
- [ ] Open document on Device B
- [ ] **Verify**: Content matches Device A

**Expected**:
- Sync happens within 30-60 seconds
- No conflicts
- Both devices show same content

---

### 5.2 Edit and Sync
**Platform**: 2 devices

- [ ] Open same document on Device A
- [ ] Make a change (add page, edit text page)
- [ ] Save
- [ ] Wait 30 seconds
- [ ] Open same document on Device B
- [ ] **Verify**: Changes appear
- [ ] **Verify**: No duplicate documents

**Expected**:
- Changes sync correctly
- No data loss
- No conflicts (last-write-wins is acceptable)

---

### 5.3 Delete and Sync
**Platform**: 2 devices

- [ ] Delete document on Device A
- [ ] Wait 30 seconds
- [ ] Check Device B
- [ ] **Verify**: Document removed from Device B

**Expected**:
- Deletion syncs
- File removed from iCloud

---

## 6. 🗂️ Document Management

### 6.1 Rename Document
**Platform**: Any

- [ ] Long-press on document (iOS) or right-click (Mac)
- [ ] Select **"Rename"**
- [ ] Enter new name: "Renamed Test Doc"
- [ ] Save
- [ ] **Verify**: Name updated in list
- [ ] **Verify**: File renamed in iCloud folder

**Expected**:
- Rename happens immediately
- Search still works (if document had OCR)

---

### 6.2 Delete Document
**Platform**: Any

- [ ] Select document to delete
- [ ] Swipe left (iOS) or right-click (Mac)
- [ ] Tap **"Delete"**
- [ ] Confirm deletion
- [ ] **Verify**: Document removed from list
- [ ] **Verify**: File removed from iCloud
- [ ] **Verify**: Associated OCR files cleaned up

**Expected**:
- Deletion is immediate
- No orphaned files

---

### 6.3 Sort and Filter
**Platform**: Any

- [ ] Create 3+ documents with different dates, titles
- [ ] Test sorting options:
  - [ ] Sort by **Date Created** (newest first)
  - [ ] Sort by **Date Modified**
  - [ ] Sort by **Title** (A-Z)
  - [ ] Sort by **Size** (if available)
- [ ] **Verify**: List reorders correctly each time

**Expected**:
- Sorting is consistent
- No crashes when switching sort modes

---

## 7. 📄 ZIP Format Validation

### 7.1 Verify ZIP Structure
**Platform**: Mac (Terminal access)

- [ ] Create new document in app
- [ ] Locate file in iCloud: `~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/`
- [ ] Run in Terminal:
  ```bash
  unzip -l "path/to/Document.yianazip"
  ```
- [ ] **Verify**: Output shows:
  ```
  metadata.json
  content.pdf
  format.json
  ```

**Expected**:
- All three files present
- File is valid ZIP archive
- No corruption

---

### 7.2 Manual ZIP Inspection
**Platform**: Mac

- [ ] Copy `.yianazip` file to Desktop
- [ ] Change extension to `.zip`
- [ ] Double-click to unzip
- [ ] **Verify**: Three files extracted
- [ ] Open `metadata.json` in text editor
  - [ ] **Verify**: Valid JSON with title, pageCount, etc.
- [ ] Open `content.pdf`
  - [ ] **Verify**: PDF opens and shows correct pages

**Expected**:
- ZIP is valid
- Metadata is readable JSON
- PDF is valid

---

## 8. 🚨 Error Handling

### 8.1 Import Invalid File
**Platform**: Any

- [ ] Try to import non-PDF file (e.g., `.jpg`, `.txt`)
- [ ] **Verify**: Error message shown
- [ ] **Verify**: App doesn't crash

**Expected**:
- Graceful error: "File type not supported"
- No crash

---

### 8.2 Import Corrupted PDF
**Platform**: Mac (easy to create test file)

- [ ] Create fake PDF: `echo "not a pdf" > fake.pdf`
- [ ] Try to import `fake.pdf`
- [ ] **Verify**: Error message shown
- [ ] **Verify**: No document created
- [ ] **Verify**: App doesn't crash

**Expected**:
- Error: "Invalid PDF file"
- No partial import

---

### 8.3 No Internet / iCloud Disabled
**Platform**: Any

- [ ] Turn off WiFi
- [ ] Disable iCloud Drive (Settings)
- [ ] Open Yiana
- [ ] **Verify**: App shows cached documents
- [ ] Try to create new document
- [ ] **Verify**: Document created locally
- [ ] Re-enable iCloud
- [ ] **Verify**: Document syncs when connection restored

**Expected**:
- App works offline
- Data doesn't get lost
- Syncs when back online

---

## 9. 🎯 Edge Cases

### 9.1 Very Long Document Title
**Platform**: Any

- [ ] Create document with 100+ character title
- [ ] **Verify**: Title truncated gracefully in UI
- [ ] **Verify**: Full title stored in metadata
- [ ] **Verify**: Search works

**Expected**:
- UI doesn't break
- Full title preserved in data

---

### 9.2 Special Characters in Title
**Platform**: Any

- [ ] Create document with title: `Test "Doc" / File's & Name!`
- [ ] **Verify**: Title saved correctly
- [ ] **Verify**: File created (filesystem handles special chars)
- [ ] **Verify**: No crash

**Expected**:
- Special characters handled
- Filename sanitized if needed

---

### 9.3 Simultaneous Edits (Conflict Test)
**Platform**: 2 devices (airplane mode trick)

- [ ] Open same document on Device A and Device B
- [ ] Put both devices in airplane mode
- [ ] Make different changes on each device
- [ ] Save both
- [ ] Re-enable internet on both
- [ ] **Verify**: How conflict is handled
  - Last write wins?
  - Duplicate documents?
  - Conflict warning?

**Expected**:
- Defined behavior (document in spec)
- No data loss
- User aware of conflict (if applicable)

---

## 10. 📊 Performance Checks

### 10.1 App Launch Time
**Platform**: Any

- [ ] Force quit Yiana
- [ ] Launch app
- [ ] Time from tap to usable UI
- [ ] **Verify**: < 3 seconds on modern devices

---

### 10.2 Large Document List
**Platform**: Any (if you have 50+ documents)

- [ ] Open app with 50+ documents
- [ ] Scroll through list
- [ ] **Verify**: Smooth scrolling (no stuttering)
- [ ] **Verify**: Thumbnails load progressively

**Expected**:
- 60fps scrolling
- No memory issues

---

### 10.3 Memory Usage
**Platform**: Any

- [ ] Open very large PDF (200+ pages)
- [ ] Scroll through all pages
- [ ] **Verify**: No memory warnings
- [ ] **Verify**: App doesn't crash

**Expected**:
- Memory usage reasonable
- No leaks

---

## Quick Pass/Fail Summary

After completing tests, fill this out:

### Critical Path (Must Pass)
- [ ] ✅ Create new document
- [ ] ✅ Import PDF
- [ ] ✅ Export PDF
- [ ] ✅ OCR completes
- [ ] ✅ Search works
- [ ] ✅ iCloud sync works

### Important (Should Pass)
- [ ] ✅ Append to document
- [ ] ✅ Delete document
- [ ] ✅ Rename document
- [ ] ✅ Cross-device sync
- [ ] ✅ Large file handling

### Nice to Have (Can Have Issues)
- [ ] ✅ Conflict resolution
- [ ] ✅ Special characters
- [ ] ✅ Error messages
- [ ] ✅ Performance optimal

---

## Test Results Template

```
Date: YYYY-MM-DD
Tester: [Your Name]
Branch: refactor/zip
Commit: [commit hash]
Build: [build number]

Devices Tested:
- [ ] iPhone [model] - iOS [version]
- [ ] iPad [model] - iPadOS [version]
- [ ] Mac [model] - macOS [version]

Critical Path: [PASS / FAIL]
Important Tests: [PASS / FAIL]
Nice to Have: [PASS / FAIL]

Issues Found:
1. [Description of issue]
   - Steps to reproduce
   - Expected vs Actual
   - Severity: Critical / Major / Minor

Notes:
- [Any observations]
```

---

## Tips for Efficient Testing

1. **Use Test Data**: Keep a folder of test PDFs ready
2. **Test in Order**: Follow checklist top-to-bottom for consistency
3. **Note Anomalies**: Even small weird behavior
4. **Clean State**: Start with fresh iCloud state for major tests
5. **Time Box**: Don't spend > 15 minutes unless investigating issue
6. **Document Issues**: Screenshot + description immediately

---

## When to Run This Checklist

### Always:
- Before merging feature branch to main
- Before creating TestFlight build
- After major refactors (like ZIP format change)

### Optionally:
- After fixing critical bugs
- Before App Store submission
- When testing on new iOS version

---

## Automation Candidates

Tests that are tedious and should be automated later:
- ✅ ZIP format validation (could be unit test)
- ✅ Import/Export round-trip (could be integration test)
- ✅ OCR completion check (could be integration test)
- ✅ Large file performance (could be performance test)

Tests that must stay manual:
- iCloud sync timing (non-deterministic)
- Camera scanning (hardware dependent)
- Cross-device testing (requires real devices)
- User experience / UI polish

---

## Quick Commands Reference

### Check iCloud Documents
```bash
ls -lah ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/
```

### Inspect ZIP Structure
```bash
unzip -l "path/to/Document.yianazip"
```

### Check File Type
```bash
file "path/to/Document.yianazip"
```

### Extract ZIP Manually
```bash
unzip "Document.yianazip" -d extracted/
```

### View Metadata
```bash
unzip -p "Document.yianazip" metadata.json | jq .
```
(requires `jq` installed: `brew install jq`)

---

**End of Manual Test Checklist**

*Keep this document updated as features are added or changed.*
