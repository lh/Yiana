// Yiana Letter Template
// Renders clinical correspondence from JSON data passed via sys.inputs.

#let data = json(bytes(sys.inputs.data))
#let sender = data.sender
#let patient = data.patient
#let recipient = data.recipient
#let all-recipients = data.all_recipients
#let is-patient-copy = data.is_patient_copy
#let body-text = data.body

// -- Derived values --
#let has-postal-address = recipient.role != "hospital_records"
#let signer-name = sender.name.replace("MBBS", "").replace("BSc", "").replace("FRCOphth", "").replace("FRCS", "").replace("MD", "").replace("PhD", "").split(",").first().trim()

// Date formatting
#let today = datetime.today()
#let day = today.day()
#let suffix = if day in (1, 21, 31) { "st" } else if day in (2, 22) { "nd" } else if day in (3, 23) { "rd" } else { "th" }
#let letter-date = today.display("[weekday], [day padding:none]") + suffix + today.display(" [month repr:long] [year]")

// -- Contact footer content (built once, used in page footer) --
#let footer-content = {
  line(length: 100%, stroke: 0.4pt)
  v(2mm)
  set text(size: 8pt)

  if sender.at("secretary", default: none) != none {
    let sec = sender.secretary
    let parts = ("Secretary: " + sec.name,)
    let parts = if sec.phone != "" { parts + ("Tel: " + sec.phone,) } else { parts }
    let parts = if sec.email != "" { parts + ("Email: " + sec.email,) } else { parts }
    parts.join(" | ")
    linebreak()
  }

  let contact = (sender.hospital,)
  let contact = if sender.address.len() > 0 { contact + (sender.address.join(", "),) } else { contact }
  let contact = if sender.phone != "" { contact + ("Tel: " + sender.phone,) } else { contact }
  contact.join(" | ")
}

// -- Page setup --
#let body-size = if is-patient-copy { 13pt } else { 11pt }
#let body-leading = if is-patient-copy { 1.2em } else { 1.1em }

#set page(
  paper: "a4",
  margin: (top: 4.5cm, bottom: 3.5cm, left: 4.5cm, right: 4.5cm),
  header: context {
    if counter(page).get().first() > 1 {
      set text(9pt, style: "italic")
      if not is-patient-copy {
        patient.name + " — " + patient.mrn
        h(1fr)
      }
      "Page " + counter(page).display("1")
    }
  },
  footer: footer-content,
)

#set text(
  font: "New Computer Modern",
  size: 11pt,
  lang: "en",
  region: "gb",
  hyphenate: true,
)

#set par(
  justify: true,
  first-line-indent: 0pt,
  spacing: 0.8em,
  leading: 1.2em,
)

// -- Sender header + date (top-right, bold italic) --
#place(top + right)[
  #set text(size: 11pt)
  #align(right)[
    #text(weight: "bold", style: "italic", sender.name) \
    #text(weight: "bold", style: "italic", sender.role)
    #if sender.department != "" [
      \ #text(weight: "bold", style: "italic", sender.department)
    ]

    #letter-date.
  ]
]

// -- Re: line (bold) --
#v(10em)
#text(weight: "bold")[Re: #patient.name. DOB: #patient.dob. #if patient.mrn != "" [MRN: #patient.mrn. ]#if patient.address.len() > 0 [Add: #patient.address.join(" ").] #if patient.phones.len() > 0 [Tel: #patient.phones.first().]]

// -- Salutation / cover line --
#v(0.5em)
#if recipient.role == "to" [
  Dear #patient.title #patient.surname,
] else [
  Please see below a copy of a letter I sent to #patient.title #patient.surname today.
]

// -- Body --
#v(0.5em)
#{
  set text(size: body-size)
  set par(leading: body-leading)
  body-text

  // -- Sign-off --
  v(2em)
  signer-name
}

// -- CC lines (exclude primary recipient and hospital_records; bold current copy's recipient) --
#v(0.3em)
#for r in all-recipients {
  if r.role != "to" and r.role != "hospital_records" {
    let is-current = r.name == recipient.name and r.role == recipient.role
    let cc-text = [#r.name #if r.at("practice", default: none) != none [#r.practice] #r.address.join(", ").]
    if is-current [
      Cc: #text(weight: "bold")[#cc-text]
    ] else [
      Cc: #cc-text
    ]
    linebreak()
  }
}
