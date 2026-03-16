# Entity Resolution Test Fixtures

Fully synthetic test data for validating `backend_db.py` entity resolution.
No real data is used — all names, addresses, and identifiers are invented.

## Structure

```
entity/
├── addresses/          # Synthetic .addresses/*.json files (input)
├── expected.json       # Expected entity counts, links, canonical names
└── README.md
```

## Test Scenarios

### Exact-match dedup (scenarios 1-10)
Same patient appears in 2+ documents (identical filename pattern).
Expected: each pair resolves to 1 patient entity.

### Near-match names (scenarios 11-15)
Name variants that should normalise to the same entity:
titles stripped, case differences, hyphenated names.

### Practitioner dedup (scenarios 16-20)
Same GP (by normalised name + type) across documents with
different address/practice formatting.

### ODS code (scenarios 21-25)
ODS code exists in schema but is not used for matching.
These tests document the current (non-)behaviour.

### Edge cases (scenarios 26-30)
Missing DOB, malformed filenames, empty pages, names with
apostrophes/hyphens, no filename pattern.
