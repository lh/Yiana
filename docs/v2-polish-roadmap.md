# Yiana 2.0 — Polish Roadmap

Generated 2026-03-21. Everything below is post-consolidation work — the core app is self-sufficient and working.

---

## Priority 1: Daily Use Blockers

These affect the compose-and-print workflow you'll be using at work.

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 17 | Document auto-reload after InjectWatcher appends PDF | Medium | NSFilePresenter or notification from InjectWatcher. Currently must close/reopen to see appended letter. |
| 19a | Envelope window alignment | Small | Position recipient address block for standard window envelope. Need measurements from work stationery. |
| 19b | Footer contact block | Small | Restore sender details / secretary block at bottom of letter. Typst template change only. |
| 21b | Cannot add a new GP card | Small | UI flow for adding GP addresses missing or broken. |
| 21c | GP card save reverts to patient data | Medium | Save path writes back original extracted data rather than edited fields. Bug in AddressesView/AddressRepository. |

## Priority 2: Extraction Quality

Improve the data that feeds into letters and address cards.

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 13 | Postcode-to-town lookup table | Small | ~2,900 outward codes, ~100KB static dict. Replaces OCR-based city heuristics. 97.6% postcode accuracy means this is reliable. |
| 9 | Extraction misses address lines | Medium | Some document layouts not recognised by label/form extractors. Investigation needed. |
| 11 | GP data not extracted from some documents | Medium | Extractor doesn't recognise some GP info layouts. Related to #9. |
| 10 | Duplicate phone numbers | Small | Deduplicate in phone extraction. |
| 7 | Use metadata.fullText as extraction fallback | Medium | Cross-check or fall back to flat text when structured OCR JSON is missing. |

## Priority 3: UI Polish

Better experience, not blocking daily use.

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 22 | Traffic light filters on iPad/iPhone | Medium | Port macOS document state filters. Suppress empty filter states. |
| 15 | Recipient tick boxes in AddressesView | Medium | To/CC/None toggles per address card. Override rules-based defaults. |
| 14 | DOB format: DD/MM/YYYY to ISO 8601 | Small | Change parsePatientFilename output, rebuild entity DB. |
| 8 | Special characters in folder names corrupt file ops | Medium | `?`, `#`, `%` in folder names cause documents to silently move. URL encoding issue. |
| 16 | HTML template: leading comma when department empty | Tiny | Filter empties before joining. Cosmetic, HTML-only. May be irrelevant now Typst renders. |

## Priority 4: Compose Module Enhancements

Build out the letter writing experience.

| # | Item | Effort | Notes |
|---|------|--------|-------|
| — | iOS compose access | Large | Info panel is macOS-only. Need compose UI for iPad. |
| — | Drafts list / sidebar | Medium | Cross-document view of pending drafts. Phase 5 item. |
| — | Work list reimplementation | Large | Reverted in March. Needs separate container from sidebar List. |
| 19c | Custom/user-editable templates | Large | Long-term. Template selection, in-app editor, or user-supplied .typ files. |

## Priority 5: Future / Exploratory

Not needed now, but worth tracking.

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 23 | Local peer-to-peer sync (Multipeer/Bonjour) | Large | Direct device-to-device sync on same network. Bypass iCloud latency. |
| 20 | iPhone camera as scanner for Mac (Continuity Camera) | Medium | Native Apple API. Multi-page support unclear. |
| 1 | Connected scanner support on macOS | Parked | DevonTHINK territory. Not our direction. |
| 3 | Expandable Typst dashboard | Small | Devon dashboard. Less relevant now services are retired. |

## Completed / Resolved

These were in the ideas log but are now done:

- **#12** iCloud override race condition — FIXED (separate .overrides.json files)
- **#18** Typst replaces LaTeX — DONE (YianaRenderer, local rendering, Devon retired)
- **#21a** Town not inferred from postcode — tracked as #13 above
- Swift extraction service on Devon — SUPERSEDED (extraction runs in-app now)
- Phase 3.1 deduplication — DONE
- Work list revert — DONE (awaiting redesign)

---

## Suggested Session Plan

**Session A (next work day):** Items 19a + 19b (letter template). Bring envelope measurements. Pure Typst template work, no app code.

**Session B:** Items 17 + 21c (auto-reload + GP save bug). Two medium fixes that improve daily workflow.

**Session C:** Items 13 + 10 (postcode lookup + phone dedup). Extraction quality improvements.

**Session D:** Item 22 (traffic lights on iPad). UI parity across platforms.

**Session E:** iOS compose. The big one — bring letter writing to iPad.
