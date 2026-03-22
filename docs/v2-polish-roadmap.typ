// Yiana 2.0 Polish Roadmap — The Gaudy Edition
#let hot-pink = rgb("ff6ec7")
#let cyan = rgb("00ffff")
#let neon-green = rgb("00ff88")
#let neon-orange = rgb("ffaa00")
#let neon-red = rgb("ff4444")
#let neon-purple = rgb("bf5fff")
#let pale-grey = rgb("e0e0e0")
#let mid-grey = rgb("888888")
#let dark-grey = rgb("666666")
#let light-grey = rgb("aaaaaa")
#let white = rgb("ffffff")
#let near-black = rgb("1a0533")
#let dark-blue = rgb("0d1b2a")

#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2cm, left: 2cm, right: 2cm),
  fill: gradient.linear(near-black, dark-blue, angle: 135deg),
  header: context {
    if counter(page).get().first() > 1 {
      set text(8pt, fill: hot-pink)
      [Yiana 2.0 Polish Roadmap]
      h(1fr)
      [Page #counter(page).display()]
    }
  },
)

#set text(
  font: "New Computer Modern",
  size: 10pt,
  fill: pale-grey,
)

#set par(justify: true, leading: 0.7em)

// Neon heading styles
#let neon-title(body) = {
  align(center)[
    #text(size: 36pt, weight: "bold", fill: hot-pink)[#body]
  ]
}

#let neon-subtitle(body) = {
  align(center)[
    #text(size: 14pt, fill: cyan, style: "italic")[#body]
  ]
}

#let section-head(icon, title, color) = {
  v(0.8em)
  block(
    width: 100%,
    inset: 12pt,
    radius: 8pt,
    fill: color.lighten(85%).transparentize(70%),
    stroke: (left: 4pt + color),
  )[
    #text(size: 16pt, weight: "bold", fill: color)[#icon #title]
  ]
  v(0.3em)
}

#let effort-pill(effort) = {
  let color = if effort == "Small" { neon-green }
              else if effort == "Medium" { neon-orange }
              else if effort == "Large" { neon-red }
              else { mid-grey }
  box(
    inset: (x: 6pt, y: 2pt),
    radius: 10pt,
    fill: color.transparentize(70%),
  )[#text(size: 8pt, weight: "bold", fill: color)[#effort]]
}

#let item-row(num, title, effort, notes, accent) = {
  block(
    width: 100%,
    inset: (x: 10pt, y: 6pt),
    radius: 4pt,
    fill: white.transparentize(92%),
  )[
    #grid(
      columns: (auto, 1fr, auto),
      column-gutter: 10pt,
      [#text(weight: "bold", fill: accent)[#num]],
      [
        #text(weight: "bold", fill: white)[#title] \
        #text(size: 8.5pt, fill: light-grey)[#notes]
      ],
      [#effort-pill(effort)]
    )
  ]
  v(2pt)
}

#let session-block(letter, color, items) = {
  box(
    width: 100%,
    inset: 10pt,
    radius: 8pt,
    stroke: 1.5pt + color,
    fill: color.transparentize(90%),
  )[
    #text(weight: "bold", size: 11pt, fill: color)[Session #letter] \
    #text(size: 9pt, fill: rgb("cccccc"))[#items]
  ]
}

// === TITLE PAGE ===

#v(3cm)

#neon-title[YIANA 2.0]

#v(0.5cm)

#align(center)[
  #block(
    inset: 16pt,
    radius: 12pt,
    fill: gradient.linear(hot-pink.transparentize(80%), cyan.transparentize(80%), angle: 90deg),
    stroke: 1pt + hot-pink.transparentize(50%),
  )[
    #text(size: 20pt, weight: "bold", fill: white)[POLISH ROADMAP]
  ]
]

#v(0.8cm)

#neon-subtitle[Post-Consolidation Backlog]

#v(0.3cm)

#align(center)[
  #text(size: 10pt, fill: mid-grey)[Generated 21 March 2026 --- The core app is self-sufficient and working.]
]

#v(1.5cm)

#align(center)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 12pt,
    box(inset: 12pt, radius: 8pt, fill: hot-pink.transparentize(85%), stroke: 1pt + hot-pink)[
      #align(center)[
        #text(size: 28pt, weight: "bold", fill: hot-pink)[0] \
        #text(size: 9pt, fill: hot-pink)[SERVERS NEEDED]
      ]
    ],
    box(inset: 12pt, radius: 8pt, fill: cyan.transparentize(85%), stroke: 1pt + cyan)[
      #align(center)[
        #text(size: 28pt, weight: "bold", fill: cyan)[30ms] \
        #text(size: 9pt, fill: cyan)[LETTER RENDER]
      ]
    ],
    box(inset: 12pt, radius: 8pt, fill: neon-green.transparentize(85%), stroke: 1pt + neon-green)[
      #align(center)[
        #text(size: 28pt, weight: "bold", fill: neon-green)[5] \
        #text(size: 9pt, fill: neon-green)[YEARS IN THE MAKING]
      ]
    ],
  )
]

#pagebreak()

// === PRIORITY 1 ===

#section-head(sym.excl, "DAILY USE BLOCKERS", neon-red)

#text(size: 9pt, fill: rgb("ff9999"))[These affect the compose-and-print workflow in clinic.]

#v(0.3em)

#item-row("17", "Auto-reload after letter injection", "Medium",
  "NSFilePresenter or notification. Currently must close/reopen to see appended letter.", neon-red)

#item-row("19a", "Envelope window alignment", "Small",
  "Position address block for standard window envelope. Need measurements from work stationery.", neon-red)

#item-row("19b", "Footer contact block", "Small",
  "Restore sender/secretary details at bottom. Typst template change only.", neon-red)

#item-row("21b", "Cannot add a new GP card", "Small",
  "UI flow for adding GP addresses missing or broken.", neon-red)

#item-row("21c", "GP card save reverts to patient data", "Medium",
  "Save path writes back original data rather than edited fields. Bug in AddressesView.", neon-red)


// === PRIORITY 2 ===

#section-head(sym.diamond.stroked, "EXTRACTION QUALITY", neon-orange)

#text(size: 9pt, fill: rgb("ffcc66"))[Better data in = better letters out.]

#v(0.3em)

#item-row("13", "Postcode-to-town lookup table", "Small",
  "~2,900 outward codes, ~100KB. Replaces OCR city heuristics. 97.6% postcode accuracy.", neon-orange)

#item-row("9", "Extraction misses address lines", "Medium",
  "Some layouts not recognised by label/form extractors. Investigation needed.", neon-orange)

#item-row("11", "GP data not extracted from some docs", "Medium",
  "Extractor doesn't recognise some GP info layouts. Related to above.", neon-orange)

#item-row("10", "Duplicate phone numbers", "Small",
  "Deduplicate in phone extraction.", neon-orange)

#item-row("7", "Use fullText as extraction fallback", "Medium",
  "Cross-check or fall back to flat OCR text when structured JSON missing.", neon-orange)


// === PRIORITY 3 ===

#section-head(sym.star.stroked, "UI POLISH", cyan)

#text(size: 9pt, fill: cyan.lighten(40%))[Better experience, not blocking daily use.]

#v(0.3em)

#item-row("22", "Traffic light filters on iPad/iPhone", "Medium",
  "Port macOS document state filters. Suppress empty states.", cyan)

#item-row("15", "Recipient tick boxes in AddressesView", "Medium",
  "To/CC/None toggles per card. Override rules-based defaults.", cyan)

#item-row("14", "DOB format to ISO 8601", "Small",
  "Change parsePatientFilename, rebuild entity DB. Sorts correctly.", cyan)

#item-row("8", "Special chars in folder names", "Medium",
  "Question marks, hashes, percents cause documents to silently move. URL encoding.", cyan)

#item-row("16", "Leading comma when department empty", "Tiny",
  "Filter empties before joining. May be irrelevant now Typst renders.", cyan)


// === PRIORITY 4 ===

#section-head(sym.suit.diamond, "COMPOSE ENHANCEMENTS", neon-purple)

#text(size: 9pt, fill: neon-purple.lighten(30%))[Build out the letter writing experience.]

#v(0.3em)

#item-row("--", "iOS compose access", "Large",
  "Info panel is macOS-only. Need compose UI for iPad.", neon-purple)

#item-row("--", "Drafts list / sidebar", "Medium",
  "Cross-document view of pending drafts.", neon-purple)

#item-row("--", "Work list reimplementation", "Large",
  "Reverted March 2026. Needs separate container from sidebar List.", neon-purple)

#item-row("19c", "Custom/user-editable templates", "Large",
  "Template selection, in-app editor, or user-supplied .typ files. Long-term.", neon-purple)

#pagebreak()

// === PRIORITY 5 ===

#section-head(sym.arrow.r.double, "FUTURE / EXPLORATORY", mid-grey)

#text(size: 9pt, fill: light-grey)[Not needed now. Worth tracking.]

#v(0.3em)

#item-row("23", "Local peer-to-peer sync", "Large",
  "Multipeer Connectivity / Bonjour. Direct device sync, bypass iCloud latency.", mid-grey)

#item-row("20", "iPhone camera as Mac scanner", "Medium",
  "Continuity Camera. Native Apple API. Multi-page support unclear.", mid-grey)

#item-row("1", "Connected scanner support", "Parked",
  "DevonTHINK territory. Not our direction.", mid-grey)


// === SESSION PLAN ===

#v(1cm)

#section-head(sym.checkmark, "SUGGESTED SESSIONS", neon-green)

#v(0.3em)

#grid(
  columns: (1fr, 1fr),
  column-gutter: 10pt,
  row-gutter: 10pt,
  session-block("A", hot-pink,
    [*Letter template polish* --- Bring envelope measurements. Items 19a + 19b. Pure Typst, no app code.]),
  session-block("B", cyan,
    [*Auto-reload + GP save bug* --- Items 17 + 21c. Two medium fixes for daily workflow.]),
  session-block("C", neon-orange,
    [*Extraction quality* --- Items 13 + 10. Postcode lookup + phone dedup.]),
  session-block("D", neon-purple,
    [*Traffic lights on iPad* --- Item 22. UI parity across platforms.]),
)

#v(0.5cm)

#session-block("E", neon-red,
  [*iOS compose* --- The big one. Bring letter writing to iPad.])


// === FOOTER ===

#v(1.5cm)

#align(center)[
  #block(
    inset: 16pt,
    radius: 8pt,
    fill: white.transparentize(95%),
  )[
    #text(size: 8pt, fill: dark-grey)[
      Yiana 2.0 --- Scan. Extract. Compose. Render. All on-device. \
      No servers. No Python. No LaTeX. No excuses. \
      #text(fill: hot-pink)[Built with love, Typst, and entirely too much neon.]
    ]
  ]
]
