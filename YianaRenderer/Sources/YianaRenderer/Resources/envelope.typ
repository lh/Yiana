// C5 Envelope Template (229mm x 162mm)
// Prints recipient address centered, sender return address top-left.

#let data = json(bytes(sys.inputs.data))
#let sender = data.sender
#let recipient = data.recipient

#set page(
  width: 229mm,
  height: 162mm,
  margin: (top: 15mm, bottom: 15mm, left: 20mm, right: 20mm),
)

#set text(
  font: "New Computer Modern",
  size: 11pt,
  lang: "en",
  region: "gb",
)

// -- Return address (top-left, small) --
#place(top + left)[
  #set text(size: 8pt, fill: rgb("666666"))
  #sender.name \
  #sender.hospital \
  #sender.address.join(", ")
]

// -- Recipient address (centered in the lower half) --
#place(center + horizon, dy: 15mm)[
  #set text(size: 13pt)
  #recipient.name \
  #for line in recipient.address {
    line
    linebreak()
  }
]
