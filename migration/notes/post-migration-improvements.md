# Post-Migration Improvements

Things noticed during migration that should NOT be done now.
Do these after consolidation is complete and verified.

---

## 1. Flatten the .addresses/*.json data structure (2026-03-16)

The current address JSON has deeply nested objects: pages[] containing patient{}, address{}, gp{} sub-objects, plus overrides[] with the same nesting, plus enriched{} with its own patient{} and practitioners[]. Override entries duplicate the full page structure just to change one field.

This makes scrubbing, diffing, and debugging harder than it needs to be. A flatter structure with explicit field names would be clearer.

Do not change during migration — the schema is frozen. Redesign after Phase 4 is complete.

---

## 2. normalize_name() doesn't strip "Doctor" (2026-03-16)

`TITLE_PATTERNS` strips "dr" but not "doctor". So "Dr Martinez" normalises to "martinez" but "Doctor Martinez" normalises to "doctor martinez" — creating two separate practitioner entities for the same GP.

Likely a bug. The title list should include "doctor" alongside "dr".

---

## 3. ODS code unused for practitioner matching (2026-03-16)

The schema has `ods_code` and `official_name` columns on practitioners, but `_resolve_practitioner()` matches only on `(full_name_normalized, type)`. Two GPs with the same ODS code but different name spellings create separate entities. Conversely, two different GPs with the same name but different ODS codes incorrectly merge.

This was probably deferred during initial implementation. The Swift version should use ODS code as a strong dedup signal — if two records share an ODS code, they're the same practice regardless of name formatting.

---

## 4. Empty pages with valid filename still creates patient entity (2026-03-16)

`parse_patient_filename()` runs before the pages loop, so a document with zero pages but a parseable filename (e.g. `Lowe_Ned_010101.json`) still creates a patient entity and a patient_documents link. The patient gets `document_count` incremented even though the document contributed no extraction data.

This might be intentional (the document exists, the patient is real) or it might inflate document_count misleadingly. Worth a design decision in the Swift version: should empty documents count toward a patient's document_count?
