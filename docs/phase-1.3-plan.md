# Phase 1.3: Wire Extraction + Lookup Into Yiana

## Context

Phase 1.2 is complete — `ExtractionCascade` and `NHSLookupService` exist in the
`YianaExtraction` package, which the app already imports. 88 tests pass. The app
currently relies on the Python extraction service running on Devon to write
`.addresses/{documentId}.json` files to iCloud, which `AddressRepository` reads.

This phase wires the Swift extraction directly into the document pipeline so
addresses appear immediately after on-device OCR, without Mac mini involvement.

## Problem: No Per-Page OCR Data

`OnDeviceOCRService.recognizeText(in:)` returns `OnDeviceOCRResult` which only
has `fullText` (all pages joined with `\n\n`). The per-page text is computed
internally but thrown away. `ExtractionCascade` needs per-page `ExtractionInput`
objects — one per page with individual text and confidence.

This is the primary prerequisite before anything else can work.

## Approach

Three sessions, each independently committable:

1. **OCR per-page data** — extend `OnDeviceOCRResult` to carry per-page text
2. **Extraction service** — new `DocumentExtractionService` that runs extraction
   + NHS lookup after OCR, writes to `.addresses/`
3. **Integration + verification** — wire into all OCR trigger points, test
   end-to-end, `/check`

## Non-Goals

- No changes to `AddressRepository` read path (it already reads the JSON format
  we'll write)
- No changes to `AddressesView` (it already displays `NHSCandidate` data)
- No removal of Python extraction on Devon (that's Phase 1.5)
- No new UI — addresses just appear in the existing view after OCR

---

## Session 1: Per-Page OCR Data

### 1a. Add per-page data to OnDeviceOCRResult

**File:** `Yiana/Yiana/Services/OnDeviceOCRService.swift`

Add a per-page struct and array to the existing result type:

```swift
struct OnDeviceOCRResult {
    struct PageResult {
        let pageNumber: Int   // 1-based
        let text: String
        let confidence: Double
    }

    let fullText: String
    let confidence: Double
    let pageCount: Int
    let pages: [PageResult]   // NEW

    static let empty = OnDeviceOCRResult(
        fullText: "", confidence: 0, pageCount: 0, pages: []
    )
}
```

Modify `recognizeText(in:)` to build `pages` alongside the existing `pageTexts`
array. `fullText` and `confidence` continue to be computed the same way — this is
a backwards-compatible addition. All existing callers that read `fullText` or
`confidence` are unaffected.

The `pageTexts` local variable already collects per-page text but discards page
numbers. Change the loop to also record `(pageNumber, text, confidence)`.
Page numbers are 1-based (matching our convention).

### 1b. Verify existing OCR tests still pass

The existing `OnDeviceOCRServiceTests` (4 tests) must still pass. They only
read `fullText`, `confidence`, and `pageCount`, so they should be unaffected.

### 1c. Commit

Commit: "Add per-page text to OnDeviceOCRResult for extraction pipeline"

---

## Session 2: DocumentExtractionService

### 2a. Bundle nhs_lookup.db in the app

**File:** `Yiana/Yiana.xcodeproj` (via Xcode project)

Add `AddressExtractor/nhs_lookup.db` to the Yiana app target as a bundle
resource. Both iOS and macOS targets need it. Size is 2.1MB — acceptable for a
bundled resource.

Verify with: `Bundle.main.url(forResource: "nhs_lookup", withExtension: "db")`

### 2b. Create DocumentExtractionService

**File:** `Yiana/Yiana/Services/DocumentExtractionService.swift`

A service that takes OCR results and runs extraction + NHS lookup, then writes
the result to `.addresses/`. This is the bridge between the OCR pipeline and the
extraction package.

```swift
import Foundation
import os
import YianaExtraction

/// Runs address extraction and NHS lookup after OCR completes,
/// writing results to .addresses/ in iCloud.
final class DocumentExtractionService {
    static let shared = DocumentExtractionService()

    private let logger = Logger(
        subsystem: "com.vitygas.Yiana",
        category: "DocumentExtraction"
    )
    private let cascade = ExtractionCascade()
    private let lookupService: NHSLookupService?

    private init() {
        // Load NHS lookup DB from app bundle
        if let dbURL = Bundle.main.url(
            forResource: "nhs_lookup", withExtension: "db"
        ) {
            lookupService = try? NHSLookupService(databasePath: dbURL.path)
        } else {
            logger.warning("nhs_lookup.db not found in bundle — NHS lookup disabled")
            lookupService = nil
        }
    }

    /// Run extraction on OCR results and write to .addresses/
    /// Preserves existing overrides and enriched data.
    func extractAndSave(
        documentId: String,
        ocrResult: OnDeviceOCRResult
    ) async {
        // 1. Build ExtractionInput from per-page OCR data
        // 2. Run ExtractionCascade.extractDocument()
        // 3. Enrich GP entries with NHSLookupService
        // 4. Read-merge-write to preserve overrides/enriched data
        // 5. Atomic write to .addresses/{documentId}.json
    }
}
```

**Algorithm detail:**

**Step 1 — Build inputs:**
```swift
let inputs = ocrResult.pages.map { page in
    ExtractionInput(
        documentId: documentId,
        pageNumber: page.pageNumber,
        text: page.text,
        confidence: page.confidence
    )
}
```

**Step 2 — Run extraction:**
```swift
let extracted = cascade.extractDocument(
    documentId: documentId, pages: inputs
)
```

**Step 3 — NHS lookup enrichment:**

For each page that has a GP postcode, call `lookupService.lookupGP()` and
attach the candidates to the page's `gp.nhsCandidates`. Use GP name and
address as hints where available.

```swift
for i in extracted.pages.indices {
    guard let postcode = extracted.pages[i].gp?.postcode ??
                         extracted.pages[i].address?.postcode,
          let service = lookupService else { continue }

    let candidates = try? service.lookupGP(
        postcode: postcode,
        nameHint: extracted.pages[i].gp?.practice,
        addressHint: extracted.pages[i].gp?.address
    )
    if let candidates, !candidates.isEmpty {
        extracted.pages[i].gp?.nhsCandidates = candidates
    }
}
```

**Step 4 — Read-merge-write:**

If an `.addresses/{documentId}.json` already exists (written by Python, or from
a previous extraction run), read it and preserve:
- `overrides` array (user edits — owned by the app)
- `enriched` dict (backend DB enrichment — owned by Devon)

Replace `pages` with the new extraction output. This ensures user overrides
survive re-extraction.

```swift
if let existingFile = try? readExistingFile(documentId: documentId) {
    extracted.overrides = existingFile.overrides
    extracted.enriched = existingFile.enriched
}
```

**Step 5 — Atomic write:**

Use the same temp-file + rename pattern as `AddressRepository.atomicWrite()`.
Write to the iCloud `.addresses/` directory. The existing `AddressRepository`
will pick up the new file on next read (or via iCloud notification).

### 2c. Error handling

All failures are logged but never thrown — extraction is best-effort. A failed
extraction should not prevent the document from saving or OCR from completing.
The service wraps the entire `extractAndSave` body in a do/catch and logs errors.

### 2d. Commit

Commit: "Add DocumentExtractionService — extraction + NHS lookup after OCR"

---

## Session 3: Wire Into OCR Pipeline + Verify

### 3a. Hook into iOS DocumentViewModel OCR

**File:** `Yiana/Yiana/ViewModels/DocumentViewModel.swift` (iOS section, ~line 72)

After `applyOCRResult(result)` and before `save()`, add:

```swift
self.applyOCRResult(result)
await DocumentExtractionService.shared.extractAndSave(
    documentId: self.document.metadata.id.uuidString,
    ocrResult: result
)
_ = await self.save()
```

The extraction runs off the main thread (the OCR Task is already async).
`extractAndSave` writes directly to iCloud; `AddressRepository` reads from
there. No additional plumbing needed.

### 3b. Hook into macOS DocumentViewModel OCR

**File:** `Yiana/Yiana/ViewModels/DocumentViewModel.swift` (macOS section, ~line 809)

Same pattern — add `extractAndSave` call after `applyOCRResult`.

### 3c. Hook into ContentView import OCR

**File:** `Yiana/Yiana/ContentView.swift` (~line 292)

The `performOCROnImportedDocument` method runs OCR on import without going
through `DocumentViewModel`. It constructs metadata directly. Add extraction
after OCR completes:

```swift
let ocrResult = await OnDeviceOCRService.shared.recognizeText(in: pdfData)
guard !ocrResult.fullText.isEmpty else { return }

// Run extraction (fire-and-forget, don't block import)
Task.detached {
    await DocumentExtractionService.shared.extractAndSave(
        documentId: metadata.id.uuidString,
        ocrResult: ocrResult
    )
}
```

### 3d. Verify document ID consistency

Confirm the document ID used in `.addresses/` filenames matches what
`AddressRepository.addresses(forDocument:)` expects. Currently the Python
service uses the document filename stem (e.g. `Surname_Firstname_DDMMYY`),
while the app metadata uses a UUID. Check which format `AddressRepository`
passes to `addresses(forDocument:)`.

**This is a potential mismatch** — if the repository passes UUID strings but
the Python service writes filename-based IDs, we need to decide which convention
the Swift extraction uses. The right answer is probably to match whatever format
`AddressRepository` callers pass in, which needs investigation at implementation
time.

### 3e. Build and test

`/check` — both iOS and macOS must build clean.

Manual test if possible: scan a document on device, verify addresses appear in
AddressesView without Devon running.

### 3f. Commit

Commit: "Wire extraction into OCR pipeline — addresses appear after scan"

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Extend OCR result vs new method | Extend | Backwards-compatible; avoids a second OCR pass |
| Singleton service | Yes | Matches `OnDeviceOCRService` pattern; one GRDB connection |
| Fire-and-forget extraction | Yes | Extraction must not block document save or UI |
| Preserve overrides on re-extract | Yes | User edits must survive; three-tier resolution unchanged |
| Bundle DB in app | Yes | 2.1MB is acceptable; avoids network dependency |
| Log errors, never throw | Yes | Extraction is enrichment, not critical path |

## Risk: Document ID Format Mismatch

The Python extraction service uses filename-based IDs (e.g. `Jones_Clara_080749`)
as the JSON filename in `.addresses/`. The app's `DocumentMetadata.id` is a UUID.
`AddressRepository.addresses(forDocument:)` takes a `String` parameter — need to
verify what callers pass.

**If they pass UUID strings:** Swift extraction writes UUID-named files, Python
files remain filename-named. Both coexist in `.addresses/` — no conflict, but the
app only sees one or the other per document depending on which ID is used.

**If they pass filename stems:** Swift extraction must derive the filename stem
from the document URL, matching the Python convention.

This must be resolved in Session 3 before the first line of wiring code.

## Files Modified / Created

| File | Action |
|------|--------|
| `Yiana/Yiana/Services/OnDeviceOCRService.swift` | Add per-page data to result |
| `Yiana/Yiana/Services/DocumentExtractionService.swift` | New — extraction + NHS lookup bridge |
| `Yiana/Yiana/ViewModels/DocumentViewModel.swift` | Hook extraction after OCR (both platforms) |
| `Yiana/Yiana/ContentView.swift` | Hook extraction after import OCR |
| `Yiana/Yiana.xcodeproj` | Add nhs_lookup.db as bundle resource |
| `docs/consolidation-plan.md` | Tick 1.3 checkboxes |
| `HANDOFF.md` | Update |

## Definition of Done

- [ ] `OnDeviceOCRResult` carries per-page text and confidence
- [ ] `nhs_lookup.db` bundled in app (both iOS and macOS targets)
- [ ] `DocumentExtractionService` extracts addresses after OCR
- [ ] NHS lookup enriches GP entries with ODS candidates
- [ ] Existing overrides and enriched data preserved on re-extraction
- [ ] All three OCR trigger points call extraction (iOS VM, macOS VM, ContentView import)
- [ ] Atomic writes to `.addresses/` directory
- [ ] Document ID format matches `AddressRepository` expectations
- [ ] Extraction failures logged, never thrown — don't block document save
- [ ] `/check` passes (both iOS and macOS)
- [ ] Existing OCR tests still pass

## Verification

1. `/check` — both platforms build clean
2. `cd YianaExtraction && swift test` — 88 existing tests still pass
3. Manual: scan document on device → addresses appear in AddressesView
