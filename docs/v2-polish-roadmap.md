# Yiana 2.0 — Polish Roadmap

Updated 2026-03-22. The core app is self-sufficient and working.

---

## Priority 1: Daily Use

| # | Item | Effort | Status |
|---|------|--------|--------|
| 26 | Performance: note loading/exiting speed | Medium | Open — measure first, then fix |
| 19a | Envelope window alignment | Small | Open — need measurements from work |
| 19b | Footer contact block in letter | Small | Open — Typst template change only |
| 8 | ~~Special characters in folder names corrupt file ops~~ | ~~Medium~~ | DONE 2026-03-22 |

## Priority 2: Extraction Quality

| # | Item | Effort | Status |
|---|------|--------|--------|
| 13 | Postcode-to-town lookup table | Small | Open |
| 9 | Extraction misses address lines on some layouts | Medium | Open — investigation needed |
| 11 | GP data not extracted from some documents | Medium | Open — related to #9 |
| 10 | Duplicate phone numbers | Small | Open |
| 7 | Use metadata.fullText as extraction fallback | Medium | Open |

## Priority 3: UI Polish

| # | Item | Effort | Status |
|---|------|--------|--------|
| 22 | Traffic light filters on iPad/iPhone | Medium | Open |
| 15 | Recipient tick boxes in AddressesView | Medium | Open |
| 14 | DOB format: DD/MM/YYYY to ISO 8601 | Small | Open |

## Priority 4: Compose Module Enhancements

| # | Item | Effort | Status |
|---|------|--------|--------|
| — | iOS compose access | Large | Open |
| — | Drafts list / sidebar | Medium | Open |
| — | Work list reimplementation | Large | Open — needs separate container |
| 19c | Custom/user-editable templates | Large | Open — long-term |

## Priority 5: Future / Exploratory

| # | Item | Effort | Status |
|---|------|--------|--------|
| 24 | Visual form template builder for OCR | Large | Open — long-term |
| 23 | Local peer-to-peer sync (Multipeer/Bonjour) | Large | Open |
| 20 | iPhone camera as scanner for Mac (Continuity Camera) | Medium | Open |
| 1 | Connected scanner support on macOS | Parked | Not our direction |

---

## Completed

| # | Item | Date |
|---|------|------|
| 17 | Document auto-reload after InjectWatcher appends PDF | 2026-03-22 |
| 21b | Cannot add a new GP card | 2026-03-22 |
| 21c | GP card save reverts to patient data | 2026-03-22 |
| 25 | Click NHS candidate to adopt as GP contact | 2026-03-22 |
| — | Live NHS lookup on GP postcode change | 2026-03-22 |
| — | Overrides not loading on document reopen | 2026-03-22 |
| — | Address card type display (selectedType fix) | 2026-03-22 |
| — | Derive surname/firstname from fullName | 2026-03-22 |
| — | Sync fullName @State after save | 2026-03-22 |
| 8 | Sanitize folder/document names — strip URL-breaking chars | 2026-03-22 |
| — | Title case enforcement for document names (O'Brien, McDonald) | 2026-03-22 |
| — | Live NHS lookup on GP postcode change | 2026-03-22 |
| — | Unified side panel (thumbnails + info in one panel) | 2026-03-22 |
| — | Configurable panel position (left/right) | 2026-03-22 |
| — | Appearance setting (System/Light/Dark) | 2026-03-22 |
| — | macOS Settings scene (Cmd+,) | 2026-03-22 |
| — | Reorder info tabs (workflow order) + merge Debug into Metadata | 2026-03-22 |
| — | Icon tab picker for unified panel | 2026-03-22 |
| 12 | iCloud override race condition | 2026-03-21 |
| 18 | Typst replaces LaTeX for rendering | 2026-03-21 |
| — | Local Typst rendering (30ms, no server) | 2026-03-21 |
| — | All Devon services retired | 2026-03-21 |
| — | iPad Air watchdog crash fix | 2026-03-21 |
| — | New Letter button | 2026-03-21 |
| — | Version 2.0 | 2026-03-21 |
| 16 | HTML template leading comma | Irrelevant — Typst renders now |
| 3 | Expandable Typst dashboard | Irrelevant — Devon retired |
| — | Swift extraction service on Devon | Superseded — extraction in-app |

---

## Suggested Next Sessions

**Session A (at work):** Items 19a + 19b (letter template). Bring envelope measurements. Pure Typst, no app code.

**Session B:** Item 26 (performance). Measure with Instruments, identify bottlenecks, set targets.

**Session C:** Items 13 + 10 (postcode lookup + phone dedup). Extraction quality.

**Session D:** Item 22 (traffic lights on iPad). UI parity across platforms.

**Session E:** iOS compose. The big one — bring letter writing to iPad.
