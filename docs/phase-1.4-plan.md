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

**Python extraction methods -> Swift equivalents:**

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

**Deployment note:** Devon has Swift 5.10 but the package requires Swift 6.2.
The CLI binary is built locally in release mode and scp'd to Devon. Same
architecture (arm64-apple-darwin), compatible macOS versions.

## What Happened

### CLI Tool

Built `yiana-extract` as an executable target in `YianaExtraction/Package.swift`.
Reads OCR JSON from stdin, runs `ExtractionCascade` + `NHSLookupService`,
writes `DocumentAddressFile` to stdout. `--db-path` argument points to
`nhs_lookup.db` on Devon.

Smoke-tested locally with test fixtures, then deployed to Devon and verified
with real OCR data.

### Comparison Script

`migration/compare_extraction.py` iterates the corpus, spawns the CLI per
document, compares field-by-field. Per-document differences use anonymised
doc indices (no PII in output). Summary report is aggregate statistics only.

### Run 1: Baseline (no fixes)

1,440 documents, 4,500+ pages, zero errors.

| Field | Match | Swift-better | Python-better | Different |
|-------|-------|-------------|---------------|-----------|
| postcode | 97.6% | 0.1% | 0.4% | 1.9% |
| patient.name | 74.8% | 9.8% | 0.4% | 15.0% |
| city | 0% | 0% | 90.8% | 0% |
| gp.postcode | 0% | 0% | 8.5% | 0% |
| DOB | 22.2% | 11.1% | 7.6% | 1.3% |
| NHS candidates | 0.3% | 31.1% | 0% | 1.5% |

**Key findings:**
- Postcodes rock solid at 97.6% match
- Swift finds 441 patient names Python missed
- NHS lookup is a net-new capability (31.1% of pages enriched)
- Three systematic gaps: city (not extracted), GP postcode (not extracted),
  DOB hyphen/2-digit-year formats (not parsed)

### Fix 1: GP Postcode and Address (RegistrationFormExtractor)

**Problem:** Python's `spire_form` extractor parses up to 4 lines after the
Doctor line in the GP section — first line is practice name, subsequent lines
are address, and any standalone postcode line becomes `gp_postcode`. Swift only
took the first line (practice name) and stopped.

**Fix:** Extended the GP section parsing in `RegistrationFormExtractor` to
collect practice name + address lines + postcode, matching Python's approach.

**Result:** GP postcode went from 382 python_better to **0 python_better,
382 match, 76 swift_better**.

### Fix 2: DOB Hyphen and 2-Digit Year (ExtractionHelpers)

**Problem:** `extractDate` only handled `/` and `.` separators with 4-digit
years. Real documents use `15-06-1954` (hyphens) and `14/3/23` (2-digit years).

**Fix:** Added `-` to the separator character class. Added a second pattern for
2-digit years with a pivot at 30 (>=30 -> 19xx, <30 -> 20xx).

**Result:** DOB python_better dropped from 345 to 333 (12 recovered), and
swift_better rose from 503 to 542 (+39). Remaining 333 cases are unusual
formats — diminishing returns.

### Fix 3: City/Town Extraction (All Three Extractors)

**Problem:** No Swift extractor extracted city. Python had it via two approaches:
line-before-postcode in address blocks, and a "Town" label pattern in spire forms.

**Fix:**
- `LabelExtractor`: line before postcode in the sliding window is the city
  (if it doesn't start with a number and isn't a postcode itself)
- `RegistrationFormExtractor`: look for "Town\n..." label pattern
- `FormExtractor`: line before postcode in the address block

**Result:** City went from 0% match / 90.8% python_better to **62.6% match /
22.4% python_better / 0.8% swift_better**.

### Run 3: Final Results (all fixes)

| Field | Match | Swift-better | Python-better | Different |
|-------|-------|-------------|---------------|-----------|
| postcode | 97.6% | 0.1% | 0.4% | 1.9% |
| patient.name | 74.8% | 9.8% | 0.4% | 15.0% |
| **city** | **62.6%** | **0.8%** | **22.4%** | **5.8%** |
| **gp.postcode** | **8.5%** | **1.7%** | **0%** | **0%** |
| DOB | 22.2% | 12.0% | 7.4% | 1.6% |
| NHS candidates | 1.5% | 31.0% | 0% | 0.3% |
| MRN | 12.4% | 0% | 0% | 0% |
| phones | 10.4% | 0% | 0.1% | 9.9% |

**Document-level:** 35.2% match, 35.7% swift_better, 10.1% python_better,
19.0% different.

**Method confusion matrix:**
```
label -> label: 3088 (exact match)
clearwater_form -> clearwater_form: 962 (exact match)
label -> form: 340 (Swift uses FormExtractor where Python used label)
form -> label: 53
form -> form: 48
unstructured -> label: 5
label -> unstructured: 4
```

### Remaining Gaps (not fixed — diminishing returns)

- **city 22.4% python_better** — Python uses hardcoded county boundaries
  (`West Sussex`, `Surrey`, etc.) to delimit address blocks. More aggressive
  but fragile. Our line-before-postcode heuristic is simpler and more
  generalisable.
- **patient.name 15% different** — case and formatting disagreements, not
  missing data. Python often uppercases, Swift title-cases.
- **DOB 7.4% python_better** — unusual date formats we don't handle yet.
- **phones 9.9% different** — phone number normalisation differences, not
  missing data.
- **postcode 1.9% different** — 86 pages where both have a postcode but they
  disagree. Worth investigating but small.

### Future: Learning from Overrides

Manual address corrections (21 documents have overrides) represent ground truth
that could train the extractors. Plan logged in memory
`project_extraction_learning` — backend pipeline work, not app UI change.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CLI tool vs in-process | CLI | Runs on Devon without Xcode; easy to pipe OCR JSON in |
| Build locally, deploy binary | Yes | Devon has Swift 5.10, package needs 6.2 |
| Python harness vs Swift | Python | Field-by-field comparison, aggregation, reporting easier |
| Run on Devon vs local | Devon | OCR data is there (2,828 files); no need to download |
| Compare pages not overrides | Yes | Overrides are user edits, not extraction output |
| Fuzzy vs exact comparison | Field-dependent | Names and addresses need normalisation; postcodes and ODS codes are exact |
| Anonymised differences file | Yes | No PII in repo; doc indices not document names |

## Files Created / Modified

| File | Action |
|------|--------|
| `YianaExtraction/Package.swift` | Add executable target |
| `YianaExtraction/Sources/YianaExtractCLI/main.swift` | New — CLI extraction tool |
| `YianaExtraction/Sources/.../ExtractionHelpers.swift` | DOB: hyphen separator + 2-digit year |
| `YianaExtraction/Sources/.../RegistrationFormExtractor.swift` | GP postcode/address + city |
| `YianaExtraction/Sources/.../LabelExtractor.swift` | City extraction |
| `YianaExtraction/Sources/.../FormExtractor.swift` | City extraction |
| `migration/compare_extraction.py` | New — comparison script |
| `docs/consolidation-plan.md` | Tick 1.4 checkboxes |
| `HANDOFF.md` | Update |

## Definition of Done

- [x] `yiana-extract` CLI builds and runs on Devon
- [x] Comparison script processes all 1,440 documents without crashing
- [x] Summary report generated with per-field breakdown
- [x] Differences file generated for post-hoc investigation
- [x] Top issues identified and triaged
- [x] Critical extractor gaps fixed: GP postcode, city, DOB formats
- [x] `/check` passes (both iOS and macOS) after extractor changes
- [x] 88/88 package tests still pass

## Verification

1. `swift build -c release` locally — CLI compiles
2. `scp` binary to Devon — runs with real OCR data
3. `python3 migration/compare_extraction.py` — 1,440/1,440 documents, zero errors
4. Three comparison runs tracking improvement across fixes
5. `cd YianaExtraction && swift test` — 88/88 pass
6. `/check` — both iOS and macOS build clean
