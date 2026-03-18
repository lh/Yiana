# Phase 1.1: Extraction Service Swift Package

## Goal

Create `YianaExtraction`, a local Swift package that takes OCR text and
produces `.addresses/*.json`-compatible output. Three extractors behind
a single cascade API. Tests written before implementation.

## Approach

Three work sessions, each producing a commit with more green tests:

1. **Scaffold + models + red tests** — package, types, test cases from Phase 0 corpus
2. **RegistrationFormExtractor** — structured form pattern matching (green tests)
3. **NLPExtractor + FallbackExtractor** — NLTagger + NSDataDetector for everything else

## Non-Goals (during this phase)

- No NHS lookup (that's Phase 1.2)
- No wiring into the Yiana app (that's Phase 1.3)
- No improvements to extraction quality (post-migration)
- No changes to the `.addresses/*.json` schema (frozen)

---

## Session 1: Package Scaffold + Models + Red Tests (Complete)

### 1a. Create the Swift package

```
YianaExtraction/
├── Package.swift
├── Sources/
│   └── YianaExtraction/
│       ├── Models/
│       │   ├── ExtractionInput.swift      # OCR page text input
│       │   └── ExtractionOutput.swift     # .addresses/*.json compatible output
│       ├── Extractors/
│       │   ├── ExtractionCascade.swift     # Runs extractors in priority order
│       │   ├── RegistrationFormExtractor.swift
│       │   ├── FormExtractor.swift
│       │   ├── LabelExtractor.swift
│       │   └── UnstructuredExtractor.swift
│       └── Utilities/
│           └── NameNormalizer.swift        # Shared name cleaning logic
└── Tests/
    └── YianaExtractionTests/
        ├── RegistrationFormTests.swift
        ├── FormExtractorTests.swift
        ├── LabelExtractorTests.swift
        ├── UnstructuredExtractorTests.swift
        ├── CascadeTests.swift
        ├── NameNormalizerTests.swift
        └── Fixtures/                      # Copied from migration/fixtures/extraction/
```

**Package.swift:**
- Swift tools version: 6.2
- Platforms: iOS 15+, macOS 12+
- Dependencies: none (Apple frameworks only — Foundation, NaturalLanguage)
- Products: single library `YianaExtraction`
- Targets: `YianaExtraction` + `YianaExtractionTests`

### 1b. Define the output model

Must match the existing `ExtractedAddress.swift` JSON schema exactly.
The app already has `DocumentAddressFile`, `AddressPageEntry`, `PatientInfo`,
`AddressInfo`, `GPInfo`, `ExtractionInfo` — the package produces these
same structures.

**Decision: share or duplicate?**

Option A: The package defines its own output types and the app maps them.
Option B: The package imports and produces the app's existing types.
Option C: Move the shared types into the package; both app and package use them.

**Recommendation: Option C.** Move `ExtractedAddress.swift` models into
`YianaExtraction` as the canonical definitions. The app imports them from
the package. This avoids duplication and ensures the extraction output is
always schema-compatible by construction.

This means `DocumentAddressFile`, `AddressPageEntry`, `PatientInfo`,
`AddressInfo`, `GPInfo`, `ExtractionInfo`, `PhoneInfo`, `NHSCandidate`
all live in the package. The app's `ExtractedAddress.swift` becomes a
thin wrapper or is replaced entirely.

### 1c. Define the input model

```swift
/// OCR text for a single page, as produced by YianaOCRService or OnDeviceOCRService.
public struct ExtractionInput {
    public let documentId: String
    public let pageNumber: Int       // 1-based
    public let text: String          // Full page OCR text
    public let confidence: Double    // OCR confidence 0...1
}
```

### 1d. Define the cascade API

```swift
public struct ExtractionCascade {
    /// Run all extractors in priority order on a single page.
    /// Returns nil if no extractor succeeds.
    public func extract(from input: ExtractionInput) -> AddressPageEntry?

    /// Run extraction on all pages of a document.
    /// Returns the complete DocumentAddressFile ready to write to JSON.
    public func extractDocument(
        documentId: String,
        pages: [ExtractionInput]
    ) -> DocumentAddressFile
}
```

### 1e. Write test cases (all red)

Port the Phase 0 extraction fixtures into XCTest. Each test:
1. Loads synthetic OCR JSON from the fixture
2. Feeds text to the cascade (or individual extractor)
3. Asserts expected fields match

```swift
// RegistrationFormTests.swift
func test_registration_form_extracts_patient_name() {
    let input = loadFixture("Baker_Wendy_070589", page: 1)
    let result = RegistrationFormExtractor().extract(from: input)
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.patient?.fullName, "Noah Palmer")
}

func test_registration_form_extracts_mrn() { ... }
func test_registration_form_extracts_dob() { ... }
func test_registration_form_extracts_postcode() { ... }
func test_registration_form_extracts_gp() { ... }
// ... 10 registration form documents

// FormExtractorTests.swift
func test_form_extracts_patient_name_after_label() { ... }
// ... 15 form-based documents

// LabelExtractorTests.swift
func test_label_extracts_name_and_postcode() { ... }
// ... 21 label documents

// CascadeTests.swift
func test_cascade_returns_nil_for_empty_page() { ... }
func test_cascade_tries_registration_first() { ... }
```

**Fixture loading helper:**
```swift
func loadFixture(_ name: String, page: Int) -> ExtractionInput {
    // Load from Tests/Fixtures/input_ocr/{name}.json
    // Extract page text by pageNumber
    // Return ExtractionInput
}
```

**Test count estimate:** ~60-80 test methods covering all 53 fixture documents.

### 1f. Commit

Commit: "Add YianaExtraction package scaffold with red tests"
- Package compiles
- All tests fail (no implementation)
- Models are defined and match existing schema
- `/check` passes (package doesn't break app build)

---

## Session 2: RegistrationFormExtractor (Complete)

### 2a. Understand what to port

The Python `SpireFormExtractor` (327 LOC) does:
1. **Detection:** checks for "Spire Healthcare" + "Registration Form" in text
2. **MRN:** regex `Patient_?\s*(\d{6,10})`
3. **Name:** regex for "Surname, Firstname" before "Date of birth" label
4. **DOB:** regex for DD.MM.YYYY after "Date of birth" label
5. **Address:** text block between "Patient name" and county name
6. **County:** hard-coded list (Sussex, Surrey, Kent, etc.)
7. **Postcode:** UK postcode regex
8. **Phones:** regex after "Tel no" labels, before "Next of kin" section
9. **GP:** regex for "Doctor NAME" then practice lines after "GP" section

### 2b. Swift implementation approach

Port the regex logic directly. Do NOT use NLTagger here — registration
forms have a fixed layout and regex is the right tool.

Key differences from Python:
- Swift `Regex` builder or `NSRegularExpression` (prefer Regex builder for readability)
- The trigger text changes from "Spire Healthcare" to whatever the
  production forms actually say. The extractor should be configurable
  with trigger phrases, not hardcoded. For now, keep "Spire Healthcare"
  as the trigger (matching production) and add "Clearwater Medical" for
  test fixtures.

```swift
public struct RegistrationFormExtractor: Extractor {
    /// Text markers that identify this form type
    let triggers: [String] = ["Spire Healthcare", "Clearwater Medical"]

    public func extract(from input: ExtractionInput) -> AddressPageEntry?
}
```

### 2c. Get tests green

Work through the 12 registration form fixture documents. Each must produce
the expected patient name, DOB, MRN, postcode, and GP name.

**Known Python limitations to replicate (not fix):**
- GP practice name truncated at "Medical"/"Account" keywords in regex
- Phone extraction limited to patient section (before "Next of kin")
- County detection uses hard-coded list

### 2d. Commit

Commit: `840c0e8` "Implement RegistrationFormExtractor (Session 2 of Phase 1.1)"
- 12/12 registration form fixture tests pass
- 6/6 field-specific tests pass (name, DOB, MRN, postcode, GP name, rejection)
- 4/4 cascade tests pass
- Two deliberate improvements over Python: full GP name capture, no "Medical" boundary truncation
- `/check` passes (iOS + macOS)

---

## Session 3: NLPExtractor + FallbackExtractor

### 3a. NLPExtractor — replaces Python's form + label extractors

This is where Swift should outperform Python. Instead of fragile regex
for names and addresses, use Apple's NLP frameworks:

**NLTagger** (NaturalLanguage framework):
- `.nameType` — identifies person names, place names, organisation names
- Tag scheme `.nameTypeOrOrganization` for splitting
- Works on free text without needing field labels

**NSDataDetector** (Foundation):
- `.address` — UK postal addresses with structured components
- `.phoneNumber` — phone numbers in various formats
- `.date` — dates (DOB candidates)

**Extraction strategy:**
```
1. Run NLTagger on full page text
   → collect person names, place names
2. Run NSDataDetector for addresses, phones, dates
3. Run UK postcode regex (NSDataDetector may miss some formats)
4. Correlate: person name near postcode = patient
5. Look for GP indicators: "Dr", "Doctor", "Surgery", "Practice"
   near a person name = practitioner
6. Confidence: 0.8 for form-like text (has field labels),
   0.7 for label-like text (address block format)
```

The Python code has two separate extractors (form-based and label-based)
that differ mainly in how they find the name:
- Form: looks for "Name:" or "Patient name:" labels
- Label: assumes first line of a block is the name

The NLP approach unifies both — NLTagger identifies names regardless of
whether they follow a label or start a block.

**Form detection heuristic:**
If text contains field labels ("Name:", "Address:", "Date of birth:"),
set method to "form" with confidence 0.8. Otherwise "label" with 0.7.
This preserves method attribution for comparison with Python output.

### 3b. FallbackExtractor — replaces Python's unstructured extractor

For text with a postcode but no clear name/address structure:

```
1. Find UK postcode (regex)
2. Look for "Mr/Mrs/Ms/Dr" + name pattern nearby
3. Find any date that looks like a DOB
4. Extract address lines around the postcode
5. Confidence: 0.5
6. Method: "unstructured"
```

This is essentially the Python `extract_unstructured()` logic ported
to Swift. It's the fallback — only fires if NLPExtractor returns nil.

### 3c. ExtractionCascade wiring

```swift
public struct ExtractionCascade {
    let extractors: [Extractor] = [
        RegistrationFormExtractor(),
        NLPExtractor(),            // handles both form + label
        FallbackExtractor(),       // unstructured
    ]

    public func extract(from input: ExtractionInput) -> AddressPageEntry? {
        for extractor in extractors {
            if let result = extractor.extract(from: input) {
                return result
            }
        }
        return nil
    }
}
```

### 3d. Get remaining tests green

Work through:
- 15 form-based fixture documents
- 21 label fixture documents
- 1 unstructured document (5 pages, all known divergences from Phase 0)
- 4 empty/edge case documents

**Expected outcome:** Most form + label tests should pass. The 13 known
divergences from Phase 0 may or may not reproduce — the Swift extractors
use different technology (NLTagger vs Python regex) so they may succeed
where Python's synthetic-text limitations caused failures, or fail
differently. Document any new divergences.

### 3e. Commit

Commit: "Implement NLPExtractor and FallbackExtractor — N/53 tests green"
- All non-divergent tests pass
- Known divergences documented in test annotations
- `/check` passes

---

## Extractor Protocol

```swift
public protocol Extractor {
    /// Attempt to extract address data from OCR text.
    /// Returns nil if this extractor cannot handle the input.
    func extract(from input: ExtractionInput) -> AddressPageEntry?
}
```

Each extractor is stateless and can be tested independently.

---

## Test Strategy

### Unit tests (per extractor)
- Each fixture document tests one extractor directly
- Assert specific fields: name, DOB, MRN, postcode, GP name, method, confidence
- Don't test fields the Python validator doesn't check (address lines, city,
  county, phones) — those are validated in Phase 1.4 against real data

### Integration tests (cascade)
- Feed full documents through `ExtractionCascade.extractDocument()`
- Assert the correct extractor fires for each page (by method name)
- Assert `DocumentAddressFile` serialises to valid JSON matching schema

### Fixture management
- Copy `migration/fixtures/extraction/input_ocr/` into
  `Tests/YianaExtractionTests/Fixtures/`
- Copy `migration/fixtures/extraction/expected_addresses/` alongside
- Load via `Bundle.module.url(forResource:withExtension:subdirectory:)`

### Known divergences
- Annotate with `// KNOWN_DIVERGENCE: reason` in test code
- These are cases where synthetic OCR text doesn't match real-world layout
- The Swift extractor may handle them differently than Python — that's fine
  as long as the Phase 1.4 parallel run validates against real data

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| NLTagger doesn't recognise UK names well | Fall back to regex patterns like Python does |
| NSDataDetector misses UK address formats | Supplement with postcode regex + surrounding-line heuristic |
| Swift Regex builder requires macOS 13+ | We target macOS 12+; use NSRegularExpression if needed |
| Test fixtures are synthetic (circular) | Phase 1.4 parallel run validates against all 1441 real documents |
| Registration form trigger text changes | Make triggers configurable, not hardcoded |

---

## Definition of Done

- [ ] `YianaExtraction` Swift package compiles on iOS and macOS
- [ ] All non-divergent fixture tests pass
- [ ] `ExtractionCascade.extractDocument()` produces valid `DocumentAddressFile` JSON
- [ ] Output JSON matches `.addresses/*.json` schema exactly
- [ ] `/check` passes (both iOS and macOS targets build)
- [ ] No new dependencies added (Apple frameworks only)
- [ ] Known divergences documented in test code
