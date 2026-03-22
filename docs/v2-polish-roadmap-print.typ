// Yiana 2.0 Polish Roadmap — Print Edition
#let hot-pink = rgb("cc2277")
#let cyan = rgb("0088aa")
#let neon-green = rgb("228844")
#let neon-orange = rgb("cc7700")
#let neon-red = rgb("cc2222")
#let neon-purple = rgb("7733bb")
#let body-text = rgb("333333")
#let subtle = rgb("666666")
#let white = rgb("ffffff")

#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2cm, left: 2cm, right: 2cm),
  fill: white,
  header: context {
    if counter(page).get().first() > 1 {
      set text(8pt, fill: hot-pink)
      [Yiana 2.0 Polish Roadmap]
      h(1fr)
      [Page #counter(page).display()]
    }
  },
)

#set text(font: "New Computer Modern", size: 10pt, fill: body-text)
#set par(justify: true, leading: 0.7em)

#let section-head(icon, title, color) = {
  v(0.8em)
  block(width: 100%, inset: 12pt, radius: 8pt, fill: color.lighten(85%), stroke: (left: 4pt + color))[
    #text(size: 16pt, weight: "bold", fill: color)[#icon #title]
  ]
  v(0.3em)
}

#let effort-pill(effort) = {
  let color = if effort == "Small" { neon-green } else if effort == "Medium" { neon-orange } else if effort == "Large" { neon-red } else { subtle }
  box(inset: (x: 6pt, y: 2pt), radius: 10pt, fill: color.lighten(80%), stroke: 0.5pt + color)[
    #text(size: 8pt, weight: "bold", fill: color)[#effort]
  ]
}

#let item-row(num, title, effort, notes, accent) = {
  block(width: 100%, inset: (x: 10pt, y: 6pt), radius: 4pt, fill: rgb("f5f5f5"), stroke: 0.5pt + rgb("e0e0e0"))[
    #grid(columns: (auto, 1fr, auto), column-gutter: 10pt,
      [#text(weight: "bold", fill: accent)[#num]],
      [#text(weight: "bold")[#title] \ #text(size: 8.5pt, fill: subtle)[#notes]],
      [#effort-pill(effort)])
  ]
  v(2pt)
}

#let session-block(letter, color, items) = {
  box(width: 100%, inset: 10pt, radius: 8pt, stroke: 1.5pt + color, fill: color.lighten(92%))[
    #text(weight: "bold", size: 11pt, fill: color)[Session #letter] \
    #text(size: 9pt, fill: body-text)[#items]
  ]
}

// === TITLE ===
#v(3cm)
#align(center)[#text(size: 36pt, weight: "bold", fill: hot-pink)[YIANA 2.0]]
#v(0.5cm)
#align(center)[#block(inset: 16pt, radius: 12pt, fill: hot-pink.lighten(90%), stroke: 1.5pt + hot-pink)[
  #text(size: 20pt, weight: "bold", fill: hot-pink)[POLISH ROADMAP]
]]
#v(0.8cm)
#align(center)[#text(size: 14pt, fill: cyan, style: "italic")[Post-Consolidation Backlog]]
#v(0.3cm)
#align(center)[#text(size: 10pt, fill: subtle)[Generated 21 March 2026 --- The core app is self-sufficient and working.]]
#v(1.5cm)
#align(center)[#grid(columns: (1fr, 1fr, 1fr), column-gutter: 12pt,
  box(inset: 12pt, radius: 8pt, fill: hot-pink.lighten(90%), stroke: 1.5pt + hot-pink)[
    #align(center)[#text(size: 28pt, weight: "bold", fill: hot-pink)[0] \ #text(size: 9pt, weight: "bold", fill: hot-pink)[SERVERS NEEDED]]],
  box(inset: 12pt, radius: 8pt, fill: cyan.lighten(90%), stroke: 1.5pt + cyan)[
    #align(center)[#text(size: 28pt, weight: "bold", fill: cyan)[30ms] \ #text(size: 9pt, weight: "bold", fill: cyan)[LETTER RENDER]]],
  box(inset: 12pt, radius: 8pt, fill: neon-green.lighten(90%), stroke: 1.5pt + neon-green)[
    #align(center)[#text(size: 28pt, weight: "bold", fill: neon-green)[5] \ #text(size: 9pt, weight: "bold", fill: neon-green)[YEARS IN THE MAKING]]],
)]

#pagebreak()

#section-head(sym.excl, "DAILY USE BLOCKERS", neon-red)
#text(size: 9pt, fill: neon-red)[These affect the compose-and-print workflow in clinic.]
#v(0.3em)
#item-row("17", "Auto-reload after letter injection", "Medium", "NSFilePresenter or notification. Currently must close/reopen to see appended letter.", neon-red)
#item-row("19a", "Envelope window alignment", "Small", "Position address block for standard window envelope. Need measurements from work stationery.", neon-red)
#item-row("19b", "Footer contact block", "Small", "Restore sender/secretary details at bottom. Typst template change only.", neon-red)
#item-row("21b", "Cannot add a new GP card", "Small", "UI flow for adding GP addresses missing or broken.", neon-red)
#item-row("21c", "GP card save reverts to patient data", "Medium", "Save path writes back original data rather than edited fields. Bug in AddressesView.", neon-red)

#section-head(sym.diamond.stroked, "EXTRACTION QUALITY", neon-orange)
#text(size: 9pt, fill: neon-orange)[Better data in = better letters out.]
#v(0.3em)
#item-row("13", "Postcode-to-town lookup table", "Small", "~2,900 outward codes, ~100KB. Replaces OCR city heuristics. 97.6% postcode accuracy.", neon-orange)
#item-row("9", "Extraction misses address lines", "Medium", "Some layouts not recognised by label/form extractors. Investigation needed.", neon-orange)
#item-row("11", "GP data not extracted from some docs", "Medium", "Extractor doesn't recognise some GP info layouts. Related to above.", neon-orange)
#item-row("10", "Duplicate phone numbers", "Small", "Deduplicate in phone extraction.", neon-orange)
#item-row("7", "Use fullText as extraction fallback", "Medium", "Cross-check or fall back to flat OCR text when structured JSON missing.", neon-orange)

#section-head(sym.star.stroked, "UI POLISH", cyan)
#text(size: 9pt, fill: cyan)[Better experience, not blocking daily use.]
#v(0.3em)
#item-row("22", "Traffic light filters on iPad/iPhone", "Medium", "Port macOS document state filters. Suppress empty states.", cyan)
#item-row("15", "Recipient tick boxes in AddressesView", "Medium", "To/CC/None toggles per card. Override rules-based defaults.", cyan)
#item-row("14", "DOB format to ISO 8601", "Small", "Change parsePatientFilename, rebuild entity DB. Sorts correctly.", cyan)
#item-row("8", "Special chars in folder names", "Medium", "Question marks, hashes, percents cause documents to silently move. URL encoding.", cyan)
#item-row("16", "Leading comma when department empty", "Tiny", "Filter empties before joining. May be irrelevant now Typst renders.", cyan)

#section-head(sym.suit.diamond, "COMPOSE ENHANCEMENTS", neon-purple)
#text(size: 9pt, fill: neon-purple)[Build out the letter writing experience.]
#v(0.3em)
#item-row("--", "iOS compose access", "Large", "Info panel is macOS-only. Need compose UI for iPad.", neon-purple)
#item-row("--", "Drafts list / sidebar", "Medium", "Cross-document view of pending drafts.", neon-purple)
#item-row("--", "Work list reimplementation", "Large", "Reverted March 2026. Needs separate container from sidebar List.", neon-purple)
#item-row("19c", "Custom/user-editable templates", "Large", "Template selection, in-app editor, or user-supplied .typ files. Long-term.", neon-purple)

#pagebreak()

#section-head(sym.arrow.r.double, "FUTURE / EXPLORATORY", subtle)
#text(size: 9pt, fill: subtle)[Not needed now. Worth tracking.]
#v(0.3em)
#item-row("23", "Local peer-to-peer sync", "Large", "Multipeer Connectivity / Bonjour. Direct device sync, bypass iCloud latency.", subtle)
#item-row("20", "iPhone camera as Mac scanner", "Medium", "Continuity Camera. Native Apple API. Multi-page support unclear.", subtle)
#item-row("1", "Connected scanner support", "Parked", "DevonTHINK territory. Not our direction.", subtle)

#v(1cm)
#section-head(sym.checkmark, "SUGGESTED SESSIONS", neon-green)
#v(0.3em)
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 10pt,
  session-block("A", hot-pink, [*Letter template polish* --- Bring envelope measurements. Items 19a + 19b. Pure Typst, no app code.]),
  session-block("B", cyan, [*Auto-reload + GP save bug* --- Items 17 + 21c. Two medium fixes for daily workflow.]),
  session-block("C", neon-orange, [*Extraction quality* --- Items 13 + 10. Postcode lookup + phone dedup.]),
  session-block("D", neon-purple, [*Traffic lights on iPad* --- Item 22. UI parity across platforms.]),
)
#v(0.5cm)
#session-block("E", neon-red, [*iOS compose* --- The big one. Bring letter writing to iPad.])

#v(1.5cm)
#align(center)[#block(inset: 16pt, radius: 8pt, fill: rgb("f0f0f0"), stroke: 0.5pt + rgb("dddddd"))[
  #text(size: 8pt, fill: subtle)[
    Yiana 2.0 --- Scan. Extract. Compose. Render. All on-device. \
    No servers. No Python. No LaTeX. No excuses. \
    #text(fill: hot-pink)[Built with love, Typst, and a reasonable amount of ink.]
  ]
]]
