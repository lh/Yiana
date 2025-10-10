# ZIP Format Refactor - Code Audit

**Date**: 2025-10-10
**Purpose**: Comprehensive audit of all code locations that need changes for ZIP format migration
**Decision**: Using ZipFoundation library

---

## Overview

This document catalogs every location in the codebase that currently uses the binary separator format `[JSON][0xFF 0xFF 0xFF 0xFF][PDF]` and needs to be refactored to use ZIP format with ZipFoundation.

**New format**: `content.pdf` + `metadata.json` in a real ZIP archive

---

## 1. Core Document Model (Critical Path)

### 1.1 NoteDocument.swift (iOS)
**Location**: `Yiana/Yiana/Models/NoteDocument.swift`

**Current implementation**:
- Line 53: Write - `contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`
- Line 65: Read - `let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`
- Line 92: Read metadata only - `let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`

**Methods to refactor**:
- `contents(forType:)` (lines 45-56) - Write operation
- `load(fromContents:ofType:)` (lines 58-81) - Read operation
- `extractMetadata(from:)` (lines 87-100) - Metadata-only read

**Changes needed**:
1. Replace write logic with ZipFoundation archive creation
2. Replace read logic with ZipFoundation archive extraction
3. Update metadata extraction to read from `metadata.json` in archive

**Priority**: P0 - Blocking all other changes

---

### 1.2 NoteDocument.swift (macOS)
**Location**: `Yiana/Yiana/Models/NoteDocument.swift` (same file, macOS section)

**Current implementation**:
- Line 166: Write - `contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`
- Line 174: Read - `let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`
- Line 206: Read metadata only - `let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`

**Methods to refactor**:
- `data(ofType:)` (lines 158-169) - Write operation (NSDocument)
- `read(from:ofType:)` (lines 171-190) - Read operation (NSDocument)
- `extractMetadata(from:)` (lines 201-214) - Metadata-only read

**Changes needed**:
Same as iOS section but for NSDocument API

**Priority**: P0 - Blocking all other changes

---

## 2. Import/Export Services

### 2.1 ImportService.swift
**Location**: `Yiana/Yiana/Services/ImportService.swift`

**Current implementation**:
- Line 30: Property - `private let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`
- Line 84: Write new document - `contents.append(separator)`
- Line 117: Read existing document - `guard let separatorRange = data.range(of: separator)`
- Line 158: Write merged document - `newContents.append(separator)`

**Methods to refactor**:
- `createNewDocument(from:title:)` (lines 52-110) - Creates new .yianazip
- `append(to:importedPDFData:)` (lines 112-184) - Reads existing, merges, writes

**Changes needed**:
1. Remove `separator` property
2. Update `createNewDocument` to create ZIP archive
3. Update `append` to:
   - Extract existing `metadata.json` and `content.pdf` from ZIP
   - Merge PDFs using PDFKit
   - Create new ZIP with updated metadata and merged PDF

**Priority**: P0 - Used for PDF imports and bulk import

---

### 2.2 ExportService.swift
**Location**: `Yiana/Yiana/Services/ExportService.swift`

**Current implementation**:
- Line 34: Property - `private let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`
- Line 42: Read - `guard let separatorRange = data.range(of: separator)`

**Methods to refactor**:
- `exportToPDF(from:to:)` (lines 36-64) - Extracts PDF from .yianazip
- `createTemporaryPDF(from:)` (lines 99-106) - Creates temp PDF for sharing

**Changes needed**:
1. Remove `separator` property
2. Update both methods to extract `content.pdf` from ZIP archive using ZipFoundation

**Priority**: P1 - Used for share/export functionality

---

## 3. ViewModels

### 3.1 DocumentListViewModel.swift
**Location**: `Yiana/Yiana/ViewModels/DocumentListViewModel.swift`

**Current implementation**:
- Line 395: Read PDF data - `let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`

**Methods to refactor**:
- `extractPDFData(from:)` (lines 386-405) - Extracts PDF for search functionality

**Changes needed**:
Update to extract `content.pdf` from ZIP archive

**Priority**: P1 - Used for search feature

---

## 4. Views

### 4.1 DocumentListView.swift (macOS)
**Location**: `Yiana/Yiana/Views/DocumentListView.swift`

**Current implementation**:
- Line 212: Create new document - `contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`

**Context**: Lines 209-216 - Quick document creation on macOS

**Changes needed**:
Replace inline document creation with call to DocumentArchive helper or ImportService

**Priority**: P1 - macOS document creation

---

### 4.2 DocumentReadView.swift
**Location**: `Yiana/Yiana/Views/DocumentReadView.swift`

**Current implementation**:
- Line 233: Read document - `let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`

**Methods to refactor**:
- `extractDocumentData(from:)` (lines 231-250) - Parses document for read-only view

**Changes needed**:
Update to read from ZIP archive

**Priority**: P2 - Read-only view feature

---

## 5. OCR Service (Separate Package)

### 5.1 YianaDocument.swift (OCR Service)
**Location**: `YianaOCRService/Sources/YianaOCRService/Models/YianaDocument.swift`

**Current implementation**:
- Line 27: Read - `let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`
- Line 67: Write with PDF - `documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`
- Line 84: Write after OCR - `documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`

**Methods to refactor**:
- `init(data:)` (lines 8-43) - Parse document
- `save(to:)` (lines 52-73) - Write document (two code paths)
- `exportData()` (lines 76-89) - Export as data

**Changes needed**:
1. Update parser to extract from ZIP
2. Update save to create ZIP
3. Note: Service also supports pure JSON format (line 18-24) - keep this for backward compatibility if needed

**Priority**: P0 - OCR service must read documents to process them

**Important**: OCR service is separate executable, needs ZipFoundation dependency added

---

## 6. Test Files

### 6.1 NoteDocumentTests.swift
**Location**: `Yiana/YianaTests/NoteDocumentTests.swift`

**Current implementation**:
- Line 137: Test helper - `contents.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`

**Changes needed**:
Update test helper to create proper ZIP format

**Priority**: P0 - Tests will fail without this

---

### 6.2 ImportServiceTests.swift
**Location**: `Yiana/YianaTests/ImportServiceTests.swift`

**Current implementation**:
- Line 5: Test helper - `private let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`
- Lines 24, 39, 61: Test setup and assertions using separator

**Changes needed**:
Rewrite tests to use ZIP format

**Priority**: P0 - Import tests validate critical functionality

---

### 6.3 OCRSearchTests.swift
**Location**: `Yiana/YianaTests/OCRSearchTests.swift`

**Current implementation**:
- Line 14: Test setup - `let sep = Data([0xFF, 0xFF, 0xFF, 0xFF])`

**Changes needed**:
Update test document creation to use ZIP

**Priority**: P1 - Search tests

---

### 6.4 YianaDocumentTests.swift (OCR Service)
**Location**: `YianaOCRService/Tests/YianaOCRServiceTests/YianaDocumentTests.swift`

**Current implementation**:
- Line 5: Test helper - `private let separator = Data([0xFF, 0xFF, 0xFF, 0xFF])`
- Line 13: Test - `raw.append(separator)`

**Changes needed**:
Update OCR service tests to use ZIP format

**Priority**: P0 - OCR service tests

---

## 7. Utilities and Test Helpers

### 7.1 TestDataHelper.swift
**Location**: `Yiana/Yiana/Utilities/TestDataHelper.swift`

**Current implementation**:
- Line 101: Create test doc - `documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`
- Line 150: Create test doc - `documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))`

**Methods to refactor**:
- `createTestDocumentWithOCR()` (starts line 78)
- `createTestDocumentWithoutOCR()` (starts line 127)

**Changes needed**:
Update both methods to create ZIP archives

**Priority**: P0 - Used by many tests

---

## 8. False Positives (No Changes Needed)

These files contain the word "separator" but are NOT related to document format:

### 8.1 String joining operations
- `YianaOCRService/Sources/YianaOCRService/Models/OCRResult.swift:23` - `joined(separator: "\n\n")`
- `YianaOCRService/Sources/YianaOCRService/Services/OCRProcessor.swift:125` - `joined(separator: "\n")`
- Multiple files use `joined(separator:)` for string operations

### 8.2 UI separator elements
- `Yiana/Yiana/Views/CommitButton.swift:106` - `Color(NSColor.separatorColor)`
- `Yiana/Yiana/Services/TextPagePDFRenderer.swift` - Drawing separator lines in PDF

### 8.3 File path operations
- Multiple files use `joined(separator: "/")` for path construction

**No changes needed** for these files.

---

## Summary Statistics

### Files requiring changes: 16

**By priority**:
- **P0 (Blocking)**: 8 files
  - NoteDocument.swift (iOS + macOS sections)
  - ImportService.swift
  - YianaDocument.swift (OCR service)
  - NoteDocumentTests.swift
  - ImportServiceTests.swift
  - YianaDocumentTests.swift (OCR)
  - TestDataHelper.swift

- **P1 (Important)**: 5 files
  - ExportService.swift
  - DocumentListViewModel.swift
  - DocumentListView.swift
  - OCRSearchTests.swift

- **P2 (Nice to have)**: 1 file
  - DocumentReadView.swift

**By category**:
- Core models: 2 locations (iOS + macOS in same file)
- Services: 3 files (Import, Export, OCR)
- ViewModels: 1 file
- Views: 2 files
- Tests: 5 files
- Utilities: 1 file

---

## Implementation Strategy

### Phase 1: Foundation (Days 1-2)
1. Add ZipFoundation dependency to main app
2. Add ZipFoundation dependency to OCR service package
3. Create `DocumentArchive.swift` helper with:
   - `write(metadata:pdfData:to:)` - Create ZIP
   - `read(from:)` - Extract both metadata and PDF
   - `readMetadata(from:)` - Extract metadata only
   - `extractPDF(from:to:)` - Stream PDF to file

### Phase 2: Core Model (Day 2)
4. Update `NoteDocument.swift` (iOS section)
5. Update `NoteDocument.swift` (macOS section)
6. Update basic test helpers (`TestDataHelper.swift`)
7. Run and fix `NoteDocumentTests.swift`

### Phase 3: Services (Day 3)
8. Update `ImportService.swift`
9. Update `ExportService.swift`
10. Update OCR service `YianaDocument.swift`
11. Run and fix service tests

### Phase 4: ViewModels and Views (Day 3-4)
12. Update `DocumentListViewModel.swift`
13. Update `DocumentListView.swift` (macOS)
14. Update `DocumentReadView.swift`
15. Run and fix remaining tests

### Phase 5: Testing (Day 4)
16. Run full test suite
17. Manual testing on iOS, iPad, macOS
18. Test OCR service integration
19. Test import/export flows

---

## Key Decisions Needed

1. **ZIP entry names**:
   - Proposal: `content.pdf` and `metadata.json`
   - Alternative: `document.pdf` and `metadata.json`

2. **Compression**:
   - PDFs are already compressed
   - Propose: `.none` compression for speed
   - Or: `.deflate` for consistency

3. **Version marker**:
   - Include `yiana.json` with `{"formatVersion": 1}` for future-proofing?
   - Or: Keep minimal (just metadata.json + content.pdf)?

4. **OCR results location**:
   - Keep in separate `.ocr_results/` directory (current)
   - Or: Include in ZIP? (adds complexity, breaks OCR service architecture)

---

## Risk Mitigation

### Critical risks:
1. **Data loss during transition**: Mitigated by atomic writes (temp file + move)
2. **OCR service breaks**: Test separately, deploy together
3. **iCloud sync issues**: Test with iCloud enabled
4. **Test failures cascade**: Fix P0 files first, then P1

### Testing checklist:
- [ ] Create new document (iOS)
- [ ] Create new document (macOS)
- [ ] Import PDF (iOS)
- [ ] Import PDF (macOS bulk)
- [ ] Scan and append
- [ ] Export/share
- [ ] Search with OCR
- [ ] OCR processing
- [ ] Duplicate document
- [ ] All tests pass

---

## Notes

- No legacy migration needed (app still in development)
- All changes are breaking - must deploy atomically
- OCR service is separate package - needs coordinated update
- Tests are comprehensive - they'll catch issues quickly
