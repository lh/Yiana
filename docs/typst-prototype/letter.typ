// Yiana Letter Template — Typst
// Renders clinical correspondence from draft JSON data.
//
// Usage: typst compile letter.typ --input data=draft.json

// -- Parameters --
// In production these come from JSON; for now, hardcoded sample data.

#let sender = (
  name: "Mr Luke Herbert MBBS BSc FRCOphth",
  role: "Consultant Ophthalmologist",
  practice: "Private Practice",
  hospital: "Gatwick Park Hospital",
  address: ("Povey Cross Road", "Horley", "Surrey", "RH6 0BB"),
  phone: "0207 8849411",
  mobile: "07956 226276",
  secretary: (
    name: "Mrs Liz Matthews",
    phone: "020 7884 9411",
    email: "referrals@vitygas.com",
  ),
)

#let patient = (
  name: "Mr Fiction Fictional",
  dob: "20/05/1960",
  mrn: "0012386780",
  address: "87 Riverside Road Bluehill RH9 5EE",
  phone: "07956303735",
)

#let recipients = (
  (role: "gp", name: "Dr J Shaw", address: "12 Thornton Side RH1 2NP"),
  (role: "optician", name: "David Clulow Opticians", address: "Unit 6. Promenade Level, Cabot Place London E14 4QT"),
)

#let letter-date = "Friday 20th March 2026"
#let letter-location = "Gatwick Park Hospital"
#let signer-name = "Mr Luke Herbert"

// Set true for patient copy (14pt, wider spacing)
#let is-patient-copy = false

// -- Postal address (for windowed envelope) --
// Set to none for hospital records copy
#let postal-address = none

// -- Body text --
#let body-text = [
It was a pleasure to meet you in clinic for the first time today. You came to see me because you have had two episodes of visual disturbance; your optician was also concerned about the possibility of glaucoma.

Your vision today measured 6/5 in the right eye and 6/5 in the left with glasses. Your pressure was 11mmHg right and 12mmHg left. The visual fields from your optician were full. OCT scanning showed normal optic nerve and ganglion cell layer thickness in both eyes, and the optic nerves looked healthy on examination. You are at low risk of having glaucoma and I would not recommend any further investigation or follow-up for this.

The visual episodes you describe are characteristic of migraine aura: fortification spectra lasting around 15 minutes are typical. Migraine in adults frequently presents without any headache at all; this is common and does not indicate anything more serious.

Your (self-measured) blood pressure is normal at 108/72. No further investigations are needed for this. If the episodes become more frequent, prolonged, or change in character, please see your GP.

Please don't hesitate to contact me (#sender.mobile) if you have any problems.

I reviewed the results of your blood tests which were all within normal limits. Your full blood count, kidney function, liver function, thyroid function, and blood glucose were all satisfactory. Your cholesterol was 4.2 which is within the desirable range.

I also reviewed the results of the MRI scan of your orbits which was reported as normal. There was no evidence of any compressive lesion along the visual pathway and the optic nerves appeared healthy bilaterally. The brain parenchyma was unremarkable for your age.

With regard to your dry eye symptoms, I would recommend continuing with preservative-free artificial tears four times daily. If symptoms persist despite this, we could consider punctal plugs at a future visit. In the meantime, warm compresses applied to the closed eyelids for ten minutes twice daily may help with meibomian gland function.

I have also arranged for you to have a Humphrey visual field test and an OCT scan of the macula at your next visit. These investigations will provide a more detailed assessment of your peripheral vision and the health of the central retina respectively. I anticipate that these will be normal given today's clinical findings, but they will serve as a useful baseline for future comparison.

I plan to review you in six months with the results of these investigations. My secretary will be in touch with an appointment. In the interim, if you experience any sudden change in vision, flashing lights, or a shadow appearing in your peripheral vision, please attend your nearest eye casualty department as an emergency.

I have copied this letter to your GP, Dr Shaw, and to your optician, David Clulow Opticians, for their records. I would be grateful if Dr Shaw could continue to monitor your blood pressure annually given the family history of hypertension that you mentioned.

Thank you once again for coming to see me today. It was a pleasure to meet you and I hope I have been able to reassure you regarding the concerns that prompted this referral.
]

// ============================================================
// TEMPLATE
// ============================================================

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
  if sender.practice != "" { header-line(sender.practice) }
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
#if postal-address != none {
  v(0.5em)
  for line in postal-address {
    line
    linebreak()
  }
  v(0.3em)
}

// -- Re: line (bold) --
#v(0.3em)
#text(weight: "bold")[Re: #patient.name. DOB: #patient.dob. PN: #patient.mrn. Add: #patient.address. Tel: #patient.phone.]

// -- Body --
#v(0.5em)
#body-text

// -- Sign-off --
#v(0.5em)
With best wishes

Yours sincerely

#signer-name

// -- CC lines --
#v(0.3em)
#for r in recipients [
  Cc: #r.name #r.address.

]
