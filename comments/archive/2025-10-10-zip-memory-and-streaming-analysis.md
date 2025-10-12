# ZIP Memory & Streaming Analysis for Yiana

**Date**: 2025-10-10
**Purpose**: Deep dive into ZIP library options focusing on memory efficiency and streaming for large PDFs

---

## Context

User clarification: **No legacy data exists** - app still in development, so we only need to:
1. Write new documents in ZIP format correctly
2. Read ZIP format correctly
3. Ensure all hooks (OCR service, search indexer, etc.) work with new format

**Key concern raised**: Memory usage when handling large PDFs. Need to understand streaming capabilities.

---

## The Memory Problem

### Scenario: 200-page color scan at high DPI
- Each page: ~2MB (color, 300 DPI)
- Total PDF: ~400MB
- If we load entire file into memory: **400MB + decompression overhead + working space = ~600MB+**

### Critical operations that could blow up memory:
1. **Save operation**: User scans 50 pages → append to existing 150-page document
2. **Page transfer**: Copy 20 pages from 200-page source to 100-page destination
3. **OCR service**: Read metadata + PDF from large document
4. **Search indexer**: Extract metadata from hundreds of documents during initial scan

### Why current format is memory-efficient:
```
[metadata JSON][0xFF 0xFF 0xFF 0xFF][PDF bytes]
```
- Can `seek()` to separator, read only metadata without loading PDF
- Can `seek()` past metadata, stream PDF to PDFKit without full load
- OCR service can read metadata, check if processing needed, then stream PDF

---

## ZIP Library Deep Dive

### Option 1: Apple's Compression Framework (iOS 15+, macOS 12+)

**APIs Available**:
```swift
import Compression
import AppleArchive
```

**Streaming Capabilities**:
- ✅ **AppleArchive** supports streaming read/write
- ✅ Can extract single entry without reading entire archive
- ✅ Can append to archive (limited support)
- ❌ More complex API, less documentation
- ❌ iOS 15+ only (need to verify deployment target)

**Example - Stream-friendly read**:
```swift
import AppleArchive
import System

// Open archive for reading
let archiveFilePath = FilePath("/path/to/document.yianazip")
let readFileStream = try ArchiveByteStream.fileStream(
    path: archiveFilePath,
    mode: .readOnly,
    options: [],
    permissions: FilePermissions(rawValue: 0o644)
)
defer { try? readFileStream.close() }

let archiveStream = try ArchiveByteStream.decompressionStream(
    using: .lzfse,
    readingFrom: readFileStream
)

// Read archive, can process entries one at a time
let decoder = ArchiveStreamDecoder(stream: archiveStream)
while let header = try? decoder.nextHeader() {
    if header.path == "metadata.json" {
        // Extract just this entry
        let metadataData = try extractEntry(header, from: decoder)
        // Process without loading full archive
    }
}
```

**Memory Characteristics**:
- ✅ Can read metadata without loading PDF
- ✅ Can stream PDF to PDFKit
- ⚠️ Writing requires careful buffering
- ⚠️ Complex API, steeper learning curve

**Verdict**: Most memory-efficient but highest complexity

---

### Option 2: ZipFoundation (Third-party, Swift)

**Repository**: https://github.com/weichsel/ZipFoundation
- Well-maintained, 2000+ stars
- Pure Swift, no C dependencies
- Clean, simple API

**Streaming Capabilities**:
```swift
import ZipFoundation

// READING - Can extract single entry efficiently
guard let archive = Archive(url: zipURL, accessMode: .read) else { return }

// Extract just metadata - DOES NOT load entire ZIP into memory
if let metadataEntry = archive["metadata.json"] {
    var metadataData = Data()
    _ = try archive.extract(metadataEntry) { data in
        metadataData.append(data)
    }
    let metadata = try JSONDecoder().decode(DocumentMetadata.self, from: metadataData)
}

// Extract PDF using streaming callback - can pass directly to PDFKit
if let pdfEntry = archive["content.pdf"] {
    var pdfData = Data()
    _ = try archive.extract(pdfEntry, bufferSize: 32 * 1024) { chunk in
        // Called multiple times with chunks
        pdfData.append(chunk)
    }
    // Or write directly to temp file without accumulating in memory:
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.pdf")
    _ = try archive.extract(pdfEntry, to: tempURL)
    // PDFKit can then read from file
}

// WRITING - Less memory-efficient
let archive = Archive(url: zipURL, accessMode: .create)

// Adding large PDF - PROBLEM: needs Data object
try archive.addEntry(with: "content.pdf", type: .file, uncompressedSize: pdfData.count) { position, size in
    // This callback is called to get chunks, but we need the data upfront
    return pdfData.subdata(in: position..<(position + size))
}

// Alternative: Write to file first, then add from file
let tempPDFURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.pdf")
try pdfData.write(to: tempPDFURL)
try archive.addEntry(with: "content.pdf", relativeTo: tempPDFURL.deletingLastPathComponent())
try FileManager.default.removeItem(at: tempPDFURL)
```

**Memory Characteristics**:
- ✅ **Reading**: Excellent - can extract single files without loading full archive
- ✅ **Reading**: Streaming callbacks allow processing chunks
- ⚠️ **Writing**: Moderate - needs data upfront OR write to temp file first
- ✅ Simple, clean API
- ✅ Well-tested in production

**Key Insight**: For reading (OCR service, search indexer), ZipFoundation is excellent. For writing (save operations), need to be careful about large PDFs.

**Verdict**: Best balance of simplicity and memory efficiency for our use case

---

### Option 3: Archive from temp directory (Hybrid Approach)

**Concept**: Avoid ZIP libraries' write limitations by using filesystem as staging area

```swift
// WRITING approach:
func saveDocument(metadata: DocumentMetadata, pdfData: Data, to finalURL: URL) throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    // Write files to temp directory - can do this with minimal memory
    let metadataURL = tempDir.appendingPathComponent("metadata.json")
    let pdfURL = tempDir.appendingPathComponent("content.pdf")

    let metadataData = try JSONEncoder().encode(metadata)
    try metadataData.write(to: metadataURL)
    try pdfData.write(to: pdfURL)  // This is where we'd have memory spike anyway

    // Now ZIP the directory using ZipFoundation
    let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
    try FileManager.default.zipItem(at: tempDir, to: tempZipURL)

    // Atomic move
    try FileManager.default.moveItem(at: tempZipURL, to: finalURL)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
}
```

**Memory Characteristics**:
- ⚠️ Still need full `pdfData` in memory at some point
- ✅ Filesystem buffering helps
- ✅ Clean separation of concerns
- ✅ Easy to understand and debug

**Critique & Refinements**
- `FileManager.zipItem` compresses with Deflate by default; if we want uncompressed entries we either need to accept the extra CPU or drop down to manual `Archive` APIs/ZipFoundation to set `.none`.
- Disk I/O doubles for the PDF (write to staging file, then read back while zipping). On big scans this adds latency and temporary storage pressure, though writes happen in the caches directory so they’re short-lived.
- Best paired with streaming writes into `content.pdf`—if upstream code already holds a `Data` blob there’s still a peak equal to PDF size, but if we can stream from a scanner/importer we avoid buffering in RAM.
- Requires diligent clean-up (use `defer` blocks) so temp folders/zips don’t leak if the save fails midway.
- The pattern shines when source material already exists on disk (e.g., importing a PDF from Files); less compelling when data only exists as an in-memory `Data`.

**Verdict**: Doesn't solve the fundamental memory problem, but simplest to implement

---

## The Fundamental Question: Can We Avoid Loading Entire PDF?

### When do we actually HAVE the full PDF in memory?

**Scenario 1: Scanning new pages**
```swift
// VisionKit gives us UIImages
func scan(images: [UIImage]) {
    // Convert to PDF - MUST load all in memory here
    let pdfData = convertImagesToPDF(images)

    // If appending to existing document:
    let existingDoc = PDFDocument(url: existingURL)  // PDFKit lazy-loads
    let newDoc = PDFDocument(data: pdfData)

    // Append pages
    for i in 0..<newDoc.pageCount {
        existingDoc.insert(newDoc.page(at: i), at: existingDoc.pageCount)
    }

    // Save - THIS is where we need full data
    let combinedData = existingDoc.dataRepresentation()  // Full document in memory
}
```

**Reality**: When we call `PDFDocument.dataRepresentation()`, we MUST have full PDF in memory. ZIP vs custom format doesn't change this.

**Scenario 2: OCR service reads document**
```swift
// Current format:
let data = try Data(contentsOf: documentURL)  // Full file in memory ❌
let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
// Split and process

// Better approach (works with current format too):
let handle = try FileHandle(forReadingFrom: documentURL)
let metadataData = // read until separator
let metadata = try JSONDecoder().decode(DocumentMetadata.self, from: metadataData)

if !metadata.ocrCompleted {
    // NOW load PDF for processing
    handle.seek(toFileOffset: separatorPosition)
    let pdfData = handle.readDataToEndOfFile()
    // Process...
}
```

**With ZIP format**:
```swift
let archive = Archive(url: documentURL, accessMode: .read)
let metadataEntry = archive["metadata.json"]!
var metadataData = Data()
_ = try archive.extract(metadataEntry) { metadataData.append($0) }
let metadata = try JSONDecoder().decode(DocumentMetadata.self, from: metadataData)

if !metadata.ocrCompleted {
    // NOW extract PDF
    let pdfEntry = archive["content.pdf"]!
    let tempPDFURL = // temp location
    _ = try archive.extract(pdfEntry, to: tempPDFURL)
    // Process from file, not memory
}
```

**Key insight**: ZIP format with ZipFoundation is BETTER for OCR service because it can:
1. Read metadata without touching PDF
2. Extract PDF to temp file instead of loading to memory
3. Process from file handle

---

## Recommended Approach

### Choice: **ZipFoundation**

**Rationale**:
1. **Simple API**: Easy to understand and maintain
2. **Good streaming for reads**: OCR and search can read metadata without loading PDF
3. **Acceptable writes**: We have to load PDF for save anyway (PDFKit requirement)
4. **Well-tested**: Production-ready, active maintenance
5. **Pure Swift**: No C interop concerns

### Architecture Pattern

```swift
// DocumentArchive.swift
import ZipFoundation

struct DocumentArchive {
    // READING - Memory-efficient
    static func readMetadata(from url: URL) throws -> DocumentMetadata {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw ArchiveError.cannotOpen
        }

        guard let entry = archive["metadata.json"] else {
            throw ArchiveError.missingMetadata
        }

        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return try JSONDecoder().decode(DocumentMetadata.self, from: data)
    }

    static func extractPDF(from url: URL, to tempURL: URL) throws {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw ArchiveError.cannotOpen
        }

        guard let entry = archive["content.pdf"] else {
            throw ArchiveError.missingPDF
        }

        // Stream to file, not memory
        _ = try archive.extract(entry, to: tempURL)
    }

    static func read(from url: URL) throws -> (metadata: DocumentMetadata, pdfData: Data) {
        let metadata = try readMetadata(from: url)

        guard let archive = Archive(url: url, accessMode: .read),
              let entry = archive["content.pdf"] else {
            throw ArchiveError.missingPDF
        }

        var pdfData = Data()
        _ = try archive.extract(entry) { pdfData.append($0) }

        return (metadata, pdfData)
    }

    // WRITING - Accepts that we need PDF in memory for this operation
    static func write(metadata: DocumentMetadata, pdfData: Data, to url: URL) throws {
        // Write to temp location first (atomic save)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".yianazip")

        // Create archive
        guard let archive = Archive(url: tempURL, accessMode: .create) else {
            throw ArchiveError.cannotCreate
        }

        // Add metadata
        let metadataData = try JSONEncoder().encode(metadata)
        try archive.addEntry(with: "metadata.json", type: .file,
                           uncompressedSize: metadataData.count) { position, size in
            return metadataData.subdata(in: position..<(position + size))
        }

        // Add PDF - THIS is where memory pressure happens (unavoidable)
        try archive.addEntry(with: "content.pdf", type: .file,
                           uncompressedSize: pdfData.count) { position, size in
            return pdfData.subdata(in: position..<(position + size))
        }

        // Atomic move
        try FileManager.default.moveItem(at: tempURL, to: url)
    }
}
```

### Memory Profile

**OCR Service** (best case):
```
1. Open document - minimal memory
2. Read metadata (10KB) - ~10KB memory
3. Check ocrCompleted flag - no PDF loaded
4. If needs processing:
   - Extract PDF to temp file - ~50MB peak (streaming)
   - Process from file handle - controlled by OCR service
```

**Save Operation** (unavoidable pressure):
```
1. User scans 50 pages - ~100MB for images
2. Convert to PDF - ~100MB for new PDF
3. Load existing document - ~300MB for existing PDF
4. Append pages via PDFKit - ~400MB for combined
5. Get dataRepresentation() - ~400MB (same data)
6. Write to ZIP - ~400MB (writing from existing data)
Peak: ~400MB (same as any format when PDFKit serializes)
```

**Search Indexer** (scanning 100 documents):
```
For each document:
1. Read metadata - ~10KB
2. Extract OCR JSON path, read that - ~50KB
3. Index - ~60KB per document
4. No PDF loaded unless specifically needed
Total: ~6MB for 100 documents (vs ~40GB if loading all PDFs)
```

---

## OCR Service Considerations

### Current OCR Service Architecture
```swift
// YianaOCRService watches documents folder
// On file change:
1. Read document
2. Check metadata.ocrCompleted
3. If false:
   - Extract PDF
   - Process with Vision framework
   - Write OCR JSON to .ocr_results/
   - Update metadata.ocrCompleted = true
```

### Changes Needed for ZIP Format

**Before** (Custom format):
```swift
let data = try Data(contentsOf: documentURL)
let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])
if let separatorRange = data.range(of: separator) {
    let metadataData = data[..<separatorRange.lowerBound]
    let pdfData = data[separatorRange.upperBound...]
    // Process...
}
```

**After** (ZIP format):
```swift
// Much better memory profile!
let metadata = try DocumentArchive.readMetadata(from: documentURL)

if !metadata.ocrCompleted {
    let tempPDF = FileManager.default.temporaryDirectory
        .appendingPathComponent("ocr-temp.pdf")

    try DocumentArchive.extractPDF(from: documentURL, to: tempPDF)

    // Process from file handle, not memory
    let pdfDocument = PDFDocument(url: tempPDF)!
    // Vision framework processes pages one at a time

    try? FileManager.default.removeItem(at: tempPDF)
}
```

**Benefits**:
- Can check `ocrCompleted` without loading PDF
- Only extracts PDF if needed
- Can stream PDF to temp file instead of loading to memory
- Vision framework can then process page-by-page from file

---

## Comparison Summary

| Aspect | Current Format | ZIP + ZipFoundation | ZIP + AppleArchive |
|--------|---------------|---------------------|-------------------|
| **Read metadata only** | Good (seek to separator) | Excellent (extract single entry) | Excellent (stream single entry) |
| **Read full document** | ~400MB peak | ~400MB peak | ~400MB peak |
| **Write document** | ~400MB peak | ~400MB peak | ~400MB peak |
| **OCR service** | Loads full file | Streams to temp file | Streams to temp file |
| **Search indexer** | Loads full file | Reads metadata only | Reads metadata only |
| **Complexity** | Simple | Medium | High |
| **User recovery** | ❌ Requires app | ✅ Rename to .zip | ✅ Rename to .zip |
| **iOS version** | Any | iOS 13+ | iOS 15+ |

---

## Recommendations

### For Implementation: Use **ZipFoundation**

**Why**:
1. ✅ Simple, clean API
2. ✅ Excellent streaming for reads (OCR, search)
3. ✅ Acceptable write performance (same memory pressure as any solution)
4. ✅ Well-tested, production-ready
5. ✅ Works on iOS 13+ (broader compatibility)
6. ✅ Pure Swift, no C concerns

**Install**:
```swift
// Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/weichsel/ZipFoundation.git", .upToNextMajor(from: "0.9.0"))
]
```

### Memory Optimization Strategy

**Accept**: Save operations will always have ~400MB peak when serializing large PDFs (PDFKit requirement)

**Optimize**:
1. ✅ OCR service: Extract PDF to temp file, process from disk
2. ✅ Search indexer: Read metadata only, never load PDF
3. ✅ Document list: Read metadata only for display
4. ⚠️ Consider background processing for large saves

**If memory becomes critical**:
- Could implement page-at-a-time processing for very large documents
- Would require custom PDF assembly without PDFKit's `dataRepresentation()`
- Significant complexity increase
- Defer until proven necessary

---

## Open Questions for Discussion

1. **iOS deployment target**: Do we support iOS 13+? (Allows ZipFoundation)
2. **OCR artifacts**: Should these go inside the ZIP or stay in `.ocr_results/`?
   - Inside: Easier backup/sharing
   - Outside: Smaller archives, faster writes
3. **Compression level**: ZIP can use different compression levels
   - PDFs are already compressed - ZIP adds ~0-5% savings
   - Could disable compression for faster writes?
4. **File naming**: `content.pdf` or `document.pdf`?
5. **Version marker**: Include `yiana.json` with `{"formatVersion": 1}` for future-proofing?

---

## Next Steps

1. Confirm ZipFoundation as choice
2. Answer open questions above
3. Create prototype `DocumentArchive.swift`
4. Update `NoteDocument` to use new archive format
5. Update OCR service to read from ZIP
6. Update search indexer to read from ZIP
7. Test memory profile with large documents
8. Remove old separator-based code

**Timeline estimate**: 2-3 days (no migration complexity!)
