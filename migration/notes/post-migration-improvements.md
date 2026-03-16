# Post-Migration Improvements

Things noticed during migration that should NOT be done now.
Do these after consolidation is complete and verified.

---

## 1. Flatten the .addresses/*.json data structure (2026-03-16)

The current address JSON has deeply nested objects: pages[] containing patient{}, address{}, gp{} sub-objects, plus overrides[] with the same nesting, plus enriched{} with its own patient{} and practitioners[]. Override entries duplicate the full page structure just to change one field.

This makes scrubbing, diffing, and debugging harder than it needs to be. A flatter structure with explicit field names would be clearer.

Do not change during migration — the schema is frozen. Redesign after Phase 4 is complete.
