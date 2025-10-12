# ZIP Format Refactor – Detailed Execution Plan
**Date:** 2025-10-10  
**Branch:** `refactor/zip`  
**Context:** All legacy tests now cover the current separator format. Next step is swapping in a real ZIP container without touching runtime code yet.

---

## 0. Pre-flight Checklist
- ✅ Tests capturing legacy behaviour (`NoteDocumentTests`, `ExportServiceTests`, OCR `YianaDocumentTests`) are green.
- ⏳ Additional suites (ImportService, OCRSearch, ViewModels) running in parallel—fold in results before Phase 2.
- ✅ Code audit (`comments/2025-10-10-zip-refactor-audit.md`) enumerates every touchpoint.

---

## 1. Dependencies & Shared Helper
### 1.1 Add ZipFoundation via SwiftPM
- App target: add package `https://github.com/weichsel/ZIPFoundation.git` (latest 0.9.x).
- OCR service package: add same dependency to `Package.swift`.
- Update Xcode project + `Package.resolved` (if committed) after verifying build.

### 1.2 Introduce `DocumentArchive`
- Location: `Yiana/Yiana/Services/Storage/DocumentArchive.swift` (new folder so both app+tests can import).
- Public surface (initial draft):
  ```swift
  struct DocumentArchive {
      struct Payload {
          var metadata: DocumentMetadata
          var pdfData: Data?
      }

      static func read(from url: URL) throws -> Payload
      static func readMetadata(from url: URL) throws -> DocumentMetadata
      static func extractPDF(from url: URL, to destination: URL) throws
      static func write(metadata: DocumentMetadata,
                        pdfData: ArchiveDataSource,
                        to destination: URL) throws
  }

  enum ArchiveDataSource {
      case data(Data)
      case file(URL)
      case stream(() throws -> Data?) // nil => end
  }
  ```
- Internals:
  - Use `Archive(url:accessMode:)` with `.read` / `.create`.
  - `write` should create archive in temp file (`destination.appendingPathExtension(".tmp")`), then replace original using `FileManager.replaceItem`.
  - Entries: `metadata.json` (UTF-8, no compression) and `content.pdf` (if available, also `.none` compression).
  - Add optional `format.json` or `.yiana_version` in later iteration; not needed Day 1.
  - Throw typed errors (`enum DocumentArchiveError: Error`).

### 1.3 Test Harness for Helper
- Create `DocumentArchiveTests.swift` under `YianaTests` mirroring baseline expectations (read/write round-trip, metadata only, PDF extraction streaming).
- Use same legacy fixtures to prove behaviour before migrating consumers.

---

## 2. Phase-by-Phase Refactor
### Phase 2 – Core Model (`NoteDocument`)
1. Update iOS `NoteDocument.contents(forType:)` and `load(fromContents:)` to delegate to `DocumentArchive`.
2. Update macOS `NoteDocument.data(ofType:)` / `read(from:ofType:)` similarly.
3. Replace `extractMetadata(from:)` to call `DocumentArchive.readMetadata`.
4. Adjust `NoteDocumentTests` & roundtrip tests to consume new helper; swap expectations from separator to ZIP entry checks.
5. Update `TestDataHelper` + any fixtures to use helper for writing sample docs.
6. Run:
   - `NoteDocumentTests`
   - `NoteDocumentRoundtripTests`
   - `DocumentViewModelTests` (sanity check)
   - New `DocumentArchiveTests`

### Phase 3 – Services
1. **ImportService**
   - New docs: call `DocumentArchive.write(metadata:pdfData:to:)`.
   - Append flow: use `DocumentArchive.read` to get payload, merge via PDFKit, then re-write.
2. **ExportService**
   - `exportToPDF`: `DocumentArchive.read(from:)` or `extractPDF` to temp file.
3. **OCR YianaDocument**
   - Mirror `DocumentArchive` functionality (option 1: expose helper in shared cross-platform module; option 2: local `DocumentArchive+OCR` shim to avoid cross-target import). Prefer sharing to keep format consistent.
4. Update corresponding tests (`ImportServiceTests`, new/updated `ExportServiceTests`, `YianaDocumentTests`).
5. Manual spot-check: import external PDF, export to PDF, ensure files rename to `.zip` and unzip as expected.

### Phase 4 – ViewModels & Views
1. `DocumentListViewModel.extractPDFData`: reuse helper to pull `content.pdf`.
2. macOS `DocumentListView.createDocument` (quick-create path) -> call helper to write empty archive.
3. `DocumentReadView.extractDocumentData`: parse via helper.
4. Any other direct separator usage from audit doc (e.g., `DocumentManagementView` paths).
5. Tests: `DocumentListViewModelTests`, `OCRSearchTests`, plus manual UI spot-check.

### Phase 5 – Integration & Clean-up
1. Update debug scripts/utilities referencing separator.
2. Update docs (`DataStructures.md`, `README`, developer guides) to new format.
3. Full test matrix:
   - `xcodebuild test -scheme Yiana`
   - `swift test` in OCR service
   - Regression manual scenarios (scan, append, duplicate, share, OCR pipeline).
4. Capture new baseline in `test-results/`.
5. Remove `separator` constants; ensure no stale references remain (run `rg "0xFF, 0xFF"`).

---

## 3. Testing/Verification Strategy
| Milestone | Tests to Run | Output Destination |
|-----------|--------------|--------------------|
| After Phase 2 | NoteDocument*, DocumentArchiveTests, DocumentViewModel | `test-results/phase-2.md` |
| After Phase 3 | + ImportServiceTests, ExportServiceTests, OCR `YianaDocumentTests` | `test-results/phase-3.md` |
| After Phase 4 | + DocumentListViewModelTests, OCRSearchTests, UI sanity run (manual notes) | `test-results/phase-4.md` |
| Final | Full suite + manual exploratory log | `test-results/final.md` |

Add short note in `test-status.md` after each phase (status, date/time, any failures).

---

## 4. Contingency & Rollback
- Work exclusively on `refactor/zip`; keep separator-based code in main as fallback.
- If a phase breaks critical paths:
  - Re-run previous baseline to confirm issue is new.
  - Revert only the phase-specific files (Helper + consumer) using git.
- Keep old helper path until final stage to compare outputs if needed (e.g., create debug command that writes both formats to ensure parity).

---

## 5. Outstanding Decisions (to confirm before coding)
1. **ZIP entry names**: default to `content.pdf` / `metadata.json` unless we want title-based naming.
2. **Compression**: use `.none` for both entries for now (faster saves, simpler code).
3. **Helper sharing**: decide whether to expose `DocumentArchive` in a shared module for OCR service (probably via `@testable import` or factoring into a tiny Swift package).
4. **Format version marker**: optional for v1; can defer unless we want guard for future migrations.

Once these decisions are green-lit, we can start Phase 1 without touching existing logic.
