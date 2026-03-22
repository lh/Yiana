# Yiana 2.0 — Polish Roadmap

Updated 2026-03-22 (afternoon). The core app is self-sufficient and working.

---

## Priority 1: Daily Use

| # | Item | Effort | Status |
|---|------|--------|--------|
| 26 | Performance: note loading/exiting speed | Medium | Open — measure first, then fix |
| 31 | Sender details in Settings UI | Medium | Open — essential for other users |
| 19a | Envelope window alignment | Small | Open — need measurements from work |
| 27 | Restore last state on launch (folder + document) | Small | Open |
| 29 | DOB field validation / date picker | Small | Open — do with #14 |

## Priority 2: Extraction Quality

| # | Item | Effort | Status |
|---|------|--------|--------|
| 9 | Extraction misses address lines on some layouts | Medium | Open — investigation needed |
| 11 | GP data not extracted from some documents | Medium | Open — related to #9 |
| 10 | Duplicate phone numbers | Small | Open |
| 7 | Use metadata.fullText as extraction fallback | Medium | Open |

## Priority 3: UI Polish

| # | Item | Effort | Status |
|---|------|--------|--------|
| 22 | Traffic light filters on iPad/iPhone | Medium | Open |
| 14 | DOB format: DD/MM/YYYY to ISO 8601 | Small | Open |
| 28 | Rename "Prime" to "Verified" | Small | Open — codebase-wide rename |

## Priority 4: Compose Module Enhancements

| # | Item | Effort | Status |
|---|------|--------|--------|
| — | iOS compose access | Large | Open |
| 30 | Built-in letter preview (iPad) | Small | Open — bundle with iOS compose |
| — | Drafts list / sidebar | Medium | Open |
| — | Work list reimplementation | Large | Open — needs separate container |
| 19c | Custom/user-editable templates | Large | Open — long-term |

## Priority 5: Future / Exploratory

| # | Item | Effort | Status |
|---|------|--------|--------|
| 24 | Visual form template builder for OCR | Large | Open — long-term |
| 23 | Local peer-to-peer sync (Multipeer/Bonjour) | Large | Open |
| 20 | iPhone camera as scanner for Mac (Continuity Camera) | Medium | Open |
| 32 | Auto-update postcode lookup from ONS ONSPD | Small | Open — direct download URL works |
| 1 | Connected scanner support on macOS | Parked | Not our direction |

---

## Completed

| # | Item | Date |
|---|------|------|
| 13 | Postcode-to-town lookup — full 9,603 sectors from ONS ONSPD | 2026-03-22 |
| — | County lookup from postcode (3,058 sectors, ceremonial counties) | 2026-03-22 |
| — | Live town + county fill on postcode edit | 2026-03-22 |
| — | Fix add address when no main JSON exists | 2026-03-22 |
| — | Fix green indicator for manual-only addresses | 2026-03-22 |
| — | MRN passed to letter, PN renamed to MRN, hidden when empty | 2026-03-22 |
| — | Per-letter print icons + Print All fix (all PDFs) | 2026-03-22 |
| — | Re-generate after editing (Generate Letter enabled in rendered state) | 2026-03-22 |
| — | Letter body stays selectable/editable after rendering | 2026-03-22 |
| — | Save Draft button removed, renamed to Generate Letter | 2026-03-22 |
| 15 | Recipient tick boxes (To/CC/None per verified card) | 2026-03-22 |
| — | Collapsible unverified cards (hidden by default) | 2026-03-22 |
| — | Title case for document names (O'Brien, McDonald) | 2026-03-22 |
| 8 | Sanitize folder/document names — strip URL-breaking chars | 2026-03-22 |
| 19b | Footer contact block on every page | 2026-03-22 |
| — | Slim header (name/role only, contact details in footer) | 2026-03-22 |
| — | Live NHS lookup on GP postcode change | 2026-03-22 |
| 25 | Click NHS candidate to adopt as GP contact | 2026-03-22 |
| — | Derive surname/firstname from fullName | 2026-03-22 |
| — | Sync fullName @State after save | 2026-03-22 |
| — | Address card type display fix (selectedType) | 2026-03-22 |
| — | Overrides not loading on document reopen | 2026-03-22 |
| 17 | Document auto-reload after InjectWatcher appends PDF | 2026-03-22 |
| 21b | Cannot add a new GP card | 2026-03-22 |
| 21c | GP card save reverts to patient data | 2026-03-22 |
| — | Unified side panel (thumbnails + info in one panel) | 2026-03-22 |
| — | Configurable panel position (left/right) live from Settings | 2026-03-22 |
| — | Appearance setting (System/Light/Dark) | 2026-03-22 |
| — | macOS Settings scene (Cmd+,) | 2026-03-22 |
| — | Reorder info tabs + merge Debug into Metadata | 2026-03-22 |
| — | Icon tab picker for unified panel | 2026-03-22 |
| — | Platform scope check rule (feedback) | 2026-03-22 |
| 12 | iCloud override race condition | 2026-03-21 |
| 18 | Typst replaces LaTeX for rendering | 2026-03-21 |
| — | Local Typst rendering (30ms, no server) | 2026-03-21 |
| — | All Devon services retired | 2026-03-21 |
| — | iPad Air watchdog crash fix | 2026-03-21 |
| — | New Letter button | 2026-03-21 |
| — | Version 2.0 | 2026-03-21 |
| 16 | HTML template leading comma | Irrelevant |
| 3 | Expandable Typst dashboard | Irrelevant |

---

## Suggested Next Sessions

**Session A (at work):** Item 19a (envelope window alignment). Bring measurements. Pure Typst template.

**Session B:** Items 31 + 27 (sender details UI + restore last state). Settings work.

**Session C:** Item 26 (performance). Measure with Instruments, identify bottlenecks.

**Session D:** Items 9 + 11 (extraction missing address lines + GP data). Investigation.

**Session E:** iOS compose + letter preview (#30). The big one.
