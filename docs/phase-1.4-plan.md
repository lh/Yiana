# Phase 1.4: Parallel Validation

## Context

Phase 1.3 is complete — the Swift extraction pipeline runs in-app after OCR.
Manual testing confirmed it works end-to-end on a real document. Now we need to
validate at scale: run Swift extraction on the same OCR data that Python already
processed, and compare outputs field-by-field.

## Data Landscape

**On Devon** (`iCloud~com~vitygas~Yiana/Documents/`):

| Directory | Count | Notes |
|-----------|-------|-------|
| `.ocr_results/PP/Clinical/*.json` | 2,828 | Server OCR output (camelCase JSON) |
| `.addresses/*.json` | 1,442 | Python extraction output (snake_case JSON) |
| Both OCR + addresses | 1,440 | Comparison corpus |
| OCR only (no addresses) | 1,388 | Python didn't extract (empty pages, no data) |
| Addresses with overrides | 21 | User-edited — compare carefully |
| Addresses with enriched | 1,425 | Backend DB enrichment — out of scope |

**OCR JSON structure** (what Python reads, what Swift will read):
```json
{
  "documentId": "Surname_Firstname_DDMMYY",
  "pages": [
    {
      "pageNumber": 1,
      "text": "...",
      "confidence": 0.95,
      "textBlocks": [...]
    }
  ]
}
```

This is the same format our test fixtures use — `ExtractionInput` maps directly
from `pages[].pageNumber`, `pages[].text`, `pages[].confidence`.

**Python extraction methods → Swift equivalents:**

| Python method | Count | Swift extractor | Swift method name |
|---------------|-------|-----------------|-------------------|
| `label` | 3,449 | `LabelExtractor` | `"label"` |
| `spire_form` | 962 | `RegistrationFormExtractor` | `"clearwater_form"` |
| `form` | 101 | `FormExtractor` | `"form"` |
| `clearwater_form` | 2 | `RegistrationFormExtractor` | `"clearwater_form"` |
| `unstructured` | 5 | `FallbackExtractor` | `"unstructured"` |

Note: Python's `spire_form` and `clearwater_form` both map to Swift's
`clearwater_form`. This is an expected method name difference — the extractors
handle the same document types.

## Approach

Build a Python comparison script that runs on Devon. It reads each OCR file,
shells out to a Swift CLI tool to run extraction, then compares the Swift output
against the existing Python `.addresses/` file.

**Why Python for the harness?** The comparison logic (field-by-field diff,
aggregation, reporting) is easier in Python. The actual extraction runs in Swift
via a small CLI wrapper around `ExtractionCascade` + `NHSLookupService`.

**Two deliverables:**

1. **Swift CLI tool** — `YianaExtraction` package gains an executable target
   that reads OCR JSON from stdin, runs extraction + NHS lookup, writes
   `DocumentAddressFile` JSON to stdout.
2. **Python comparison script** — iterates the 1,440-document corpus, runs the
   CLI tool, compares output field-by-field, writes a summary report.

## Session 1: Swift CLI Tool

### 1a. Add executable target to YianaExtraction

**File:** `YianaExtraction/Package.swift`

Add a new executable product and target:

```swift
products: [
    .library(name: "YianaExtraction", targets: ["YianaExtraction"]),
    .executable(name: "yiana-extract", targets: ["YianaExtractCLI"]),
],
```

```swift
.executableTarget(
    name: "YianaExtractCLI",
    dependencies: ["YianaExtraction"],
    path: "Sources/YianaExtractCLI"
),
```

### 1b. Implement the CLI tool

**File:** `YianaExtraction/Sources/YianaExtractCLI/main.swift`

Simple pipeline:
1. Read OCR JSON from stdin (same format as `.ocr_results/` files)
2. Parse into `[ExtractionInput]`
3. Run `ExtractionCascade.extractDocument()`
4. Run `NHSLookupService.lookupGP()` for each page with a GP postcode
5. Encode `DocumentAddressFile` as JSON to stdout

```
Usage: cat ocr_result.json | yiana-extract --db-path /path/to/nhs_lookup.db
       yiana-extract --db-path /path/to/nhs_lookup.db < ocr_result.json
```

The `--db-path` argument points to `nhs_lookup.db` on Devon (same DB the Python
service uses). No need to bundle it — it's already on disk.

Error handling: if extraction produces no pages, output a valid but empty
`DocumentAddressFile` (matching Python's behavior for empty documents).

### 1c. Build on Devon

```bash
ssh devon@Devon-6
cd /path/to/Yiana/YianaExtraction
swift build -c release
# Binary at .build/release/yiana-extract
```

### 1d. Smoke test

```bash
cat .ocr_results/PP/Clinical/SomeDocument.json | \
  .build/release/yiana-extract --db-path /path/to/nhs_lookup.db | \
  python3 -m json.tool
```

Verify output looks reasonable.

### 1e. Commit

Commit: "Add yiana-extract CLI for parallel validation (Phase 1.4)"

---

## Session 2: Comparison Script

### 2a. Build the comparison script

**File:** `migration/compare_extraction.py`

```
Usage: python3 compare_extraction.py \
  --ocr-dir .ocr_results/PP/Clinical/ \
  --addr-dir .addresses/ \
  --swift-bin .build/release/yiana-extract \
  --db-path /path/to/nhs_lookup.db \
  --report-dir migration/validation_report/
```

**Per-document comparison:**

For each document that has both OCR and addresses files:

1. Run `yiana-extract` on the OCR file → Swift output
2. Load existing Python `.addresses/` file → Python output
3. Compare page-by-page, field-by-field:

**Fields to compare (per page):**

| Field | Comparison | Notes |
|-------|-----------|-------|
| `patient.full_name` | Exact (case-insensitive, whitespace-normalised) | Core field |
| `patient.date_of_birth` | Exact | Core field |
| `patient.phones.*` | Set equality | Order doesn't matter |
| `patient.mrn` | Exact | May be absent |
| `address.postcode` | Exact (normalised) | Core field |
| `address.line1` | Fuzzy (lowercase contains) | Known gap in Swift |
| `address.city` | Fuzzy | Known gap in Swift |
| `gp.name` | Fuzzy (case-insensitive) | |
| `gp.practice` | Fuzzy | |
| `gp.postcode` | Exact (normalised) | |
| `extraction.method` | Map Python→Swift names, then compare | `spire_form` → `clearwater_form` |
| `nhs_candidates` | Compare ODS codes (set equality) | |

**Outcome categories per page:**

- **match** — all core fields agree
- **swift_better** — Swift has data Python missed (e.g. found a name Python didn't)
- **python_better** — Python has data Swift missed
- **different** — both have data but it disagrees
- **both_empty** — neither extracted anything

**Page count mismatch handling:**

Python and Swift may extract different numbers of pages (Swift might extract a
page Python skipped, or vice versa). Match pages by `page_number`, not by array
index. Pages present in one but not the other count as `swift_better` or
`python_better`.

### 2b. Comparison approach for method names

Python's `spire_form` maps to Swift's `clearwater_form`. Create a normalisation
map:

```python
METHOD_MAP = {
    "spire_form": "clearwater_form",
    "clearwater_form": "clearwater_form",
    "form": "form",
    "label": "label",
    "unstructured": "unstructured",
}
```

Method disagreement is informational, not a failure — the cascade order differs
slightly between Python and Swift. What matters is whether the extracted data
is correct, not which extractor found it.

### 2c. Skip overrides and enriched data

The comparison should only look at `pages` — ignore `overrides` (user edits)
and `enriched` (backend DB). These are not produced by extraction.

### 2d. Report output

**Summary report** (`migration/validation_report/summary.txt`):

```
Total documents: 1440
  match: 850 (59%)
  swift_better: 200 (14%)
  python_better: 150 (10%)
  different: 180 (13%)
  both_empty: 60 (4%)

Field-level breakdown:
  patient.full_name: 1200 agree, 120 swift_better, 80 python_better, 40 different
  patient.date_of_birth: ...
  address.postcode: ...
  ...
```

**Per-document details** (`migration/validation_report/differences.jsonl`):

One JSON object per line for every document where Swift != Python:

```json
{"document_id": "...", "page": 1, "field": "patient.full_name", "python": "JOHN SMITH", "swift": "John Smith", "category": "match"}
```

This allows post-hoc filtering and investigation.

**Top discrepancies** (`migration/validation_report/top_issues.txt`):

Group by discrepancy pattern (e.g. "Swift extracts name, Python doesn't"
or "Python form extractor finds postcode, Swift label extractor doesn't")
and rank by frequency. This tells us where to focus extractor improvements.

### 2e. Run on Devon

```bash
ssh devon@Devon-6
cd /path/to/Yiana
python3 migration/compare_extraction.py \
  --ocr-dir ".ocr_results/PP/Clinical/" \
  --addr-dir ".addresses/" \
  --swift-bin "YianaExtraction/.build/release/yiana-extract" \
  --db-path "AddressExtractor/nhs_lookup.db" \
  --report-dir "migration/validation_report/"
```

Estimated time: ~1,440 documents, each running a Swift process. If the CLI
takes ~100ms per document, total is ~2.5 minutes.

### 2f. Commit

Commit: "Add extraction comparison script and validation report (Phase 1.4)"

---

## Session 3: Review and Fix

### 3a. Triage the report

Review the summary and top issues. Categorise:

1. **Expected differences** — method name mapping (`spire_form` → `clearwater_form`),
   case differences, whitespace normalisation
2. **Swift wins** — Swift found data Python missed. Document these as improvements.
3. **Python wins** — Swift missed data Python found. These need investigation:
   - Is it an extractor gap? (e.g. a pattern Python handles but Swift doesn't)
   - Is it a cascade ordering issue?
   - Is it a regex difference?
4. **True disagreements** — both have data but it differs. These need case-by-case review.

### 3b. Fix critical gaps

If there are systematic patterns where Swift misses data Python finds (e.g.
"Swift never extracts address line1"), fix the extractor and re-run.

If the gaps are edge cases affecting <5% of documents, log them and move on.

### 3c. Update docs

- Tick Phase 1.4 checkboxes in `docs/consolidation-plan.md`
- Write summary of validation results
- Update `HANDOFF.md`

### 3d. Commit

Commit: "Complete Phase 1.4: validation results and extractor fixes"

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CLI tool vs in-process | CLI | Runs on Devon without Xcode; easy to pipe OCR JSON in |
| Python harness vs Swift | Python | Field-by-field comparison, aggregation, reporting easier |
| Run on Devon vs local | Devon | OCR data is there (2,828 files); no need to download |
| Compare pages not overrides | Yes | Overrides are user edits, not extraction output |
| Fuzzy vs exact comparison | Field-dependent | Names and addresses need normalisation; postcodes and ODS codes are exact |

## Files Created / Modified

| File | Action |
|------|--------|
| `YianaExtraction/Package.swift` | Add executable target |
| `YianaExtraction/Sources/YianaExtractCLI/main.swift` | New — CLI extraction tool |
| `migration/compare_extraction.py` | New — comparison script |
| `migration/validation_report/` | New — output directory |
| `docs/consolidation-plan.md` | Tick 1.4 checkboxes |
| `HANDOFF.md` | Update |

## Definition of Done

- [ ] `yiana-extract` CLI builds and runs on Devon
- [ ] Comparison script processes all 1,440 documents without crashing
- [ ] Summary report generated with per-field breakdown
- [ ] Differences file generated for post-hoc investigation
- [ ] Top issues identified and triaged
- [ ] Critical extractor gaps fixed (if any)
- [ ] `/check` passes (both iOS and macOS) after any extractor changes
- [ ] 88+ package tests still pass

## Verification

1. `swift build -c release` on Devon — CLI compiles
2. `python3 migration/compare_extraction.py` — runs to completion
3. Review `migration/validation_report/summary.txt`
4. If extractor changes made: `cd YianaExtraction && swift test` + `/check`
