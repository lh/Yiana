# Migration

Temporary directory for the backend consolidation (Python/Bash → Swift).
Delete this directory when migration is complete and verified.

See `docs/consolidation-architecture.md` and `docs/consolidation-plan.md` for context.

## Structure

```
migration/
├── fixtures/           # Test corpus (Phase 0)
│   ├── extraction/     # OCR JSON input → expected address JSON output
│   ├── entity/         # Entity resolution test cases
│   └── nhs_lookup/     # Postcode → practice lookup cases
├── validation/         # Parallel-run comparison scripts and results
└── notes/              # Decision log, discrepancy reviews
```
