// Yiana Letter Template
// Renders clinical correspondence from JSON data passed via sys.inputs.
//
// Layout for postal copies (has-postal-address = true):
//   Above fold (0-99mm): sender, date, postal address — all at 20mm left margin
//   Below fold (99mm+):  Re: line, body, sign-off, CC — at 45mm left margin
// Non-postal copies (GP CC, hospital records): standard layout, 45mm margins throughout.

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
#let body-leading = if is-patient-copy { 1.4em } else { 1.2em }
#let left-margin = if has-postal-address { 20mm } else { 4.5cm }

#set page(
  paper: "a4",
  margin: (top: 20mm, bottom: 3.5cm, left: left-margin, right: 20mm),
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
  size: body-size,
  lang: "en",
  region: "gb",
  hyphenate: true,
)

#set par(
  justify: true,
  first-line-indent: 0pt,
  spacing: 0.8em,
  leading: body-leading,
)

// -- Above-fold content --
#if has-postal-address {
  // Postal copies: just date and recipient address, no sender header.
  // Sender details are in the footer on every page.
  letter-date + "."
  // Push address down to envelope window zone (~55mm from top, margin is 20mm = 35mm from content top)
  v(35mm)
  {
    set text(size: 11pt)
    recipient.name
    linebreak()
    for line in recipient.address {
      line
      linebreak()
    }
  }
  // Push body below the fold
  v(1fr)
} else {
  // Non-postal (hospital records): sender header + date
  {
    set text(size: 11pt)
    text(weight: "bold", style: "italic", sender.name)
    linebreak()
    text(weight: "bold", style: "italic", sender.role)
    if sender.department != "" {
      linebreak()
      text(weight: "bold", style: "italic", sender.department)
    }
  }
  v(0.5em)
  letter-date + "."
}

// -- Re: line (bold) --
#v(1em)
#if has-postal-address {
  // After the fold: widen left margin for body text
  pad(left: 25mm)[
    #text(weight: "bold")[Re: #patient.name. DOB: #patient.dob. #if patient.mrn != "" [MRN: #patient.mrn. ]#if patient.address.len() > 0 [Add: #patient.address.join(" ").] #if patient.phones.len() > 0 [Tel: #patient.phones.first().]]

    #v(0.5em)
    #body-text

    #v(2em)
    #signer-name

    #v(0.3em)
    #for r in all-recipients {
      if r.role != recipient.role and r.role != "hospital_records" [
        Cc: #r.name #if r.at("practice", default: none) != none [#r.practice] #r.address.join(", ").

      ]
    }
  ]
} else {
  // Non-postal copies: standard layout
  text(weight: "bold")[Re: #patient.name. DOB: #patient.dob. #if patient.mrn != "" [MRN: #patient.mrn. ]#if patient.address.len() > 0 [Add: #patient.address.join(" ").] #if patient.phones.len() > 0 [Tel: #patient.phones.first().]]

  v(0.5em)
  body-text

  v(2em)
  signer-name

  v(0.3em)
  for r in all-recipients {
    if r.role != recipient.role and r.role != "hospital_records" [
      Cc: #r.name #if r.at("practice", default: none) != none [#r.practice] #r.address.join(", ").

    ]
  }
}
