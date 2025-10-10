# Format Migration & Cross-Document Page Copy - Design Discussion

**Date**: 2025-10-09
**Status**: Design phase - iteration before implementation
**Purpose**: Plan both features, decide implementation order

---

## Two Features to Implement

### A. ZIP Format Migration
**Goal**: Make `.yianazip` a real ZIP file that can be unzipped to access content

**Current**: Custom binary `[JSON][0xFF 0xFF 0xFF 0xFF][PDF]`
**Target**: Real ZIP containing `content.pdf` + `metadata.json` + other files

**Why**: Data portability - users can access files without the app

### B. Cross-Document Page Copy
**Goal**: Copy page(s) from Document A to Document B

**Use case**: Scan appears in wrong document, need to move it

---

## Implementation Order Question

### Option 1: Format First, Then Copy

**Reasoning**:
- Format change affects file I/O fundamentally
- Copy feature will need to write documents
- Better to write copy feature against final format
- Avoids implementing copy twice (once for old format, once for new)

**Timeline**:
- Week 1: Format migration (3-5 days)
- Week 2: Copy feature (1-2 days)
- Total: 4-7 days

**Pros**:
- ✅ Copy feature built on final architecture
- ✅ Only implement copy once
- ✅ Format risk contained (fix bugs before adding features)

**Cons**:
- ⚠️ Format migration is riskier (could find unexpected issues)
- ⚠️ Copy feature delayed until format stable

### Option 2: Copy First, Then Format

**Reasoning**:
- Copy is user-visible feature (immediate value)
- Format is architectural (users don't see it)
- Get user feedback on copy UX sooner
- Format migration must handle old format anyway (for existing docs)

**Timeline**:
- Week 1: Copy feature on current format (1-2 days)
- Week 2: Format migration (3-5 days)
- Total: 4-7 days (same)

**Pros**:
- ✅ User-visible feature shipped first
- ✅ Can get feedback on copy UX
- ✅ Lower risk first (copy is simpler)

**Cons**:
- ⚠️ Copy feature might need adjustments after format change
- ⚠️ Format migration must preserve copy functionality

### Option 3: Parallel Implementation

**Reasoning**:
- Features are largely independent
- Could work on both simultaneously

**Pros**:
- ✅ Fastest overall (if parallel work possible)

**Cons**:
- ❌ High risk (two major changes at once)
- ❌ Testing complexity increases
- ❌ Hard to isolate issues
- ❌ Not recommended for solo developer

---

## Recommendation: Format First

**Why this order makes sense**:

1. **Format is foundational** - Everything else builds on file I/O
2. **Copy will use document save/load** - Better to build on final format
3. **Migration is one-way** - Once users have ZIP format, can't easily go back
4. **Testing is clearer** - Fix format bugs before adding features
5. **Your stated principle** - Format fix aligns with core values

**Counter-argument**: Copy feature is simpler and provides immediate user value, but format affects data integrity long-term.

---

## Part A: ZIP Format Migration - Detailed Design

### Current Format (Verified from Code)

**File**: `document.yianazip` (not actually a ZIP)

**Structure**:
```
[metadata JSON bytes]
[0xFF 0xFF 0xFF 0xFF]  ← Separator
[raw PDF bytes]
```

**Reading**:
```swift
let data = try Data(contentsOf: url)
// Find separator [0xFF, 0xFF, 0xFF, 0xFF]
// Split into metadata and PDF
```

**Writing**:
```swift
var contents = Data()
contents.append(metadataJSON)
contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))
contents.append(pdfData)
try contents.write(to: url)
```

### Target Format

**File**: `document.yianazip` (real ZIP file)

**Structure**:
```
document.yianazip (ZIP archive)
├── content.pdf          ← The PDF itself
├── metadata.json        ← Document metadata
└── .yiana_version       ← Format version marker
```

**After unzipping** (user renames to .zip):
```bash
unzip document.zip
# Creates folder with:
# - content.pdf (readable in any PDF viewer)
# - metadata.json (human-readable)
```

### Implementation Questions

#### Q1: Which ZIP Library?

**Option A: Apple's Compression Framework** (Recommended)
```swift
import Compression
import AppleArchive
```
- ✅ Native Apple framework
- ✅ No dependencies
- ✅ Well supported
- ⚠️ Requires iOS 15+ / macOS 12+

**Option B: ZipFoundation**
```swift
// Swift Package Manager
dependencies: [
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
]
```
- ✅ Pure Swift
- ✅ Supports older OS versions
- ✅ Simple API
- ⚠️ Third-party dependency

**Option C: Manual ZIP Implementation**
- ❌ Complex
- ❌ Error-prone
- ❌ Not recommended

**Recommendation**: **Use ZipFoundation**
- Your CLAUDE.md says "No dependencies except GRDB"
- But also says dependencies OK for "mature projects with 5+ years production use"
- ZipFoundation: 7+ years, 2000+ stars, actively maintained
- Simple API, reliable
- Trade-off: One dependency vs native-only

**Alternative**: Use Compression framework, set minimum OS to iOS 15+
- Your target users likely on recent iOS anyway
- Could check current deployment target

#### Q2: Migration Strategy

**Option A: Automatic Silent Migration**
```swift
func openDocument(at url: URL) -> Document {
    if isZipFormat(url) {
        return readZipFormat(url)
    } else {
        let doc = readLegacyFormat(url)
        doc.needsMigration = true  // Mark for migration
        return doc
    }
}

func saveDocument(_ doc: Document, to url: URL) {
    // Always save as ZIP
    writeZipFormat(doc, to: url)
}
```

**User experience**:
- Open old document → works fine
- Make any edit → save converts to ZIP automatically
- Transparent, no user action needed

**Pros**:
- ✅ Seamless user experience
- ✅ No user action required
- ✅ Gradual migration (as documents are opened)

**Cons**:
- ⚠️ Mixed formats during transition
- ⚠️ If something breaks, user might not notice until too late

**Option B: Explicit Migration Prompt**
```swift
if !isZipFormat(url) {
    showAlert("This document uses an older format. Convert to new format?")
    // If yes: migrate now
    // If no: open read-only
}
```

**User experience**:
- Open old document → prompt appears
- User chooses to migrate or not
- Can defer migration

**Pros**:
- ✅ User aware of change
- ✅ User controls timing

**Cons**:
- ❌ Friction in user experience
- ❌ User might click "no" and never migrate
- ❌ More complex state management

**Option C: Batch Migration Tool**
```swift
// Settings → "Migrate all documents to new format"
func migrateAllDocuments() async {
    let allDocs = findAllDocuments()
    for doc in allDocs {
        await migrateDocument(doc)
    }
}
```

**Pros**:
- ✅ User controls migration timing
- ✅ All documents migrated at once

**Cons**:
- ❌ Requires user action
- ❌ Could take long time
- ❌ What if migration fails partway through?

**Recommendation**: **Option A - Automatic Silent Migration**
- Best user experience
- Documents migrate as they're used
- Keep ability to read old format forever (safety)

#### Q3: Migration Safety

**Strategy: Always Keep Reading Old Format**

```swift
enum DocumentFormat {
    case legacy  // [JSON][sep][PDF]
    case zip     // ZIP archive
}

func read(url: URL) throws -> Document {
    let format = detectFormat(url)

    switch format {
    case .legacy:
        return try readLegacyFormat(url)
    case .zip:
        return try readZipFormat(url)
    }
}

func write(document: Document, to url: URL) throws {
    // ALWAYS write as ZIP (new format)
    try writeZipFormat(document, to: url)
}
```

**Safety measures**:

1. **Backup before migration** (optional but safe):
```swift
func saveDocument(_ doc: Document, to url: URL) throws {
    // If converting from legacy format, backup first
    if doc.wasLegacyFormat && !backupExists(url) {
        let backupURL = url.appendingPathExtension("backup")
        try FileManager.default.copyItem(at: url, to: backupURL)
    }

    try writeZipFormat(doc, to: url)
}
```

2. **Keep legacy reader forever**:
- Never remove `readLegacyFormat()` function
- Users with old backups can always restore

3. **Format version marker**:
```swift
// Inside ZIP: .yiana_version file
{
    "format_version": 2,
    "created_by": "Yiana 1.0",
    "migration_date": "2025-10-09"
}
```
- Helps future format changes
- Can detect and handle multiple versions

#### Q4: What Goes in the ZIP?

**Minimum (MVP)**:
```
document.yianazip/
├── content.pdf       ← Main PDF content
└── metadata.json     ← Document metadata
```

**Extended (Future)**:
```
document.yianazip/
├── content.pdf           ← Main PDF
├── metadata.json         ← Metadata
├── .yiana_version        ← Format version
├── ocr_results.json      ← OCR data (if available)
├── annotations/          ← Markup data (future)
│   └── page_1.json
└── thumbnails/           ← Pre-rendered thumbnails (future)
    ├── page_1.jpg
    └── page_2.jpg
```

**For MVP, recommend**: Just PDF + metadata + version marker
- Keep it simple
- Easy to understand for users
- Can add more later

#### Q5: OCR Results - Include or Separate?

**Current**: OCR results stored in `.ocr_results/` folder next to document

**Option A: Keep OCR Separate** (Recommended for now)
```
Documents/
├── receipt.yianazip        ← ZIP with PDF + metadata
└── .ocr_results/
    └── receipt.json        ← OCR data separate
```

**Pros**:
- ✅ OCR is backend service output
- ✅ Separates "source of truth" from "derived data"
- ✅ Simpler migration (don't need to package OCR)
- ✅ Can delete/regenerate OCR without affecting document

**Cons**:
- ⚠️ If user copies .yianazip alone, loses OCR data
- ⚠️ Two files to manage

**Option B: Include OCR in ZIP**
```
document.yianazip/
├── content.pdf
├── metadata.json
└── ocr_results.json    ← Include OCR data
```

**Pros**:
- ✅ Self-contained document
- ✅ OCR travels with document

**Cons**:
- ❌ Increases file size
- ❌ OCR changes require re-zipping
- ❌ More complex migration

**Recommendation**: **Keep OCR separate for MVP**
- Can reconsider later if users request it
- Simpler implementation
- Backend service can still write to `.ocr_results/`

### Implementation Phases

#### Phase 1: Add ZIP Support (Days 1-2)

**Tasks**:
1. Add ZipFoundation dependency (or Compression framework)
2. Implement `writeZipFormat(document:to:)`
3. Implement `readZipFormat(url:)`
4. Add format detection `detectFormat(url:)`
5. Unit tests for ZIP read/write

**Deliverable**: Can read/write ZIP format (parallel to legacy)

#### Phase 2: Migration Logic (Day 3)

**Tasks**:
1. Update `NoteDocument` to detect format on load
2. Mark legacy documents for migration
3. Auto-migrate on save
4. Handle migration errors gracefully

**Deliverable**: Documents auto-migrate transparently

#### Phase 3: Update Import/Export (Day 4)

**Tasks**:
1. Update `ImportService` to create ZIP format
2. Update bulk import (macOS) to create ZIP
3. Export still creates plain PDF (user wants PDF, not .yianazip)

**Deliverable**: All new documents created as ZIP

#### Phase 4: Testing & Edge Cases (Day 5)

**Tasks**:
1. Test migration of various documents
2. Test with/without PDF data
3. Test with provisional pages
4. Test iCloud sync with new format
5. Test opening migrated docs on other devices
6. Performance testing (ZIP overhead)

**Deliverable**: Stable, tested migration

### Code Structure Proposal

**New file**: `DocumentArchive.swift`
```swift
import Foundation
import ZipFoundation  // or Compression

enum DocumentArchiveFormat {
    case legacy
    case zip
}

struct DocumentArchive {
    // Read operations
    static func detectFormat(at url: URL) -> DocumentArchiveFormat
    static func readLegacy(from url: URL) throws -> (metadata: DocumentMetadata, pdfData: Data?)
    static func readZip(from url: URL) throws -> (metadata: DocumentMetadata, pdfData: Data?)

    // Write operations
    static func writeZip(metadata: DocumentMetadata, pdfData: Data?, to url: URL) throws

    // Migration
    static func needsMigration(url: URL) -> Bool
    static func migrate(from url: URL) throws
}
```

**Updated**: `NoteDocument.swift`
```swift
class NoteDocument: UIDocument {
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Use DocumentArchive to detect and load
        let format = DocumentArchive.detectFormat(at: fileURL)

        switch format {
        case .legacy:
            (metadata, pdfData) = try DocumentArchive.readLegacy(from: fileURL)
            needsMigration = true
        case .zip:
            (metadata, pdfData) = try DocumentArchive.readZip(from: fileURL)
            needsMigration = false
        }
    }

    override func contents(forType typeName: String) throws -> Any {
        // Always write ZIP
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try DocumentArchive.writeZip(metadata: metadata, pdfData: pdfData, to: tempURL)
        return try Data(contentsOf: tempURL)
    }
}
```

### Risks & Mitigation

**Risk 1: iCloud Sync Issues**
- **Problem**: ZIP format might sync differently than binary blob
- **Mitigation**: Test thoroughly on multiple devices
- **Fallback**: ZIP should actually sync BETTER (proper file format)

**Risk 2: Performance Overhead**
- **Problem**: ZIP compression/decompression slower than raw binary
- **Mitigation**: Use ZIP with no compression (store only) for PDF (already compressed)
- **Test**: Measure read/write times

**Risk 3: Migration Failures**
- **Problem**: Some documents fail to migrate
- **Mitigation**: Keep legacy reader, log failures, user can retry
- **Fallback**: Document opens read-only if migration fails

**Risk 4: File System Case Sensitivity**
- **Problem**: `content.pdf` vs `Content.pdf` on case-sensitive systems
- **Mitigation**: Use lowercase consistently, document in code
- **Test**: Test on case-sensitive file system

### User Communication

**Do you need to tell users?**

**Option A: Silent (Recommended)**
- Migration happens automatically
- No user communication needed
- Users who check will find ZIP files work as expected

**Option B: Release Notes**
```
Version 1.0 Update:
- Documents now use standard ZIP format
- Your data is more accessible - rename .yianazip to .zip to access contents
- Existing documents automatically updated
```

**Option C: In-App Notice (First Launch)**
```
[Alert on first launch after update]
"Yiana now uses an improved document format that makes your data more accessible. Documents will automatically update as you use them."
```

**Recommendation**: **Option A (Silent)** + brief mention in release notes
- Best UX (no friction)
- Power users can discover ZIP feature
- Could add tip in documentation

---

## Part B: Cross-Document Page Copy - Detailed Design

### Use Cases

**Primary use case**:
1. User scans pages into wrong document
2. Realizes mistake
3. Wants to move page(s) to correct document
4. Without re-scanning

**Secondary use cases**:
- Combine pages from multiple documents
- Split one document into multiple
- Collect related pages from various documents

### UX Design Options

#### Option 1: Copy/Paste Pattern (iOS Standard)

**Flow**:
1. Open Document A
2. Select page(s) in sidebar or page management
3. Tap "Copy" button
4. Back to document list
5. Open Document B
6. Tap "Paste" button (appears in toolbar)
7. Pages inserted

**Implementation**:
```swift
// Step 1: Copy to app clipboard
class PageClipboard {
    static let shared = PageClipboard()
    private var copiedPages: [(sourceURL: URL, pageIndices: [Int])] = []

    func copyPages(from docURL: URL, indices: [Int]) {
        copiedPages = [(docURL, indices)]
    }

    func hasCopiedPages() -> Bool {
        return !copiedPages.isEmpty
    }

    func pastePages(into targetDoc: PDFDocument) throws {
        // Extract pages from source, insert into target
    }
}

// Step 2: UI shows "Paste" when clipboard has pages
if PageClipboard.shared.hasCopiedPages() {
    Button("Paste \(count) Pages") {
        pastePages()
    }
}
```

**Pros**:
- ✅ Familiar iOS pattern
- ✅ Simple mental model
- ✅ Non-destructive (copy, not move)

**Cons**:
- ⚠️ Clipboard state survives app close? (UX question)
- ⚠️ User must remember they copied something
- ⚠️ Where to paste? (beginning, end, current position?)

#### Option 2: "Move to..." Picker

**Flow**:
1. Open Document A
2. Select page(s)
3. Tap "Move to..."
4. Sheet shows document picker
5. Select destination document
6. Pages move immediately

**Implementation**:
```swift
// Step 1: Show document picker
.sheet(isPresented: $showingMoveToPicker) {
    DocumentPickerView(
        excludeDocument: currentDocURL,
        onSelect: { destURL in
            movePages(from: currentDocURL, to: destURL, indices: selectedPages)
        }
    )
}

// Step 2: Move operation
func movePages(from source: URL, to dest: URL, indices: [Int]) async {
    // Extract pages from source
    // Insert into destination
    // Optionally delete from source
}
```

**Pros**:
- ✅ Single flow (no remembering clipboard)
- ✅ Immediate feedback
- ✅ Clear destination selection

**Cons**:
- ⚠️ Move vs Copy? (destructive vs non-destructive)
- ⚠️ Document picker needed
- ⚠️ Where in destination? (always append at end?)

#### Option 3: Share Sheet Integration

**Flow**:
1. Select page(s)
2. Tap "Share" button
3. iOS share sheet appears
4. "Add to Yiana Document" option
5. Select destination
6. Pages copied

**Implementation**:
```swift
// Create temporary PDF with selected pages
let selectedPagesPDF = extractPages(indices: selectedPages)

// Share sheet
.sheet(items: [selectedPagesPDF]) { pdf in
    ShareSheet(items: [pdf])
}

// App appears in share sheet (already have this!)
// ImportService handles adding to existing document
```

**Pros**:
- ✅ Uses existing share infrastructure
- ✅ Familiar iOS pattern
- ✅ Could share to other apps too

**Cons**:
- ❌ Clunky for internal operation
- ❌ Creates temporary files
- ❌ Less intuitive for "move pages" use case

#### Option 4: Long-Press Context Menu

**Flow**:
1. Long-press on page thumbnail
2. Context menu appears: "Copy to..." or "Move to..."
3. Document picker slides up
4. Select destination
5. Pages transferred

**Implementation**:
```swift
.contextMenu {
    Button(action: { showMoveToPicker() }) {
        Label("Move to...", systemImage: "folder")
    }
    Button(action: { showCopyToPicker() }) {
        Label("Copy to...", systemImage: "doc.on.doc")
    }
}
```

**Pros**:
- ✅ Discoverable (long-press is common pattern)
- ✅ Separate Copy vs Move options
- ✅ Context-specific action

**Cons**:
- ⚠️ Only works for single page at a time? (or selection mode first)
- ⚠️ Requires implementing document picker

### Recommended UX: Combination Approach

**Selection mode** (already exists):
1. Select pages in sidebar
2. Action buttons appear: [Duplicate] [Delete] [**Move to...**]
3. "Move to..." shows document picker
4. Select destination → pages move
5. Exit selection mode

**Additions needed**:
- Add "Move to..." button in action toolbar (sidebar)
- Implement document picker sheet
- Handle page extraction and insertion

**Why this approach**:
- ✅ Fits existing selection UI
- ✅ Clear single flow
- ✅ Follows pattern of Duplicate/Delete buttons
- ✅ Non-destructive default (can be "Copy to..." instead)
- ✅ Where to insert? → Always append at end (simplest)

### Technical Design

#### Component 1: Document Picker

**New file**: `DocumentPickerView.swift`
```swift
struct DocumentPickerView: View {
    let excludeDocument: URL?  // Don't show current document
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Show all documents except current
                ForEach(availableDocuments) { doc in
                    Button(action: {
                        onSelect(doc.url)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "doc")
                            Text(doc.title)
                        }
                    }
                }
            }
            .navigationTitle("Select Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

#### Component 2: Page Transfer Service

**New file**: `PageTransferService.swift`
```swift
class PageTransferService {
    enum TransferMode {
        case copy  // Leave originals, copy pages
        case move  // Remove from source, add to dest
    }

    func transferPages(
        from sourceURL: URL,
        to destinationURL: URL,
        pageIndices: [Int],
        mode: TransferMode
    ) async throws {
        // 1. Load source document
        let sourceDoc = try loadDocument(at: sourceURL)

        // 2. Extract selected pages
        let pages = try extractPages(from: sourceDoc, indices: pageIndices)

        // 3. Load destination document
        var destDoc = try loadDocument(at: destinationURL)

        // 4. Append pages to destination
        try appendPages(pages, to: &destDoc)

        // 5. Save destination
        try saveDocument(destDoc, to: destinationURL)

        // 6. If move mode, remove from source
        if mode == .move {
            try removePages(from: sourceURL, indices: pageIndices)
        }
    }

    private func extractPages(from doc: PDFDocument, indices: [Int]) throws -> [PDFPage] {
        // Extract pages as copies (not references)
        var pages: [PDFPage] = []
        for index in indices.sorted() {
            guard let page = doc.page(at: index) else { continue }

            // Create deep copy
            if let copied = page.copy() as? PDFPage {
                pages.append(copied)
            } else {
                // Fallback: serialize/deserialize technique (learned from reorder bug!)
                let tempDoc = PDFDocument()
                tempDoc.insert(page, at: 0)
                if let data = tempDoc.dataRepresentation(),
                   let freshDoc = PDFDocument(data: data),
                   let freshPage = freshDoc.page(at: 0) {
                    pages.append(freshPage)
                }
            }
        }
        return pages
    }

    private func appendPages(_ pages: [PDFPage], to document: inout PDFDocument) throws {
        for page in pages {
            document.insert(page, at: document.pageCount)
        }
    }
}
```

#### Component 3: UI Integration

**Updated**: `ThumbnailSidebarView.swift`
```swift
// Add new callback
var onMoveSelection: (() -> Void)? = nil

// In action toolbar
if isSelecting {
    HStack(spacing: 12) {
        // ... existing Duplicate and Delete buttons ...

        if let onMoveSelection {
            Button {
                onMoveSelection()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
        }

        Spacer()
    }
}
```

**Updated**: `DocumentEditView.swift`
```swift
@State private var showingMoveToPicker = false

// In sidebar
onMoveSelection: selectedSidebarPages.isEmpty ? nil : {
    showingMoveToPicker = true
}

// Sheet for document picker
.sheet(isPresented: $showingMoveToPicker) {
    DocumentPickerView(excludeDocument: documentURL) { destURL in
        movePagesToDocument(destURL)
    }
}

private func movePagesToDocument(_ destinationURL: URL) {
    let indices = Array(selectedSidebarPages)
    Task {
        let service = PageTransferService()
        try await service.transferPages(
            from: documentURL,
            to: destinationURL,
            pageIndices: indices,
            mode: .move  // or .copy based on user preference
        )

        await MainActor.run {
            exitSidebarSelection()
            // Refresh current document (pages removed)
            // Maybe show toast: "Moved X pages to [Document]"
        }
    }
}
```

### Design Questions

#### Q1: Copy vs Move?

**Move** (destructive):
- Pages removed from source
- Added to destination
- Source document has fewer pages

**Copy** (non-destructive):
- Pages stay in source
- Also added to destination
- Source unchanged

**Recommendation**: Start with **"Move to..."**
- Matches primary use case (correcting mistake)
- Clearer intent
- Can add "Copy to..." later if requested
- User can always Duplicate first, then Move if they want to keep copy

#### Q2: Where to Insert in Destination?

**Option A: Always Append at End**
- Simplest
- Predictable
- User can reorder after if needed

**Option B: Ask User (Show Page Picker)**
- More control
- More complex UI
- Slows down operation

**Option C: Insert at Current Page**
- If destination is open, insert at viewed page
- If destination is closed, append at end

**Recommendation**: **Option A - Always Append**
- Simplest implementation
- Matches "adding pages to document" mental model
- User can use reorder feature after if they want different position

#### Q3: What if Destination is Open?

**Scenario**: User has both Document A and Document B open (iPad multitasking)

**Problem**: Document B needs to refresh after pages added

**Solutions**:

**Option A: Disallow if Destination is Open**
- Show error: "Please close [Document] before moving pages to it"
- Simplest, avoids conflicts

**Option B: Use Notifications**
```swift
// After saving destination
NotificationCenter.default.post(
    name: .yianaDocumentsChanged,
    object: destinationURL
)

// In DocumentEditView
.onReceive(NotificationCenter.default.publisher(for: .yianaDocumentsChanged)) { notification in
    if let url = notification.object as? URL, url == documentURL {
        // Reload document
    }
}
```

**Recommendation**: **Option B** - Already have notification system
- More robust
- Better UX (no restrictions)
- Document auto-refreshes when changed externally

#### Q4: Confirmation or Undo?

**Confirmation** (before action):
```swift
Alert("Move \(count) pages to \(destTitle)?")
```

**Undo** (after action):
```swift
Toast("Moved \(count) pages to \(destTitle)")
Button("Undo") { undoMove() }
```

**Recommendation**: **No confirmation, but show feedback**
- Action is non-destructive (pages not deleted)
- User selected pages + destination explicitly
- Show toast with destination name for feedback
- Undo could be Phase 2 if needed

#### Q5: Provisional Pages - Allow Moving?

**Scenario**: User wants to move a draft markdown page to another document

**Problem**: Provisional pages exist only in displayPDFData, not pdfData

**Options**:

**Option A: Disallow**
- If selection includes provisional pages, disable "Move to..."
- Show message: "Save draft pages before moving"

**Option B: Auto-commit**
- Commit provisional pages to main document first
- Then allow move

**Option C: Allow, Extract from displayPDFData**
- Extract from combined document (displayPDFData)
- More complex

**Recommendation**: **Option A - Disallow for MVP**
- Simpler implementation
- Provisional pages are temporary by nature
- User can commit, then move
- Can revisit if users request it

### Implementation Phases

#### Phase 1: Core Service (Days 1)

**Tasks**:
1. Create `PageTransferService`
2. Implement page extraction (with deep copy)
3. Implement page insertion
4. Implement page removal
5. Unit tests

**Deliverable**: Service that can move pages programmatically

#### Phase 2: Document Picker UI (Day 1)

**Tasks**:
1. Create `DocumentPickerView`
2. List available documents
3. Exclude current document
4. Handle selection

**Deliverable**: Working document picker

#### Phase 3: UI Integration (Day 2)

**Tasks**:
1. Add "Move to..." button in sidebar
2. Wire up document picker sheet
3. Connect to PageTransferService
4. Handle success/error cases
5. Show user feedback (toast/alert)

**Deliverable**: End-to-end page moving works

#### Phase 4: Edge Cases & Polish (Day 2)

**Tasks**:
1. Handle provisional pages (disallow or auto-commit)
2. Refresh destination if open
3. Update page count in metadata
4. Test with various document states
5. Error handling and user messages

**Deliverable**: Robust, tested feature

### Risks & Mitigation

**Risk 1: Page Copy Fails**
- **Problem**: `page.copy()` might fail (learned from reorder bug)
- **Mitigation**: Use serialization fallback (create temp PDF document)
- **Code**: Already have pattern from reorder fix

**Risk 2: Document Corruption**
- **Problem**: Saving destination fails mid-operation
- **Mitigation**: Atomic writes, rollback on failure
- **Test**: Simulate failure scenarios

**Risk 3: Metadata Out of Sync**
- **Problem**: Page count doesn't match actual pages
- **Mitigation**: Recalculate page count after operations
- **Code**: Already doing this in DocumentViewModel

**Risk 4: Large Documents**
- **Problem**: Moving 50 pages could be slow
- **Mitigation**: Show progress indicator for large operations
- **Test**: Performance test with large selections

### User Communication

**Button Label Options**:
- "Move to..." (✅ Clear intent)
- "Send to..." (⚠️ Less clear)
- "Transfer to..." (⚠️ Formal)
- [folder icon only] (⚠️ Less discoverable)

**Feedback Options**:
- Toast: "Moved 3 pages to Receipts 2024"
- Alert: "Successfully moved pages"
- Silent: No feedback (❌ Bad UX)

**Recommendation**:
- Button: "Move to..." with folder icon
- Feedback: Toast with document name + undo option (future)

---

## Implementation Order - Final Recommendation

### Recommended: Format First, Then Copy

**Week 1: ZIP Format Migration**
- Days 1-2: Add ZIP support
- Day 3: Migration logic
- Day 4: Update import/export
- Day 5: Testing

**Week 2: Cross-Document Page Copy**
- Day 1: Core service + document picker
- Day 2: UI integration + polish

**Total**: ~7 days

**Rationale**:
1. Format is foundational architecture
2. Copy feature builds on file I/O
3. Better to implement copy once (on final format)
4. Format migration is riskier (want to find/fix bugs first)
5. Both features tested independently before combining

---

## Open Questions for Discussion

### Format Migration

1. **Dependency choice**: ZipFoundation (simple) vs Compression framework (native)?
   - Check current deployment target (iOS version)
   - Check CLAUDE.md dependency policy interpretation

2. **Migration timing**: Silent automatic vs user-prompted?
   - I recommend automatic
   - You might want user awareness

3. **OCR data**: Keep separate or include in ZIP?
   - I recommend separate for MVP
   - Can revisit later

4. **Backup strategy**: Create .backup files during migration?
   - Extra safety vs disk space
   - Your preference?

### Page Copy

1. **Operation mode**: Move (destructive) or Copy (non-destructive)?
   - I recommend Move (matches use case)
   - Could offer both

2. **Insert position**: Always append vs ask user?
   - I recommend always append
   - Simpler, predictable

3. **Provisional pages**: Disallow, auto-commit, or allow?
   - I recommend disallow for MVP
   - Keeps complexity down

4. **Confirmation**: Ask before moving or just do it with undo?
   - I recommend no confirmation (clear action already)
   - Show feedback toast

### General

1. **Which feature first**: Still confident in Format → Copy order?
2. **Timeline pressure**: Need to ship sooner? Could affect decisions
3. **Testing approach**: How thoroughly to test before moving to next feature?

---

## Next Steps

**After this discussion**:
1. You review this document
2. We iterate on any questions/concerns
3. You make final decisions on open questions
4. We create detailed implementation plan
5. Then we start coding

**No code yet** - let's make sure the design is right first!

---

## Summary

### Two Features Planned

**A. ZIP Format Migration**
- 3-5 days work
- Aligns with original vision
- Makes data accessible without app
- Automatic migration on save

**B. Cross-Document Page Copy**
- 2 days work
- Adds "Move to..." button in selection mode
- Document picker for destination
- Append pages at end (simple, predictable)

### Recommendation

**Do Format first, then Copy**
- Total: ~7 days work
- Format is foundational
- Copy builds on stable file I/O
- Both tested independently

### Your Decision Needed

Review design, iterate on questions, then we implement!
