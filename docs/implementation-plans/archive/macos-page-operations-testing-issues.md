# macOS Page Operations Testing Issues

**Date:** October 12, 2025
**Status:** Blocking defect identified – ready for re-test once fix merged

## Summary

After implementing the macOS copy/cut/paste functionality and addressing the code review feedback, we're experiencing test failures in the `DocumentViewModelPageOperationsMacOSTests` test suite. While we've fixed several issues, 3 out of 5 tests are still failing.

## Test Results

### Current Status (before fix)
- ✅ `testCopyPagesOnMacOS` – **PASSING**
- ❌ `testCutPagesOnMacOS` – **FAILING**
- ❌ `testPastePagesOnMacOS` – **FAILING**
- ✅ `testSaveIntegrationOnMacOS` – **PASSING**
- ❌ `testUndoRedoOnMacOS` – **FAILING**

## Issues Found and Fixed

### 1. ✅ PDF Not Updating in Reader (FIXED)
- **Problem:** `DocumentReadView` was using local `@State pdfData` instead of `viewModel?.pdfData`
- **Fix:** Changed `MacPDFViewer` to use `viewModel?.pdfData ?? pdfData` and added `onChange` observer
- **Location:** `DocumentReadView.swift:119`

### 2. ✅ Wrong Document Type in Save (FIXED)
- **Problem:** Save was using `"com.vitygas.yianazip"` instead of `UTType.yianaDocument.identifier`
- **Fix:** Used correct UTType and added extension for macOS
- **Location:** `DocumentViewModel.swift:635`

### 3. ✅ Clipboard Clearing Everything (FIXED)
- **Problem:** `PageClipboard.clear()` was clearing entire macOS pasteboard
- **Fix:** Changed to only clear our custom UTI with `setData(Data(), forType:)`
- **Location:** `PageClipboard.swift:195`

### 4. ✅ Weak Reference Causing Deallocation (FIXED)
- **Problem:** Tests were failing because `NoteDocument` was deallocated after `setUp`
- **Fix:** Added strong reference `noteDocument` instance variable in test class
- **Location:** `DocumentViewModelPageOperationsTests.swift:332`

### 5. ✅ isReadOnly Blocking Mutations (FIXED)
- **Problem:** The macOS `DocumentViewModel` treated documents without a `fileURL` as read-only, causing `ensureDocumentIsAvailable()` to throw in tests (and in any unsaved document workflow).
- **Fix:** Updated `isReadOnly` to allow edits when `fileURL` is `nil`, matching UIDocument behavior.
- **Location:** `DocumentViewModel.swift:577`

### Retest Status (October 12, 2025 - After isReadOnly Fix)

Test results after applying the `isReadOnly` fix:
- ✅ `testCopyPagesOnMacOS` – **PASSING**
- ✅ `testCutPagesOnMacOS` – **PASSING**
- ✅ `testPastePagesOnMacOS` – **PASSING**
- ✅ `testSaveIntegrationOnMacOS` – **PASSING**
- ❌ `testUndoRedoOnMacOS` – **FAILING** (Fixed below)

**Success Rate:** 4 out of 5 tests passing (80%)

### 6. ✅ Test Not Setting Clipboard Payload (FIXED)
- **Problem:** The `testUndoRedoOnMacOS` test was not calling `PageClipboard.shared.setPayload()` after cutting pages, causing the assertion to fail when checking for the cut payload.
- **Fix:** Added `PageClipboard.shared.setPayload(payload)` after the cut operation to match the pattern used in other tests.
- **Location:** `DocumentViewModelPageOperationsTests.swift:451-452`

### Final Test Status (October 12, 2025 - All Issues Resolved)

✅ **ALL TESTS PASSING** - 5 out of 5 macOS tests now pass successfully:
- ✅ `testCopyPagesOnMacOS` – **PASSING**
- ✅ `testCutPagesOnMacOS` – **PASSING**
- ✅ `testPastePagesOnMacOS` – **PASSING**
- ✅ `testSaveIntegrationOnMacOS` – **PASSING**
- ✅ `testUndoRedoOnMacOS` – **PASSING**

**Success Rate:** 100% (5/5 tests passing)

## Remaining Issues

None - all test failures have been resolved.

## Code Structure

The macOS implementation is located in `DocumentViewModel.swift` starting at line 529:
- Lines 529-814: Complete macOS DocumentViewModel implementation
- Line 587: `weak var document: NoteDocument?` - weak reference (intentional)
- Line 673: `removePages` helper function
- Line 700: `copyPages` implementation
- Line 715: `cutPages` implementation
- Line 755: `insertPages` implementation

## Next Steps

1. **Re-run the macOS page operation tests** locally and on CI to confirm the `isReadOnly` fix resolves the failures.
2. **Add a regression test** ensuring `isReadOnly` returns `false` for a `NoteDocument` without a `fileURL`, to prevent this scenario from regressing.
3. **Optional:** add assertions in the macOS tests verifying `ensureDocumentIsAvailable()` no longer throws for unsaved documents.

## Test Environment

- Xcode 16.0
- macOS 26.0 SDK
- Platform: macOS (arm64)
- Test framework: XCTest

## Recommendations

1. Consider temporarily disabling undo registration in tests to isolate the core functionality
2. Add assertions at each step of the cut/paste flow to identify exact failure point
3. Verify that `PDFDocument.dataRepresentation()` is returning valid data after modifications
4. Check if NSDocument autosave is interfering with test expectations

## Related Files

- `/Users/rose/Code/Yiana/Yiana/Yiana/ViewModels/DocumentViewModel.swift`
- `/Users/rose/Code/Yiana/Yiana/YianaTests/DocumentViewModelPageOperationsTests.swift`
- `/Users/rose/Code/Yiana/Yiana/Yiana/Services/PageClipboard.swift`
- `/Users/rose/Code/Yiana/Yiana/Yiana/Models/NoteDocument.swift`
