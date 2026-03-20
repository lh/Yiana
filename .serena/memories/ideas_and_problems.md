# Ideas & Problems

Quick-capture list for things that come to mind mid-task.

\1
7. **Address extraction could use metadata.fullText as fallback/cross-check** — Currently reads only from `.ocr_results/` JSON (structured, per-page). `fullText` is flat but sufficient for basic pattern matching (postcodes, names, DOBs). Could validate backend OCR vs on-device OCR, fall back when JSON missing, or boost confidence when both agree. Logged 2026-02-22.

## Problems

12. **iCloud override race condition — implement before Phase 1.5** — When user edits an override on device A and device B re-extracts before sync completes, the override is lost. Fix: separate override file (`{documentId}.overrides.json`) so extraction never touches user edits. `AddressRepository` merges at read time. Must be done before retiring Python extraction (Phase 1.5). See HANDOFF.md "Open Design Question" for full analysis. Discovered 2026-03-20.

9. **Extraction misses address lines** — Real-world test (Groves_Simon_250870, single-page scan) extracted postcode RH1 4DD, patient name, DOB, and phone, but no street address lines. Likely the extractors (label/form) aren't picking up address lines from this document layout. Needs investigation in the extraction cascade. Discovered 2026-03-20.

10. **Duplicate phone numbers** — When the same phone number appears multiple times in the source document, it gets extracted multiple times. Need deduplication in phone extraction. Discovered 2026-03-20.

11. **GP data not extracted from some documents** — Groves_Simon_250870 has GP info but none was picked up by any extractor. May be a layout the extractors don't recognise. Discovered 2026-03-20.

8. **Special characters in folder names (`?`, `#`, `%`) corrupt file operations** — Folder `Junk?` causes documents to silently move to parent folder during save/archive operations. The `?` is likely interpreted as a URL query separator at some point in the URL→path→URL chain (e.g. `URL(fileURLWithPath:)` round-trip). Documents "vanish" from the folder and reappear in parent. Need to either sanitize folder names on creation or ensure all file operations use `.path` instead of URL string comparisons. Discovered 2026-02-28.

## Ideas

3. **Expandable Typst dashboard** — The Devon dashboard (`scripts/dashboard.typ` + `dashboard-collector.py`, served via typst-live LaunchAgent on port 5599) can be extended with any server-side metric: extraction stats, backend DB counts, iCloud sync state, log growth trends, etc. Just add to collector + template.

1. **Connected scanner support on macOS** -- Interesting but out of scope. Bulk scanning from a connected scanner is more of a DevonTHINK use case. We are not trying to compete with or be as complex as that. Would also need external LLM integration to be truly useful (auto-classify, auto-title, auto-folder scanned pages). Park indefinitely unless the product direction changes. Logged 2026-02-25.

## Swift Extraction Service on Devon (logged 2026-03-14)

**Goal:** Replace Python extraction service + backend DB + letter generator with Swift equivalents on Devon.

**Why:**
- Mac mini already has NLTagger, NSDataDetector, Vision — better than Python regex cascade
- OCR service is already Swift; one language simplifies deployment and maintenance
- Eliminates Python venv/PYTHONPATH/launchd headaches
- NLTagger+NSDataDetector parser (90 lines) already outperforms Python regex extractors

**Approach:**
- Build Swift extraction service alongside existing Python — run both in parallel, compare outputs
- No need to take Python down until Swift is proven
- Backend DB: GRDB.swift (already approved dependency)
- Letter generator: port last (most complex, lowest priority)

**Blocker:** Devon runs older macOS. NLTagger NER needs macOS 10.14+ (should be fine). NSDataDetector since 10.7. Check Devon's exact macOS version before starting. Tahoe upgrade possible but painful — only needed for Apple Intelligence, not for core NLP frameworks.

**Scope:** extraction_service.py, address_extractor.py, spire_form_extractor.py, backend_db.py, letter_generator.py, letter_system_db_simple.py

## Work List — reverted and redesigning (2026-03-08)

All work list code reverted from Yiana (commit cd5340a). Eight attempts to fix click navigation inside `List(selection:)` failed. The feature will be reimplemented from scratch with the work list OUTSIDE the sidebar List. Full spec and architectural constraint documented in `HANDOFF.md`. Diagnostic history in `docs/work-list-navigation-failures.md`.
