# Session Handoff — 2026-03-14 (evening)

## Session Summary

Major address panel overhaul plus "Address it!" text extraction feature. Two tracks: address card UI improvements merged to main, and experimental text extraction on `feature/address-from-selection`.

## What Was Completed

### On `main` (merged)

1. **Name field split** — surname/firstname surfaced from filename parse through enrichment pipeline. Edit mode shows Title / First name(s) / Surname. Save joins back to fullName for backward compat.
2. **is_prime cleanup** — Extraction service no longer auto-sets is_prime. Cleared 1433 migrated auto-primes. Only human-set primes preserved.
3. **Address card UI cleanup:**
   - "Specialist" renamed to "Other" (display only, JSON stays "specialist")
   - `key` field on `AddressTypeDefinition` decouples display label from JSON value
   - Subtype name TextField removed from card header
   - Type picker and prime toggle in edit mode only
   - Grey header for non-prime cards
4. **Manual address entry** — page-0 virtual addresses via overrides. Add Address menu. Delete for manual, Dismiss for extracted.
5. **Auto-save on prime toggle** during editing
6. **matchAddressType tracking** — fixes dismiss/save using wrong override key
7. **selectedType for field display** — changing type in edit mode shows correct fields
8. **Address status indicator** includes page-0 manual overrides

### On `feature/address-from-selection` (not merged)

1. **SelectableTextView** — NSTextView wrapper for OCR panel. Scroll elasticity disabled.
2. **"Address it!" button** — menu with Patient/GP/Optician/Other. Inline preview card below OCR text. Save/Discard.
3. **Text parser** (three layers):
   - NLTagger (NER) for person names
   - NSDataDetector for addresses, phones, dates
   - Label fallbacks ("Name:", "DOB:", "Add:")
   - Title-prefix fallback (greedy, up to 5 words)
   - UK postcode regex fallback
4. **Address status filter bar** — coloured dots (grey/green/red/blue) above document list. Debug aid, marked for easy removal.
5. **NHS lookup database** — `nhs_lookup.db` (NOT in git, licensing):
   - 1,592 GP practices with full addresses (ODS API)
   - 3,900 branch surgeries (NHS CSV)
   - 7,008 opticians (NHS CSV)
   - Deployed to Devon at `~/Data/nhs_lookup.db`
   - Local copy at `AddressExtractor/nhs_lookup.db`

## Next Step: Wire NHS Lookup into "Address it!"

When user clicks "Address it! > GP" and parser finds a postcode:
- Look up postcode in `nhs_lookup.db` → gp_practices table
- One match: auto-fill practice name + address in preview
- Multiple matches: show picker
- Same for "Address it! > Optician" → opticians table

**Decision needed:** how to make the DB accessible to the Swift app:
- **Bundle in app** (1.7MB, simplest, works offline)
- **Query Devon via network** (adds latency, but always current)
- Bundling recommended for now

## Known Issues

- **Dismiss needs re-testing** on GP type after matchAddressType fix
- **Parser limitations** — NLTagger struggles with OCR line breaks. Label fallbacks help but don't cover all cases
- **Dead code** — `highlightedText()` in DocumentInfoPanel, `updateAddressType()` in AddressesView. Clean up when stable.
- **Feature branch not merged** — needs more testing

## Key Files

| File | Changes |
|------|---------|
| `AddressExtractor/backend_db.py` | Enrichment writes surname/firstname |
| `AddressExtractor/extraction_service.py` | is_prime defaults to None |
| `AddressExtractor/letter_generator.py` | Uses enriched surname |
| `Yiana/Models/ExtractedAddress.swift` | surname/firstname/title/isDismissed/matchAddressType |
| `Yiana/Models/AddressTypeConfiguration.swift` | key field, "Other" label |
| `Yiana/Views/AddressesView.swift` | Edit mode controls, manual/dismiss/delete |
| `Yiana/Services/AddressRepository.swift` | Manual addresses, dismiss, page-0 resolution |
| `Yiana/Views/DocumentInfoPanel.swift` | SelectableTextView, TextAddressParser, preview (feature branch) |
| `Yiana/Views/DocumentListView.swift` | Status filter bar (feature branch) |

## Branch Status

- `main` — all address card improvements merged and pushed
- `feature/address-from-selection` — pushed to remote, not merged. Active development.
- Devon SSH: `devon@devon-6` (key auth works)

## Future Work (in Serena memory `ideas_and_problems`)

**Swift extraction service on Devon** — replace Python extractors with Swift using NLTagger + NSDataDetector. Devon runs macOS 14.8 (Sonoma), frameworks fully available. Build alongside Python, compare, cut over.
