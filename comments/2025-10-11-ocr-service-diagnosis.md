# OCR Service Diagnosis - Devon
**Date:** 2025-10-11
**Issue:** No files are being OCR'd despite service running

---

## Problem Summary

The YianaOCRService on devon is running correctly BUT not processing documents because:

1. ✅ **Service is running:** PID 81401, launched at 12:49pm
2. ✅ **Service can find documents:** Logs show "Found document to process" for 10+ files
3. ❌ **Documents already marked processed:** Metadata has `ocrCompleted: true`
4. ❌ **Processed tracking file huge:** `processed.json` contains 500+ document identifiers

## Evidence

### Service Status
```bash
PID: 81401
Command: /Users/devon/bin/yiana-ocr watch --path /Users/devon/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents
Uptime: 5+ hours (since 12:49pm)
```

### Logs Show Skipping
```
file=Test-ocr.yianazip [YianaOCRService] Checking document
file=Test-ocr.yianazip [YianaOCRService] Document already has OCR

file=iPad test add Copy.yianazip [YianaOCRService] Checking document
file=iPad test add Copy.yianazip [YianaOCRService] Document already has OCR
```

### OCR Results Directory
```bash
/Users/devon/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results/
```

**Contents:**
- Only 1 successfully processed file: `specialist_and_gp_training.{json,xml,hocr}`
- Processed at: 15:57 (over 2 hours ago)
- All other documents: NONE

### Processed Tracking File
```bash
/Users/devon/Library/Application Support/YianaOCR/processed.json
```

**Contains:** 500+ entries like:
- `"Bown Christina 171148.yianazip_1758375450.0"`
- `"Test-ocr.yianazip_1760202859.0920534"`
- `"iPhone. 1.yianazip_1760195750.0"`

## Why Documents Are Skipped

The service checks TWO conditions before processing:

### 1. Processed Tracking (Line 184-189)
```swift
if processedDocuments.contains(fileIdentifier) {
    logger.debug("Document already processed", ...)
    return
}
```

**File identifier:** `filename_modificationTimestamp`
- Example: `"Test-ocr.yianazip_1760202859.0920534"`

### 2. Document Metadata (Line 204-207)
```swift
if document.metadata.ocrCompleted {
    logger.info("Document already has OCR", ...)
    return
}
```

**Most documents have `ocrCompleted: true` in their metadata!**

## Root Cause Analysis

### Possible Scenarios

**A) Metadata was set but OCR never ran**
- Something marked documents as `ocrCompleted: true` prematurely
- Perhaps during ZIP format refactor?
- OCR results never actually generated

**B) OCR results were lost**
- Documents were OCR'd successfully
- Results written to `.ocr_results/`
- iCloud or filesystem issue deleted/lost the results
- Metadata still says `ocrCompleted: true`

**C) Old OCR format migration issue**
- Documents OCR'd in old format (binary separator)
- Results not migrated to new `.ocr_results/` structure
- Metadata preserved but results lost

### Evidence Points to Scenario A or C

- Only 1 file in `.ocr_results/` (very recent)
- 500+ files in `processed.json` (historical)
- Service logs show constant skipping
- Manual processing works fine

## Solutions

### Solution 1: Reset All OCR Flags (Nuclear Option)

**Impact:** Will reprocess ALL documents (500+)
**Time:** Several hours on devon
**Risk:** HIGH CPU usage, may need to run overnight

```bash
# On devon
cd /Users/devon/bin

# Clear processed tracking
rm "/Users/devon/Library/Application Support/YianaOCR/processed.json"

# Create script to reset ocrCompleted flags
# (Requires tool to edit .yianazip metadata)
```

**Problem:** We don't have a tool to bulk-edit metadata in `.yianazip` files

### Solution 2: Selective Reset (Recommended)

**Impact:** Only reprocess documents without OCR results
**Time:** Depends on how many need processing
**Risk:** LOW

**Steps:**

1. **Identify documents needing OCR**
   ```bash
   # On devon - find documents
   cd "/Users/devon/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"

   # List all documents
   find . -name "*.yianazip" -type f > /tmp/all_docs.txt

   # List documents with OCR results
   cd .ocr_results
   find . -name "*.json" -type f | sed 's/\.json$//' > /tmp/ocr_done.txt

   # Compare to find missing
   comm -23 <(sort /tmp/all_docs.txt) <(sort /tmp/ocr_done.txt) > /tmp/need_ocr.txt
   ```

2. **Clear processed tracking**
   ```bash
   rm "/Users/devon/Library/Application Support/YianaOCR/processed.json"
   ```

3. **Restart service**
   ```bash
   launchctl stop com.vitygas.yiana-ocr
   launchctl start com.vitygas.yiana-ocr
   ```

4. **Monitor progress**
   ```bash
   tail -f /Users/devon/Library/Logs/yiana-ocr.log | grep -E "Processing OCR|completed"
   ```

**Problem:** Still need to reset `ocrCompleted` flags in metadata

### Solution 3: Create Metadata Reset Tool (Best Long-Term)

**Create utility to reset OCR flags:**

```swift
// YianaOCRService/Sources/YianaOCRService/Utilities/ResetOCR.swift
func resetOCRFlag(at url: URL) throws {
    let data = try Data(contentsOf: url)
    var document = try YianaDocument(data: data)

    // Check if OCR results exist
    let ocrPath = ocrResultsPath(for: url)
    let hasResults = FileManager.default.fileExists(atPath: ocrPath)

    if !hasResults && document.metadata.ocrCompleted {
        // Reset flag if no results
        document.metadata.ocrCompleted = false
        document.metadata.fullText = nil
        document.metadata.ocrProcessedAt = nil

        // Write back
        let updatedData = try document.write()
        try updatedData.write(to: url)
    }
}
```

**Add command:**
```swift
// In main.swift
struct ResetOCR: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Reset OCR flags for documents without results"
    )

    @Option(name: .long, help: "Path to documents directory")
    var path: String?

    mutating func run() async throws {
        // Scan and reset
    }
}
```

### Solution 4: Quick Manual Test (Immediate)

**Test with a single document:**

1. **Pick a test document**
   ```bash
   cd "/Users/devon/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"
   TEST_DOC="iPhone. 1.yianazip"
   ```

2. **Check if it has OCR results**
   ```bash
   ls -la .ocr_results/ | grep "iPhone"
   # If empty, no OCR results exist
   ```

3. **Remove from processed.json** (can't easily edit)
   OR just clear the whole file:
   ```bash
   rm "/Users/devon/Library/Application Support/YianaOCR/processed.json"
   ```

4. **Stop and restart service**
   ```bash
   launchctl stop com.vitygas.yiana-ocr
   sleep 2
   launchctl start com.vitygas.yiana-ocr
   ```

5. **Watch logs**
   ```bash
   tail -f /Users/devon/Library/Logs/yiana-ocr.log | grep "iPhone"
   ```

**Expected:** Service will still skip because `ocrCompleted: true` in metadata

## Immediate Action Needed

**The core problem:** Documents have `ocrCompleted: true` but no OCR results exist.

**We need:**
1. A tool to reset `ocrCompleted` flag in document metadata
2. OR accept that we need to rebuild all OCR from scratch
3. OR modify the service to ignore the flag and force reprocessing

## Service Code Changes Needed

### Option A: Add Force Flag

```swift
// DocumentWatcher.swift - add option
struct Watch: AsyncParsableCommand {
    @Flag(name: .long, help: "Force reprocess all documents")
    var force: Bool = false

    // In processDocument:
    if !force && document.metadata.ocrCompleted {
        // skip
    }
}
```

### Option B: Check for Results File

```swift
// DocumentWatcher.swift - modify check
func hasOCRResults(for url: URL) -> Bool {
    let baseName = url.deletingPathExtension().lastPathComponent
    let resultsDir = url.deletingLastPathComponent()
        .appendingPathComponent(".ocr_results")
    let jsonPath = resultsDir.appendingPathComponent("\(baseName).json")
    return FileManager.default.fileExists(atPath: jsonPath.path)
}

// In processDocument:
if document.metadata.ocrCompleted && hasOCRResults(for: url) {
    // Only skip if BOTH flag is set AND results exist
    return
}
```

## Recommendation

**For immediate fix:**
1. Add `--force` flag to watch command
2. Deploy updated binary to devon
3. Restart service with force flag
4. Let it reprocess all documents overnight

**For long-term:**
1. Implement check for OCR results file existence
2. Only skip if results actually exist
3. This prevents future issues with missing results

## Next Steps

1. **Decide on approach:**
   - Nuclear: Reprocess everything
   - Surgical: Reset only documents without results
   - Code fix: Modify service logic

2. **Implement chosen solution**

3. **Monitor processing:**
   - Watch CPU usage on devon
   - Check OCR results directory growth
   - Verify search works with new results

4. **Update documentation:**
   - Note this issue in troubleshooting
   - Document recovery procedure

---

**Status:** Diagnosis complete, awaiting decision on fix approach
