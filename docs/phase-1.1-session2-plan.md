# Phase 1.1 Session 2: RegistrationFormExtractor

## Goal

Implement `RegistrationFormExtractor` in Swift to pass the 12 registration
form fixture tests. Direct port of Python's `SpireFormExtractor` regex logic.

## What the Tests Expect

Each of the 12 fixtures has synthetic OCR text containing "Clearwater Medical"
+ "Registration Form". The tests assert:

- `result != nil` (detection works)
- `extraction.method == "clearwater_form"`
- `extraction.confidence == 0.9`
- Patient name matches expected (case-insensitive)
- DOB matches expected
- MRN matches expected
- Postcode matches expected (normalised, space-insensitive)
- GP name matches expected (case-insensitive)

## Implementation Steps

### Step 1: Detection

Check for trigger text. The Python code checks for "Spire Healthcare" +
"Registration Form". Our fixtures use "Clearwater Medical". The extractor
should support both (configurable triggers, defaulting to both).

```swift
let triggers: [(String, String)] = [
    ("Spire Healthcare", "Registration Form"),
    ("Clearwater Medical", "Registration Form"),
]
// Return nil if no trigger pair found in text
```

### Step 2: MRN Extraction

Python patterns:
```
Patient_?\s*(\d{6,10})
Patient\s*No\.?\s*(\d{6,10})
```

Synthetic text example: `Patient_ 53978606`

Swift approach: `NSRegularExpression` or Swift `Regex`. These are simple
patterns — either works.

### Step 3: Patient Name

Python pattern: `([A-Z][a-z]+,\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*\n\s*Date of birth`

Synthetic text example:
```
Stone, Karen
Date of birth
```

Logic: find "Surname, Firstname" on a line before "Date of birth",
then flip to "Firstname Surname".

### Step 4: Date of Birth

Python patterns (in priority order):
1. Already captured by name pattern (pattern 2)
2. `Date of birth\s*\n?\s*(\d{1,2}[./]\d{1,2}[./]\d{4})`
3. Any `DD.MM.YYYY` or `DD/MM/YYYY` with 19xx year

Synthetic text example: `02.11.1997` → normalise dots to slashes → `02/11/1997`

### Step 5: Postcode

Python pattern: `([A-Z]{1,2}\d{1,2}[A-Z]?\s*\d[A-Z]{2})` on uppercased text.
Take first valid match.

Synthetic text example: `MM3 3JE`

Note: the synthetic postcodes use fake formats like `MM3`, `JJ9`, etc.
The regex doesn't validate against a real postcode database — it only
checks the format pattern.

### Step 6: Phones

Python logic:
1. Find "Next of kin" / "Emergency contact" → truncate text before that
2. Search truncated text for 11-digit numbers or 5+6 digit pairs
3. Numbers starting with `07` → mobile, else → home

Synthetic text example: `07700988113` appears before "Next of kin" section.

### Step 7: GP Name

Python patterns: `(?:Doctor|Dr|Dostor)\s+([A-Z][A-Z]+)` or `(?:Doctor|Dr|Dostor)\s+([A-Z][a-z]+)`

Synthetic text example: `Doctor G Tanaka` → extract "G Tanaka" → format as "Dr G Tanaka"

Wait — the Python regex `(?:Doctor|Dr|Dostor)\s+([A-Z][A-Z]+)` only captures
a SINGLE uppercase word. "G Tanaka" would match `[A-Z][A-Z]+` for "G"? No —
"G" is one character, `[A-Z]+` requires 2+. The second pattern
`(?:Doctor|Dr|Dostor)\s+([A-Z][a-z]+)` would match "Tanaka" (capital + lowercase).

So "Doctor G Tanaka" → Python extracts just "Tanaka" → `Dr Tanaka`.

But the expected output says "Dr G Tanaka". This is because the expected output
was scrubbed from real data where the Python extractor produced "Dr G Tanaka"
from different (real) text. The synthetic text was generated from the scrubbed
expected output, not the other way around. This is the circularity issue from
our Phase 0 review.

**Decision:** The Swift extractor should capture "Doctor/Dr + full remaining
name" — i.e., `Doctor G Tanaka` → `Dr G Tanaka`. This is an improvement over
Python's single-word capture, and it matches the expected test output. We're
not "improving" the extractor — we're making it produce the right answer from
the synthetic text that was designed to contain the right answer.

### Step 8: GP Practice

Python regex: `GP\s*\n.*?Address.*?\n(.*?)(?:Account|Medical|Reason)`

This captures text between "GP / Address" labels and "Account" / "Medical" /
"Reason" keywords. The "Medical" boundary truncates practice names containing
that word (documented in post-migration-improvements.md).

Synthetic text example:
```
GP
Address
Doctor G Tanaka
VALLEY MEDICAL CENTRE

Account Settlement
```

With the Python regex, "VALLEY MEDICAL CENTRE" gets truncated at "Medical" →
"VALLEY". But the expected output says "VALLEY MEDICAL CENTRE" (from scrubbed
real data where the practice name was different).

**Decision:** The Swift extractor should NOT truncate at "Medical". Use
"Account" and "Reason" as boundaries but NOT "Medical". This fixes the
known bug and matches the expected test output.

### Step 9: Validation

Python requires both `full_name` and `postcode` to return a result.
If either is missing, return nil.

### Step 10: Assemble Result

Return `AddressPageEntry` with all extracted fields and:
- `extraction.method = "clearwater_form"`
- `extraction.confidence = 0.9`
- `addressType = "patient"`

## Regex Approach

Use Swift `Regex` builder (requires macOS 13+ / iOS 16+). Our package
targets macOS 12+ / iOS 15+, so we need `NSRegularExpression` instead.

Helper function:
```swift
func firstMatch(_ pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
    return (0..<match.numberOfRanges).compactMap { i in
        guard let range = Range(match.range(at: i), in: text) else { return nil }
        return String(text[range])
    }
}
```

## Test Verification

After implementation, run:
```bash
cd YianaExtraction && swift test 2>&1 | grep -E "(pass|fail|Test)"
```

Target: 12 registration form tests + 6 specific field tests + 4 cascade tests = 22 pass.
Form/label/unstructured tests remain red (48 - 12 = 36 still red).

## Files to Edit

- `YianaExtraction/Sources/YianaExtraction/Extractors/RegistrationFormExtractor.swift`

No other files should change.
