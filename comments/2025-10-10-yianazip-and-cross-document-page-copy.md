# YianaZip Packaging & Cross-Document Page Copy – Discussion
**Date:** 2025-10-10  
**Authors:** Codex planning notes  
**Purpose:** Capture options and open questions before implementing changes

---

## 1. `.yianazip` Packaging Refresh

### 1.1 Desired Outcome
- A document saved as `*.yianazip` should really be a ZIP archive.
- Renaming to `*.zip` must expose a folder with `document.pdf` (or similar) and separate metadata, so users can recover files without the app.
- Preserve iCloud friendliness and atomic saves.

### 1.2 Current State (2025-10-10)
- Referenced prior notes in `comments/2025-10-09-format-and-copy-discussion.md`; this document folds in that thinking while removing the no-longer-needed migration plan.
- Format is a custom binary blob: `[JSON metadata][0xFF 0xFF 0xFF 0xFF][PDF bytes]`.
- Metadata updates and PDF writes are handled straight through `NoteDocument`, `ImportService`, and macOS bulk importer helpers.
- OCR watcher and search indexer assume they can stream the file from disk and split on the sentinel separator.
- Tests and fixtures (e.g., `DocumentViewModelTests`) expect the old format.

### 1.3 Scope Adjustment (No Legacy Data)
- App is still in development; we only need to support the new ZIP layout for newly-saved documents.
- Legacy migration helpers can be omitted entirely unless we want a diagnostic tool for old test fixtures.
- Importers/OCR watcher just need to understand the new structure from day one.

### 1.4 Packaging Layout
- `document.pdf` (primary content, original naming preserved if we want to mirror user title)
- `metadata.json` (UTF-8, prettified or compact—needs decision)
- Optional future directories (`attachments/`, `ocr/`, `thumbnails/`)
- Consider an optional `format.json` or `.yiana_version` file to future-proof changes even without legacy data.

### 1.5 Zip Engine Options & Memory/Performance Notes
| Option | Pros | Cons | Memory Notes |
| --- | --- | --- | --- |
| **Foundation Archive** (`import Foundation`, `Archive`) | Built-in, no dependency, streaming read/write supported | API is lower-level; lacks convenience functions for directories | Supports incremental writes via `Archive.addEntry`; we must manage buffering manually but avoids loading entire PDF in RAM |
| **Compression + AppleArchive** | Highly efficient, modern API, supports streaming | Requires iOS 15+/macOS 12+, more boilerplate, less common in examples | Designed for streaming; Apple recommends for large archives |
| **ZipFoundation (SPM)** | Mature (7+ years), high-level API, easier to use, streaming support | Introduces third-party dependency | `Archive` class in ZipFoundation streams entries; can write PDF by chunk to keep peak memory low |

Memory scenarios to sanity-check:
1. **Small scans (<=5 MB)** – any approach fine, but keep operations on a background queue to avoid UI hitching.
2. **Large merged PDFs (>100 MB)** – must stream: avoid `Data(contentsOf:)` for entire archive, prefer `InputStream`/`OutputStream` or ZipFoundation’s chunked APIs.
3. **OCR pipeline** – Mac watcher likely runs on desktop hardware, but should still stream to keep CLI memory bounded.

Implementation guardrails:
- Use temporary files + `FileManager.replaceItemAt` to stay atomic.
- Keep metadata JSON small; consider writing via `OutputStream` to avoid redundant copies.
- Ensure unzip path preserves file permissions (default ZIP entries should be fine).

### 1.6 Open Questions
- Naming inside archive: `document.pdf` vs `content.pdf`? Should metadata file name be fixed (`metadata.json`)?
- Do we include thumbnails or OCR artifacts now, or keep minimal set and add later?
- Is a format manifest worth adding even without legacy data, to keep future upgrades predictable?
- Do we need compression (reduce size) or should we store files uncompressed for faster loads?

### 1.7 Next-Step Proposal
1. Prototype archive helper that writes the new layout and reads it back, using preferred ZIP engine.
2. Update iOS/macOS/OCR code paths to rely on the helper (no legacy branching required).
3. Validate with manual unzip + Xcode previews; profile memory when saving a large test PDF.

### 1.8 Streaming Strategy Options (Deep Dive)
- **Foundation `Archive`**
  - Reading: use `archive.extract(entry, to: outputStream)` which streams entry data directly into a file/`OutputStream`.
  - Writing: create an `OutputStream` to a temp URL; call `archive.addEntry(with:relativePath:compressionMethod:uncompressedSize:provider:)` and feed chunks from an `InputStream`.
  - Recommended chunk size: 128 KB–512 KB to balance syscalls vs memory.
  - Caveat: API is verbose; need to manage CRC checksums when writing.
- **AppleArchive (`ArchiveStream` API)**
  - Provides high-level support for streaming with built-in checksums.
  - Can chain with `CompressionAlgorithm.lzfse` or `none`.
  - Requires iOS 15/macOS 12; aligns with modern deployment targets.
- **ZipFoundation**
  - `Archive` offers `read(into:)` and `write(from:)` that accept closures supplying buffers.
  - Handles CRC transparently, less boilerplate.
  - Supports `compressionMethod: .none` for speed, or `.deflate` for size savings.
  - Battle-tested in many shipping apps; easiest to integrate quickly.

**Common guardrails regardless of engine**
- Always write to a temporary archive (`<url>.tmp`) and replace via `FileManager.replaceItemAt`.
- Prefer background queues for heavy IO, then hop back to main for UI updates.
- When reading, stop extraction once both `metadata.json` and `document.pdf` are located; ignore unfamiliar files gracefully for forward compatibility.
- Add unit tests covering 1-page (~20 KB), 50-page (~5 MB), and synthetic large (~150 MB) PDFs to profile memory spikes using Instruments.

### 1.9 Staging Directory (“Zip after write”) Pattern
- Workflow: write `metadata.json` and `content.pdf` into a temporary directory, then zip that folder (e.g., via `FileManager.zipItem` or manual archive writer) before atomically replacing the destination.
- Pros:
  - Keeps ZIP assembly logic simple; easy to reason about and debug.
  - Works well when source assets already live on disk (e.g., importing an external PDF) since the staging step can be just a file copy.
- Cons and caveats:
  - `zipItem` deflates entries by default; if we want uncompressed storage we must drop to lower-level APIs or accept the extra CPU cost.
  - Doubles disk I/O for the PDF (write to staging file, then read it back during zipping), so large saves take longer and temporarily increase storage usage.
  - Only reduces memory if upstream code streams pages into the staging file—if we already hold `pdfData` in memory, the approach doesn’t eliminate that spike.
  - Requires careful cleanup with `defer` blocks so temp folders/zips aren’t left behind on errors.
- When to consider:
  - Importing existing PDFs or OCR outputs where the source is already on disk.
  - Early implementation phase if we want the most straightforward code path before investing in fully streamed archive writes.

---

## 2. Cross-Document Page Copy / Move

### 2.1 Use Cases
- Move a misfiled scan page into the correct document.
- Copy a set of pages from one document into another (e.g., shared appendix).
- Potential future: drag-and-drop between split views or context menus.

### 2.2 Current Capabilities
- We can duplicate/delete pages within one document (sidebar + page manager).
- No mechanism to export/import individual pages between documents.
- Markdown “provisional” pages complicate page identities; we now rebuild PDFs from `displayPDFData`.

### 2.3 Design Considerations
1. **Source Page Extraction**
   - Need helper to pull specific pages from a `PDFDocument` and return raw PDF data for those pages (preserving annotations, rotation).
   - Should leverage the same rebuild pipeline used for reordering to avoid `page.copy()` data loss.
2. **Destination Insertion**
   - Insert pages at arbitrary positions in target document (start, end, specific index).
   - Respect provisional pages—probably block insertion until drafts are resolved.
3. **UI Workflow Options**
   - **Clipboard-style:** Provide “Copy/Move to…” actions in sidebar/page manager; open picker to choose target document and position.
   - **Drag & drop:** Long-term goal for iPad split view? needs additional plumbing.
   - **Batch operations:** allow multi-select, choose target once, insert all sequentially.
4. **File Access**
   - Requires opening two `NoteDocument` instances simultaneously; confirm UIDocument concurrency handling.
   - macOS bulk importer/OCR service may also benefit from shared helper to avoid duplicated logic.
5. **Error Handling**
   - Conflicts if destination document is modified simultaneously via sync.
   - Need rollback behavior if insertion fails mid-way.

### 2.4 Open Questions
- Do we need a full-fledged picker UI or will an intermediate “staging area” (like clipboard) suffice?
- Should “move” delete pages from origin automatically, or require confirmation after copy succeeds?
- Preferred interaction surface: sidebar context menu, swipe-up page manager, or global action sheet?
- How do we surface progress/feedback on large multi-page moves (spinner, toast, blocking dialog)?

### 2.5 Suggested Approach Outline
1. Build shared `DocumentPageTransferService` (name TBD) that can:
   - Export selected page indices to a temporary PDF bundle.
   - Insert a provided PDF blob into target document at index.
2. Wire first UI surface (likely sidebar multi-select) to call the service in a “copy” mode.
3. Add optional “move” variant once copy flow is stable, ensuring undo/delete path is safe.
4. Extend later to support drag-and-drop or multi-document pasteboard integration.

---

## Next Steps for Discussion
- Confirm archive layout & migration preference.
- Agree on first UI for page transfer and the minimal viable workflow.
- Identify any platform-specific blockers (e.g., UIDocument limitations, macOS parity).
- Once aligned, we can schedule implementation tasks and associated QA/testing.
