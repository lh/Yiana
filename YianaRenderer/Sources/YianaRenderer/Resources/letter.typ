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
#let has-postal-address = recipient.role != "hospital_records" and recipient.address.len() > 0
#let signer-name = sender.name.replace("MBBS", "").replace("BSc", "").replace("FRCOphth", "").replace("FRCS", "").replace("MD", "").replace("PhD", "").split(",").first().trim()

// Date formatting
#let today = datetime.today()
#let day = today.day()
#let suffix = if day in (1, 21, 31) { "st" } else if day in (2, 22) { "nd" } else if day in (3, 23) { "rd" } else { "th" }
#let letter-date = today.display("[weekday], [day padding:none]") + suffix + today.display(" [month repr:long] [year]")
#let letter-location = sender.hospital

// -- Page setup --
#let body-size = if is-patient-copy { 14pt } else { 11pt }
#let body-leading = if is-patient-copy { 1.4em } else { 1.2em }

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

// -- Sender header (bold italic) --
#let header-line(content) = {
  text(weight: "bold", style: "italic", content)
  linebreak()
}

#{
  set text(size: 11pt)
  header-line(sender.name)
  header-line(sender.role)
  if sender.department != "" { header-line(sender.department) }
  header-line(sender.hospital)
  for line in sender.address {
    header-line(line)
  }
  header-line[Ph: #sender.phone]
}

// -- Date and location --
#v(0.3em)
#letter-date.

#letter-location.

// -- Postal address for windowed envelope --
#if has-postal-address {
  v(0.5em)
  for line in recipient.address {
    line
    linebreak()
  }
  v(0.3em)
}

// -- Re: line (bold) --
#v(0.3em)
#text(weight: "bold")[Re: #patient.name. DOB: #patient.dob. PN: #patient.mrn. #if patient.address.len() > 0 [Add: #patient.address.join(" ").] #if patient.phones.len() > 0 [Tel: #patient.phones.first().]]

// -- Body --
#v(0.5em)
#body-text

// -- Sign-off --
#v(2em)
#signer-name

// -- CC lines --
#v(0.3em)
#for r in all-recipients {
  if r.role != recipient.role and r.role != "hospital_records" [
    Cc: #r.name #if r.at("practice", default: none) != none [#r.practice] #r.address.join(", ").

  ]
}
