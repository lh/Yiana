// Yiana Server Status Dashboard
// Reads live data from dashboard-data.json
// Run with: typst watch dashboard.typ

#set document(title: "Yiana Server Status")
#set page(
  paper: "a4",
  margin: (top: 1.5cm, bottom: 1.2cm, left: 1.5cm, right: 1.5cm),
  fill: rgb("#1a1a2e"),
)
#set text(font: "Menlo", size: 10pt, fill: rgb("#e0e0e0"))

// --- Load data ---
#let data = json("dashboard-data.json")

// --- Colour palette ---
#let bg-dark = rgb("#1a1a2e")
#let bg-card = rgb("#16213e")
#let bg-card-alt = rgb("#0f3460")
#let accent = rgb("#00b4d8")
#let green = rgb("#2ecc71")
#let red = rgb("#e74c3c")
#let yellow = rgb("#f1c40f")
#let dim = rgb("#7f8c8d")
#let white = rgb("#ecf0f1")

// --- Helper functions ---
#let age-color(seconds) = {
  if seconds < 120 { green }
  else if seconds < 600 { yellow }
  else { red }
}

#let age-text(s) = {
  if s < 60 { str(s) + "s" }
  else if s < 3600 { str(calc.floor(s / 60)) + "m " + str(calc.rem(s, 60)) + "s" }
  else if s < 86400 { str(calc.floor(s / 3600)) + "h " + str(calc.floor(calc.rem(s, 3600) / 60)) + "m" }
  else { str(calc.floor(s / 86400)) + "d " + str(calc.floor(calc.rem(s, 86400) / 3600)) + "h" }
}

#let status-badge(status) = {
  let (label, color) = if status == "up" { ("UP", green) } else { ("DOWN", red) }
  box(
    fill: color.transparentize(80%),
    stroke: 1pt + color,
    inset: (x: 8pt, y: 3pt),
    radius: 3pt,
  )[#text(fill: color, weight: "bold", size: 9pt)[#label]]
}

#let card(body, title: none) = {
  block(
    fill: bg-card,
    stroke: 1pt + rgb("#2a2a4a"),
    inset: 1em,
    radius: 6pt,
    width: 100%,
  )[
    #if title != none {
      text(fill: accent, weight: "bold", size: 11pt)[#title]
      v(0.5em)
    }
    #body
  ]
}

#let stat-box(label, value, accent-color: accent) = {
  block(
    fill: bg-card-alt,
    inset: (x: 1em, y: 0.8em),
    radius: 4pt,
    width: 100%,
  )[
    #text(fill: dim, size: 8pt, weight: "bold")[#upper(label)]
    #v(0.2em)
    #text(fill: accent-color, size: 20pt, weight: "bold")[#value]
  ]
}

#let progress-bar(percent, width: 100%, color: accent) = {
  let bar-height = 8pt
  let filled = percent * 1% * 100%
  block(width: width)[
    #box(
      width: 100%,
      height: bar-height,
      radius: 4pt,
      fill: rgb("#2a2a4a"),
    )[
      #box(
        width: filled,
        height: bar-height,
        radius: 4pt,
        fill: color,
      )
    ]
  ]
}

// Bar chart using simple blocks
#let bar-chart(history, max-height: 60pt) = {
  let values = history.map(h => h.count)
  let peak = calc.max(1, ..values)

  grid(
    columns: values.map(_ => 1fr),
    gutter: 4pt,
    align: center,
    // Bars
    ..values.map(v => {
      let height = v / peak * max-height
      let intensity = v / peak
      let color = if intensity > 0.7 { accent }
        else if intensity > 0.4 { accent.transparentize(30%) }
        else { accent.transparentize(60%) }
      box(height: max-height)[
        #align(bottom)[
          #block(
            width: 100%,
            height: height,
            radius: (top: 3pt),
            fill: color,
          )
        ]
      ]
    }),
    // Labels
    ..history.map(h => {
      let day = h.date.slice(8)
      text(fill: dim, size: 7pt)[#day]
    }),
    // Values
    ..values.map(v => {
      text(fill: white, size: 7pt, weight: "bold")[#v]
    }),
  )
}

// ═══════════════════════════════════════════════════
// LAYOUT
// ═══════════════════════════════════════════════════

// --- Header ---
#block(width: 100%)[
  #grid(
    columns: (1fr, auto),
    align: (left, right),
    [
      #text(fill: accent, size: 22pt, weight: "bold")[Yiana Server Status]
      #h(0.5em)
      #box(
        fill: green.transparentize(80%),
        stroke: 1pt + green,
        inset: (x: 6pt, y: 2pt),
        radius: 10pt,
      )[#text(fill: green, size: 8pt, weight: "bold")[LIVE]]
    ],
    [
      #text(fill: dim, size: 9pt)[#data.timestamp]
      #v(0.2em)
      #text(fill: dim, size: 8pt)[devon.local]
    ],
  )
]

#v(0.5em)
#line(length: 100%, stroke: 1pt + rgb("#2a2a4a"))
#v(0.5em)

// --- Services ---
#card(title: "Services")[
  #for (i, svc) in data.services.enumerate() {
    if i > 0 { v(0.6em); line(length: 100%, stroke: 0.5pt + rgb("#2a2a4a")); v(0.6em) }

    grid(
      columns: (2.5cm, auto, 1fr, auto),
      gutter: 1em,
      align: (left, left, left, right),
      // Name
      text(fill: white, weight: "bold", size: 11pt)[#svc.name],
      // Status badge
      status-badge(svc.status),
      // Heartbeat
      {
        let age = svc.heartbeat_age_seconds
        let color = age-color(age)
        text(fill: dim, size: 9pt)[HB: ]
        text(fill: color, size: 9pt, weight: "bold")[#age-text(age) ago]
      },
      // PID
      text(fill: dim, size: 9pt)[PID #text(fill: white)[#svc.pid]],
    )

    // Error line
    if svc.last_error != none {
      v(0.3em)
      block(
        inset: (left: 2.5cm + 1em),
      )[
        #text(fill: red, size: 8pt)[#svc.last_error.message]
        #h(0.5em)
        #text(fill: dim, size: 8pt)[(#age-text(svc.last_error.age_seconds) ago)]
      ]
    }

    // Log sizes
    v(0.2em)
    block(
      inset: (left: 2.5cm + 1em),
    )[
      #text(fill: dim, size: 8pt)[Logs: stdout #text(fill: white)[#svc.log_size]  stderr #text(fill: white)[#svc.err_log_size]]
    ]
  }
]

#v(0.6em)

// --- Data Stats ---
#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 0.6em,
  stat-box("Documents", str(data.data.documents)),
  stat-box("OCR Results", str(data.data.ocr_results), accent-color: green),
  stat-box("Addresses", str(data.data.addresses), accent-color: yellow),
)

#v(0.6em)

#grid(
  columns: (1fr, 1fr),
  gutter: 0.6em,

  // OCR activity chart
  card(title: "OCR Activity (7 days)")[
    #bar-chart(data.ocr_history)
    #v(0.4em)
    #grid(
      columns: (1fr, 1fr),
      text(fill: dim, size: 8pt)[Today: #text(fill: accent, weight: "bold")[#data.data.ocr_today processed]],
      text(fill: dim, size: 8pt)[Pending: #text(fill: yellow, weight: "bold")[#data.data.pending_ocr remaining]],
    )
  ],

  // Disk + pipeline status
  {
    card(title: "Disk")[
      #grid(
        columns: (1fr, 1fr, 1fr),
        gutter: 0.5em,
        [
          #text(fill: dim, size: 8pt)[USED]
          #v(0.1em)
          #text(fill: white, size: 12pt, weight: "bold")[#data.disk.used]
        ],
        [
          #text(fill: dim, size: 8pt)[FREE]
          #v(0.1em)
          #text(fill: green, size: 12pt, weight: "bold")[#data.disk.available]
        ],
        [
          #text(fill: dim, size: 8pt)[CAPACITY]
          #v(0.1em)
          #text(fill: white, size: 12pt, weight: "bold")[#data.disk.capacity_percent\%]
        ],
      )
      #v(0.4em)
      #progress-bar(
        data.disk.capacity_percent,
        color: if data.disk.capacity_percent < 60 { green }
          else if data.disk.capacity_percent < 80 { yellow }
          else { red },
      )
    ]
    v(0.6em)
    card(title: "Pipeline")[
      #let total = data.data.documents
      #let done = data.data.ocr_results
      #let pct = calc.round(done / total * 100, digits: 1)
      #grid(
        columns: (1fr, auto),
        [
          #text(fill: dim, size: 8pt)[OCR COMPLETION]
          #v(0.3em)
          #progress-bar(pct, color: green)
        ],
        align(right)[
          #text(fill: green, size: 16pt, weight: "bold")[#pct\%]
        ],
      )
      #v(0.3em)
      #text(fill: dim, size: 8pt)[#done of #total documents processed]
      #v(0.5em)
      #let addr-ratio = calc.round(data.data.addresses / done, digits: 1)
      #text(fill: dim, size: 8pt)[Address yield: #text(fill: yellow, weight: "bold")[#addr-ratio per doc]]
    ]
  },
)

// --- Footer ---
#v(1fr)
#line(length: 100%, stroke: 0.5pt + rgb("#2a2a4a"))
#v(0.3em)
#grid(
  columns: (1fr, auto),
  text(fill: dim, size: 7pt)[Yiana Status Dashboard \u{2F}\u{2F} typst watch dashboard.typ \u{2F}\u{2F} data from dashboard-data.json],
  text(fill: dim, size: 7pt)[Refresh: edit JSON \u{2192} PDF updates in ~50ms],
)
