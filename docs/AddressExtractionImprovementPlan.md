# Address Extraction Improvement Plan

**Date**: November 1, 2025
**Status**: Planning
**Goal**: Systematically improve address extraction accuracy through user feedback and training

---

## Overview

The current address extraction is "patchy" - working well for some documents (Spire Healthcare forms) but missing or misidentifying addresses in others. This plan creates a feedback loop to continuously improve extraction performance.

---

## Core Strategy: Keep Original + User Corrections

Store both automated extractions and user corrections in separate tables, allowing:
1. Users to fix/add/remove addresses without losing original data
2. Analysis of extraction failures to improve algorithms
3. Training data generation for ML enhancements
4. A/B testing of new extraction methods

---

## Implementation Phases

### Phase 1 - Quick Wins (Immediate)

**Goal**: Prevent common false positives and prepare for user feedback

**Tasks**:
1. ✅ Create `address_exclusions` table
2. ✅ Add exclusion patterns (e.g., user's own address)
3. ✅ Create `address_overrides` table structure
4. ⬜ Update extraction service to check exclusions
5. ⬜ Add "Show original extraction" UI component (collapsed by default)
6. ⬜ Log low-confidence extractions for review

**Example Exclusions**:
```sql
-- Recipient's own address (letters addressed TO the user)
INSERT INTO address_exclusions (full_name_pattern, exclusion_type, reason)
VALUES ('Rose %', 'recipient', 'My own address - I am the recipient');

-- Common clinic addresses
INSERT INTO address_exclusions (address_pattern, exclusion_type, reason)
VALUES ('% Harley Street%', 'clinic_address', 'Clinic address not patient');
```

**Impact**: Immediately reduces false positives for known patterns

---

### Phase 2 - User Editing (After Phase 1)

**Goal**: Allow users to correct/add/remove addresses and build training dataset

**Tasks**:
1. ⬜ Add "Edit" button to address cards in AddressesView
2. ⬜ Create edit form with all address fields
3. ⬜ Save corrections to `address_overrides` table
4. ⬜ Update Swift AddressRepository to query overrides first
5. ⬜ Show visual indicator when address has been corrected
6. ⬜ Add "View original" button to see automated extraction

**UI Changes**:
```
Address Card:
┌─────────────────────────────────────┐
│ 👤 Patient Information    [Edit ✏️] │
│                                      │
│ Name: John Smith ⚠️ (corrected)    │
│ [View original extraction ▼]        │
│                                      │
│ DOB: 05/03/1978                     │
│ Address: 123 Main Street...         │
└─────────────────────────────────────┘
```

**Database Design**:
```sql
CREATE TABLE address_overrides (
    id INTEGER PRIMARY KEY,
    document_id TEXT NOT NULL,
    page_number INTEGER,
    original_extraction_id INTEGER,  -- NULL if user added new

    -- Same fields as extracted_addresses
    full_name TEXT,
    date_of_birth TEXT,
    address_line_1 TEXT,
    -- ... etc ...

    -- Override metadata
    overridden_at TIMESTAMP,
    override_reason TEXT,  -- 'corrected', 'added', 'removed'
    override_notes TEXT,

    -- Training flags
    is_training_candidate BOOLEAN DEFAULT 1,
    training_used BOOLEAN DEFAULT 0
)
```

**Impact**: Build training dataset while users use the app naturally

---

### Phase 3 - Training Loop (After ~20 corrections)

**Goal**: Analyze patterns in corrections and improve extraction rules

**Tasks**:
1. ⬜ Implement training analysis script (`training_analysis.py`)
2. ⬜ Run analysis automatically after N corrections
3. ⬜ Generate improvement reports
4. ⬜ Update extraction rules based on patterns
5. ⬜ A/B test new rules against old ones
6. ⬜ Mark successful improvements as `training_used`

**Analysis Categories**:

1. **Common False Positives**
   - Extraction method that generated them
   - Text patterns that trigger false matches
   - → Add exclusion rules or improve regex

2. **Systematic Name Errors**
   - "Mr John Smith" → "Mr" (title extracted as name)
   - "Dr. Jane Doe" → "Dr Jane" (period handling)
   - → Improve name parsing regex

3. **Missing Extractions by Method**
   - Which methods fail most often?
   - What text patterns are they missing?
   - → Add new extraction heuristics

4. **Confidence vs Accuracy**
   - Do low-confidence extractions correlate with errors?
   - Are high-confidence extractions sometimes wrong?
   - → Adjust confidence thresholds

**Output Example**:
```markdown
# Training Report - 2025-11-15

## Summary
- 23 corrections analyzed
- 12 false positives (8 from 'label' method)
- 7 name parsing errors
- 4 missing extractions

## Suggested Improvements

### HIGH PRIORITY: Add exclusion pattern
False positive pattern detected 8 times:
- "Occupier Owner" (extracted as patient name)
→ Add exclusion: full_name_pattern = 'Occupier Owner'

### MEDIUM PRIORITY: Improve title handling
Common error: Titles extracted as names
- "Mr John Smith" → "Mr" (x4)
- "Dr Jane Doe" → "Dr" (x3)
→ Update name regex to strip titles
```

**Impact**: Continuous improvement based on real usage data

---

### Phase 4 - ML Enhancement (Optional, Future)

**Goal**: Use local LLM for ambiguous/difficult extractions

**Approach**: Hybrid system
- **Pattern-based** (current): Fast, deterministic, works for 70% of cases
- **LLM-based** (new): Handles ambiguous cases, learns from corrections

**When to use LLM**:
1. No pattern-based match found
2. Low confidence (<0.5) from pattern matching
3. Multiple conflicting extractions
4. Complex/unusual letter formats

**Local LLM Options** (see separate section below)

**Training Data Format**:
```json
{
  "ocr_text": "Dear Mr John Smith\n123 High Street...",
  "correct_extraction": {
    "full_name": "John Smith",
    "address_line_1": "123 High Street",
    "postcode": "SW1A 1AA"
  },
  "original_extraction": {
    "full_name": "Mr John",
    "confidence": 0.3
  }
}
```

**Implementation**:
1. ⬜ Export training data (OCR + corrections)
2. ⬜ Fine-tune chosen LLM on medical letter format
3. ⬜ Create LLM extraction method in `llm_extractor.py`
4. ⬜ A/B test against pattern-based extraction
5. ⬜ Deploy hybrid system

**Impact**: Handle edge cases and unusual formats

---

## Database Schema

### address_exclusions
```sql
CREATE TABLE address_exclusions (
    id INTEGER PRIMARY KEY,
    full_name_pattern TEXT,      -- SQL LIKE pattern (% = wildcard)
    address_pattern TEXT,
    postcode_pattern TEXT,
    exclusion_type TEXT,          -- 'recipient', 'sender', 'clinic_address'
    reason TEXT,
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP,
    last_used_at TIMESTAMP
);
```

### address_overrides
```sql
CREATE TABLE address_overrides (
    id INTEGER PRIMARY KEY,
    document_id TEXT NOT NULL,
    page_number INTEGER,
    original_extraction_id INTEGER,  -- FK to extracted_addresses

    -- Address fields (same as extracted_addresses)
    full_name TEXT,
    date_of_birth TEXT,
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    county TEXT,
    postcode TEXT,
    country TEXT DEFAULT 'UK',
    phone_home TEXT,
    phone_work TEXT,
    phone_mobile TEXT,
    gp_name TEXT,
    gp_practice TEXT,
    gp_address TEXT,
    gp_postcode TEXT,
    gp_ods_code TEXT,
    gp_official_name TEXT,

    -- Metadata
    overridden_at TIMESTAMP,
    override_reason TEXT,         -- 'corrected', 'added', 'removed'
    override_notes TEXT,
    is_training_candidate BOOLEAN DEFAULT 1,
    training_used BOOLEAN DEFAULT 0,

    FOREIGN KEY(original_extraction_id)
        REFERENCES extracted_addresses(id) ON DELETE SET NULL
);
```

### addresses_with_overrides (View)
```sql
CREATE VIEW addresses_with_overrides AS
SELECT
    COALESCE(ao.full_name, ea.full_name) as full_name,
    -- ... other fields with COALESCE ...
    ea.extraction_confidence,
    ea.extraction_method,
    CASE WHEN ao.id IS NOT NULL THEN 1 ELSE 0 END as is_overridden,
    ao.override_reason
FROM extracted_addresses ea
LEFT JOIN address_overrides ao ON ea.id = ao.original_extraction_id
WHERE ao.override_reason IS NULL OR ao.override_reason != 'removed';
```

**Usage in Swift**:
```swift
// Get addresses (overrides take precedence)
let addresses = try await repository.addresses(forDocument: documentId, includeOverrides: true)

// Get original extraction for comparison
let original = try await repository.originalExtraction(forAddress: addressId)
```

---

## Metrics to Track

### Extraction Quality
- **Precision**: % of extracted addresses that are correct
- **Recall**: % of actual addresses that were found
- **Confidence vs Accuracy**: Correlation analysis

### User Corrections
- **Correction rate**: % of extractions that need correction
- **Time to correct**: How long users spend fixing
- **Correction types**: Distribution of 'corrected', 'added', 'removed'

### Method Performance
- **Accuracy by method**: spire_form vs label vs form vs unstructured
- **False positive rate**: By method and document type
- **Coverage**: % of documents with at least one extraction

### Training Impact
- **Before/After accuracy**: After each training cycle
- **Exclusion effectiveness**: Reduction in false positives
- **LLM vs Pattern**: Comparison when both available

---

## Success Criteria

### Phase 1 (Immediate)
- ✅ Exclusion list prevents known false positives
- ✅ Database schema supports user corrections
- ✅ Original extractions preserved for analysis

### Phase 2 (After 2 weeks)
- 🎯 Users can edit addresses in < 30 seconds
- 🎯 20+ corrections collected for training
- 🎯 UI clearly shows corrected vs original

### Phase 3 (After 1 month)
- 🎯 First training report generated
- 🎯 2-3 extraction rules improved based on patterns
- 🎯 Measurable increase in precision (target: +10%)

### Phase 4 (After 3 months, optional)
- 🎯 LLM handles ambiguous cases
- 🎯 Hybrid system accuracy >90% on test set
- 🎯 False positive rate <5%

---

## Related Documentation

- **AddressExtractionDesign.md**: Overall architecture
- **iOSDataProtectionImplementation.md**: Data security
- **training_analysis.py**: Analysis script for correction patterns
- **schema_update.sql**: Database migrations for new tables

---

## Notes

- Start simple: Focus on preventing false positives first
- User friction: Make editing quick and easy
- Training loop: Don't wait for perfection, iterate
- Privacy: All processing stays local (no cloud LLM needed)
- Backup: Always keep original extractions for analysis

---

## Changelog

| Date | Phase | Change |
|------|-------|--------|
| 2025-11-01 | Planning | Created improvement plan |
| 2025-11-01 | Phase 1 | Schema design for exclusions and overrides |
