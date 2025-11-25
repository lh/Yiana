# Automated OCR and Address Extraction Triggers - Implementation Plan

## Overview
Implement page-level processing flags to automatically trigger OCR on new pages and address extraction after OCR completion.

## ⚠️ Critical Implementation Notes

### .yianazip Format
**The format is a ZIP archive, NOT a simple byte-separated file.**

Structure:
```
archive.yianazip (ZIP format)
├── metadata.json    # DocumentMetadata JSON
├── content.pdf      # PDF data (optional)
└── format.json      # {"formatVersion": 2}
```

Python must use `zipfile` module:
```python
import zipfile
import json

def read_document_metadata(yianazip_path):
    with zipfile.ZipFile(yianazip_path, 'r') as archive:
        metadata_bytes = archive.read('metadata.json')
        return json.loads(metadata_bytes.decode('utf-8'))

def update_document_metadata(yianazip_path, updated_metadata):
    # Use atomic write: write to temp, then replace
    import tempfile, shutil

    temp_fd, temp_path = tempfile.mkstemp(suffix='.yianazip')
    os.close(temp_fd)

    with zipfile.ZipFile(yianazip_path, 'r') as src:
        with zipfile.ZipFile(temp_path, 'w') as dst:
            # Copy all entries except metadata.json
            for item in src.namelist():
                if item != 'metadata.json':
                    dst.writestr(item, src.read(item))
            # Write updated metadata
            dst.writestr('metadata.json', json.dumps(updated_metadata).encode('utf-8'))

    shutil.move(temp_path, yianazip_path)
```

### Two DocumentMetadata Structs
Both must be kept in sync:
- `Yiana/Yiana/Models/DocumentMetadata.swift` (iOS/macOS app)
- `YianaOCRService/Sources/YianaOCRService/Models/YianaDocument.swift` (OCR service)

---

## Design Decision: Page-Level Flags (No Hashing)

Track processing status per page using simple boolean flags. Accept that external PDF edits won't be auto-detected (can add "Force Re-OCR" UI later if needed).

## Phase 1: Add Page Metadata to DocumentMetadata

**Files:**
- `Yiana/Yiana/Models/DocumentMetadata.swift`
- `YianaOCRService/Sources/YianaOCRService/Models/YianaDocument.swift`

Add new struct and property to BOTH files:
```swift
struct PageProcessingState: Codable, Equatable {
    let pageNumber: Int              // 1-based
    var needsOCR: Bool              // true = page needs OCR processing
    var needsExtraction: Bool       // true = page needs address extraction
    var ocrProcessedAt: Date?       // when OCR last completed
    var addressExtractedAt: Date?   // when extraction last completed
}

// Add to DocumentMetadata:
var pageProcessingStates: [PageProcessingState] = []
```

**Initialization rules:**
- New documents: create PageProcessingState for all pages with `needsOCR = true`
- Appended pages: add PageProcessingState entries with `needsOCR = true`
- Existing documents (migration): initialize from `ocrCompleted` flag

## Phase 2: Update Page Operations

**Files to modify:**
- `Yiana/Yiana/ViewModels/DocumentViewModel.swift`
- `Yiana/Yiana/Services/ImportService.swift`

**When pages added (append/import):**
1. Increment `pageCount`
2. Add PageMetadata entries for new pages with `needsOCR = true, needsExtraction = false`
3. Save document metadata

**When pages deleted:**
1. Remove PageMetadata entries for deleted pages
2. Renumber remaining pages sequentially
3. Update `pageCount`
4. Save document metadata

## Phase 3: Modify yiana-ocr Service

**Files:**
- `YianaOCRService/Sources/YianaOCRService/Services/DocumentWatcher.swift`
- `YianaOCRService/Sources/YianaOCRService/Services/OCRProcessor.swift`

**Changes to DocumentWatcher.checkAndProcessDocument():**
```swift
// Current logic (line ~231):
if document.metadata.ocrCompleted { ... return }

// New logic:
let pagesToProcess = document.metadata.pageProcessingStates
    .filter { $0.needsOCR }
    .map { $0.pageNumber }

if pagesToProcess.isEmpty {
    // All pages done, ensure ocrCompleted is true
    if !document.metadata.ocrCompleted {
        var updated = document.metadata
        updated.ocrCompleted = true
        // Save updated document...
    }
    return
}

// Process only pages in pagesToProcess
```

**OCR Results Merging Strategy:**
When processing specific pages:
1. Load existing `.ocr_results/{documentId}.json` if present
2. Replace only the pages that were re-processed
3. Keep existing OCR data for pages not in `pagesToProcess`
4. Renumber pages if needed (e.g., after deletions)

```swift
func mergeOCRResults(existing: OCRResult?, newPages: [OCRPage], processedPageNumbers: Set<Int>) -> OCRResult {
    guard let existing = existing else {
        return newResult // First time processing
    }

    // Keep pages not in processedPageNumbers, add new pages
    var mergedPages = existing.pages.filter { !processedPageNumbers.contains($0.pageNumber) }
    mergedPages.append(contentsOf: newPages)
    mergedPages.sort { $0.pageNumber < $1.pageNumber }

    return OCRResult(..., pages: mergedPages, ...)
}
```

**After successful OCR:**
1. Set `needsOCR = false` for processed pages
2. Set `needsExtraction = true` for processed pages
3. Set `ocrProcessedAt = Date()` for processed pages
4. Set document-level `ocrCompleted = true` when all `pageProcessingStates` have `needsOCR = false`
5. Save DocumentMetadata (writes to .yianazip)

**Backward compatibility:**
- If `pageProcessingStates` is empty, fall back to processing entire document (old behavior)
- Initialize `pageProcessingStates` during migration based on `ocrCompleted` flag

## Phase 4: Create Address Extraction Daemon (Python)

**File:** `AddressExtractor/address_extraction_daemon.py` (new file)

**Functionality:**
1. Watch `.ocr_results/` directory for JSON file changes
2. For each modified OCR JSON:
   - Find corresponding `.yianazip` file (by document ID in filename)
   - Read DocumentMetadata from ZIP archive
   - Find pages with `needsExtraction = true`
   - Run extraction for only those pages
   - Update database with extracted addresses
   - Set `needsExtraction = false`, `addressExtractedAt` = current time
   - Save DocumentMetadata back to ZIP archive

**Implementation approach:**
```python
import zipfile
import json
import os
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from datetime import datetime

class OCRResultHandler(FileSystemEventHandler):
    def __init__(self, documents_path, db_path):
        self.documents_path = documents_path
        self.db_path = db_path
        self.extractor = AddressExtractor(db_path)

    def on_modified(self, event):
        if event.is_directory or not event.src_path.endswith('.json'):
            return
        self.process_ocr_result(event.src_path)

    def find_yianazip_for_document(self, document_id):
        """Find the .yianazip file containing this document ID"""
        for root, _, files in os.walk(self.documents_path):
            for f in files:
                if f.endswith('.yianazip'):
                    path = os.path.join(root, f)
                    try:
                        meta = self.read_metadata(path)
                        if meta.get('id') == document_id:
                            return path
                    except:
                        continue
        return None

    def read_metadata(self, yianazip_path):
        with zipfile.ZipFile(yianazip_path, 'r') as archive:
            return json.loads(archive.read('metadata.json').decode('utf-8'))

    def update_metadata(self, yianazip_path, updated_metadata):
        import tempfile, shutil

        temp_path = yianazip_path + '.tmp'
        with zipfile.ZipFile(yianazip_path, 'r') as src:
            with zipfile.ZipFile(temp_path, 'w') as dst:
                for item in src.namelist():
                    if item != 'metadata.json':
                        dst.writestr(item, src.read(item))
                dst.writestr('metadata.json',
                            json.dumps(updated_metadata, default=str).encode('utf-8'))

        # Atomic replace
        os.replace(temp_path, yianazip_path)

    def process_ocr_result(self, ocr_json_path):
        # Extract document ID from filename (format: {uuid}.json)
        filename = os.path.basename(ocr_json_path)
        document_id = os.path.splitext(filename)[0]

        yianazip_path = self.find_yianazip_for_document(document_id)
        if not yianazip_path:
            return

        metadata = self.read_metadata(yianazip_path)
        states = metadata.get('pageProcessingStates', [])

        pages_to_extract = [s['pageNumber'] for s in states if s.get('needsExtraction')]
        if not pages_to_extract:
            return

        # Run extraction for specific pages
        self.extractor.extract_from_ocr_json(ocr_json_path, document_id, pages=pages_to_extract)

        # Update flags
        now = datetime.utcnow().isoformat() + 'Z'
        for state in states:
            if state['pageNumber'] in pages_to_extract:
                state['needsExtraction'] = False
                state['addressExtractedAt'] = now

        metadata['pageProcessingStates'] = states
        self.update_metadata(yianazip_path, metadata)
```

**Race Condition Handling:**
Both yiana-ocr and the extraction daemon may write to `.yianazip` files. Mitigations:
1. Use atomic file operations (`os.replace()` / `replaceItemAt()`)
2. Read-modify-write with minimal time between read and write
3. Consider adding a simple file lock using `.lock` files if issues arise

## Phase 5: Create LaunchAgent Configuration

**File:** `AddressExtractor/com.vitygas.yiana-address-extraction.plist` (new file)

**Note:** Replace `$USER` with actual username (e.g., `devon` or `rose`) when installing.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vitygas.yiana-address-extraction</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/Users/$USER/Code/Yiana/AddressExtractor/address_extraction_daemon.py</string>
        <string>--documents-path</string>
        <string>/Users/$USER/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents</string>
        <string>--db-path</string>
        <string>/Users/$USER/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/addresses.db</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/$USER/Library/Logs/yiana-address-extraction.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/$USER/Library/Logs/yiana-address-extraction.log</string>
</dict>
</plist>
```

**Installation script** (`AddressExtractor/install_daemon.sh`):
```bash
#!/bin/bash
USER_HOME="$HOME"
PLIST_SRC="$(dirname "$0")/com.vitygas.yiana-address-extraction.plist"
PLIST_DEST="$USER_HOME/Library/LaunchAgents/com.vitygas.yiana-address-extraction.plist"

# Replace $USER placeholder with actual username
sed "s|\$USER|$USER|g" "$PLIST_SRC" > "$PLIST_DEST"

launchctl load "$PLIST_DEST"
echo "Daemon installed and started"
```

## Phase 6: Update address_extractor.py

**File:** `AddressExtractor/address_extractor.py`

**Add page filtering capability:**
- Add `--pages` argument to accept comma-separated page numbers
- Modify extraction logic to process only specified pages from OCR JSON
- When inserting to database, check for existing addresses on those pages first

## Phase 7: Deploy and Test

**Deployment steps:**
1. Deploy updated yiana-ocr service to devon machine
2. Copy address_extraction_daemon.py to devon machine
3. Install Python dependencies (watchdog) on devon
4. Load LaunchAgent: `launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-address-extraction.plist`
5. Verify both services running: `launchctl list | grep yiana`

**Test scenarios:**
1. Add new pages to existing document → verify OCR runs → verify extraction runs
2. Create new document with multiple pages → verify all pages processed
3. Check logs for both services showing incremental processing
4. Verify database has addresses for new pages only

## Migration Strategy

**For existing documents without pageMetadata:**
- On first open, initialize pageMetadata based on current state:
  - If `ocrCompleted = true`: create entries with `needsOCR = false, needsExtraction = false`
  - If `ocrCompleted = false`: create entries with `needsOCR = true, needsExtraction = false`
- Save updated metadata

## Codebase Verification (2025-11-25)

| Component | Status | Location | Notes |
|-----------|--------|----------|-------|
| `PageProcessingState` struct | ❌ Not implemented | - | Doesn't exist in either DocumentMetadata |
| `pageProcessingStates` property | ❌ Not implemented | - | Not in iOS app or OCR service |
| Page add/delete with state tracking | ❌ Not implemented | `DocumentViewModel.swift` | Has `removePages`/`insertPages` but no state tracking |
| OCR page-level processing | ❌ Not implemented | `DocumentWatcher.swift:231` | Still uses document-level `ocrCompleted` flag |
| `address_extraction_daemon.py` | ❌ Not implemented | - | File doesn't exist |
| `--pages` argument in extractor | ❌ Not implemented | `address_extractor.py` | No page filtering capability |
| LaunchAgent plist | ❌ Not implemented | - | File doesn't exist |

**Existing infrastructure that can be leveraged:**
- ✅ `YianaDocumentArchive` package with ZIP format handling
- ✅ `DocumentWatcher` already watches for documents needing OCR
- ✅ `address_extractor.py` has working extraction logic
- ✅ OCR service runs as LaunchAgent

## Implementation Order

1. ⬜ Add PageProcessingState struct to BOTH DocumentMetadata files
2. ⬜ Add CodingKeys and encode/decode for new property
3. ⬜ Update page add/delete operations in DocumentViewModel
4. ⬜ Add migration logic for existing documents (in app and OCR service)
5. ⬜ Modify yiana-ocr DocumentWatcher to process flagged pages only
6. ⬜ Add OCR results merging logic
7. ⬜ Create address_extraction_daemon.py with correct ZIP handling
8. ⬜ Add `--pages` argument to address_extractor.py
9. ⬜ Create LaunchAgent plist and install script
10. ⬜ Deploy to processing machine
11. ⬜ Test end-to-end workflow
12. ⬜ Monitor logs and verify incremental processing

## Success Criteria

- ⬜ New pages added to documents automatically get OCR'd
- ⬜ OCR completion automatically triggers address extraction
- ⬜ Only new/modified pages are processed (not entire document)
- ⬜ Both services run reliably as LaunchAgents
- ⬜ Logs show clear incremental processing messages
- ⬜ Database only contains addresses from processed pages

## Key Technical Details from Discussion

### User Requirements (Confirmed)
1. **Python daemon approach** (Option A) - faster to implement than Swift service
2. **OCR only new pages** - when pages added, don't re-OCR entire document
3. **Extraction triggered by OCR completion** - extraction runs immediately after OCR finishes for a page
4. **Incremental extraction** - only process newly OCR'd pages, not full document
5. **Page-level tracking with flags** - simple boolean flags, no content hashing

### Why Page-Level Tracking?
Document-level tracking fails when:
- User deletes page 3, adds new page 3: `pageCount` unchanged but content different
- User deletes pages 2-4, adds 3 new pages: `pageCount` unchanged but pages 2-4 and 8-10 are different

### Why No Content Hashing?
- Simpler implementation
- App controls all PDF modifications (users don't edit externally)
- Can add "Force Re-OCR" button if needed for edge cases
- KISS principle - solve 99% case simply

### OCR Service Integration
- yiana-ocr already runs as LaunchAgent on devon machine
- Watches: `/Users/devon/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents`
- Needs modification to read pageMetadata and process flagged pages only

### Database Location
- SQLite database: `~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/addresses.db`
- OCR results: `~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results/`

## Implementation Notes

**See "⚠️ Critical Implementation Notes" at the top of this document for correct .yianazip format handling.**

The old separator-based format (`[metadata][0xFF 0xFF 0xFF 0xFF][PDF]`) is no longer used.
The current format is a ZIP archive with `metadata.json`, `content.pdf`, and `format.json` entries.
